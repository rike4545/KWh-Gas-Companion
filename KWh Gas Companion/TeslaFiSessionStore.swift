//
//  TeslaFiSessionStore.swift
//  My KWh Companion
//
//  On-device persistence + canonicalization + merge integrity controls.
//  - Persists RAW sessions to JSON
//  - Builds CANONICAL sessions by merging near-duplicates
//  - Supports "do not merge" pair blocking
//  - Publishes integrity issues + merge maps for UI
//
//  Swift 6 • iOS 17+
//

import Foundation
import Combine
import CryptoKit

public struct TeslaFiIntegrityIssue: Identifiable, Hashable, Sendable {
    public enum Severity: String, Hashable, Sendable { case info, warning }
    public var id: String { "\(severity.rawValue)|\(title)|\(detail)" }
    public let severity: Severity
    public let title: String
    public let detail: String
}

final class TeslaFiSessionStore: ObservableObject {

    // MARK: - RAW sessions (persisted)

    @Published private(set) var sessions: [TeslaFiSession] = [] {
        didSet { persistAsync() }
    }

    // MARK: - Canonical + integrity (derived)

    @Published private(set) var canonicalSessions: [TeslaFiSession] = []
    @Published private(set) var integrityMergeMap: [UUID: [TeslaFiSession]] = [:]   // canonicalID → raw sessions
    @Published private(set) var integrityIssues: [TeslaFiIntegrityIssue] = []

    // Persisted “do not merge these two fingerprints”
    @Published private(set) var doNotMergePairs: Set<String> = []

    // MARK: - Import UI state

    @Published private(set) var lastImportReport: TFIImportReport?
    @Published private(set) var lastError: String?
    @Published private(set) var isImporting: Bool = false

    // MARK: - Persistence

    private let sessionsFileURL: URL
    private let blocksFileURL: URL

    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = []
        return enc
    }()

    private let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    private let writeQueue = DispatchQueue(label: "TeslaFiSessionStore.WriteQueue", qos: .utility)

    // MARK: - Init

    init(fileURL: URL? = nil) {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.urls(for: .documentDirectory, in: .userDomainMask).first!

        if !fm.fileExists(atPath: base.path) {
            try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        }

        self.sessionsFileURL = (fileURL ?? base.appendingPathComponent("teslafi.sessions.json"))
        self.blocksFileURL = base.appendingPathComponent("teslafi.mergeblocks.json")

        loadAsync()
    }

    static func loadDefault() -> TeslaFiSessionStore { TeslaFiSessionStore() }

    // MARK: - Public convenience

    var sessionsForUI: [TeslaFiSession] { canonicalSessions }

    var rawSessions: [TeslaFiSession] { sessions }

    var totalKWh: Double { sessions.reduce(0) { $0 + $1.energyAddedKWh } }
    var totalCost: Double { sessions.compactMap(\.cost).reduce(0, +) }
    var sessionCount: Int { sessions.count }
    var latestSession: TeslaFiSession? { sessions.max(by: { $0.startDate < $1.startDate }) }

    // MARK: - Mutation API (MainActor)

    @MainActor
    func replaceAll(with newSessions: [TeslaFiSession]) {
        sessions = Self.deduplicated(from: newSessions)
        rebuildCanonicalSessions()
    }

    @MainActor
    func append(_ newSessions: [TeslaFiSession]) {
        guard !newSessions.isEmpty else { return }
        var combined = sessions
        combined.append(contentsOf: newSessions)
        sessions = Self.deduplicated(from: combined)
        rebuildCanonicalSessions()
    }

    @MainActor
    func upsert(_ session: TeslaFiSession) {
        if let idx = sessions.firstIndex(where: { $0.sessionHash == session.sessionHash }) {
            sessions[idx] = session
        } else {
            sessions.append(session)
        }
        sessions = Self.deduplicated(from: sessions)
        rebuildCanonicalSessions()
    }

    @MainActor
    func remove(_ session: TeslaFiSession) {
        sessions.removeAll { $0.sessionHash == session.sessionHash }
        rebuildCanonicalSessions()
    }

    @MainActor
    func clear() {
        sessions.removeAll()
        rebuildCanonicalSessions()
    }

    // MARK: - Canonical rebuild

    /// Recompute canonical sessions + merge map + issues.
    @MainActor
    func rebuildCanonicalSessions() {
        let (canon, map) = canonicalize(raw: sessions, doNotMergePairs: doNotMergePairs)
        canonicalSessions = canon
        integrityMergeMap = map
        integrityIssues = buildIssues(raw: sessions, canonical: canon, mergeMap: map)
    }

    func rawSessions(forCanonical canonicalID: UUID) -> [TeslaFiSession] {
        integrityMergeMap[canonicalID] ?? []
    }

    // MARK: - Merge blocking

    @MainActor
    func blockMergeBetween(_ a: TeslaFiSession, and b: TeslaFiSession) {
        let key = mergeBlockKey(a.sessionHash, b.sessionHash)
        doNotMergePairs.insert(key)
        persistBlocksAsync()
        rebuildCanonicalSessions()
    }

    @MainActor
    func clearAllMergeBlocks() {
        doNotMergePairs.removeAll()
        persistBlocksAsync()
        rebuildCanonicalSessions()
    }

    // MARK: - Missing-cost helper

    /// Apply an estimated $/kWh to RAW sessions that have nil cost.
    @MainActor
    func applyEstimatedCost(ratePerKWh: Double, onlySince: Date? = nil) {
        guard ratePerKWh > 0 else { return }

        let since = onlySince
        var changed = false

        for i in sessions.indices {
            if sessions[i].cost != nil { continue }
            if let since, sessions[i].startDate < since { continue }

            sessions[i].cost = sessions[i].energyAddedKWh * ratePerKWh
            changed = true
        }

        if changed {
            sessions = Self.deduplicated(from: sessions)
            rebuildCanonicalSessions()
        }
    }

    // MARK: - Async CSV import entry point

    @MainActor
    func importFromCSV(at url: URL) async {
        lastError = nil
        lastImportReport = nil
        isImporting = true

        let existing = sessions
        do {
            let (parsed, report) = try await Self.loadAndParseCSV(at: url, existing: existing)
            append(parsed)
            lastImportReport = report
        } catch {
            lastError = Self.describeImportError(error)
        }

        isImporting = false
    }

    private static func loadAndParseCSV(
        at url: URL,
        existing: [TeslaFiSession]
    ) async throws -> ([TeslaFiSession], TFIImportReport) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let started = url.startAccessingSecurityScopedResource()
                defer { if started { url.stopAccessingSecurityScopedResource() } }

                do {
                    let data = try Data(contentsOf: url)
                    let (sessions, report) = try TeslaFiSessionStore.parseTeslaFiCSV(
                        data: data,
                        filenameHint: url.lastPathComponent,
                        existing: existing
                    )
                    continuation.resume(returning: (sessions, report))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func describeImportError(_ error: Error) -> String {
        if let tfi = error as? TFIImportError,
           let desc = tfi.errorDescription { return desc }

        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain {
            switch ns.code {
            case NSFileReadNoSuchFileError:
                return "The selected file could not be found."
            case NSFileReadNoPermissionError:
                return "No permission to read this file. Try copying it into Files (On My iPhone / iCloud Drive) and import again."
            case NSFileReadInapplicableStringEncodingError:
                return "The CSV encoding could not be read as UTF-8 or ASCII."
            default:
                return ns.localizedDescription
            }
        }
        return error.localizedDescription
    }

    // MARK: - Canonicalization internals

    private func canonicalize(
        raw: [TeslaFiSession],
        doNotMergePairs: Set<String>
    ) -> ([TeslaFiSession], [UUID: [TeslaFiSession]]) {

        let sorted = raw.sorted { $0.startDate < $1.startDate }
        var clusters: [[TeslaFiSession]] = []
        clusters.reserveCapacity(sorted.count)

        for s in sorted {
            if clusters.isEmpty {
                clusters.append([s])
                continue
            }

            var last = clusters.removeLast()
            if shouldMerge(into: last, candidate: s, doNotMergePairs: doNotMergePairs) {
                last.append(s)
                clusters.append(last)
            } else {
                clusters.append(last)
                clusters.append([s])
            }
        }

        var canonical: [TeslaFiSession] = []
        canonical.reserveCapacity(clusters.count)

        var map: [UUID: [TeslaFiSession]] = [:]
        map.reserveCapacity(clusters.count)

        for group in clusters {
            let canon = makeCanonical(from: group)
            canonical.append(canon)
            map[canon.id] = group
        }

        canonical.sort { $0.startDate > $1.startDate }
        return (canonical, map)
    }

    private func shouldMerge(
        into cluster: [TeslaFiSession],
        candidate: TeslaFiSession,
        doNotMergePairs: Set<String>
    ) -> Bool {
        guard let anchor = cluster.first else { return false }

        let blockKey = mergeBlockKey(anchor.sessionHash, candidate.sessionHash)
        if doNotMergePairs.contains(blockKey) { return false }

        let locA = normalizeLocation(anchor.location)
        let locB = normalizeLocation(candidate.location)
        if locA != locB { return false }

        let dtStart = abs(candidate.startDate.timeIntervalSince(anchor.startDate))
        if dtStart > 4 * 60 { return false }

        let dtEnd = abs(candidate.endDate.timeIntervalSince(anchor.endDate))
        if dtEnd > 8 * 60 { return false }

        let dkWh = abs(candidate.energyAddedKWh - anchor.energyAddedKWh)
        if dkWh > 0.35 { return false }

        return true
    }

    private func makeCanonical(from group: [TeslaFiSession]) -> TeslaFiSession {
        let start = group.map(\.startDate).min() ?? group[0].startDate
        let end = group.map(\.endDate).max() ?? group[0].endDate

        let location = bestLocation(from: group)
        let energy = group.map(\.energyAddedKWh).max() ?? group[0].energyAddedKWh
        let cost = group.compactMap(\.cost).max()

        let bestRaw = group.max(by: { $0.raw.count < $1.raw.count })?.raw ?? group[0].raw

        let id = stableUUID(for: "\(Int(start.timeIntervalSince1970))|\(Int(end.timeIntervalSince1970))|\(String(format: "%.3f", energy))|\(normalizeLocation(location))")

        return TeslaFiSession(
            id: id,
            startDate: start,
            endDate: end,
            energyAddedKWh: energy,
            cost: cost,
            location: location,
            raw: bestRaw
        )
    }

    private func bestLocation(from group: [TeslaFiSession]) -> String? {
        let candidates = group.compactMap(\.location)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if candidates.isEmpty { return group.first?.location }
        return candidates.max(by: { $0.count < $1.count })
    }

    private func normalizeLocation(_ loc: String?) -> String {
        let s = (loc ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.isEmpty { return "unknown" }
        return s.replacingOccurrences(of: "supercharger", with: "sc")
    }

    private func mergeBlockKey(_ a: String, _ b: String) -> String {
        let x = a <= b ? a : b
        let y = a <= b ? b : a
        return "\(x)||\(y)"
    }

    private func stableUUID(for key: String) -> UUID {
        let digest = SHA256.hash(data: Data(key.utf8))
        let bytes = Array(digest)
        let uuidBytes = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuidBytes)
    }

    private func buildIssues(
        raw: [TeslaFiSession],
        canonical: [TeslaFiSession],
        mergeMap: [UUID: [TeslaFiSession]]
    ) -> [TeslaFiIntegrityIssue] {

        var issues: [TeslaFiIntegrityIssue] = []

        let mergedCount = mergeMap.values.filter { $0.count > 1 }.count
        if mergedCount > 0 {
            issues.append(.init(
                severity: .info,
                title: "Merged near-duplicate sessions",
                detail: "\(mergedCount) canonical session(s) were formed by merging duplicates."
            ))
        }

        let missingCosts = canonical.filter { $0.cost == nil }.count
        if missingCosts > 0 {
            issues.append(.init(
                severity: .warning,
                title: "Missing costs",
                detail: "\(missingCosts) canonical session(s) have no cost."
            ))
        }

        if raw.isEmpty {
            issues.append(.init(
                severity: .info,
                title: "No TeslaFi sessions yet",
                detail: "Import a TeslaFi CSV to see charging analytics."
            ))
        }

        return issues
    }

    private static func deduplicated(from sessions: [TeslaFiSession]) -> [TeslaFiSession] {
        var seen = Set<String>()
        var out: [TeslaFiSession] = []
        out.reserveCapacity(sessions.count)
        for s in sessions {
            if seen.insert(s.sessionHash).inserted {
                out.append(s)
            }
        }
        return out
    }

    // MARK: - Disk I/O

    private func persistAsync() {
        let data: Data
        do { data = try encoder.encode(sessions) }
        catch { return }

        let url = sessionsFileURL
        writeQueue.async {
            do {
                var options: Data.WritingOptions = [.atomic]
                #if os(iOS)
                options.insert(.completeFileProtection)
                #endif
                try data.write(to: url, options: options)
            } catch {
                #if DEBUG
                print("TeslaFiSessionStore write error:", error)
                #endif
            }
        }
    }

    private func loadAsync() {
        let sessionsURL = sessionsFileURL
        let blocksURL = blocksFileURL

        Task.detached(priority: .utility) { [sessionsURL, blocksURL] in
            let sessionsDecoded: [TeslaFiSession] = {
                do {
                    let data = try Data(contentsOf: sessionsURL)
                    let dec = JSONDecoder()
                    dec.dateDecodingStrategy = .iso8601
                    return try dec.decode([TeslaFiSession].self, from: data)
                } catch {
                    return []
                }
            }()

            let blocksDecoded: [String] = {
                do {
                    let data = try Data(contentsOf: blocksURL)
                    let dec = JSONDecoder()
                    dec.dateDecodingStrategy = .iso8601
                    return try dec.decode([String].self, from: data)
                } catch {
                    return []
                }
            }()

            await MainActor.run {
                self.sessions = Self.deduplicated(from: sessionsDecoded)
                self.doNotMergePairs = Set(blocksDecoded)
                self.rebuildCanonicalSessions()
            }
        }
    }

    private func persistBlocksAsync() {
        let snapshot = Array(doNotMergePairs).sorted()
        let data: Data
        do { data = try encoder.encode(snapshot) }
        catch { return }

        let url = blocksFileURL
        writeQueue.async {
            try? data.write(to: url, options: [.atomic])
        }
    }
}
