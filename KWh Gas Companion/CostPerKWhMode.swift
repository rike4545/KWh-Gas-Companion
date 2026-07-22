//
//  CostPerKWhMode.swift
//  KWh Gas Companion
//
//

import SwiftUI

enum CostPerKWhMode: String, CaseIterable, Identifiable {
    case auto      // Amount ÷ kWh (if provided)
    case manual    // Use a default rate from Settings

    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto:   return "Auto (Amount ÷ kWh)"
        case .manual: return "Manual (use default rate)"
        }
    }
}

/// Global helper you can call anywhere to get the effective $/kWh for a row/draft.
func effectiveCostPerKWh(amount: Double?, kWh: Double?) -> Double? {
    let modeRaw = UserDefaults.standard.string(forKey: "costPerKWhMode") ?? CostPerKWhMode.auto.rawValue
    let mode    = CostPerKWhMode(rawValue: modeRaw) ?? .auto

    switch mode {
    case .manual:
        // If user set a positive manual rate, prefer it; otherwise fall back to auto.
        let manual = UserDefaults.standard.double(forKey: "manualCostPerKWh")
        if manual > 0 { return manual }
        fallthrough
    case .auto:
        guard let a = amount, let e = kWh, e > 0 else { return nil }
        return a / e
    }
}
