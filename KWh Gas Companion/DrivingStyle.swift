//
//  DrivingStyle 2.swift
//  KWh Gas Companion
//
//

// DrivingStyle.swift
// My KWh Companion

import Foundation

enum DrivingStyle: String, CaseIterable, Identifiable, Codable {
    case conservative, normal, sport
    var id: String { rawValue }
    /// Multiplier on Wh-per-mile: lower = more efficient
    var efficiencyFactor: Double {
        switch self {
        case .conservative: return 0.9
        case .normal:       return 1.0
        case .sport:        return 1.15
        }
    }
}
