//
//  EVChargingLedgerItem.swift
//  My KWh Companion
//
//  Canonical ledger row model ONLY.
//  IMPORTANT: This file intentionally does NOT define EVChargingLedgerMapping
//  because your project already defines it elsewhere (causing redeclaration).
//
//  Swift 6 • iOS 17+
//

import Foundation

struct EVChargingLedgerItem: Identifiable, Codable, Hashable, Sendable {

    // Stable identity across refreshes
    var id: String

    var source: EVChargingLedgerSource

    // Timing
    var startDate: Date
    var endDate: Date?

    // Energy + money
    var energyKWh: Double?
    var cost: Double?
    var currencyCode: String?

    // Context
    var location: String
    var isFastCharge: Bool

    // Back-references (optional)
    var teslaFiSessionID: UUID?
    var expenseEntryID: UUID?

    var durationSeconds: TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(startDate))
    }

    // MARK: - Inference

    static func inferFastCharge(location: String, category: String? = nil, chargeType: String? = nil) -> Bool {
        let l = location.lowercased()
        let c = (category ?? "").lowercased()
        let t = (chargeType ?? "").lowercased()

        if l.contains("supercharg") { return true }
        if l.contains("dcfc") { return true }
        if l.contains("electrify america") { return true }
        if l.contains("evgo") { return true }
        if l.contains("chargepoint") { return true }
        if l.contains("fast") { return true }

        if c.contains("dcfc") || c.contains("supercharg") { return true }
        if t.contains("dcfc") || t.contains("supercharg") { return true }

        return false
    }

    // MARK: - Builders (avoid init(from:) label confusion)

    static func fromTeslaFi(_ s: TeslaFiSession) -> EVChargingLedgerItem {
        let loc = s.displayLocation
        let fast = inferFastCharge(location: loc)

        return EVChargingLedgerItem(
            id: "teslafi|\(s.sessionHash)",
            source: .teslaFi,
            startDate: s.startDate,
            endDate: s.endDate,
            energyKWh: max(0, s.energyAddedKWh),
            cost: s.cost,
            currencyCode: nil,
            location: loc,
            isFastCharge: fast,
            teslaFiSessionID: s.id,
            expenseEntryID: nil
        )
    }

    static func fromEntry(_ e: ExpenseEntry) -> EVChargingLedgerItem {
        let start = e.charging?.startDate ?? e.date
        let end = e.charging?.endDate

        let rawLoc = (e.charging?.siteName ?? e.location ?? "Unknown")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let loc = rawLoc.isEmpty ? "Unknown" : rawLoc

        let energy = e.energyAddedKWh ?? e.energyKWh

        let fast =
            (e.charging?.isSupercharger == true)
            || inferFastCharge(location: loc, category: e.category, chargeType: e.chargeType)

        return EVChargingLedgerItem(
            id: "entry|\(e.id.uuidString)",
            source: .entry,
            startDate: start,
            endDate: end,
            energyKWh: energy,
            cost: e.amount,
            currencyCode: e.currencyCode,
            location: loc,
            isFastCharge: fast,
            teslaFiSessionID: nil,
            expenseEntryID: e.id
        )
    }
}

// MARK: - Store helpers (items only)

@MainActor
extension TeslaFiSessionStore {
    func evChargingLedgerItems(preferCanonical: Bool = true) -> [EVChargingLedgerItem] {
        let src: [TeslaFiSession] =
            (preferCanonical && !canonicalSessions.isEmpty) ? canonicalSessions : sessions

        return src.map { EVChargingLedgerItem.fromTeslaFi($0) }
            .sorted(by: { $0.startDate > $1.startDate })
    }
}

@MainActor
extension EntriesStore {
    func evChargingLedgerItems() -> [EVChargingLedgerItem] {
        entries
            .filter { $0.isEnergyEffective }
            .map { EVChargingLedgerItem.fromEntry($0) }
            .sorted(by: { $0.startDate > $1.startDate })
    }
}
