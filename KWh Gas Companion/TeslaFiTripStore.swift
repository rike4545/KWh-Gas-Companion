//  TeslaFiTripStore.swift
//  KWh Gas Companion
//
//  Stores raw TeslaFiTrip rows with de-duplication and helpers to group by day.
//  Depends on:
//    - TeslaFiTrip (in TeslaFiTrip.swift)
//    - TripSegment (in TripSegment.swift)

import Foundation
import Combine

public final class TeslaFiTripStore: ObservableObject {
    @Published public private(set) var trips: [TeslaFiTrip] = []

    private let calendar: Calendar
    private var seenKeys: Set<String> = []

    // Persistence (optional)
    private let persistToDisk: Bool
    private let fileURL: URL?

    // MARK: - Init

    public init(
        calendar: Calendar = .current,
        seed: [TeslaFiTrip] = [],
        persistToDisk: Bool = false,
        filename: String = "teslafi_trips.json"
    ) {
        self.calendar = calendar
        self.persistToDisk = persistToDisk

        if persistToDisk {
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            self.fileURL = dir?.appendingPathComponent(filename)
            if seed.isEmpty, let loaded = try? Self.load(from: fileURL) {
                self.trips = loaded.sorted(by: { $0.date > $1.date })
            } else {
                self.trips = seed.sorted(by: { $0.date > $1.date })
            }
        } else {
            self.fileURL = nil
            self.trips = seed.sorted(by: { $0.date > $1.date })
        }

        rebuildSeen()
    }

    // MARK: - Public API

    /// Ingest new trips, skipping duplicates. Returns count actually added.
    @discardableResult
    public func ingest(_ newTrips: [TeslaFiTrip]) -> Int {
        guard !newTrips.isEmpty else { return 0 }

        var added = 0
        var latest = trips

        for t in newTrips {
            let k = dedupKey(for: t)
            if seenKeys.contains(k) { continue }
            seenKeys.insert(k)
            latest.append(t)
            added += 1
        }

        guard added > 0 else { return 0 }
        latest.sort(by: { $0.date > $1.date })
        trips = latest
        persistIfNeeded()
        return added
    }

    /// Replace the entire store.
    public func replaceAll(with trips: [TeslaFiTrip]) {
        self.trips = trips.sorted(by: { $0.date > $1.date })
        rebuildSeen()
        persistIfNeeded()
    }

    /// Remove everything.
    public func clear() {
        trips.removeAll()
        seenKeys.removeAll()
        persistIfNeeded()
    }

    /// Remove a single trip by ID.
    public func remove(id: UUID) {
        if let idx = trips.firstIndex(where: { $0.id == id }) {
            let k = dedupKey(for: trips[idx])
            trips.remove(at: idx)
            seenKeys.remove(k)
            persistIfNeeded()
        }
    }

    /// All trips on the same calendar day.
    public func trips(on day: Date) -> [TeslaFiTrip] {
        trips.filter { calendar.isDate($0.date, inSameDayAs: day) }
             .sorted(by: { $0.date < $1.date })
    }

    /// Build day-based segments from current trips.
    public func segments() -> [TripSegment] {
        TripSegment.buildSegments(from: trips, calendar: calendar)
    }

    /// Quick per-day stats (distance via odometer delta, total kWh, count).
    public func stats(for day: Date) -> (distance: Double?, energyKWh: Double, tripCount: Int) {
        let seg = TripSegment(day: calendar.startOfDay(for: day), trips: trips(on: day))
        return (seg.distance, seg.totalEnergyKWh, seg.tripCount)
    }

    // MARK: - Private

    private func rebuildSeen() {
        seenKeys.removeAll(keepingCapacity: true)
        for t in trips {
            seenKeys.insert(dedupKey(for: t))
        }
    }

    /// Stable composite key to avoid duplicate imports.
    private func dedupKey(for t: TeslaFiTrip) -> String {
        let ts = String(Int(t.date.timeIntervalSince1970))
        let odo = t.odometer.map { String(format: "%.1f", $0) } ?? "_"
        let kwh = t.energyKWh.map { String(format: "%.2f", $0) } ?? "_"
        let loc = (t.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return [ts, odo, kwh, loc].joined(separator: "|")
    }

    private func persistIfNeeded() {
        guard persistToDisk, let url = fileURL else { return }
        do {
            let data = try JSONEncoder().encode(trips)
            try data.write(to: url, options: .atomic)
        } catch {
            // Silent fail by default; add logging if you prefer.
            // print("Trip persistence failed:", error)
        }
    }

    private static func load(from url: URL?) throws -> [TeslaFiTrip] {
        guard let url else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([TeslaFiTrip].self, from: data)
    }
}
