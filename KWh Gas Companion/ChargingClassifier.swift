//
//  ChargingClassifier.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/17/25.
//


//
//  ChargingClassifier.swift
//  My KWh Companion
//
//  Infers home vs fastDC vs destination using ExpenseEntry + TeslaFi heuristics.
//  Swift 6 • iOS 17+
//

import Foundation

enum ChargingClassifier {

    static func classify(entry: ExpenseEntry) -> ChargingKind {
        let cat = entry.category.lowercased()
        let loc = (entry.charging?.siteName ?? entry.location ?? "").lowercased()
        let type = (entry.chargeType ?? "").lowercased()

        if entry.charging?.isSupercharger == true { return .fastDC }
        if type.contains("supercharger") || type.contains("dcfc") { return .fastDC }
        if cat.contains("dcfc") || cat.contains("fast") || cat.contains("supercharger") { return .fastDC }
        if let brand = entry.charging?.fastChargerBrand, !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .fastDC
        }

        if let p = entry.charging?.chargerPowerkW {
            if p >= 45 { return .fastDC }
            if p >= 3 {
                if loc.contains("home") || cat.contains("home") || cat.contains("garage") { return .home }
                return .destination
            }
        }

        if loc.contains("supercharger") { return .fastDC }
        if loc.contains("home") || cat.contains("home") || cat.contains("garage") { return .home }

        return .unknown
    }

    static func classify(session: TeslaFiSession) -> ChargingKind {
        let loc = (session.location ?? "").lowercased()

        if loc.contains("supercharger") { return .fastDC }
        if loc.contains("home") { return .home }

        // Try to infer from raw columns if present (best-effort)
        if let kw = rawDouble(session.raw, keys: ["charger_power_kw", "charger power", "kW", "charge rate kw", "charge rate (kw)"]) {
            if kw >= 45 { return .fastDC }
            if kw >= 3 {
                return loc.contains("hotel") || loc.contains("mall") ? .destination : .home
            }
        }

        return .unknown
    }

    private static func rawDouble(_ raw: [String: String], keys: [String]) -> Double? {
        // match keys loosely by lowercasing
        let lowered = Dictionary(uniqueKeysWithValues: raw.map { ($0.key.lowercased(), $0.value) })
        for k in keys {
            let key = k.lowercased()
            if let v = lowered[key] {
                if let d = Double(v.trimmingCharacters(in: .whitespacesAndNewlines)) { return d }
                // some CSV values may be like "72 kW"
                let digits = v.filter { "0123456789.-".contains($0) }
                if let d = Double(digits) { return d }
            }
        }
        return nil
    }
}
