//
//  ChargingSession.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/17/25.
//


import Foundation

// MARK: - Lightweight canonical type (adapt to your TeslaFiSession as needed)

public struct ChargingSession: Identifiable, Codable, Hashable {
    public var id: UUID
    public var startDate: Date
    public var endDate: Date
    public var energyAddedKWh: Double
    public var location: String
    public var cost: Double?

    public init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        energyAddedKWh: Double,
        location: String,
        cost: Double?
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.energyAddedKWh = energyAddedKWh
        self.location = location
        self.cost = cost
    }
}

// MARK: - Issues

public enum SessionIssueSeverity: String, Codable { case info, warning, critical }

public enum SessionIssueKind: String, Codable {
    case endBeforeStart
    case missingLocation
    case nonPositiveEnergy
    case negativeCost
    case implausiblePower
    case suspiciousDuplicate
}

public struct SessionIssue: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var sessionID: UUID
    public var severity: SessionIssueSeverity
    public var kind: SessionIssueKind
    public var message: String
}

// MARK: - Result

public struct NormalizationResult: Codable, Hashable {
    public var canonical: [ChargingSession]
    /// Map: canonicalSessionID -> rawSessionIDs that were merged into it
    public var mergeMap: [UUID: [UUID]]
    public var issues: [SessionIssue]
}

public enum ChargingSessionNormalizationEngine {

    public struct Settings: Codable, Hashable {
        public var gapThresholdSeconds: TimeInterval = 6 * 60
        public var maxReasonableKW: Double = 350 // flag above this
        /// Fingerprints that should NEVER be merged (manual user override)
        public var doNotMergeFingerprints: Set<String> = []

        public init() {}
    }

    // MARK: - Public API

    public static func normalize(_ raw: [ChargingSession], settings: Settings = .init()) -> NormalizationResult {
        let cleaned = raw
            .map(sanitize(_:))
            .sorted { $0.startDate < $1.startDate }

        var canonical: [ChargingSession] = []
        var mergeMap: [UUID: [UUID]] = [:]

        var i = 0
        while i < cleaned.count {
            var base = cleaned[i]
            var mergedIDs: [UUID] = [base.id]

            var j = i + 1
            while j < cleaned.count {
                let next = cleaned[j]

                // Stop if location differs and time gap is large (fast exit).
                // We still allow merges with unknown location only if fingerprints match (handled below).
                if !shouldConsiderMerging(base: base, next: next, settings: settings) {
                    break
                }

                // Respect manual override
                let pairFP = pairFingerprint(a: base, b: next)
                if settings.doNotMergeFingerprints.contains(pairFP) {
                    j += 1
                    continue
                }

                if shouldMerge(base: base, next: next, settings: settings) {
                    base = mergeSessions(base: base, next: next)
                    mergedIDs.append(next.id)
                    j += 1
                    continue
                } else {
                    break
                }
            }

            canonical.append(base)
            mergeMap[base.id] = mergedIDs
            i = max(j, i + 1)
        }

        // Post-pass: detect issues on canonical sessions
        let issues = canonical.flatMap { detectIssues(for: $0, settings: settings) }

        return NormalizationResult(canonical: canonical, mergeMap: mergeMap, issues: issues)
    }

    // MARK: - Merge logic

    private static func shouldConsiderMerging(base: ChargingSession, next: ChargingSession, settings: Settings) -> Bool {
        // If next starts very far after base ends, don't bother.
        let gap = next.startDate.timeIntervalSince(base.endDate)
        if gap > settings.gapThresholdSeconds * 4 { return false }

        // If locations match (normalized), it’s worth checking.
        if normalizeLocation(base.location) == normalizeLocation(next.location) { return true }

        // If either is unknown location, allow consideration only when very close in time.
        let baseUnknown = normalizeLocation(base.location).isEmpty
        let nextUnknown = normalizeLocation(next.location).isEmpty
        if baseUnknown || nextUnknown {
            return gap <= settings.gapThresholdSeconds
        }

        return false
    }

    private static func shouldMerge(base: ChargingSession, next: ChargingSession, settings: Settings) -> Bool {
        let locA = normalizeLocation(base.location)
        let locB = normalizeLocation(next.location)

        // Require same location OR one is unknown (tight time window handled above)
        let locationCompatible = (locA == locB) || locA.isEmpty || locB.isEmpty
        if !locationCompatible { return false }

        let overlap = next.startDate <= base.endDate
        let gap = next.startDate.timeIntervalSince(base.endDate)

        // Merge if overlapping or close enough gap
        if overlap { return true }
        if gap >= 0 && gap <= settings.gapThresholdSeconds { return true }

        return false
    }

    private static func mergeSessions(base: ChargingSession, next: ChargingSession) -> ChargingSession {
        var out = base

        let overlap = next.startDate <= base.endDate
        out.startDate = min(base.startDate, next.startDate)
        out.endDate = max(base.endDate, next.endDate)

        // Energy strategy:
        // - If overlap, likely duplicate/progress record → take max to avoid double counting.
        // - If sequential segments, sum (split session)
        if overlap {
            out.energyAddedKWh = max(base.energyAddedKWh, next.energyAddedKWh)
        } else {
            out.energyAddedKWh = base.energyAddedKWh + next.energyAddedKWh
        }

        // Cost strategy:
        let a = base.cost ?? 0
        let b = next.cost ?? 0
        if overlap {
            out.cost = max(a, b) == 0 ? nil : max(a, b)
        } else {
            let sum = a + b
            out.cost = sum == 0 ? nil : sum
        }

        // Prefer non-empty location
        if normalizeLocation(out.location).isEmpty && !normalizeLocation(next.location).isEmpty {
            out.location = next.location
        }

        return out
    }

    private static func sanitize(_ s: ChargingSession) -> ChargingSession {
        var out = s
        // Fix inverted dates defensively (don’t mutate raw permanently unless user applies fixes)
        if out.endDate < out.startDate {
            // Swap rather than discard (we’ll still flag it)
            let tmp = out.startDate
            out.startDate = out.endDate
            out.endDate = tmp
        }
        // Trim location
        out.location = out.location.trimmingCharacters(in: .whitespacesAndNewlines)
        return out
    }

    private static func normalizeLocation(_ s: String) -> String {
        let t = s
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        // Treat "unknown"/"n/a" as empty
        if t == "unknown" || t == "n/a" { return "" }
        return t
    }

    private static func pairFingerprint(a: ChargingSession, b: ChargingSession) -> String {
        // Stable-ish fingerprint for user override storage
        "\(fingerprint(a))::\(fingerprint(b))"
    }

    public static func fingerprint(_ s: ChargingSession) -> String {
        // Round times to 1 minute to tolerate tiny offsets
        let a = Int(s.startDate.timeIntervalSince1970 / 60)
        let b = Int(s.endDate.timeIntervalSince1970 / 60)
        let kwh = Int((s.energyAddedKWh * 10).rounded()) // 0.1 kWh precision
        let loc = normalizeLocation(s.location)
        return "\(a)-\(b)-\(kwh)-\(loc)"
    }

    // MARK: - Issue detection

    private static func detectIssues(for s: ChargingSession, settings: Settings) -> [SessionIssue] {
        var out: [SessionIssue] = []

        if s.endDate < s.startDate {
            out.append(.init(sessionID: s.id, severity: .critical, kind: .endBeforeStart,
                             message: "End time occurs before start time."))
        }

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

        let minutes = max(1.0, s.endDate.timeIntervalSince(s.startDate) / 60.0)
        let impliedKW = (s.energyAddedKWh / (minutes / 60.0))
        if impliedKW > settings.maxReasonableKW {
            out.append(.init(sessionID: s.id, severity: .warning, kind: .implausiblePower,
                             message: "Implied charging power looks unusually high (~\(Int(impliedKW)) kW)."))
        }

        return out
    }
}
