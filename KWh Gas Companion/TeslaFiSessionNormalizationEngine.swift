//  TeslaFiSessionNormalizationEngine.swift
//  KWh Gas Companion
//
//  Bucket 1: Canonical merge/dedup + anomalies
//  Swift 6 • iOS 17+
//

import Foundation

public enum TeslaFiSessionNormalizationEngine {

    public static func normalize(
        raw sessions: [TeslaFiSession],
        settings: TeslaFiNormalizationSettings = .init()
    ) -> TeslaFiNormalizationResult {

        // 1) Sort by start time (stable)
        let sorted = sessions.sorted { $0.startDate < $1.startDate }

        // 2) Flag suspicious exact duplicates in the *raw* stream (before merging)
        var issues: [TeslaFiSessionIssue] = []
        let groupedByApprox = Dictionary(grouping: sorted, by: { approxFingerprint($0) })
        for (fp, group) in groupedByApprox where group.count >= 2 {
            // If many raw sessions share the same approximate fingerprint, flag them.
            // (Even if you already dedupe by sessionHash, this catches “almost same” rows.)
            for s in group {
                issues.append(.init(
                    sessionID: s.id,
                    severity: .info,
                    kind: .suspiciousDuplicate,
                    message: "Multiple sessions look nearly identical (fp: \(fp.prefix(24))…)."
                ))
            }
        }

        // 3) Merge pass
        var canonical: [TeslaFiSession] = []
        var mergeMap: [UUID: [UUID]] = [:]

        var i = 0
        while i < sorted.count {
            var base = sorted[i]
            var mergedIDs: [UUID] = [base.id]

            // We may swap inverted dates for canonical presentation, but still flag it.
            if base.endDate < base.startDate {
                issues.append(.init(
                    sessionID: base.id,
                    severity: .critical,
                    kind: .endBeforeStart,
                    message: "End time occurs before start time."
                ))
                base = swappedIfNeeded(base)
            }

            var j = i + 1
            while j < sorted.count {
                var next = sorted[j]

                if next.endDate < next.startDate {
                    issues.append(.init(
                        sessionID: next.id,
                        severity: .critical,
                        kind: .endBeforeStart,
                        message: "End time occurs before start time."
                    ))
                    next = swappedIfNeeded(next)
                }

                // Fast exit: if next starts far after base ends, stop scanning.
                let gap = next.startDate.timeIntervalSince(base.endDate)
                if gap > settings.gapThresholdSeconds * 4 {
                    break
                }

                let pairFP = pairFingerprint(a: base, b: next)
                if settings.doNotMergePairFingerprints.contains(pairFP) {
                    j += 1
                    continue
                }

                if shouldMerge(base: base, next: next, settings: settings) {
                    base = merge(base: base, next: next, settings: settings)
                    mergedIDs.append(next.id)
                    j += 1
                    continue
                } else {
                    break
                }
            }

            // Store merge metadata into raw map for traceability
            var final = base
            final.raw["_canonical_from_ids"] = mergedIDs.map(\.uuidString).joined(separator: ",")
            final.raw["_canonical_merge_count"] = "\(mergedIDs.count)"

            canonical.append(final)
            mergeMap[final.id] = mergedIDs

            i = max(j, i + 1)
        }

        // 4) Post-pass issues on CANONICAL
        for s in canonical {
            issues.append(contentsOf: detectIssues(on: s, settings: settings))
        }

        // De-dupe identical issues
        issues = Array(Set(issues)).sorted {
            if $0.severity.sortRank != $1.severity.sortRank { return $0.severity.sortRank < $1.severity.sortRank }
            return $0.kind.rawValue < $1.kind.rawValue
        }

        return TeslaFiNormalizationResult(canonical: canonical, mergeMap: mergeMap, issues: issues)
    }

    // MARK: - Merge rules

    private static func shouldMerge(base: TeslaFiSession, next: TeslaFiSession, settings: TeslaFiNormalizationSettings) -> Bool {
        let locA = normalizeLocation(base.location)
        let locB = normalizeLocation(next.location)

        let gap = next.startDate.timeIntervalSince(base.endDate)
        let overlaps = next.startDate <= base.endDate

        // Require same normalized location OR one missing (but tight time window applies)
        let locationCompatible = (locA == locB) || locA.isEmpty || locB.isEmpty
        if !locationCompatible { return false }

        if overlaps {
            return settings.mergeOverlaps
        }

        if gap >= 0 && gap <= settings.gapThresholdSeconds {
            return true
        }

        return false
    }

    private static func merge(base: TeslaFiSession, next: TeslaFiSession, settings: TeslaFiNormalizationSettings) -> TeslaFiSession {
        var out = base

        let overlaps = next.startDate <= base.endDate

        out.startDate = min(base.startDate, next.startDate)
        out.endDate = max(base.endDate, next.endDate)

        // Energy strategy:
        // - Overlap: likely duplicate/progress record → take max to avoid double counting
        // - Non-overlap (small gap): split session → sum
        out.energyAddedKWh = overlaps ? max(base.energyAddedKWh, next.energyAddedKWh)
                                     : (base.energyAddedKWh + next.energyAddedKWh)

        // Cost strategy:
        let a = base.cost ?? 0
        let b = next.cost ?? 0
        if overlaps {
            let m = max(a, b)
            out.cost = (m == 0) ? nil : m
        } else {
            let s = a + b
            out.cost = (s == 0) ? nil : s
        }

        // Prefer non-empty location
        let baseLoc = normalizeLocation(base.location)
        let nextLoc = normalizeLocation(next.location)
        if baseLoc.isEmpty, !nextLoc.isEmpty {
            out.location = next.location
        }

        // Merge raw maps (base wins on key collisions)
        var mergedRaw = next.raw
        for (k, v) in base.raw { mergedRaw[k] = v }
        out.raw = mergedRaw

        return out
    }

    private static func swappedIfNeeded(_ s: TeslaFiSession) -> TeslaFiSession {
        guard s.endDate < s.startDate else { return s }
        var out = s
        let tmp = out.startDate
        out.startDate = out.endDate
        out.endDate = tmp
        return out
    }

    // MARK: - Issues

    private static func detectIssues(on s: TeslaFiSession, settings: TeslaFiNormalizationSettings) -> [TeslaFiSessionIssue] {
        var out: [TeslaFiSessionIssue] = []

        if normalizeLocation(s.location).isEmpty {
            out.append(.init(sessionID: s.id, severity: .warning, kind: .missingLocation,
                             message: "Location is missing or unknown."))
        }

        if s.energyAddedKWh <= 0 {
            out.append(.init(sessionID: s.id, severity: .warning, kind: .nonPositiveEnergy,
                             message: "Energy added is 0 or negative."))
        }

        if let c = s.cost, c < 0 {
            out.append(.init(sessionID: s.id, severity: .critical, kind: .negativeCost,
                             message: "Cost is negative."))
        }

        let minutes = max(1.0, s.durationSeconds / 60.0)
        let impliedKW = (s.energyAddedKWh / (minutes / 60.0))
        if impliedKW > settings.maxReasonableKW {
            out.append(.init(sessionID: s.id, severity: .warning, kind: .implausiblePower,
                             message: "Implied charging power looks unusually high (~\(Int(impliedKW)) kW)."))
        }

        return out
    }

    // MARK: - Fingerprints

    private static func normalizeLocation(_ s: String?) -> String {
        let t = (s ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        if t == "unknown" || t == "n/a" { return "" }
        return t
    }

    /// Approx fingerprint: minute-rounded timestamps + 0.1 kWh + normalized location
    private static func approxFingerprint(_ s: TeslaFiSession) -> String {
        let a = Int(s.startDate.timeIntervalSince1970 / 60)
        let b = Int(s.endDate.timeIntervalSince1970 / 60)
        let kwh = Int((s.energyAddedKWh * 10).rounded())
        let loc = normalizeLocation(s.location)
        return "\(a)-\(b)-\(kwh)-\(loc)"
    }

    /// Pair fingerprint for “do not merge these two”
    private static func pairFingerprint(a: TeslaFiSession, b: TeslaFiSession) -> String {
        "\(approxFingerprint(a))::\(approxFingerprint(b))"
    }
}
