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

    /// Serialize / write on a background queue (Data only, never the array itself).
    private let writeQueue = DispatchQueue(label: "EntriesStore.WriteQueue", qos: .utility)

    /// JSON encoder/decoder (main-actor only)
    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = []                 // compact
        enc.dateEncodingStrategy = .iso8601
        return enc
    }()

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

    /// Encodes on the main actor (safe for `@MainActor`-isolated `entries`),
    /// then writes the Data on a background queue.
    private func persistAsync() {
        // 1) Encode on main actor
        let data: Data
        do {
            data = try encoder.encode(entries)
        } catch {
            #if DEBUG
            print("EntriesStore encode error:", error)
            #endif
            return
        }

        // 2) Write Data off the main thread
        let url = saveURL
        writeQueue.async { [url] in
            do {
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
