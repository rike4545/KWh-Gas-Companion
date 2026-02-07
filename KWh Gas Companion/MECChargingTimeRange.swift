//
//  MECChargingTimeRange.swift
//  KWh Gas Companion
//
//  Shared filter enums used by Charging Data Studio.
//
//  Swift 6 • iOS 17+
//

import Foundation

enum MECChargingTimeRange: String, CaseIterable, Identifiable {
    case last30
    case last90
    case last365
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last30:  return "30D"
        case .last90:  return "90D"
        case .last365: return "12M"
        case .all:     return "All"
        }
    }

    // Added `calendar:` with a default so old call sites still compile.
    func contains(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch self {
        case .all:
            return true
        case .last30:
            guard let start = calendar.date(byAdding: .day, value: -30, to: now) else { return true }
            return date >= start && date <= now
        case .last90:
            guard let start = calendar.date(byAdding: .day, value: -90, to: now) else { return true }
            return date >= start && date <= now
        case .last365:
            guard let start = calendar.date(byAdding: .day, value: -365, to: now) else { return true }
            return date >= start && date <= now
        }
    }
}

enum MECChargingSortKey: String, CaseIterable, Identifiable {
    case dateDesc
    case costDesc
    case kWhDesc
    case pricePerKWhDesc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dateDesc:        return "Date"
        case .costDesc:        return "Cost"
        case .kWhDesc:         return "kWh"
        case .pricePerKWhDesc: return "Price/kWh"
        }
    }
}
