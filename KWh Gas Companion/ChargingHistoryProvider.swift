//
//  ChargingHistoryProvider.swift
//  KWh Gas Companion
//
//  Created by Bryan on 11/2/25.
//


//  ForecastEngine.swift
//  My KWh Companion
//  Seasonal rates + behavior-driven monthly forecast (Swift 6 / iOS 17+)

import Foundation

// MARK: - Protocols

/// Minimal history provider so ForecastEngine stays decoupled from your stores.
public protocol ChargingHistoryProvider {
    /// Return sessions in [start, end). Energy is in kWh; cost is currency.
    func sessions(from start: Date, to end: Date) async -> [ChargeSession]
}

/// Lightweight session DTO for forecasting.
public struct ChargeSession: Sendable, Hashable {
    public var start: Date
    public var end: Date
    public var energyKWh: Double
    public var cost: Double?
    public var isSupercharging: Bool
    public init(start: Date, end: Date, energyKWh: Double, cost: Double?, isSupercharging: Bool) {
        self.start = start; self.end = end; self.energyKWh = energyKWh; self.cost = cost; self.isSupercharging = isSupercharging
    }
}

// MARK: - Rate Model

public struct RatePlan: Sendable, Hashable {
    public struct SeasonRate: Sendable, Hashable {
        public var startMonth: Int  // 1...12
        public var endMonth: Int    // 1...12 (inclusive)
        public var dailyService: Double // $/day
        public var deliveryPerKWh: Double
        public var note: String
        public init(startMonth: Int, endMonth: Int, dailyService: Double, deliveryPerKWh: Double, note: String) {
            self.startMonth = startMonth; self.endMonth = endMonth; self.dailyService = dailyService; self.deliveryPerKWh = deliveryPerKWh; self.note = note
        }
    }
    public var summer: SeasonRate
    public var winter: SeasonRate
    public init(summer: SeasonRate, winter: SeasonRate) {
        self.summer = summer; self.winter = winter
    }

    public func rate(for month: Int) -> SeasonRate {
        func contains(_ r: SeasonRate, _ m: Int) -> Bool {
            if r.startMonth <= r.endMonth { return (r.startMonth...r.endMonth).contains(m) }
            // wrap-around (e.g., Oct–May)
            return m >= r.startMonth || m <= r.endMonth
        }
        return contains(summer, month) ? summer : winter
    }
}

public struct SuperchargePricing: Sendable, Hashable {
    public var perKWh: Double // simple flat assumption; refine later if you have tiers
    public init(perKWh: Double) { self.perKWh = perKWh }
}

// MARK: - Inputs / Outputs

public struct ForecastInputs: Sendable, Hashable {
    public var month: DateComponents // year + month
    public var homeRate: RatePlan
    public var supercharge: SuperchargePricing
    public var expectedHomeShare: Double // 0...1 fraction of energy
    public var expectedTotalMiles: Double
    public var expectedWhPerMile: Double
    public var daysInMonthOverride: Int?

    public init(
        month: DateComponents,
        homeRate: RatePlan,
        supercharge: SuperchargePricing,
        expectedHomeShare: Double,
        expectedTotalMiles: Double,
        expectedWhPerMile: Double,
        daysInMonthOverride: Int? = nil
    ) {
        self.month = month
        self.homeRate = homeRate
        self.supercharge = supercharge
        self.expectedHomeShare = max(0, min(1, expectedHomeShare))
        self.expectedTotalMiles = max(0, expectedTotalMiles)
        self.expectedWhPerMile = max(1, expectedWhPerMile)
        self.daysInMonthOverride = daysInMonthOverride
    }
}

public struct ForecastResult: Sendable, Hashable {
    public var monthStart: Date
    public var daysInMonth: Int

    public var projectedEnergyKWh: Double
    public var homeEnergyKWh: Double
    public var superchargeEnergyKWh: Double

    public var homeCost: Double
    public var superchargeCost: Double
    public var totalCost: Double

    public var notes: [String]
}

// MARK: - Engine

public actor ForecastEngine {
    private let history: ChargingHistoryProvider
    private let calendar: Calendar

    public init(history: ChargingHistoryProvider, calendar: Calendar = .autoupdatingCurrent) {
        self.history = history
        self.calendar = calendar
    }

    public func forecast(_ inputs: ForecastInputs) async -> ForecastResult {
        let comp = inputs.month
        let monthStart = calendar.date(from: DateComponents(year: comp.year, month: comp.month, day: 1)) ?? Date()
        let monthRange = calendar.range(of: .day, in: .month, for: monthStart)!
        let daysInMonth = inputs.daysInMonthOverride ?? monthRange.count
        let monthEnd = calendar.date(byAdding: .day, value: daysInMonth, to: monthStart)!

        // Behavior baseline from expected miles & efficiency
        let projectedEnergy = inputs.expectedTotalMiles * (inputs.expectedWhPerMile / 1000.0)
        let homeEnergy = projectedEnergy * inputs.expectedHomeShare
        let scEnergy = projectedEnergy - homeEnergy

        // Rates
        let month = calendar.component(.month, from: monthStart)
        let homeSeason = inputs.homeRate.rate(for: month)
        let homeCost = (homeEnergy * homeSeason.deliveryPerKWh) + (homeSeason.dailyService * Double(daysInMonth))
        let superchargeCost = scEnergy * inputs.supercharge.perKWh

        // Notes (include a tiny backcast)
        let backcast = await backcastEnergyKWh(for: monthStart, end: monthEnd)
        var notes: [String] = []
        notes.append("Behavior-driven projection from \(Int(inputs.expectedTotalMiles)) mi @ \(Int(inputs.expectedWhPerMile)) Wh/mi.")
        notes.append("Backcast last \(calendar.monthSymbols[month-1]) energy: \(String(format: "%.0f", backcast)) kWh (observed).")
        notes.append("Home season: \(homeSeason.note). Daily svc \(currency(homeSeason.dailyService))/day, delivery \(currency(homeSeason.deliveryPerKWh))/kWh.")
        notes.append("Supercharge: \(currency(inputs.supercharge.perKWh))/kWh (flat).")

        return ForecastResult(
            monthStart: monthStart,
            daysInMonth: daysInMonth,
            projectedEnergyKWh: projectedEnergy,
            homeEnergyKWh: homeEnergy,
            superchargeEnergyKWh: scEnergy,
            homeCost: homeCost,
            superchargeCost: superchargeCost,
            totalCost: homeCost + superchargeCost,
            notes: notes
        )
    }

    // MARK: - Helpers

    private func backcastEnergyKWh(for start: Date, end: Date) async -> Double {
        let sessions = await history.sessions(from: start, to: end)
        return sessions.reduce(0) { $0 + max(0, $1.energyKWh) }
    }

    private func currency(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency
        return f.string(from: NSNumber(value: v)) ?? String(format: "$%.2f", v)
    }
}
