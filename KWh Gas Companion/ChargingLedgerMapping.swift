//
//  EVChargingLedgerMapping.swift
//  My KWh Companion
//
//  Canonical mapping model for charging ledger reconciliation.
//  IMPORTANT: Ensure this struct exists in exactly ONE file in the project.
//
//  Swift 6 • iOS 17+
//

import Foundation

struct EVChargingLedgerMapping: Sendable, Hashable {

    var ledgerCharging: [EVChargingLedgerItem]
    var fromTeslaFi: [EVChargingLedgerItem]
    var fromEntries: [EVChargingLedgerItem]

    init(teslaFiSessions: [TeslaFiSession], entries: [ExpenseEntry]) {
        self.fromTeslaFi = teslaFiSessions.map { EVChargingLedgerItem.fromTeslaFi($0) }
        self.fromEntries = entries
            .filter { $0.isEnergyEffective }
            .map { EVChargingLedgerItem.fromEntry($0) }

        self.ledgerCharging = (fromTeslaFi + fromEntries)
            .sorted(by: { $0.startDate > $1.startDate })
    }
}

@MainActor
extension TeslaFiSessionStore {

    /// Build mapping from TeslaFi + entries.
    func evChargingLedgerMapping(entries: [ExpenseEntry], preferCanonical: Bool = true) -> EVChargingLedgerMapping {
        let sessionsToUse: [TeslaFiSession] =
            (preferCanonical && !canonicalSessions.isEmpty) ? canonicalSessions : sessions
        return EVChargingLedgerMapping(teslaFiSessions: sessionsToUse, entries: entries)
    }

    /// Convenience: mapping with EntriesStore.
    func evChargingLedgerMapping(entriesStore: EntriesStore, preferCanonical: Bool = true) -> EVChargingLedgerMapping {
        evChargingLedgerMapping(entries: entriesStore.entries, preferCanonical: preferCanonical)
    }
}
