//
//  ChargeSeason 2.swift
//  KWh Gas Companion
//
//  Created by Bryan on 8/7/25.
//


// ChargeSeason.swift
// My KWh Companion

import Foundation

enum ChargeSeason: String, CaseIterable, Identifiable, Codable {
    case summer, winter
    var id: String { rawValue }
}
