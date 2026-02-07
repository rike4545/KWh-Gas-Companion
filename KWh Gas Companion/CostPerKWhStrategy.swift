//
//  CostPerKWhStrategy.swift
//  KWh Gas Companion
//
//  Created by Bryan on 8/17/25.
//


import SwiftUI
import Foundation

enum CostPerKWhStrategy: String, CaseIterable, Identifiable {
    case smart          // session rate -> station memory -> manual default
    case auto           // Amount ÷ kWh only
    case manualDefault  // Always use manual default if set

    var id: String { rawValue }
    var label: String {
        switch self {
        case .smart:          return "Smart"
        case .auto:           return "Auto (Amount ÷ kWh)"
        case .manualDefault:  return "Manual default"
        }
    }
}

enum RatesService {
    private static let dictKey = "stationRatesDictV1"
    private static let rememberKey = "rememberRatesByLocation"

    static var shouldRemember: Bool {
        UserDefaults.standard.object(forKey: rememberKey) as? Bool ?? true
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased()
         .trimmingCharacters(in: .whitespacesAndNewlines)
         .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func loadDict() -> [String: Double] {
        if let data = UserDefaults.standard.data(forKey: dictKey),
           let d = try? JSONDecoder().decode([String: Double].self, from: data) {
            return d
        }
        return [:]
    }

    private static func saveDict(_ d: [String: Double]) {
        if let data = try? JSONEncoder().encode(d) {
            UserDefaults.standard.set(data, forKey: dictKey)
        }
    }

    static func lastRate(for location: String) -> Double? {
        let key = normalize(location)
        return loadDict()[key]
    }

    static func record(rate: Double, for location: String) {
        guard rate > 0 else { return }
        var d = loadDict()
        d[normalize(location)] = rate
        saveDict(d)
    }

    static func allSavedRates() -> [(location: String, rate: Double)] {
        loadDict().map { ($0.key, $0.value) }.sorted { $0.location < $1.location }
    }

    static func remove(location: String) {
        var d = loadDict()
        d.removeValue(forKey: normalize(location))
        saveDict(d)
    }

    static func clearAll() {
        saveDict([:])
    }
}

/// Read the current strategy once
private func currentStrategy() -> CostPerKWhStrategy {
    let raw = UserDefaults.standard.string(forKey: "costPerKWhStrategy") ?? CostPerKWhStrategy.smart.rawValue
    return CostPerKWhStrategy(rawValue: raw) ?? .smart
}

/// Manual default from Settings
private func manualDefault() -> Double? {
    let v = UserDefaults.standard.double(forKey: "manualCostPerKWh")
    return v > 0 ? v : nil
}

/// Main helper: compute the effective $/kWh for a row
func effectiveCostPerKWh(amount: Double?, kWh: Double?, location: String?) -> Double? {
    let strategy = currentStrategy()

    switch strategy {
    case .smart:
        // 1) Real session rate if present
        if let a = amount, let e = kWh, e > 0 {
            let r = a / e
            if let loc = location, RatesService.shouldRemember { RatesService.record(rate: r, for: loc) }
            return r
        }
        // 2) Last-known station rate
        if let loc = location, let last = RatesService.lastRate(for: loc) { return last }
        // 3) Manual default
        return manualDefault()

    case .auto:
        guard let a = amount, let e = kWh, e > 0 else { return nil }
        return a / e

    case .manualDefault:
        return manualDefault()
    }
}
