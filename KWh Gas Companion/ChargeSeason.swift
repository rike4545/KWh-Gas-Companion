//
//  ChargeSeason.swift
//  My KWh Companion
//
//  🔧 FIX: Removed duplicate file-header comment ("ChargeSeason 2.swift").
//  Swift 6 / iOS 17+
//

import Foundation

enum ChargeSeason: String, CaseIterable, Identifiable, Codable {
    case summer, winter
    var id: String { rawValue }
}
