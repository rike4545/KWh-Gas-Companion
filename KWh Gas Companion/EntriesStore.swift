//
//  EntriesStore.swift
//  My KWh Companion
//
//  Canonical store for ExpenseEntry with background JSON persistence.
//  Swift 6 / iOS 17+
//

import Foundation
import Combine

@MainActor
final class EntriesStore: ObservableObject {

    // MARK: - Published data

    /// Canonical source of truth for all expense/charging entries.
    @Published var entries: [ExpenseEntry] = [] {
        didSet {
            guard !isHydrating else { return }
            persistAsync()
        }
    }

    // MARK: - Persistence

    private let saveURL: URL = EntriesStore.makeSaveURL()
    private var isHydrating = true

    /// Serial queue that owns both encoding and writing, off the main thread.
    private let writeQueue = DispatchQueue(label: "EntriesStore.WriteQueue", qos: .utility)

    /// Set when a mutation needs to reach disk; cleared once the save is
    /// scheduled. See `persistAsync()` for why this exists.
    private var hasPendingSave = false

    private let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    private nonisolated static func makeSaveURL(fileManager: FileManager = .default) -> URL {
        let baseDir =
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory

        if !fileManager.fileExists(atPath: baseDir.path) {
            try? fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true)
        }

        return baseDir.appendingPathComponent("entries.store.json")
    }

    // MARK: - Init

    init() {
        loadAsync()
    }

    // MARK: - CRUD

    /// Insert if new, otherwise replace in place by ID.
    func upsert(_ entry: ExpenseEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
    }

    /// Alias kept for older call sites.
    func addOrReplace(_ entry: ExpenseEntry) {
        upsert(entry)
    }

    /// Insert-or-replace a whole batch in one shot.
    ///
    /// PERF: importers used to call `addOrReplace(_:)` in a loop. Each call did
    /// a `firstIndex(where:)` linear scan of an array that grows with every
    /// insert — O(n·m) — and mutated `entries` m times, so even with coalesced
    /// saves SwiftUI got m change notifications. This builds an id→index map
    /// once (O(n + m)) and assigns `entries` exactly once, producing a single
    /// `objectWillChange` and a single save.
    func upsertMany(_ incoming: [ExpenseEntry]) {
        guard !incoming.isEmpty else { return }

        var working = entries
        var indexByID = [UUID: Int](minimumCapacity: working.count + incoming.count)
        for (offset, entry) in working.enumerated() { indexByID[entry.id] = offset }

        for entry in incoming {
            if let idx = indexByID[entry.id] {
                working[idx] = entry
            } else {
                indexByID[entry.id] = working.count
                working.append(entry)
            }
        }

        entries = working
    }

    /// Append without checking for an existing entry.
    func add(_ entry: ExpenseEntry) {
        entries.append(entry)
    }

    /// Update an existing entry *by ID*; no-op if the ID isn’t found.
    func update(_ entry: ExpenseEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        }
    }

    /// Remove this exact entry (by ID).
    func remove(_ entry: ExpenseEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    /// Remove by ID.
    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    /// Replace the entire collection at once.
    func replaceAll(_ newEntries: [ExpenseEntry]) {
        entries = newEntries
    }

    /// Clear all entries.
    func clearAll() {
        entries.removeAll()
    }

    // MARK: - Queries / convenience

    /// Entries that represent energy/charging sessions.
    func energyEntries() -> [ExpenseEntry] {
        entries.filter { $0.isEnergyEffective }
    }

    /// Entries that are not treated as energy/charging.
    func nonEnergyEntries() -> [ExpenseEntry] {
        entries.filter { !$0.isEnergyEffective }
    }

    // MARK: - Disk IO

    /// Schedules a save, coalescing every mutation made in the current run-loop
    /// turn into a single encode + write.
    ///
    /// PERF: this used to encode the *entire* entries array to JSON on the main
    /// actor inside `entries.didSet` — synchronously, on every single mutation.
    /// The CSV import in `CSVChargingWizardView.startImport()` calls
    /// `addOrReplace(_:)` once per row in a synchronous loop, so importing N
    /// rows performed N full encodes of an array that grows to N — O(N²) JSON
    /// serialization on the main thread, with the whole UI (including the
    /// import progress bar) wedged until it finished. A few thousand rows meant
    /// a freeze measured in minutes.
    ///
    /// Now a burst of mutations sets a flag and hops through a `Task`, which
    /// only runs once the synchronous burst has returned to the run loop, so
    /// the import produces exactly one save. The encode itself also moved off
    /// the main actor onto `writeQueue` — the array snapshot is a value type,
    /// so handing it to the serial queue is safe and the queue preserves write
    /// ordering.
    private func persistAsync() {
        guard !hasPendingSave else { return }
        hasPendingSave = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.hasPendingSave = false
            self.flushToDisk(self.entries)
        }
    }

    /// Encodes and writes `snapshot` on the serial write queue.
    private func flushToDisk(_ snapshot: [ExpenseEntry]) {
        let url = saveURL
        writeQueue.async {
            let encoder = JSONEncoder()
            encoder.outputFormatting = []                 // compact
            encoder.dateEncodingStrategy = .iso8601

            do {
                let data = try encoder.encode(snapshot)
                var options: Data.WritingOptions = [.atomic]
                #if os(iOS)
                options.insert(.completeFileProtection) // ignored where unsupported
                #endif
                try data.write(to: url, options: options)
            } catch {
                #if DEBUG
                print("EntriesStore save error:", error)
                #endif
            }
        }
    }

    /// Async load at initialization (off-main file I/O + decode).
    private func loadAsync() {
        let url = saveURL
        Task.detached(priority: .utility) { [url] in
            let decoded: [ExpenseEntry]
            do {
                let data = try Data(contentsOf: url)
                let dec = JSONDecoder()
                dec.dateDecodingStrategy = .iso8601
                decoded = try dec.decode([ExpenseEntry].self, from: data)
            } catch {
                decoded = []
                await MainActor.run {
                    #if DEBUG
                    let ns = error as NSError
                    if !(ns.domain == NSCocoaErrorDomain && ns.code == NSFileReadNoSuchFileError) {
                        print("EntriesStore load warning:", error)
                    }
                    #endif
                }
            }

            await MainActor.run { [decoded] in
                // Capture any entries that were written before hydration completed
                // (e.g., from another store's init calling upsert during this window).
                let pending = self.entries
                self.isHydrating = true
                self.entries = decoded
                // Merge pending entries that aren't already in the loaded data.
                for e in pending where !decoded.contains(where: { $0.id == e.id }) {
                    self.entries.append(e)
                }
                self.isHydrating = false
            }
        }
    }
}
