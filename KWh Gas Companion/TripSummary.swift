//
//  TripSummary.swift
//  KWh Gas Companion
//
//  Created by Bryan on 8/9/25.
//


// TripSummary.swift
// Summarizes one day of trips: miles, kWh, and cost-at-supercharger-rate.

import Foundation

public struct TripSummary: Equatable {
    public let date: Date
    public let distanceMiles: Double?   // nil if odometer values are missing
    public let energyKWh: Double
    public let estimatedCostUSD: Double

    public init(date: Date, trips: [TeslaFiTrip], superchargerRate: Double, calendar: Calendar = .current) {
        self.date = calendar.startOfDay(for: date)

        let sorted = trips.sorted(by: { $0.date < $1.date })
        let odometers = sorted.compactMap { $0.odometer }
        if let minOdo = odometers.min(), let maxOdo = odometers.max(), maxOdo >= minOdo {
            self.distanceMiles = maxOdo - minOdo
        } else {
            self.distanceMiles = nil
        }

        self.energyKWh = sorted.compactMap { $0.energyKWh }.reduce(0, +)
        self.estimatedCostUSD = self.energyKWh * max(0, superchargerRate)
    }
}

public extension Array where Element == TeslaFiTrip {
    /// Build a summary for the given calendar day.
    func dailySummary(on day: Date, superchargerRate: Double, calendar: Calendar = .current) -> TripSummary {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let tripsForDay = self.filter { $0.date >= start && $0.date < end }
        return TripSummary(date: start, trips: tripsForDay, superchargerRate: superchargerRate, calendar: calendar)
    }
}
