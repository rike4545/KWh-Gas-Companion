//  ChargingReconciliationEngine.swift
//  KWh Gas Companion
//
//  Compare TeslaFi (canonical) vs Ledger (ExpenseEntries mapped to ChargingLedgerItem)
//  Swift 6 • iOS 17+
//

import Foundation

public struct ChargingLedgerItem: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var date: Date
    public var amount: Double
    public var locationHint: String?

    public init(id: UUID = UUID(), date: Date, amount: Double, locationHint: String? = nil) {
        self.id = id
        self.date = date
        self.amount = amount
        self.locationHint = locationHint
    }
}

public struct MonthlyChargingReconciliationRow: Identifiable, Codable, Hashable {
    public var id: String { monthKey }

    public var monthKey: String
    public var monthStart: Date

    public var teslaFiSessions: Int
    public var teslaFiKWh: Double
    public var teslaFiCost: Double
    public var teslaFiMissingCostSessions: Int

    public var ledgerItems: Int
    public var ledgerCost: Double

    public var delta: Double { ledgerCost - teslaFiCost }
}

public enum ChargingReconciliationEngine {

    public static func reconcileMonthly(
        canonicalSessions: [TeslaFiSession],
        ledgerCharging: [ChargingLedgerItem],
        calendar: Calendar = .current
    ) -> [MonthlyChargingReconciliationRow] {

        func monthStart(_ d: Date) -> Date {
            let comps = calendar.dateComponents([.year, .month], from: d)
            return calendar.date(from: comps) ?? d
        }

        func monthKey(_ d: Date) -> String {
            let comps = calendar.dateComponents([.year, .month], from: d)
            let y = comps.year ?? 0
            let m = comps.month ?? 0
            return String(format: "%04d-%02d", y, m)
        }

        var months = Set<Date>()
        for s in canonicalSessions { months.insert(monthStart(s.startDate)) }
        for l in ledgerCharging { months.insert(monthStart(l.date)) }

        let sortedMonths = months.sorted(by: >)

        return sortedMonths.map { ms in
            let key = monthKey(ms)

            let sessions = canonicalSessions.filter { monthStart($0.startDate) == ms }
            let ledger = ledgerCharging.filter { monthStart($0.date) == ms }

            let kwh = sessions.reduce(0) { $0 + $1.energyAddedKWh }
            let cost = sessions.reduce(0) { $0 + ($1.cost ?? 0) }
            let missingCost = sessions.filter { $0.cost == nil }.count

            let ledgerCost = ledger.reduce(0) { $0 + abs($1.amount) }

            return MonthlyChargingReconciliationRow(
                monthKey: key,
                monthStart: ms,
                teslaFiSessions: sessions.count,
                teslaFiKWh: kwh,
                teslaFiCost: cost,
                teslaFiMissingCostSessions: missingCost,
                ledgerItems: ledger.count,
                ledgerCost: ledgerCost
            )
        }
    }
}
