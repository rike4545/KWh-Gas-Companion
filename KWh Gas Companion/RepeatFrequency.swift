//  ExpenseRepeatRule.swift
//  My KWh Companion
//
//  Repeat scheduling model for ExpenseEntry.
//  - Codable + Equatable + Hashable
//  - Next/expand helpers
//  - Weekdays use 0=Sun...6=Sat
//
//  iOS 17+ / Swift 6

import Foundation

public enum RepeatFrequency: String, Codable, CaseIterable, Identifiable, Hashable {
    case daily, weekly, monthly, yearly
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .daily:   return "Daily"
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        case .yearly:  return "Yearly"
        }
    }
}

public struct ExpenseRepeatRule: Codable, Equatable, Identifiable, Hashable {
    public var id: UUID = UUID()

    public var startDate: Date
    public var frequency: RepeatFrequency
    public var interval: Int
    /// Weekly: 0=Sun ... 6=Sat (nil/empty -> startDate’s weekday)
    public var weekdays: Set<Int>?
    /// Monthly: 1...31 (nil -> startDate’s DOM; capped per month)
    public var dayOfMonth: Int?
    /// Inclusive end date (optional)
    public var endsOn: Date?

    public init(startDate: Date,
                frequency: RepeatFrequency,
                interval: Int = 1,
                weekdays: Set<Int>? = nil,
                dayOfMonth: Int? = nil,
                endsOn: Date? = nil) {
        self.startDate = startDate
        self.frequency = frequency
        self.interval = max(1, interval)
        self.weekdays = weekdays
        self.dayOfMonth = dayOfMonth
        self.endsOn = endsOn
    }
}

// MARK: - Engine
public enum RepeatEngine {
    /// Next occurrence strictly after `date` (or equal if `allowSame`)
    public static func nextOccurrence(after date: Date,
                                      rule: ExpenseRepeatRule,
                                      allowSame: Bool = false,
                                      calendar: Calendar = .current) -> Date? {
        let start = rule.startDate
        if let end = rule.endsOn, date > end { return nil }

        if allowSame {
            if date <= start { return start }
        } else if date < start {
            return start
        }

        switch rule.frequency {
        case .daily:
            let days = calendar.dateComponents([.day], from: start, to: date).day ?? 0
            let steps = Int(ceil(Double(days + 1) / Double(rule.interval)))
            // Use flatMap to avoid Date?? (this fixes your compile error)
            return calendar.date(byAdding: .day, value: steps * rule.interval, to: start)
                .flatMap { capToEnd($0, end: rule.endsOn) }

        case .weekly:
            return nextWeekly(after: date, rule: rule, calendar: calendar)

        case .monthly:
            return nextMonthly(after: date, rule: rule, calendar: calendar)

        case .yearly:
            var guess = start
            while guess <= date {
                guard let next = calendar.date(byAdding: .year, value: rule.interval, to: guess) else { break }
                guess = next
            }
            return capToEnd(guess, end: rule.endsOn)
        }
    }

    /// Expand all occurrences within [start, end]
    public static func expand(from start: Date,
                              to end: Date,
                              rule: ExpenseRepeatRule,
                              calendar: Calendar = .current) -> [Date] {
        var out: [Date] = []
        var current = nextOccurrence(after: start, rule: rule, allowSame: true, calendar: calendar)
        while let c = current, c <= end {
            out.append(c)
            current = nextOccurrence(after: c, rule: rule, allowSame: false, calendar: calendar)
        }
        return out
    }

    // MARK: Weekly
    private static func nextWeekly(after date: Date,
                                   rule: ExpenseRepeatRule,
                                   calendar: Calendar) -> Date? {
        let start = rule.startDate
        // Default weekday0 from Calendar’s 1...7
        let defaultWD0 = (calendar.component(.weekday, from: start) + 6) % 7
        let days = (rule.weekdays?.sorted()) ?? [defaultWD0]

        var anchor = start
        while true {
            for wd0 in days {
                if let d = nextWeekday0(wd0, inSameWeekAs: anchor, after: date, calendar: calendar) {
                    if let end = rule.endsOn, d > end { return nil }
                    if d > date { return d }
                }
            }
            guard let nextAnchor = calendar.date(byAdding: .weekOfYear, value: rule.interval, to: anchor) else { return nil }
            anchor = nextAnchor
            if let end = rule.endsOn, anchor > end { return nil }
        }
    }

    /// First given weekday0 in same week as `anchor`, after `date`.
    private static func nextWeekday0(_ weekday0: Int,
                                     inSameWeekAs anchor: Date,
                                     after date: Date,
                                     calendar: Calendar) -> Date? {
        // 0..6 -> Calendar weekday 1..7
        let calWD = ((weekday0 % 7) + 7) % 7 + 1
        guard let week = calendar.dateInterval(of: .weekOfYear, for: anchor) else { return nil }
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: week.start)
        comps.weekday = calWD
        guard var candidate = calendar.date(from: comps) else { return nil }
        // Preserve time from anchor
        let t = calendar.dateComponents([.hour, .minute, .second], from: anchor)
        candidate = calendar.date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: t.second ?? 0, of: candidate) ?? candidate
        return candidate > date ? candidate : nil
    }

    // MARK: Monthly
    private static func nextMonthly(after date: Date,
                                    rule: ExpenseRepeatRule,
                                    calendar: Calendar) -> Date? {
        let start = rule.startDate
        let dom = rule.dayOfMonth ?? calendar.component(.day, from: start)
        var guess = setDayOfMonth(start, day: dom, calendar: calendar) ?? start
        while guess <= date {
            guard let next = calendar.date(byAdding: .month, value: rule.interval, to: guess) else { break }
            guess = setDayOfMonth(next, day: dom, calendar: calendar) ?? next
        }
        return capToEnd(guess, end: rule.endsOn)
    }

    private static func setDayOfMonth(_ date: Date, day: Int, calendar: Calendar) -> Date? {
        var comps = calendar.dateComponents([.year, .month, .hour, .minute, .second], from: date)
        comps.day = min(max(1, day), daysInMonth(for: date, calendar: calendar))
        return calendar.date(from: comps)
    }

    private static func daysInMonth(for date: Date, calendar: Calendar) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 28
    }

    private static func capToEnd(_ date: Date, end: Date?) -> Date? {
        guard let e = end else { return date }
        return date <= e ? date : nil
    }
}
