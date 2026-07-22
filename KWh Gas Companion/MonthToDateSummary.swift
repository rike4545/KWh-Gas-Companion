//  MonthToDateSummary.swift
//  My KWh Companion
//
//  Lightweight summary of current calendar month usage/spend.

import Foundation

public struct MonthToDateSummary: Hashable, Codable, CustomStringConvertible {
    public let periodStart: Date
    public let periodEnd: Date
    public let kWh: Double
    public let sessions: Int
    public let actualSpend: Double

    public init(periodStart: Date, periodEnd: Date, kWh: Double, sessions: Int, actualSpend: Double) {
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.kWh = kWh
        self.sessions = sessions
        self.actualSpend = actualSpend
    }

    public var description: String {
        let df = DateFormatter(); df.dateFormat = "MMM d"
        return "MTD \(df.string(from: periodStart))–\(df.string(from: periodEnd)) • kWh: \(kWh) • sessions: \(sessions) • actual: $\(String(format: "%.2f", actualSpend))"
    }
}
