//
//  EnergyMix 2.swift
//  KWh Gas Companion
//
//  Created by Bryan on 8/7/25.
//


// EnergyMix.swift
// My KWh Companion

import Foundation

enum EnergyMix: String, CaseIterable, Identifiable, Codable, Hashable {
    case defaultMix, homeHeavy, roadHeavy, custom
    var id: String { rawValue }

    /// Preset ratios (custom uses engine’s custom* properties)
    var homeFraction: Double {
        switch self {
        case .defaultMix: return 0.5
        case .homeHeavy:  return 0.8
        case .roadHeavy:  return 0.3
        case .custom:     return 0.0
        }
    }
    var superchargerFraction: Double {
        switch self {
        case .defaultMix: return 0.3
        case .homeHeavy:  return 0.1
        case .roadHeavy:  return 0.4
        case .custom:     return 0.0
        }
    }
    var publicFraction: Double {
        switch self {
        case .defaultMix: return 0.2
        case .homeHeavy:  return 0.1
        case .roadHeavy:  return 0.3
        case .custom:     return 0.0
        }
    }
}
