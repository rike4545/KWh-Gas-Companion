//  TripShiftStore.swift
//  KWh Gas Companion
//
//  Stores TeslaFi trips grouped by calendar day (TripSegment).
//  - Merge-friendly ingest() with de-duplication
//  - Simple stats and lookups
//
//  Depends on:
//    - TeslaFiTrip (in TeslaFiTrip.swift)
//    - TripSegment (in TripSegment.swift)

import Foundation
import Combine

public final class TripShiftStore: ObservableObject {
    @Published public private(set) var segments: [TripSegment] = []

    private var calendar: Calendar
    /// Dedup keys for trips already stored
    private var seenKeys: Set<String> = []

    // MARK: - Init

    public init(
        calendar: Calendar = .current,
        seed trips: [TeslaFiTrip] = []
    ) {
        self.calendar = calendar
        if !trips.isEmpty {
            self.segments = TripSegment.buildSegments(from: trips, calendar: calendar)
            rebuildSeenKeys()
        }
    }

    // MARK: - Public API

    /// Merge new trips into existing day segments. Skips duplicates.
    @discardableResult
    public func ingest(_ newTrips: [TeslaFiTrip]) -> Int {
        guard !newTrips.isEmpty else { return 0 }

        // Filter duplicates first
        let unique = newTrips.filter { trip in
            let k = dedupKey(for: trip)
            if seenKeys.contains(k) { return false }
            seenKeys.insert(k)
            return true
        }
        guard !unique.isEmpty else { return 0 }

        // Merge into segments
        segments = TripSegment.merge(existing: segments, with: unique, calendar: calendar)
        return unique.count
    }

    /// Replace the entire store with a new list of trips.
    public func replaceAll(with trips: [TeslaFiTrip]) {
        segments = TripSegment.buildSegments(from: trips, calendar: calendar)
        rebuildSeenKeys()
    }

    /// Remove everything.
    public func clear() {
        segments.removeAll()
        seenKeys.removeAll()
    }

    /// Return all trips (flattened), newest first.
    public func allTrips() -> [TeslaFiTrip] {
        segments
            .sorted(by: { $0.day > $1.day })
            .flatMap { $0.trips }
            .sorted(by: { $0.date > $1.date })
    }

    /// Find the segment for a specific date (same calendar day).
    public func segment(for date: Date) -> TripSegment? {
        segments.first(where: { calendar.isDate($0.day, inSameDayAs: date) })
    }

    /// Remove all trips on a specific day.
    public func removeTrips(on day: Date) {
        let start = calendar.startOfDay(for: day)
        segments.removeAll(where: { calendar.isDate($0.day, inSameDayAs: start) })
        rebuildSeenKeys()
    }

    /// Basic stats for a day (distance, energy, trip count).
    public func stats(for day: Date) -> (distance: Double?, energyKWh: Double, tripCount: Int) {
        guard let seg = segment(for: day) else { return (nil, 0, 0) }
        return (seg.distance, seg.totalEnergyKWh, seg.tripCount)
    }

    // MARK: - Private

    private func rebuildSeenKeys() {
        seenKeys.removeAll(keepingCapacity: true)
        for t in allTrips() {
            seenKeys.insert(dedupKey(for: t))
        }
    }

    /// Build a stable composite key so the same TeslaFi row doesn't import twice.
    /// We keep it tolerant to minor formatting differences.
    private func dedupKey(for trip: TeslaFiTrip) -> String {
        // Round date to seconds for stability
        let ts = String(Int(trip.date.timeIntervalSince1970))
        let odo = trip.odometer.map { String(format: "%.1f", $0) } ?? "_"
        let kwh = trip.energyKWh.map { String(format: "%.2f", $0) } ?? "_"
        let loc = (trip.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return [ts, odo, kwh, loc].joined(separator: "|")
    }
}
