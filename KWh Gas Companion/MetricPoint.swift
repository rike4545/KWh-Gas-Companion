//
//  MetricPoint.swift
//  KWh Gas Companion
//
//  Lightweight time-series primitive + helpers for monthly bucketing/aggregation.
//  Regenerated 2025-08-30 (UTC-safe IDs, seeded months, trailing/centered MAs).
//

import Foundation

// MARK: - Model

/// One measurement in a (series, date) time series.
struct MetricPoint: Identifiable, Hashable, Codable {
    var series: String          // logical series name, e.g. "CostPerMile"
    var date: Date              // timestamp of the measurement (any granularity)
    var value: Double           // primary numeric value
    var count: Int = 1          // optional weight / samples contributing to value
    var note: String? = nil     // optional label/annotation

    /// Stable ID that does **not** depend on user locale/timezone.
    /// Uses whole-second UNIX time + series + a compact value signature.
    var id: String {
        let t = Int(date.timeIntervalSince1970) // UTC seconds
        let sig = String(value.bitPattern, radix: 36)
        return "\(series)|\(t)|\(sig)"
    }
}

// MARK: - Monthly key (no tuples -> Hashable, safe for Dictionary)

/// Key for (series, year, month).
private struct MonthlyKey: Hashable {
    let series: String
    let year: Int
    let month: Int
}

// MARK: - Public helpers

extension MetricPoint {
    /// Return points sorted by (series, date).
    static func sort(_ points: [MetricPoint]) -> [MetricPoint] {
        points.sorted { lhs, rhs in
            if lhs.series != rhs.series { return lhs.series < rhs.series }
            return lhs.date < rhs.date
        }
    }

    /// Group into monthly buckets (start-of-month) and **SUM** values per (series, month).
    /// Pass `.utc` calendar for timezone-stable bucketing in charts.
    static func monthlySum(_ points: [MetricPoint], calendar: Calendar = .current) -> [MetricPoint] {
        aggregateMonthly(points, calendar: calendar) { acc, p in
            acc.value += p.value
            acc.count &+= p.count
        }
    }

    /// Group into monthly buckets and compute **AVERAGE** of values per (series, month).
    /// When `count` > 1 on inputs, this yields a **count-weighted mean**.
    static func monthlyAverage(_ points: [MetricPoint], calendar: Calendar = .current) -> [MetricPoint] {
        aggregateMonthly(points, calendar: calendar) { acc, p in
            acc.value += p.value
            acc.count &+= p.count
        }
        .map { pt in
            var m = pt
            if m.count > 0 { m.value /= Double(m.count) }
            return m
        }
    }

    /// Centered moving average within each series using a window of `window` samples.
    /// For odd windows it is centered; for even windows it’s slightly forward-biased.
    static func movingAverage(_ points: [MetricPoint], window: Int) -> [MetricPoint] {
        guard window > 1 else { return points }
        let groups = Dictionary(grouping: sort(points), by: \.series)
        var out: [MetricPoint] = []
        out.reserveCapacity(points.count)

        for (series, arr) in groups {
            let vals = arr.map(\.value)
            let ma = slidingAverage(vals, window: window)
            for (i, base) in arr.enumerated() {
                var m = base
                m.series = series + ".ma\(window)"
                m.value = ma[i]
                out.append(m)
            }
        }
        return out
    }

    /// **Trailing** simple moving average using the previous `window` samples (incl. current).
    static func trailingMovingAverage(_ points: [MetricPoint], window: Int) -> [MetricPoint] {
        guard window > 1 else { return points }
        let groups = Dictionary(grouping: sort(points), by: \.series)
        var out: [MetricPoint] = []
        out.reserveCapacity(points.count)

        for (series, arr) in groups {
            let vals = arr.map(\.value)
            let sma = trailingSMA(vals, window: window)
            for (i, base) in arr.enumerated() {
                var m = base
                m.series = series + ".tma\(window)"
                m.value = sma[i]
                out.append(m)
            }
        }
        return out
    }

    /// **Trailing weighted** moving average using each point’s `count` as weight.
    static func trailingWeightedMovingAverage(_ points: [MetricPoint], window: Int) -> [MetricPoint] {
        guard window > 1 else { return points }
        let groups = Dictionary(grouping: sort(points), by: \.series)
        var out: [MetricPoint] = []
        out.reserveCapacity(points.count)

        for (series, arr) in groups {
            let vals = arr.map(\.value)
            let wts  = arr.map { max(0, $0.count) }
            let wma = trailingWMA(vals, weights: wts, window: window)
            for (i, base) in arr.enumerated() {
                var m = base
                m.series = series + ".twma\(window)"
                m.value = wma[i]
                out.append(m)
            }
        }
        return out
    }

    /// Cumulative sum by series ordered by date.
    static func cumulative(_ points: [MetricPoint]) -> [MetricPoint] {
        let groups = Dictionary(grouping: sort(points), by: \.series)
        var out: [MetricPoint] = []
        out.reserveCapacity(points.count)

        for (series, arr) in groups {
            var running = 0.0
            for var p in arr {
                running += p.value
                p.series = series + ".cum"
                p.value = running
                out.append(p)
            }
        }
        return out
    }

    /// Split array by series name.
    static func bySeries(_ points: [MetricPoint]) -> [String: [MetricPoint]] {
        Dictionary(grouping: points, by: \.series)
    }

    /// Min/Max across values; returns nil for empty input. Ignores NaN/±Inf.
    static func range(_ points: [MetricPoint]) -> (min: Double, max: Double)? {
        var lo = Double.greatestFiniteMagnitude
        var hi = -Double.greatestFiniteMagnitude
        var saw = false
        for p in points where p.value.isFinite {
            lo = min(lo, p.value)
            hi = max(hi, p.value)
            saw = true
        }
        return saw ? (lo, hi) : nil
    }

    // MARK: Seeding / Filling

    /// Return a month-seeded series from `startMonth` (inclusive) to `endMonth` (inclusive),
    /// ensuring each month exists. Missing months are filled with value=0, count=0.
    /// - Note: Uses the provided calendar (default `.current`). Consider `.utc` for charts.
    static func seedMissingMonths(
        _ points: [MetricPoint],
        series: String,
        startMonth: Date,
        endMonth: Date,
        calendar: Calendar = .current
    ) -> [MetricPoint] {
        guard startMonth <= endMonth else { return [] }

        // Normalize existing points by month and sum duplicates
        let normed = points
            .filter { $0.series == series }
            .map { p -> MetricPoint in
                var copy = p
                copy.date = p.date.startOfMonth(calendar)
                return copy
            }

        var byMonth: [Date: MetricPoint] = [:]
        for p in normed {
            if var acc = byMonth[p.date] {
                acc.value += p.value
                acc.count &+= p.count
                byMonth[p.date] = acc
            } else {
                byMonth[p.date] = p
            }
        }

        var out: [MetricPoint] = []
        var m = startMonth.startOfMonth(calendar)
        let end = endMonth.startOfMonth(calendar)
        while m <= end {
            if let existing = byMonth[m] {
                out.append(existing)
            } else {
                out.append(MetricPoint(series: series, date: m, value: 0, count: 0, note: nil))
            }
            m = calendar.date(byAdding: .month, value: 1, to: m) ?? m.addingTimeInterval(30 * 24 * 3600)
        }
        return out
    }
}

// MARK: - Internal aggregation utilities

private extension MetricPoint {
    static func aggregateMonthly(
        _ points: [MetricPoint],
        calendar: Calendar = .current,
        combine: (_ acc: inout MetricPoint, _ p: MetricPoint) -> Void
    ) -> [MetricPoint] {
        var dict: [MonthlyKey: MetricPoint] = [:]
        dict.reserveCapacity(points.count)

        for p in points {
            // Normalize to calendar month (caller can pass `Calendar.utc` to avoid DST concerns)
            let comps = calendar.dateComponents([.year, .month], from: p.date)
            guard let y = comps.year, let m = comps.month else { continue }
            let key = MonthlyKey(series: p.series, year: y, month: m)

            if var acc = dict[key] {
                combine(&acc, p)
                dict[key] = acc
            } else {
                let monthStart = calendar.date(from: DateComponents(year: y, month: m, day: 1)) ?? p.date
                var seed = MetricPoint(series: p.series, date: monthStart, value: 0, count: 0, note: nil)
                combine(&seed, p)
                dict[key] = seed
            }
        }

        // Return in (series, y, m) order
        return dict
            .sorted { (lhs, rhs) in
                if lhs.key.series != rhs.key.series { return lhs.key.series < rhs.key.series }
                if lhs.key.year   != rhs.key.year   { return lhs.key.year   < rhs.key.year }
                return lhs.key.month < rhs.key.month
            }
            .map { $0.value }
    }

    /// Centered window average; uses smaller windows near edges.
    static func slidingAverage(_ values: [Double], window: Int) -> [Double] {
        guard !values.isEmpty, window > 1 else { return values }
        let w = max(2, window)
        var out = Array(repeating: 0.0, count: values.count)

        // Prefix sums for O(n)
        var prefix = Array(repeating: 0.0, count: values.count + 1)
        for i in 0..<values.count { prefix[i + 1] = prefix[i] + values[i] }

        let half = w / 2
        for i in values.indices {
            let start = max(0, i - half)
            let end = min(values.count - 1, i + (w - 1 - half))
            let count = (end - start + 1)
            let sum = prefix[end + 1] - prefix[start]
            out[i] = count > 0 ? (sum / Double(count)) : values[i]
        }
        return out
    }

    /// Trailing simple moving average: average of the last `window` samples including i.
    static func trailingSMA(_ values: [Double], window: Int) -> [Double] {
        guard !values.isEmpty, window > 1 else { return values }
        let w = max(2, window)
        var out = Array(repeating: 0.0, count: values.count)

        var queue: [Double] = []
        queue.reserveCapacity(w)
        var running = 0.0

        for i in values.indices {
            let v = values[i]
            queue.append(v)
            running += v
            if queue.count > w {
                running -= queue.removeFirst()
            }
            out[i] = running / Double(queue.count)
        }
        return out
    }

    /// Trailing weighted moving average with integer weights (`count`).
    static func trailingWMA(_ values: [Double], weights: [Int], window: Int) -> [Double] {
        guard !values.isEmpty, values.count == weights.count, window > 1 else { return values }
        let w = max(2, window)
        var out = Array(repeating: 0.0, count: values.count)

        var vq: [Double] = []
        var wq: [Double] = []
        vq.reserveCapacity(w); wq.reserveCapacity(w)

        var sumVW = 0.0
        var sumW  = 0.0

        for i in values.indices {
            let v = values[i]
            let ww = max(0, weights[i])

            vq.append(v)
            wq.append(Double(ww))
            sumVW += v * Double(ww)
            sumW  += Double(ww)

            if vq.count > w {
                let removedV = vq.removeFirst()
                let removedW = wq.removeFirst()
                sumVW -= removedV * removedW
                sumW  -= removedW
            }

            out[i] = sumW > 0 ? (sumVW / sumW) : (vq.last ?? 0.0)
        }
        return out
    }
}

// MARK: - Date conveniences

extension Date {
    /// Start of month at 00:00 in the provided calendar.
    func startOfMonth(_ calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)) ?? self
    }
}

extension Calendar {
    /// Gregorian UTC calendar (stable across locales/timezones).
    static var utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()
}
