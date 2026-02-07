//  AnalyticsEngine.swift
//  Standalone, framework-free analytics utilities that do not depend on
//  ExpenseEntry / EntriesStore OR your BudgetStore. Safe to drop into any target.

import Foundation

public struct AEEntry: Hashable, Codable, Identifiable {
    public let id: UUID
    public var date: Date
    /// Energy consumed or delivered, in kWh
    public var energyKWh: Double
    /// Cost associated with the entry, in the app's currency (e.g., USD)
    public var cost: Double
    /// Vehicle odometer, in miles (optional). Used for cost-per-mile.
    public var odometerMiles: Double?
    /// Optional category label (e.g., "Home", "Fast", "Work").
    public var category: String?
    /// Optional extra metadata for future use.
    public var metadata: [String: String]

    public init(id: UUID = UUID(),
                date: Date,
                energyKWh: Double,
                cost: Double,
                odometerMiles: Double? = nil,
                category: String? = nil,
                metadata: [String: String] = [:]) {
        self.id = id
        self.date = date
        self.energyKWh = energyKWh
        self.cost = cost
        self.odometerMiles = odometerMiles
        self.category = category
        self.metadata = metadata
    }
}

/// Month identifier used by AnalyticsEngine only (avoids collisions with app's YearMonth).
public struct AEYearMonth: Hashable, Comparable, Codable {
    public let year: Int
    public let month: Int // 1...12

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public init(date: Date, calendar: Calendar = .current) {
        let comps = calendar.dateComponents([.year, .month], from: date)
        self.year = comps.year ?? 0
        self.month = comps.month ?? 1
    }

    public static func < (lhs: AEYearMonth, rhs: AEYearMonth) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        return lhs.month < rhs.month
    }

    public func startDate(calendar: Calendar = .current) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }

    public func description() -> String { String(format: "%04d-%02d", year, month) }
}

public enum AnalyticsEngine {

    // MARK: - Basic totals

    public static func totalCost(_ entries: [AEEntry]) -> Double {
        entries.reduce(0) { $0 + $1.cost }
    }

    public static func totalEnergy(_ entries: [AEEntry]) -> Double {
        entries.reduce(0) { $0 + $1.energyKWh }
    }

    public static func costPerKWh(_ entries: [AEEntry]) -> Double? {
        let e = totalEnergy(entries)
        guard e > 0 else { return nil }
        return totalCost(entries) / e
    }

    // MARK: - Cost per mile

    public static func costPerMile(_ entries: [AEEntry], calendar: Calendar = .current) -> Double? {
        let sorted = entries.sorted { $0.date < $1.date }
        let odometers: [Double] = sorted.compactMap { $0.odometerMiles }
        guard let first = odometers.first, let last = odometers.last, last > first else { return nil }
        let miles = last - first
        let cost = totalCost(sorted)
        guard miles > 0 else { return nil }
        return cost / miles
    }

    // MARK: - Grouping / Aggregates

    /// Aggregates entries by (year, month).
    /// - Returns: A dictionary keyed by AEYearMonth with (cost, energy, sessions) totals.
    public static func monthlyTotals(_ entries: [AEEntry], calendar: Calendar = .current) -> [AEYearMonth: (cost: Double, energy: Double, sessions: Int)] {
        var bucket: [AEYearMonth: (cost: Double, energy: Double, sessions: Int)] = [:]
        for e in entries {
            let key = AEYearMonth(date: e.date, calendar: calendar)
            var agg = bucket[key] ?? (0, 0, 0)
            agg.cost += e.cost
            agg.energy += e.energyKWh
            agg.sessions += 1
            bucket[key] = agg
        }
        return bucket
    }

    /// Groups totals by category.
    public static func categoryBreakdown(_ entries: [AEEntry]) -> [(category: String, cost: Double, energy: Double, sessions: Int)] {
        var map: [String: (Double, Double, Int)] = [:]
        for e in entries {
            let key = (e.category?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? e.category! : "Uncategorized"
            var agg = map[key] ?? (0, 0, 0)
            agg.0 += e.cost
            agg.1 += e.energyKWh
            agg.2 += 1
            map[key] = agg
        }
        return map.map { (k, v) in (category: k, cost: v.0, energy: v.1, sessions: v.2) }
            .sorted { $0.cost > $1.cost }
    }

    // MARK: - Time-series helpers

    public static func movingAverage(values: [Double], window: Int) -> [Double?] {
        guard window > 0 else { return values.map { Optional($0) } }
        var result: [Double?] = Array(repeating: nil, count: values.count)
        var sum: Double = 0
        var q: [Double] = []
        for (i, v) in values.enumerated() {
            sum += v
            q.append(v)
            if q.count > window { sum -= q.removeFirst() }
            if q.count == window { result[i] = sum / Double(window) }
        }
        return result
    }

    public static func linearTrend(x: [Double], y: [Double]) -> (slope: Double, intercept: Double)? {
        guard x.count == y.count, x.count >= 2 else { return nil }
        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXX = zip(x, x).reduce(0) { $0 + $1.0 * $1.1 }
        let sumXY = zip(x, y).reduce(0) { $0 + $1.0 * $1.1 }
        let denom = (n * sumXX - sumX * sumX)
        guard denom != 0 else { return nil }
        let slope = (n * sumXY - sumX * sumY) / denom
        let intercept = (sumY - slope * sumX) / n
        return (slope, intercept)
    }

    public static func linearTrend(values: [Double]) -> (slope: Double, intercept: Double)? {
        let x = (0..<values.count).map { Double($0) }
        return linearTrend(x: x, y: values)
    }

    // MARK: - Outlier detection

    public static func zScoreOutliers(values: [Double], threshold: Double = 3.0) -> [Int] {
        guard values.count >= 2 else { return [] }
        let mean = values.reduce(0, +) / Double(values.count)
        let varSum = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        let std = (varSum / Double(values.count - 1)).squareRoot()
        guard std > 0 else { return [] }
        return values.enumerated().compactMap { idx, v in
            abs((v - mean) / std) > threshold ? idx : nil
        }
    }

    public static func iqrOutliers(values: [Double], multiplier k: Double = 1.5) -> [Int] {
        guard values.count >= 4 else { return [] }
        let sorted = values.sorted()
        let q1 = percentile(sorted, 25)
        let q3 = percentile(sorted, 75)
        let iqr = q3 - q1
        let low = q1 - k * iqr
        let high = q3 + k * iqr
        return values.enumerated().compactMap { (i, v) in (v < low || v > high) ? i : nil }
    }

    // MARK: - Distributions

    public static func percentile(_ sortedValues: [Double], _ p: Double) -> Double {
        let n = sortedValues.count
        guard n > 0 else { return .nan }
        let clampedP = max(0, min(100, p))
        let rank = (clampedP / 100.0) * Double(n - 1)
        let i = Int(floor(rank))
        let frac = rank - Double(i)
        if i >= n - 1 { return sortedValues[n - 1] }
        return sortedValues[i] * (1 - frac) + sortedValues[i + 1] * frac
    }

    public static func histogram(values: [Double], binCount: Int) -> (edges: [Double], counts: [Int]) {
        guard !values.isEmpty, binCount > 0 else { return ([], []) }
        guard let minV = values.min(), let maxV = values.max() else { return ([], []) }
        if minV == maxV { return ([minV, maxV], [values.count]) }
        let width = (maxV - minV) / Double(binCount)
        var edges: [Double] = (0...binCount).map { minV + Double($0) * width }
        var counts = Array(repeating: 0, count: binCount)
        for v in values {
            var idx = Int((v - minV) / width)
            if idx == binCount { idx = binCount - 1 }
            counts[idx] += 1
        }
        edges[edges.count - 1] = maxV
        return (edges, counts)
    }

    public static func normalize(values: [Double]) -> [Double] {
        guard let minV = values.min(), let maxV = values.max(), maxV > minV else {
            return Array(repeating: 0, count: values.count)
        }
        return values.map { ($0 - minV) / (maxV - minV) }
    }

    public static func rollingMetric(entries: [AEEntry], window: Int, value: (AEEntry) -> Double) -> [Double?] {
        let values = entries.map(value)
        return movingAverage(values: values, window: window)
    }
}
