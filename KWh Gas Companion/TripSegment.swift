//  TripSegment.swift
//  KWh Gas Companion
//
//  Model representing a day's worth of TeslaFi trips (a "segment").
//  Depends on the single, project-wide TeslaFiTrip model defined in TeslaFiTrip.swift.

import Foundation

public struct TripSegment: Identifiable, Equatable, Codable {
    public let id: UUID
    /// Start-of-day (Calendar.current by default when built) for grouping
    public let day: Date
    /// Trips that occurred on `day`, sorted by timestamp ascending
    public private(set) var trips: [TeslaFiTrip]

    // MARK: - Aggregates

    /// Minimum odometer reading found in `trips`
    public var startOdometer: Double? { trips.compactMap { $0.odometer }.min() }

    /// Maximum odometer reading found in `trips`
    public var endOdometer: Double? { trips.compactMap { $0.odometer }.max() }

    /// Distance computed as `endOdometer - startOdometer` when both exist and non-negative
    public var distance: Double? {
        guard let s = startOdometer, let e = endOdometer, e >= s else { return nil }
        return e - s
    }

    /// Sum of all kWh across trips (ignores nils)
    public var totalEnergyKWh: Double {
        trips.compactMap { $0.energyKWh }.reduce(0, +)
    }

    /// Distinct non-empty locations, alphabetized
    public var locations: [String] {
        Array(Set(trips.compactMap { $0.location?.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }))
            .sorted()
    }

    /// Number of trips in this segment
    public var tripCount: Int { trips.count }

    // MARK: - Init

    public init(id: UUID = UUID(), day: Date, trips: [TeslaFiTrip]) {
        self.id = id
        self.day = day
        self.trips = trips.sorted(by: { $0.date < $1.date })
    }

    // MARK: - Mutation

    /// Append a trip to this segment and keep trips sorted
    public mutating func append(_ trip: TeslaFiTrip) {
        trips.append(trip)
        trips.sort(by: { $0.date < $1.date })
    }

    /// Append multiple trips to this segment and keep trips sorted
    public mutating func append(contentsOf newTrips: [TeslaFiTrip]) {
        guard !newTrips.isEmpty else { return }
        trips.append(contentsOf: newTrips)
        trips.sort(by: { $0.date < $1.date })
    }

    // MARK: - Builders

    /// Build day-based segments from a flat list of trips using the provided calendar.
    public static func buildSegments(
        from trips: [TeslaFiTrip],
        calendar: Calendar = .current
    ) -> [TripSegment] {
        guard !trips.isEmpty else { return [] }

        // Group by start-of-day
        let groups = Dictionary(grouping: trips) { t in
            calendar.startOfDay(for: t.date)
        }

        // Map to segments
        var segments = groups.map { (day, tripsForDay) in
            TripSegment(day: day, trips: tripsForDay)
        }

        // Sort newest day first
        segments.sort(by: { $0.day > $1.day })
        return segments
    }

    /// Merge new trips into existing segments by calendar day.
    /// Creates segments when none exist for that day.
    public static func merge(
        existing: [TripSegment],
        with newTrips: [TeslaFiTrip],
        calendar: Calendar = .current
    ) -> [TripSegment] {
        guard !newTrips.isEmpty else { return existing }
        if existing.isEmpty { return buildSegments(from: newTrips, calendar: calendar) }

        // Index existing by day for quick lookups
        var byDay: [Date: TripSegment] = Dictionary(uniqueKeysWithValues: existing.map { ($0.day, $0) })

        // Assign each new trip to its start-of-day bucket
        for trip in newTrips {
            let day = calendar.startOfDay(for: trip.date)
            if var seg = byDay[day] {
                seg.append(trip)
                byDay[day] = seg
            } else {
                byDay[day] = TripSegment(day: day, trips: [trip])
            }
        }

        // Return sorted segments, newest first
        var merged = Array(byDay.values)
        merged.sort(by: { $0.day > $1.day })
        return merged
    }
}
