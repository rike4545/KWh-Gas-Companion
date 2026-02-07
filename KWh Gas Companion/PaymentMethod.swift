//
//  PaymentMethod.swift
//  KWh Gas Companion
//
//  Created by Bryan on 9/3/25.
//


//  EVgoVsTeslaAnalyzer.swift
//  My KWh Companion
//
//  Core calculators for EVgo vs Tesla, plus Electrify America and Month‑to‑Date what‑ifs.
//  Depends on: EVgoPlan.swift, EVgoPlanSpec.swift, ProviderComparison.swift, RateModel.swift,
//              MonthToDateSummary.swift, ProviderDelta.swift
//
//  ⚠️ Disclaimers (display elsewhere in UI):
//  • Tesla Supercharger rates vary by location and can fluctuate with demand, time of day, and station speed.
//  • EVgo pricing depends on plan, location, and time of use. Station‑specific pricing is available in the EVgo app.
//  • ChargePoint not compared because station owners set pricing independently; see their app for station rates.

import Foundation

// MARK: - Public simple types used by UI

public enum PaymentMethod: String, Codable, Hashable { case appOrRFID, creditCard }

public enum ChargingDefaults {
    /// EVgo CCS DC Fast base price (before plan discounts): $0.520/kWh
    public static let evgoCCS_BasePricePerKWh: Double = 0.520
    /// EVgo Level 2 hourly price: $1.50/hr (convert with avg power)
    public static let evgoL2_PerHour: Double = 1.50

    /// Tesla Owner schedule
    public static let teslaOwner_TOU: [TimeOfUseTier] = [
        .init(0, 4, 0.30), .init(4, 9, 0.30), .init(9, 23, 0.39), .init(23, 24, 0.30)
    ]
    /// Tesla All‑EVs schedule
    public static let teslaAllEVs_TOU: [TimeOfUseTier] = [
        .init(0, 4, 0.42), .init(4, 9, 0.42), .init(9, 23, 0.55), .init(23, 24, 0.42)
    ]

    /// Weighted average helper for TOU based on optional hour mix (0–23 → fraction). If mix is nil,
    /// weights by tier duration / 24.
    public static func weightedTOUPrice(_ tiers: [TimeOfUseTier], hourMix: [Int: Double]? = nil) -> Double {
        if let mix = hourMix, !mix.isEmpty {
            let total = mix.values.reduce(0, +)
            let norm = total > 0 ? mix.mapValues { $0 / total } : mix
            var sum = 0.0
            for h in 0..<24 {
                let weight = norm[h] ?? 0.0
                guard weight > 0 else { continue }
                if let tier = tiers.first(where: { $0.contains(hour: h) }) {
                    sum += weight * tier.pricePerKWh
                }
            }
            return max(0, sum)
        } else {
            let totalHours = max(1, tiers.reduce(0) { $0 + $1.hours })
            let sum = tiers.reduce(0.0) { $0 + (Double($1.hours) * $1.pricePerKWh) }
            return max(0, sum / Double(totalHours))
        }
    }
}

// MARK: - Analyzer

public enum EVgoVsTeslaAnalyzer {

    // MARK: Totals
    public static func monthlyEVgoTotal(
        monthlyKWh: Double,
        sessionsPerMonth: Int,
        evgoStationRate: RateModel,
        planSpec: EVgoPlanSpec,
        paymentMethod: PaymentMethod
    ) -> Double {
        let unitPriceEVgo = unitPrice(for: evgoStationRate, discount: planSpec.energyDiscount)
        let energyCost = monthlyKWh * unitPriceEVgo
        let perSessionOverhead = planSpec.baseSessionFee + (paymentMethod == .creditCard ? planSpec.creditCardTransactionFee : 0.0)
        let sessionCost = Double(max(0, sessionsPerMonth)) * perSessionOverhead
        return max(0, planSpec.monthlyFee + energyCost + sessionCost)
    }

    public static func monthlyTeslaTotal(
        monthlyKWh: Double,
        sessionsPerMonth: Int,
        teslaRate: RateModel,
        teslaPerSessionFee: Double = 0.0
    ) -> Double {
        let unitPriceTesla = unitPrice(for: teslaRate, discount: 0.0)
        let energyCost = monthlyKWh * unitPriceTesla
        let sessionCost = Double(max(0, sessionsPerMonth)) * max(0, teslaPerSessionFee)
        return max(0, energyCost + sessionCost)
    }

    public static func monthlyElectrifyAmericaTotal(
        monthlyKWh: Double,
        sessionsPerMonth: Int,
        ratePerKWh: Double = 0.64,
        monthlyFee: Double = 8.0,
        perSessionFee: Double = 0.0
    ) -> Double {
        let energy = max(0, monthlyKWh) * max(0, ratePerKWh)
        let sessions = Double(max(0, sessionsPerMonth)) * max(0, perSessionFee)
        return monthlyFee + energy + sessions
    }

    // MARK: Provider comparisons
    public static func compareAllProviders(
        monthlyKWh: Double,
        sessionsPerMonth: Int,
        evgoStationRate: RateModel,
        teslaRate: RateModel,
        paymentMethod: PaymentMethod,
        teslaPerSessionFee: Double = 0.0,
        includeEA: Bool = true,
        eaRatePerKWh: Double = 0.64,
        eaMonthlyFee: Double = 8.0,
        eaPerSessionFee: Double = 0.0,
        plans: [EVgoPlan] = EVgoPlan.allCases
    ) -> [ProviderComparison] {
        let tesla = monthlyTeslaTotal(monthlyKWh: monthlyKWh,
                                      sessionsPerMonth: sessionsPerMonth,
                                      teslaRate: teslaRate,
                                      teslaPerSessionFee: teslaPerSessionFee)
        var list: [ProviderComparison] = [.init(label: "Tesla", monthly: tesla, savingsVsTesla: 0)]

        for plan in plans {
            let spec = EVgoPlanSpec.defaults(for: plan)
            let evgo = monthlyEVgoTotal(monthlyKWh: monthlyKWh,
                                        sessionsPerMonth: sessionsPerMonth,
                                        evgoStationRate: evgoStationRate,
                                        planSpec: spec,
                                        paymentMethod: paymentMethod)
            list.append(.init(label: spec.plan.readableName, monthly: evgo, savingsVsTesla: tesla - evgo))
        }

        if includeEA {
            let ea = monthlyElectrifyAmericaTotal(monthlyKWh: monthlyKWh,
                                                  sessionsPerMonth: sessionsPerMonth,
                                                  ratePerKWh: eaRatePerKWh,
                                                  monthlyFee: eaMonthlyFee,
                                                  perSessionFee: eaPerSessionFee)
            list.append(.init(label: "Electrify America", monthly: ea, savingsVsTesla: tesla - ea))
        }

        return list.sorted { $0.monthly < $1.monthly }
    }

    // MARK: Break‑even
    public static func breakEvenKWh(
        sessionsPerMonth: Int,
        evgoStationRate: RateModel,
        planSpec: EVgoPlanSpec,
        paymentMethod: PaymentMethod,
        teslaRate: RateModel,
        teslaPerSessionFee: Double = 0.0
    ) -> Double? {
        let p_e = unitPrice(for: evgoStationRate, discount: planSpec.energyDiscount)
        let p_t = unitPrice(for: teslaRate, discount: 0.0)
        let evgoFixed = planSpec.monthlyFee + Double(max(0, sessionsPerMonth)) * (planSpec.baseSessionFee + (paymentMethod == .creditCard ? planSpec.creditCardTransactionFee : 0.0))
        let teslaFixed = Double(max(0, sessionsPerMonth)) * max(0, teslaPerSessionFee)
        let deltaP = p_e - p_t
        let rhs = teslaFixed - evgoFixed
        if abs(deltaP) < 1e-9 { return evgoFixed <= teslaFixed ? 0.0 : nil }
        let x = rhs / deltaP
        if deltaP > 0 { return x >= 0 ? x : nil }
        let threshold = (evgoFixed - teslaFixed) / (p_t - p_e)
        return threshold > 0 ? threshold : 0.0
    }

    // MARK: Month‑to‑Date (generic)
    public static func monthToDateSummary<T>(
        entries: [T],
        dateOf: (T) -> Date,
        kWhOf: (T) -> Double,
        costOf: ((T) -> Double)? = nil,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> MonthToDateSummary {
        let monthRange = calendar.dateInterval(of: .month, for: referenceDate) ?? DateInterval(start: referenceDate, duration: 0)
        let periodStart = monthRange.start
        let periodEnd = min(Date(), monthRange.end)
        let inRange = entries.filter { d in
            let t = dateOf(d)
            return t >= periodStart && t <= periodEnd
        }
        let kWh = inRange.reduce(0.0) { $0 + max(0, kWhOf($1)) }
        let sessions = inRange.count
        let spend = costOf.map { f in inRange.reduce(0.0) { $0 + max(0, f($1)) } } ?? 0.0
        return .init(periodStart: periodStart, periodEnd: periodEnd, kWh: kWh, sessions: sessions, actualSpend: spend)
    }

    public static func monthToDateWhatIfComparisons<T>(
        entries: [T],
        dateOf: (T) -> Date,
        kWhOf: (T) -> Double,
        costOf: ((T) -> Double)? = nil,
        teslaRate: RateModel,
        evgoStationRate: RateModel,
        evgoPlan: EVgoPlanSpec,
        paymentMethod: PaymentMethod,
        includeEA: Bool = true,
        eaRatePerKWh: Double = 0.64,
        eaMonthlyFee: Double = 8.0,
        eaPerSessionFee: Double = 0.0,
        teslaPerSessionFee: Double = 0.0,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> (summary: MonthToDateSummary, deltas: [ProviderDelta]) {
        let s = monthToDateSummary(entries: entries, dateOf: dateOf, kWhOf: kWhOf, costOf: costOf, referenceDate: referenceDate, calendar: calendar)
        let teslaMonthly = monthlyTeslaTotal(monthlyKWh: s.kWh, sessionsPerMonth: s.sessions, teslaRate: teslaRate, teslaPerSessionFee: teslaPerSessionFee)
        let evgoMonthly  = monthlyEVgoTotal(monthlyKWh: s.kWh, sessionsPerMonth: s.sessions, evgoStationRate: evgoStationRate, planSpec: evgoPlan, paymentMethod: paymentMethod)
        var deltas: [ProviderDelta] = []
        func d(_ m: Double) -> Double? { costOf == nil ? nil : (m - s.actualSpend) }
        deltas.append(.init(label: "Tesla", estMonthlyCost: teslaMonthly, deltaVsActualMTD: d(teslaMonthly), deltaVsTesla: 0))
        deltas.append(.init(label: evgoPlan.plan.readableName, estMonthlyCost: evgoMonthly, deltaVsActualMTD: d(evgoMonthly), deltaVsTesla: evgoMonthly - teslaMonthly))
        if includeEA {
            let eaMonthly = monthlyElectrifyAmericaTotal(monthlyKWh: s.kWh, sessionsPerMonth: s.sessions, ratePerKWh: eaRatePerKWh, monthlyFee: eaMonthlyFee, perSessionFee: eaPerSessionFee)
            deltas.append(.init(label: "Electrify America", estMonthlyCost: eaMonthly, deltaVsActualMTD: d(eaMonthly), deltaVsTesla: eaMonthly - teslaMonthly))
        }
        deltas.sort { $0.estMonthlyCost < $1.estMonthlyCost }
        return (s, deltas)
    }

    // MARK: ExpenseEntry conveniences (internal due to access control)
    // These are intentionally NOT public because ExpenseEntry is internal in most app targets.
    static func monthToDateSummary(entries: [ExpenseEntry], referenceDate: Date = Date(), calendar: Calendar = .current) -> MonthToDateSummary {
        let energy = entries.filter { $0.isEnergyEffective && (($0.energyAddedKWh ?? 0) > 0) }
        return monthToDateSummary(entries: energy,
                                  dateOf: { $0.charging?.endDate ?? $0.charging?.startDate ?? $0.date },
                                  kWhOf:  { $0.energyAddedKWh ?? 0 },
                                  costOf: { $0.amount },
                                  referenceDate: referenceDate,
                                  calendar: calendar)
    }

    static func monthToDateWhatIfComparisons(
        entries: [ExpenseEntry],
        teslaRate: RateModel,
        evgoStationRate: RateModel,
        evgoPlan: EVgoPlanSpec,
        paymentMethod: PaymentMethod,
        includeEA: Bool = true,
        eaRatePerKWh: Double = 0.64,
        eaMonthlyFee: Double = 8.0,
        eaPerSessionFee: Double = 0.0,
        teslaPerSessionFee: Double = 0.0,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> (summary: MonthToDateSummary, deltas: [ProviderDelta]) {
        let energy = entries.filter { $0.isEnergyEffective && (($0.energyAddedKWh ?? 0) > 0) }
        return monthToDateWhatIfComparisons(entries: energy,
                                            dateOf: { $0.charging?.endDate ?? $0.charging?.startDate ?? $0.date },
                                            kWhOf:  { $0.energyAddedKWh ?? 0 },
                                            costOf: { $0.amount },
                                            teslaRate: teslaRate,
                                            evgoStationRate: evgoStationRate,
                                            evgoPlan: evgoPlan,
                                            paymentMethod: paymentMethod,
                                            includeEA: includeEA,
                                            eaRatePerKWh: eaRatePerKWh,
                                            eaMonthlyFee: eaMonthlyFee,
                                            eaPerSessionFee: eaPerSessionFee,
                                            teslaPerSessionFee: teslaPerSessionFee,
                                            referenceDate: referenceDate,
                                            calendar: calendar)
    }

    // MARK: Unit price helper
    private static func unitPrice(for model: RateModel, discount: Double) -> Double {
        let base: Double
        switch model {
        case .perKWh(let p):
            base = p
        case .perMinute(let perMin, let avgPowerkW):
            base = perMin * 60.0 / max(1e-6, avgPowerkW)
        case .perHour(let perHour, let avgPowerkW):
            base = perHour / max(1e-6, avgPowerkW)
        case .timeOfUse(let tiers, let mix):
            base = ChargingDefaults.weightedTOUPrice(tiers, hourMix: mix)
        }
        return max(0, base * (1.0 - max(0, discount)))
    }
}
