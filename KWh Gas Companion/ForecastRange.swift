//
//  ForecastRange 2.swift
//  KWh Gas Companion
//
//

// ForecastRange.swift
// My KWh Companion

import Foundation

enum ForecastRange: String, CaseIterable, Identifiable {
    case week  = "Week"
    case month = "Month"
    case year  = "Year"

    var id: String { rawValue }
    /// Multiplier relative to one month
    var multiplier: Double {
        switch self {
        case .week:  return 7.0 / 30.0
        case .month: return 1.0
        case .year:  return 12.0
        }
    }
}
