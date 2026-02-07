//
//  SuperchargerPriceSample.swift
//  KWh Gas Companion
//
//  Created by Bryan on 1/2/26.
//


//
//  SuperchargerPriceStore.swift
//  My KWh Companion
//
//  Local history of Supercharger prices keyed by station (String ID).
//  Used by SuperchargerPredictionEngine + SuperchargerPredictionViewModel.
//
//  Upgrade:
//  - Adds bulk ingest for “official” scraped prices
//  - Adds dedupe + sample trimming (prevents growth explosions)
//  - Moves persistence to Application Support JSON (migrates from old UserDefaults key)
//

import Foundation

/// A single logged Supercharger price sample.
struct SuperchargerPriceSample: Identifiable, Codable, Hashable {
    let id: UUID
    /// Matches station id/slug (String).
    let stationId: String
    let pricePerKwh: Double
    let timestamp: Date

    init(
        id: UUID = UUID(),
        stationId: String,
        pricePerKwh: Double,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.stationId = stationId
        self.pricePerKwh = pricePerKwh
        self.timestamp = timestamp
    }
}

/// Lightweight payload for “official” price snapshots (scraped).
struct OfficialSuperchargerPrice: Codable, Hashable {
    let stationId: String
    let pricePerKwh: Double
    let fetchedAt: Date
    let sourceURL: URL?

    init(stationId: String, pricePerKwh: Double, fetchedAt: Date = Date(), sourceURL: URL? = nil) {
        self.stationId = stationId
        self.pricePerKwh = pricePerKwh
        self.fetchedAt = fetchedAt
        self.sourceURL = sourceURL
    }
}

@MainActor
final class SuperchargerPriceStore: ObservableObject {
    /// Shared instance used by the prediction VM by default.
    static let shared = SuperchargerPriceStore()

    /// All samples for all stations.
    @Published private(set) var allSamples: [SuperchargerPriceSample] = []

    // OLD: UserDefaults key (migration source)
    private let legacyStorageKey = "SuperchargerPriceSamples.v1"

    // NEW: file-based persistence
    private let cacheFilename = "supercharger_price_samples_v2.json"

    // Safety caps (prevents unbounded growth)
    private let maxSamplesPerStation = 240     // e.g. 240 samples per station
    private let maxTotalSamples = 50_000       // hard cap overall

    // MARK: - Init

    private init() {
        load()
    }

    // MARK: - Public API used by the ViewModel / Engine

    /// Returns price history for a given station, sorted oldest → newest.
    func history(for stationId: String) -> [SuperchargerPriceSample] {
        allSamples
            .filter { $0.stationId == stationId }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Most recent sample for a station (if any).
    func mostRecent(for stationId: String) -> SuperchargerPriceSample? {
        allSamples
            .filter { $0.stationId == stationId }
            .max(by: { $0.timestamp < $1.timestamp })
    }

    /// Adds a new sample for the given station and persists it.
    func addSample(
        stationId: String,
        pricePerKwh: Double,
        timestamp: Date = Date()
    ) {
        let sample = SuperchargerPriceSample(
            stationId: stationId,
            pricePerKwh: pricePerKwh,
            timestamp: timestamp
        )

        allSamples.append(sample)
        trimIfNeeded()
        persist()
    }

    /// Adds a new sample only if it differs from the most recent sample (or the last sample is “stale”).
    ///
    /// - Parameters:
    ///   - minInterval: If the last sample is newer than this interval AND the price is unchanged, skip.
    ///   - epsilon: small tolerance for floating comparisons.
    func addSampleIfChanged(
        stationId: String,
        pricePerKwh: Double,
        timestamp: Date = Date(),
        minInterval: TimeInterval = 6 * 60 * 60, // 6 hours
        epsilon: Double = 0.0001
    ) {
        if let last = mostRecent(for: stationId) {
            let unchanged = abs(last.pricePerKwh - pricePerKwh) <= epsilon
            let freshEnough = timestamp.timeIntervalSince(last.timestamp) < minInterval
            if unchanged && freshEnough { return }
        }

        addSample(stationId: stationId, pricePerKwh: pricePerKwh, timestamp: timestamp)
    }

    /// Bulk ingest: feed in official scraped prices (fixed $/kWh stations).
    /// This persists once at the end (fast).
    func ingestOfficialPrices(
        _ prices: [OfficialSuperchargerPrice],
        minInterval: TimeInterval = 6 * 60 * 60,
        epsilon: Double = 0.0001
    ) {
        guard !prices.isEmpty else { return }

        var appended = 0

        for p in prices {
            let stationId = p.stationId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !stationId.isEmpty else { continue }
            guard p.pricePerKwh > 0 else { continue }

            if let last = mostRecent(for: stationId) {
                let unchanged = abs(last.pricePerKwh - p.pricePerKwh) <= epsilon
                let freshEnough = p.fetchedAt.timeIntervalSince(last.timestamp) < minInterval
                if unchanged && freshEnough { continue }
            }

            allSamples.append(
                SuperchargerPriceSample(
                    stationId: stationId,
                    pricePerKwh: p.pricePerKwh,
                    timestamp: p.fetchedAt
                )
            )
            appended += 1
        }

        if appended > 0 {
            trimIfNeeded()
            persist()
        }
    }

    /// Optional: remove all samples for a station.
    func clearHistory(for stationId: String) {
        allSamples.removeAll { $0.stationId == stationId }
        persist()
    }

    /// Optional: nuke all stored samples.
    func clearAll() {
        allSamples.removeAll()
        persist()
    }

    // MARK: - Persistence

    private func load() {
        // 1) Prefer file cache
        if let fileURL = try? cacheURL(),
           let data = try? Data(contentsOf: fileURL) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                allSamples = try decoder.decode([SuperchargerPriceSample].self, from: data)
                trimIfNeeded()
                return
            } catch {
                // fall through to legacy
            }
        }

        // 2) Legacy migration from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: legacyStorageKey) else {
            allSamples = []
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            allSamples = try decoder.decode([SuperchargerPriceSample].self, from: data)
            trimIfNeeded()

            // Persist to file and clear legacy key
            persist()
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        } catch {
            allSamples = []
        }
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(allSamples)

            let url = try cacheURL()
            try data.write(to: url, options: [.atomic])
        } catch {
            #if DEBUG
            print("SuperchargerPriceStore persist error: \(error)")
            #endif
        }
    }

    private func cacheURL() throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("SuperchargerPrices", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(cacheFilename)
    }

    // MARK: - Trimming / caps

    private func trimIfNeeded() {
        // Cap total
        if allSamples.count > maxTotalSamples {
            allSamples.sort { $0.timestamp > $1.timestamp } // newest first
            allSamples = Array(allSamples.prefix(maxTotalSamples))
        }

        // Cap per station
        let grouped = Dictionary(grouping: allSamples, by: { $0.stationId })
        var trimmed: [SuperchargerPriceSample] = []
        trimmed.reserveCapacity(allSamples.count)

        for (_, samples) in grouped {
            let sorted = samples.sorted { $0.timestamp > $1.timestamp } // newest first
            trimmed.append(contentsOf: sorted.prefix(maxSamplesPerStation))
        }

        // Normalize final ordering (optional)
        allSamples = trimmed.sorted { $0.timestamp < $1.timestamp }
    }
}
