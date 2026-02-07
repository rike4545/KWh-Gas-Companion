//
//  EVChargingLedgerSource.swift
//  My KWh Companion
//
//  Canonical source enum for EV charging ledger rows.
//  Keep INTERNAL (no `public`) to avoid access-level conflicts.
//
//  Swift 6 • iOS 17+
//

import Foundation

enum EVChargingLedgerSource: String, Codable, Hashable, CaseIterable, Identifiable, Sendable {

    case teslaFi
    case entry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .teslaFi: return "TeslaFi"
        case .entry:   return "Manual Entry"
        }
    }

    var systemImage: String {
        switch self {
        case .teslaFi: return "tray.and.arrow.down"
        case .entry:   return "square.and.pencil"
        }
    }

    /// Short UI subtitle / hint.
    var detail: String {
        switch self {
        case .teslaFi: return "Imported session data"
        case .entry:   return "Your expense ledger"
        }
    }
}
