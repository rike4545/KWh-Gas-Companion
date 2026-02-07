//
//  SparkShiftStore.swift
//  KWh Gas Companion — Spark
//
//  Regenerated: Oct 27, 2025
//

import Foundation
import Combine

// MARK: - Model

public struct SparkShiftEntry: Codable, Identifiable, Hashable {
    public let id: UUID
    public var date: Date
    public var energyKWh: Double?
    public var cost: Double?
    public var miles: Double?
    public var site: String?
    public var kind: SparkTripKind?
    public var durationSeconds: Double?
    public var note: String?

    public init(
        id: UUID = UUID(),
        date: Date,
        energyKWh: Double? = nil,
        cost: Double? = nil,
        miles: Double? = nil,
        site: String? = nil,
        kind: SparkTripKind? = nil,
        durationSeconds: Double? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.energyKWh = energyKWh
        self.cost = cost
        self.miles = miles
        self.site = site
        self.kind = kind
        self.durationSeconds = durationSeconds
        self.note = note
    }

    /// Stable natural key to detect duplicates from CSV/API imports.
    public func dedupeKey(
        timeBucketSeconds: TimeInterval = 15 * 60,
        kWhPlaces: Int = 2,
        milesPlaces: Int = 2
    ) -> String {
        let t = floor(date.timeIntervalSince1970 / timeBucketSeconds)
        func quant(_ v: Double?, places: Int) -> String {
            guard let v = v else { return "nil" }
            let p = pow(10.0, Double(places))
            return String((v * p).rounded() / p)
        }
        return [
            "t:\(Int(t))",
            "kWh:\(quant(energyKWh, places: kWhPlaces))",
            "mi:\(quant(miles, places: milesPlaces))",
            "cost:\(quant(cost, places: 2))",
            "site:\(site?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "nil")",
            "kind:\(kind.map { String(describing: $0) } ?? "nil")"
        ].joined(separator: "|")
    }
}

// MARK: - Persistence Backend

public enum SparkStorage {
    case inMemory
    case userDefaults(key: String)
    case file(url: URL)

    /// Default Application Support file URL (excluded from backups).
    public static func defaultFileURL() -> URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        var url = dir.appendingPathComponent("SparkShiftEntries.v2.json")
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        return url
    }

    /// Default storage (UserDefaults).
    public static let `default`: SparkStorage = .userDefaults(key: "SparkShiftEntries.v2")
}

// MARK: - Store

@MainActor
public final class SparkShiftStore: ObservableObject {

    // Public, read-only outside the store
    @Published public private(set) var entries: [SparkShiftEntry] = []

    // Quick index for upserts/removals
    private var indexByID: [UUID: Int] = [:]

    // Persistence
    private let storage: SparkStorage
    private let schemaVersion = 2

    // Debounced save
    private var saveTask: Task<Void, Never>?

    // MARK: Init

    public init(storage: SparkStorage = .default) {
        self.storage = storage
        load()
        migrateIfNeeded()
    }

    // MARK: Persistence

    private struct PersistEnvelope: Codable {
        var schema: Int
        var items: [SparkShiftEntry]
    }

    private static let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.sortedKeys]
        return enc
    }()

    private static let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    private func load() {
        switch storage {
        case .inMemory:
            entries = []
        case .userDefaults(let key):
            guard let data = UserDefaults.standard.data(forKey: key) else { entries = []; break }
            if let env = try? Self.decoder.decode(PersistEnvelope.self, from: data) {
                entries = env.items
            } else if let arr = try? Self.decoder.decode([SparkShiftEntry].self, from: data) {
                entries = arr
            } else {
                entries = []
            }
        case .file(let url):
            guard let data = try? Data(contentsOf: url) else { entries = []; break }
            if let env = try? Self.decoder.decode(PersistEnvelope.self, from: data) {
                entries = env.items
            } else if let arr = try? Self.decoder.decode([SparkShiftEntry].self, from: data) {
                entries = arr
            } else {
                entries = []
            }
        }
        stableSort()
        rebuildIndex()
    }

    private func saveDebounced(delay: Duration = .milliseconds(250)) {
        saveTask?.cancel()
        let snapshot = entries
        let storage = self.storage
        let schema = self.schemaVersion
        saveTask = Task { [snapshot] in
            try? await Task.sleep(for: delay)
            await _save(entries: snapshot, storage: storage, schema: schema)
        }
    }

    private func _save(entries: [SparkShiftEntry], storage: SparkStorage, schema: Int) async {
        let env = PersistEnvelope(schema: schema, items: entries)
        switch storage {
        case .inMemory:
            return
        case .userDefaults(let key):
            if let data = try? Self.encoder.encode(env) {
                UserDefaults.standard.set(data, forKey: key)
            }
        case .file(let url):
            if let data = try? Self.encoder.encode(env) {
                do { try data.write(to: url, options: .atomic) } catch { /* ignore in production */ }
            }
        }
    }

    private func stableSort() {
        // Stable by (date, id) to ensure deterministic ordering
        entries.sort { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }
    }

    private func rebuildIndex() {
        indexByID.removeAll(keepingCapacity: true)
        for (i, e) in entries.enumerated() { indexByID[e.id] = i }
    }

    // MARK: Migration (one-time, idempotent)

    private func migrateIfNeeded() {
        guard entries.isEmpty else { return }
        var changed = false

        // Legacy UserDefaults keys
        for k in ["SparkShiftEntries.v1", "SparkShiftEntries"] {
            if let data = UserDefaults.standard.data(forKey: k) {
                _ = importJSON(data, merge: true, preferIncomingOnCollision: true, dedupeByNaturalKey: true)
                UserDefaults.standard.removeObject(forKey: k)
                changed = true
            }
        }

        // Legacy file example
        let oldURL = SparkStorage.defaultFileURL().deletingLastPathComponent()
            .appendingPathComponent("SparkEntries.json")
        if let data = try? Data(contentsOf: oldURL) {
            _ = importJSON(data, merge: true, preferIncomingOnCollision: true, dedupeByNaturalKey: true)
            try? FileManager.default.removeItem(at: oldURL)
            changed = true
        }

        if changed { saveDebounced() }
    }

    // MARK: CRUD

    public func addEntry(
        date: Date = Date(),
        energyKWh: Double? = nil,
        cost: Double? = nil,
        miles: Double? = nil,
        site: String? = nil,
        kind: SparkTripKind? = nil,
        durationSeconds: Double? = nil,
        note: String? = nil
    ) {
        let new = SparkShiftEntry(
            date: date,
            energyKWh: energyKWh,
            cost: cost,
            miles: miles,
            site: site,
            kind: kind,
            durationSeconds: durationSeconds,
            note: note
        )
        entries.append(new)
        stableSort()
        rebuildIndex()
        saveDebounced()
    }

    public func upsertEntry(_ entry: SparkShiftEntry) {
        if let idx = indexByID[entry.id] {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
        stableSort()
        rebuildIndex()
        saveDebounced()
    }

    /// Update an existing entry by id. Mutate the `inout` copy to apply changes.
    public func updateEntry(id: UUID, mutate: (inout SparkShiftEntry) -> Void) {
        guard let idx = indexByID[id] else { return }
        var copy = entries[idx]
        mutate(&copy)
        entries[idx] = copy
        stableSort()
        rebuildIndex()
        saveDebounced()
    }

    public func removeEntry(id: UUID) {
        if let idx = indexByID[id] {
            entries.remove(at: idx)
            rebuildIndex()
            saveDebounced()
        }
    }

    public func clearEntries() {
        entries.removeAll()
        rebuildIndex()
        switch storage {
        case .inMemory: break
        case .userDefaults(let key):
            UserDefaults.standard.removeObject(forKey: key)
        case .file(let url):
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Replace with a new set (sorted).
    public func replaceAll(with newEntries: [SparkShiftEntry]) {
        entries = newEntries
        stableSort()
        rebuildIndex()
        saveDebounced()
    }

    /// Append many entries at once (sorted afterwards).
    public func addEntries(_ batch: [SparkShiftEntry]) {
        guard !batch.isEmpty else { return }
        entries.append(contentsOf: batch)
        stableSort()
        rebuildIndex()
        saveDebounced()
    }

    /// Batch update (single sort/save).
    public func batchUpdate(_ mutate: (inout [SparkShiftEntry]) -> Void) {
        var copy = entries
        mutate(&copy)
        copy.sort { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }
        entries = copy
        rebuildIndex()
        saveDebounced()
    }

    // MARK: Import / Export

    public func exportJSON(pretty: Bool = false) -> Data? {
        let env = PersistEnvelope(schema: schemaVersion, items: entries)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = pretty ? [.sortedKeys, .prettyPrinted] : [.sortedKeys]
        return try? enc.encode(env)
    }

    /// Import entries from JSON `[SparkShiftEntry]` or wrapped envelope.
    /// - Parameters:
    ///   - merge: When true (default), merges on `id`; additional natural de-dup removes near-duplicates.
    ///   - preferIncomingOnCollision: When merging, incoming values replace existing on id match.
    ///   - dedupeByNaturalKey: Also remove duplicates detected by `dedupeKey(...)`.
    /// - Returns: Count of decoded entries (before merge).
    @discardableResult
    public func importJSON(
        _ data: Data,
        merge: Bool = true,
        preferIncomingOnCollision: Bool = true,
        dedupeByNaturalKey: Bool = true
    ) -> Int {
        let incoming: [SparkShiftEntry]
        if let env = try? Self.decoder.decode(PersistEnvelope.self, from: data) {
            incoming = env.items
        } else if let arr = try? Self.decoder.decode([SparkShiftEntry].self, from: data) {
            incoming = arr
        } else {
            return 0
        }

        if !merge {
            entries = incoming
            stableSort()
            rebuildIndex()
            saveDebounced()
            return incoming.count
        }

        // Merge by id first
        var map: [UUID: SparkShiftEntry] = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        for inc in incoming {
            if map[inc.id] != nil {
                map[inc.id] = preferIncomingOnCollision ? inc : map[inc.id]
            } else {
                map[inc.id] = inc
            }
        }
        var merged = Array(map.values)

        // Optional natural-key de-duplication
        if dedupeByNaturalKey {
            var seen: Set<String> = []
            merged.sort { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }
            merged = merged.reduce(into: [SparkShiftEntry]()) { acc, e in
                let k = e.dedupeKey()
                if seen.insert(k).inserted { acc.append(e) }
            }
        }

        entries = merged
        stableSort()
        rebuildIndex()
        saveDebounced()
        return incoming.count
    }

    // MARK: Queries

    /// Return entries within [start, end).
    public func entries(from start: Date, to end: Date) -> [SparkShiftEntry] {
        entries.filter { $0.date >= start && $0.date < end }
    }

    /// Return entries for a specific (local) month.
    public func entries(year: Int, month: Int, calendar: Calendar = .current) -> [SparkShiftEntry] {
        var comp = DateComponents()
        comp.year = year; comp.month = month; comp.day = 1
        guard let start = calendar.date(from: comp),
              let range = calendar.range(of: .day, in: .month, for: start),
              let end = calendar.date(byAdding: .day, value: range.count, to: start) else { return [] }
        return entries(from: start, to: end)
    }

    /// Group entries by (year, month). Keys are "YYYY-MM".
    public func monthBuckets(calendar: Calendar = .current) -> [(key: String, items: [SparkShiftEntry])] {
        let keyFor: (Date) -> String = { d in
            let c = calendar.dateComponents([.year, .month], from: d)
            return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
        }
        let grouped = Dictionary(grouping: entries) { keyFor($0.date) }
        return grouped.keys.sorted().compactMap { k in
            guard let arr = grouped[k] else { return nil }
            return (k, arr.sorted { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) })
        }
    }

    /// Lightweight free-text search over site, note, kind.
    public func search(freeText: String) -> [SparkShiftEntry] {
        let q = freeText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return entries }
        return entries.filter { e in
            if let s = e.site?.lowercased(), s.contains(q) { return true }
            if let n = e.note?.lowercased(), n.contains(q) { return true }
            if let k = e.kind.map({ String(describing: $0).lowercased() }), k.contains(q) { return true }
            return false
        }
    }

    // MARK: Metrics

    public var entryCount: Int { entries.count }

    public var totalEnergyKWh: Double {
        entries.compactMap { $0.energyKWh }.reduce(0, +)
    }

    public var totalMiles: Double {
        entries.compactMap { $0.miles }.reduce(0, +)
    }

    public var totalCost: Double {
        entries.compactMap { $0.cost }.reduce(0, +)
    }

    /// Weighted average price/kWh when both price and energy are known.
    public var avgPricePerKWhWeighted: Double? {
        var num = 0.0, den = 0.0
        for e in entries {
            guard let k = e.energyKWh, k > 0, let c = e.cost else { continue }
            num += (c / k) * k
            den += k
        }
        return den > 0 ? num / den : nil
    }

    /// Average Wh/mi across entries with both energy and miles.
    public var avgWhPerMile: Double? {
        var wh = 0.0, mi = 0.0
        for e in entries {
            if let k = e.energyKWh, let m = e.miles, m > 0 {
                wh += k * 1000.0
                mi += m
            }
        }
        return mi > 0 ? wh / mi : nil
    }

    /// Per-entry price/kWh if derivable (cost / kWh).
    public func pricePerKWh(of e: SparkShiftEntry) -> Double? {
        guard let c = e.cost, let k = e.energyKWh, k > 0 else { return nil }
        return c / k
    }
}

// MARK: - Repo bridge for summarizer (used by SparkyEngine)

public extension SparkShiftStore {
    /// Adapter to `SparkEntriesRepository` (store-agnostic access).
    var repositoryAdapter: StoreEntriesRepo {
        StoreEntriesRepo(readAllEntries: { [weak self] in
            self?.entries ?? []
        })
    }

    // Convenience closures used by LocalSparkSummarizer
    var costOf: (SparkShiftEntry) -> Double? { { $0.cost } }

    var pricePerKWhOf: (SparkShiftEntry) -> Double? {
        { e in
            guard let c = e.cost, let k = e.energyKWh, k > 0 else { return nil }
            return c / k
        }
    }

    var tripKindOf: (SparkShiftEntry) -> SparkTripKind? { { $0.kind } }
    var milesOf: (SparkShiftEntry) -> Double? { { $0.miles } }
    var energyKWhOf: (SparkShiftEntry) -> Double? { { $0.energyKWh } }

    /// Optional regional carbon factor provider (kg CO₂ per kWh). Return nil if unknown.
    var gridKgCO2PerKWh: () -> Double? { { nil } }
}

// MARK: - Preview Seed (Debug)

#if DEBUG
public extension SparkShiftStore {
    static func previewSeed() -> SparkShiftStore {
        let store = SparkShiftStore(storage: .inMemory)
        let now = Date()
        let cal = Calendar.current
        for d in (-14...0) {
            store.addEntry(
                date: cal.date(byAdding: .day, value: d, to: now) ?? now,
                energyKWh: [6.5, 7.8, 8.9, 10.2, 12.4, nil].randomElement()!,
                cost: [2.95, 3.70, 4.10, 5.40, nil].randomElement()!,
                miles: [16.7, 18.2, 22.9, 27.3, 31.5, 40.1, nil].randomElement()!,
                site: ["Home", "EVgo", "Tesla SC", "EA", nil].randomElement()!,
                kind: SparkTripKind.allCases.randomElement(),
                durationSeconds: [1200, 1800, 2400, 3600, nil].randomElement()!,
                note: ["", "Grocery run", "Work commute", "Errands", nil].randomElement()!
            )
        }
        return store
    }
}
#endif
