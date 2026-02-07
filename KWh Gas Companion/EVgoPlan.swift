//
//  EVgoPlan.swift
//  KWh Gas Companion
//
//  Created by Bryan on 9/3/25.
//


//  EVgoPlan.swift
//  My KWh Companion
//
//  EVgo membership plans.
//  Keep this file focused on the plan identity and display name only.

import Foundation

public enum EVgoPlan: String, CaseIterable, Codable, Hashable {
    case payAsYouGo
    case plus
    case plusMax
    case uberBlue
    case uberGoldPlatinumDiamond
}

public extension EVgoPlan {
    var readableName: String {
        switch self {
        case .payAsYouGo: return "EVgo Pay As You Go"
        case .plus: return "EVgo Plus"
        case .plusMax: return "EVgo PlusMax"
        case .uberBlue: return "EVgo Uber Pro Blue"
        case .uberGoldPlatinumDiamond: return "EVgo Uber Pro Gold/Platinum/Diamond"
        }
    }
}
