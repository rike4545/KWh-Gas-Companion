//
//  SparkSummaryResult.swift
//  KWh Gas Companion — Spark
//
//  Regenerated: Oct 27, 2025
//

import Foundation

// MARK: - Public Result Model

public struct SparkSummaryResult: Hashable {
    public var title: String
    public var message: String
    public var totalDistance: Double
    public var totalEnergyKWh: Double
    public var avgWhPerMile: Double
    public var entryCount: Int

    public var totalCost: Double?
    public var avgPricePerKWh: Double?
    public var avgCostPerMile: Double?
    public var co2Kg: Double?
    public var bestKind: String?
    public var worstKind: String?
    public var anomalyCount: Int?
    public var dialogLine: String

    public init(
        title: String,
        message: String,
        totalDistance: Double,
        totalEnergyKWh: Double,
        avgWhPerMile: Double,
        entryCount: Int,
        totalCost: Double? = nil,
        avgPricePerKWh: Double? = nil,
        avgCostPerMile: Double? = nil,
        co2Kg: Double? = nil,
        bestKind: String? = nil,
        worstKind: String? = nil,
        anomalyCount: Int? = nil,
        dialogLine: String = ""
    ) {
        self.title = title
        self.message = message
        self.totalDistance = totalDistance
        self.totalEnergyKWh = totalEnergyKWh
        self.avgWhPerMile = avgWhPerMile
        self.entryCount = entryCount
        self.totalCost = totalCost
        self.avgPricePerKWh = avgPricePerKWh
        self.avgCostPerMile = avgCostPerMile
        self.co2Kg = co2Kg
        self.bestKind = bestKind
        self.worstKind = worstKind
        self.anomalyCount = anomalyCount
        self.dialogLine = dialogLine
    }
}

// MARK: - Repository

public protocol SparkEntriesRepository {
    func entries(from start: Date, to end: Date) async -> [SparkShiftEntry]
}

public struct StoreEntriesRepo: SparkEntriesRepository {
    public let readAllEntries: @MainActor () -> [SparkShiftEntry]
    public init(readAllEntries: @escaping @MainActor () -> [SparkShiftEntry]) {
        self.readAllEntries = readAllEntries
    }
    public func entries(from start: Date, to end: Date) async -> [SparkShiftEntry] {
        await MainActor.run {
            readAllEntries().filter { e in e.date >= start && e.date < end }
        }
    }
}

public struct InMemoryEntriesRepo: SparkEntriesRepository {
    public var items: [SparkShiftEntry]
    public init(items: [SparkShiftEntry]) { self.items = items }
    public func entries(from start: Date, to end: Date) async -> [SparkShiftEntry] {
        items.filter { $0.date >= start && $0.date < end }
    }
}

// MARK: - Summarizer

public enum SparkDistanceUnit: String, Codable, Hashable { case miles, kilometers }

public struct LocalSparkSummarizer {

    public var repo: SparkEntriesRepository
    public var now: Date
    public var calendar: Calendar
    public var locale: Locale
    public var distanceUnit: SparkDistanceUnit

    public var costOf: (SparkShiftEntry) -> Double?
    public var pricePerKWhOf: (SparkShiftEntry) -> Double?
    public var tripKindOf: (SparkShiftEntry) -> SparkTripKind?
    public var milesOf: (SparkShiftEntry) -> Double?
    public var energyKWhOf: (SparkShiftEntry) -> Double?
    public var gridKgCO2PerKWh: () -> Double?

    public var trace: Bool = false

    public init(
        repo: SparkEntriesRepository,
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current,
        distanceUnit: SparkDistanceUnit = .miles,
        costOf: @escaping (SparkShiftEntry) -> Double? = { _ in nil },
        pricePerKWhOf: @escaping (SparkShiftEntry) -> Double? = { _ in nil },
        tripKindOf: @escaping (SparkShiftEntry) -> SparkTripKind? = { $0.kind },
        milesOf: @escaping (SparkShiftEntry) -> Double? = { $0.miles },
        energyKWhOf: @escaping (SparkShiftEntry) -> Double? = { $0.energyKWh },
        gridKgCO2PerKWh: @escaping () -> Double? = { nil },
        trace: Bool = false
    ) {
        self.repo = repo
        self.now = now
        self.calendar = calendar
        self.locale = locale
        self.distanceUnit = distanceUnit
        self.costOf = costOf
        self.pricePerKWhOf = pricePerKWhOf
        self.tripKindOf = tripKindOf
        self.milesOf = milesOf
        self.energyKWhOf = energyKWhOf
        self.gridKgCO2PerKWh = gridKgCO2PerKWh
        self.trace = trace
    }

    // MARK: Windows

    public func summarize(windowDays: Int = 1) async -> SparkSummaryResult? {
        guard windowDays >= 1 else { return nil }
        guard let today = calendar.dateInterval(of: .day, for: now) else { return nil }
        let endOfWindow = today.end
        let startOfTarget = calendar.date(byAdding: .day, value: -(windowDays - 1), to: today.start) ?? today.start
        let entries = await repo.entries(from: startOfTarget, to: endOfWindow)
        return computeSummary(entries: entries, windowDays: windowDays)
    }

    public func summarize7And31() async -> (last7: SparkSummaryResult?, last31: SparkSummaryResult?) {
        guard let today = calendar.dateInterval(of: .day, for: now) else { return (nil, nil) }
        let endOfWindow = today.end
        let start31 = calendar.date(byAdding: .day, value: -30, to: today.start) ?? today.start
        let start7  = calendar.date(byAdding: .day, value:  -6, to: today.start) ?? today.start
        let all = await repo.entries(from: start31, to: endOfWindow)
        let last31 = computeSummary(entries: all, windowDays: 31)
        let last7  = computeSummary(entries: all.filter { $0.date >= start7 }, windowDays: 7)
        return (last7, last31)
    }

    public func summaries(for windows: [Int]) async -> [Int: SparkSummaryResult] {
        guard let today = calendar.dateInterval(of: .day, for: now), !windows.isEmpty else { return [:] }
        let endOfWindow = today.end
        let maxDays = max(windows.max() ?? 1, 1)
        let startMax = calendar.date(byAdding: .day, value: -(maxDays - 1), to: today.start) ?? today.start
        let base = await repo.entries(from: startMax, to: endOfWindow)

        var out: [Int: SparkSummaryResult] = [:]
        for days in Set(windows).sorted() where days >= 1 {
            if days == maxDays {
                if let r = computeSummary(entries: base, windowDays: days) { out[days] = r }
            } else {
                let start = calendar.date(byAdding: .day, value: -(days - 1), to: today.start) ?? today.start
                if let r = computeSummary(entries: base.filter { $0.date >= start }, windowDays: days) { out[days] = r }
            }
        }
        return out
    }

    // MARK: Compute

    public func computeSummary(entries: [SparkShiftEntry], windowDays: Int = 1) -> SparkSummaryResult? {
        guard !entries.isEmpty, windowDays >= 1 else { return nil }

        var milesTotal = 0.0
        var kWhTotal   = 0.0
        var costTotal  = 0.0
        var costHasAny = false

        var priceTimesEnergy = 0.0
        var energyWeight     = 0.0

        var whPerMi: [Double] = []
        var perKind: [String: [Double]] = [:]

        for e in entries {
            let miles = max(0, milesOf(e) ?? 0)
            let kWh   = max(0, energyKWhOf(e) ?? 0)

            milesTotal += miles
            kWhTotal   += kWh

            if let c = costOf(e) {
                costHasAny = true
                costTotal += max(0, c)
            }
            if let p = pricePerKWhOf(e), kWh > 0 {
                priceTimesEnergy += max(0, p) * kWh
                energyWeight     += kWh
            }

            if miles > 0, kWh > 0 {
                let whmi = (kWh * 1000.0) / miles
                whPerMi.append(whmi)
                if let k = tripKindOf(e) {
                    perKind[String(describing: k), default: []].append(whmi)
                }
            }
        }

        let (distanceValue, distanceSuffix): (Double, String) = {
            switch distanceUnit {
            case .miles: return (milesTotal, "mi")
            case .kilometers: return (milesTotal * 1.609344, "km")
            }
        }()

        let avgWhMi = milesTotal > 0 ? (kWhTotal * 1000.0) / milesTotal : 0
        let anomalies: Int? = Self.madOutlierCount(values: whPerMi)

        var bestKindName: String?
        var worstKindName: String?
        if !perKind.isEmpty {
            let medians: [(String, Double)] = perKind.compactMap { (name, arr) in
                guard let m = arr.median else { return nil }
                return (name, m)
            }
            if let best = medians.min(by: { $0.1 < $1.1 }) { bestKindName = best.0 }
            if let worst = medians.max(by: { $0.1 < $1.1 }) { worstKindName = worst.0 }
        }

        let avgPrice = energyWeight > 0 ? (priceTimesEnergy / energyWeight) : nil
        let avgCostPerMi = (costHasAny && milesTotal > 0) ? (costTotal / milesTotal) : nil
        let co2 = (gridKgCO2PerKWh() ?? 0) > 0 ? kWhTotal * (gridKgCO2PerKWh() ?? 0) : nil

        // Message
        let title = (windowDays == 1) ? "Today’s Driving" : "Last \(windowDays) Days"
        var lines: [String] = []
        lines.append("Distance \(fmt(distanceValue, 1)) \(distanceSuffix) • Energy \(fmt(kWhTotal, 2)) kWh • Avg \(fmt(avgWhMi, 0)) Wh/mi • \(entries.count) entr\(entries.count == 1 ? "y" : "ies")")

        if let total = (costHasAny ? costTotal : nil) {
            var costBits: [String] = ["Cost \(currency(total))"]
            if let ap = avgPrice { costBits.append("avg \(currency(ap))/kWh") }
            if let cpm = avgCostPerMi {
                let unit = (distanceUnit == .miles) ? "mi" : "km"
                costBits.append("\(currency(cpm))/\(unit)")
            }
            lines.append(costBits.joined(separator: " • "))
        }

        if let co2 = co2, co2 > 0 { lines.append("Estimated CO₂ \(fmt(co2, 1)) kg") }

        if avgWhMi > 0 {
            if avgWhMi > 320 {
                lines.append("Consumption ran high (\(fmt(avgWhMi, 0)) Wh/mi). Try gentler acceleration and lower cruising speeds.")
            } else if avgWhMi > 280 {
                lines.append("Efficiency was average at \(fmt(avgWhMi, 0)) Wh/mi. Tire pressure and climate control can shift this.")
            } else {
                lines.append("Great efficiency at \(fmt(avgWhMi, 0)) Wh/mi. Nice driving!")
            }
        }

        if let b = bestKindName, let w = worstKindName, b != w {
            lines.append("Best efficiency: \(b). Watch \(w) for improvements.")
        }

        if let n = anomalies, n > 0 {
            lines.append("\(n) session\(n == 1 ? "" : "s") looked unusual (outliers by efficiency).")
        }

        let message = lines.joined(separator: "\n")

        // Dialog
        let dialog = makeDialogLine(
            windowDays: windowDays,
            miles: distanceValue,
            kWh: kWhTotal,
            avgWhMi: avgWhMi,
            totalCost: costHasAny ? costTotal : nil,
            avgPricePerKWh: avgPrice
        )

        return SparkSummaryResult(
            title: title,
            message: message,
            totalDistance: distanceValue,
            totalEnergyKWh: kWhTotal,
            avgWhPerMile: avgWhMi,
            entryCount: entries.count,
            totalCost: costHasAny ? costTotal : nil,
            avgPricePerKWh: avgPrice,
            avgCostPerMile: avgCostPerMi,
            co2Kg: co2,
            bestKind: bestKindName,
            worstKind: worstKindName,
            anomalyCount: anomalies,
            dialogLine: dialog
        )
    }

    // MARK: Helpers

    private func makeDialogLine(windowDays: Int,
                                miles: Double,
                                kWh: Double,
                                avgWhMi: Double,
                                totalCost: Double?,
                                avgPricePerKWh: Double?) -> String {
        let span = (windowDays == 1) ? "today" : "in the last \(windowDays) days"
        var bits: [String] = []
        bits.append("\(fmt(miles, 1)) \(distanceUnit == .miles ? "miles" : "kilometers")")
        bits.append("\(fmt(kWh, 2)) kWh")
        bits.append("\(fmt(avgWhMi, 0)) Wh/mi")
        if let c = totalCost { bits.append(currency(c)) }
        if let p = avgPricePerKWh { bits.append("\(currency(p))/kWh") }
        return "You drove \(span): " + bits.joined(separator: " • ") + "."
    }

    private func fmt(_ value: Double, _ fractionDigits: Int) -> String {
        if #available(iOS 15.0, macOS 12.0, *) {
            return value.formatted(
                .number
                .precision(.fractionLength(fractionDigits))
                .locale(locale)
            )
        } else {
            let nf = NumberFormatter()
            nf.locale = locale
            nf.minimumFractionDigits = fractionDigits
            nf.maximumFractionDigits = fractionDigits
            return nf.string(from: value as NSNumber) ?? String(format: "%.\(fractionDigits)f", value)
        }
    }

    private func currency(_ value: Double) -> String {
        if #available(iOS 15.0, macOS 12.0, *),
           let code = locale.currency?.identifier {
            return value.formatted(.currency(code: code).locale(locale))
        } else {
            let nf = NumberFormatter()
            nf.locale = locale
            nf.numberStyle = .currency
            return nf.string(from: value as NSNumber) ?? String(format: "$%.2f", value)
        }
    }

    /// Robust outlier count via MAD.
    private static func madOutlierCount(values: [Double]) -> Int? {
        guard values.count >= 5 else { return nil }
        guard let med = values.median else { return nil }
        let absDevs = values.map { abs($0 - med) }
        guard let mad = absDevs.median, mad > 0 else { return nil }
        let k = 1.4826 * mad
        return values.filter { abs($0 - med) / k > 3.5 }.count
    }
}

// MARK: - Numeric helpers

fileprivate extension Array where Element == Double {
    var median: Double? {
        guard !isEmpty else { return nil }
        let s = self.sorted()
        let mid = s.count / 2
        return s.count % 2 == 0 ? (s[mid - 1] + s[mid]) / 2 : s[mid]
    }
}
