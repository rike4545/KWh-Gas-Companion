//
//  ChartSession.swift
//  KWh Gas Companion
//
//

// ChartAdapter.swift
// My KWh Companion
//
// A lightweight adapter that transforms your entries into chart-ready series,
// using closures to map your model's fields (date, isEnergy, kWh, cost, etc).

import Foundation

public struct ChartSession: Identifiable, Equatable {
    public let id = UUID()
    public let date: Date
    public let kwh: Double
    public let cost: Double
    public let durationMinutes: Double?
    public let miles: Double?
}

public struct MonthlyCostPoint: Identifiable {
    public let id = UUID()
    public let month: Date   // month-start date
    public let costPerKWh: Double
}

public struct EfficiencyBin: Identifiable {
    public let id = UUID()
    public let label: String // e.g., "22–24"
    public let count: Int
}

public struct ChargeScatterPoint: Identifiable {
    public let id = UUID()
    public let minutes: Double
    public let kwh: Double
}

public struct ChartAdapter<Source> {
    // Raw sessions after mapping & filtering
    private let sessions: [ChartSession]
    private let calendar = Calendar.current

    public init(
        entries: [Source],
        mapDate: (Source) -> Date,
        mapIsEnergy: (Source) -> Bool,
        mapKWh: (Source) -> Double?,                // per session energy (kWh)
        mapCost: (Source) -> Double?,               // per session cost ($)
        mapDurationMinutes: (Source) -> Double?,    // optional minutes
        mapMiles: (Source) -> Double?               // optional miles (for kWh/100mi)
    ) {
        // Build normalized sessions (energy-only with valid kWh & cost)
        self.sessions = entries.compactMap { e in
            guard mapIsEnergy(e) else { return nil }
            guard let kwh = mapKWh(e), kwh > 0 else { return nil }
            // cost can be zero (free charging), default to 0 if nil
            let cost = mapCost(e) ?? 0
            return ChartSession(
                date: mapDate(e),
                kwh: kwh,
                cost: cost,
                durationMinutes: mapDurationMinutes(e),
                miles: mapMiles(e)
            )
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: - Series

    /// Monthly cost per kWh = sum(cost) / sum(kWh) per month
    public func monthlyCostPerKWh() -> [MonthlyCostPoint] {
        let byMonth = Dictionary(grouping: sessions) { s in
            calendar.date(from: calendar.dateComponents([.year, .month], from: s.date)) ?? s.date
        }
        .mapValues { arr -> (kwh: Double, cost: Double) in
            arr.reduce(into: (0,0)) { acc, s in
                acc.kwh += s.kwh
                acc.cost += s.cost
            }
        }

        return byMonth
            .compactMap { (month, agg) -> MonthlyCostPoint? in
                guard agg.kwh > 0 else { return nil }
                return MonthlyCostPoint(month: month, costPerKWh: agg.cost / agg.kwh)
            }
            .sorted { $0.month < $1.month }
    }

    /// Histogram bins for kWh/100mi using sessions that have miles
    /// `range` is the min..max center; `step` is bin width (e.g., 2 → "22–24")
    public func efficiencyBins(range: ClosedRange<Int> = 18...36, step: Int = 2) -> [EfficiencyBin] {
        guard step > 0 else { return [] }

        // Build empty bins
        var bins: [(label: String, count: Int)] = stride(from: range.lowerBound, through: range.upperBound - step, by: step).map { start in
            (label: "\(start)–\(start + step)", count: 0)
        }

        for s in sessions {
            guard let miles = s.miles, miles > 0 else { continue }
            let kwhPer100 = (s.kwh / miles) * 100.0
            let rounded = Int(floor(Double(roundedToStep(kwhPer100, step: step))))
            // Find the bin index
            if let idx = bins.firstIndex(where: { label in
                let parts = label.label.split(separator: "–").compactMap { Int($0) }
                guard parts.count == 2 else { return false }
                return rounded >= parts[0] && rounded < parts[1]
            }) {
                bins[idx].count += 1
            }
        }

        return bins.map { EfficiencyBin(label: $0.label, count: $0.count) }
    }

    /// Scatter points of duration (minutes) vs energy (kWh)
    public func chargeScatter() -> [ChargeScatterPoint] {
        sessions.compactMap { s in
            guard let m = s.durationMinutes, m > 0 else { return nil }
            return ChargeScatterPoint(minutes: m, kwh: s.kwh)
        }
    }

    // MARK: - Helpers
    private func roundedToStep(_ value: Double, step: Int) -> Int {
        let s = Double(step)
        return Int((value / s).rounded(.down) * s)
    }
}
