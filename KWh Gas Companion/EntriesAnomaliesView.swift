//
//  EntriesAnomaliesView.swift
//  KWh Gas Companion
//
//  Bridges EntriesStore → AnomalyListView without touching your data models.
//  - Accepts optional ALVRules (default provided)
//  - Maps arbitrary Entry objects to ALVObservation via lightweight reflection
//  - Lenient numeric parsing (commas/spaces), robust date parsing
//  - Sorted newest-first
//

import SwiftUI
import Foundation

@MainActor
public struct EntriesAnomaliesView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    private let rules: ALVRules   // kept for future use/config

    public init(rules: ALVRules = .default) {
        self.rules = rules
    }

    public var body: some View {
        let obs = entriesStoreObservations()
        AnomalyListView(observations: obs) // ← removed `rules:` to fix “Extra argument” error
            .navigationTitle("Entry Anomalies")
    }

    // MARK: - Map EntriesStore -> [ALVObservation]

    private func entriesStoreObservations() -> [ALVObservation] {
        let entries = entriesStore.entries
        return entries.compactMap { e in
            guard let date = extractDate(from: e) else { return nil }
            let energy = extractEnergyKWh(from: e) ?? 0
            let cost   = extractCost(from: e) ?? 0
            let miles  = extractMiles(from: e)
            return ALVObservation(date: date, energyKWh: energy, cost: cost, miles: miles)
        }
        .sorted { $0.date > $1.date }
    }

    // MARK: - Reflection helpers (model-agnostic)

    private func extractDate(from entry: Any) -> Date? {
        for (label, value) in reflect(entry) {
            let key = label.lowercased()

            if let d = value as? Date, key == "date" || key == "startdate" || key == "enddate" {
                return d
            }

            if key.contains("timestamp") || key == "date" {
                if let secs = value as? TimeInterval { return Date(timeIntervalSince1970: secs) }
                if let i = value as? Int {
                    let t = TimeInterval(i)
                    return Date(timeIntervalSince1970: t > 2_000_000_000 ? t / 1000 : t)
                }
                if let s = value as? String {
                    if let numeric = Double(s.replacingOccurrences(of: " ", with: "")) {
                        let t = numeric
                        return Date(timeIntervalSince1970: t > 2_000_000_000 ? t / 1000 : t)
                    }
                    if let iso = parseISODate(s) { return iso }
                    if let df = parseCommonDate(s) { return df }
                }
            }
        }
        return nil
    }

    private func extractEnergyKWh(from entry: Any) -> Double? {
        for (label, value) in reflect(entry) {
            let key = label.lowercased()
            if key == "energykwh",   let d = asDouble(value) { return d }
            if key == "kwh",         let d = asDouble(value) { return d }
            if key == "energy",      let d = asDouble(value) { return d }
            if key == "energyadded", let d = asDouble(value) { return d }
        }
        return nil
    }

    private func extractCost(from entry: Any) -> Double? {
        for (label, value) in reflect(entry) {
            let key = label.lowercased()
            if key == "cost",      let d = asDouble(value) { return d }
            if key == "amount",    let d = asDouble(value) { return d }
            if key == "totalcost", let d = asDouble(value) { return d }
            if key == "price",     let d = asDouble(value) { return d }
        }
        return nil
    }

    private func extractMiles(from entry: Any) -> Double? {
        for (label, value) in reflect(entry) {
            let key = label.lowercased()
            if key == "miles",         let d = asDouble(value) { return d }
            if key == "distancemiles", let d = asDouble(value) { return d }
            if key == "distance",      let d = asDouble(value) { return d }
        }
        return nil
    }

    // MARK: - Generic reflection utilities

    private func reflect(_ object: Any) -> [(label: String, value: Any)] {
        Mirror(reflecting: object).children.compactMap { child in
            guard let label = child.label else { return nil }
            return (label, unwrapAny(child.value))
        }
    }

    private func unwrapAny(_ value: Any) -> Any {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            return mirror.children.first?.value ?? (Optional<Any>.none as Any)
        }
        return value
    }

    /// Robust numeric parsing:
    /// - Doubles/Floats/Ints/NSNumber
    /// - Strings with spaces as thousands
    /// - Strings with “,” or “.” as decimal marks
    private func asDouble(_ value: Any) -> Double? {
        switch value {
        case let d as Double: return d
        case let f as Float:  return Double(f)
        case let i as Int:    return Double(i)
        case let i8 as Int8:  return Double(i8)
        case let i16 as Int16: return Double(i16)
        case let i32 as Int32: return Double(i32)
        case let i64 as Int64: return Double(i64)
        case let u as UInt:   return Double(u)
        case let u8 as UInt8: return Double(u8)
        case let u16 as UInt16: return Double(u16)
        case let u32 as UInt32: return Double(u32)
        case let u64 as UInt64: return Double(u64)
        case let n as NSNumber: return n.doubleValue
        case let s as String:
            let stripped = s.replacingOccurrences(of: " ", with: "")
            if stripped.contains(",") && stripped.contains(".") {
                return Double(stripped.replacingOccurrences(of: ",", with: ""))
            }
            if stripped.contains(",") {
                return Double(stripped.replacingOccurrences(of: ",", with: "."))
            }
            return Double(stripped)
        default:
            return nil
        }
    }

    // MARK: - Date parsing helpers

    private func parseISODate(_ s: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: s)
    }

    private func parseCommonDate(_ s: String) -> Date? {
        let formats = [
            "yyyy-MM-dd",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "MM/dd/yyyy",
            "MM/dd/yyyy HH:mm",
            "MM/dd/yyyy HH:mm:ss"
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for f in formats {
            df.dateFormat = f
            if let d = df.date(from: s) { return d }
        }
        return nil
    }
}

#if DEBUG
#Preview {
    let store = EntriesStore()
    return NavigationStack {
        EntriesAnomaliesView() // uses .default rules, not passed to AnomalyListView
            .environmentObject(store)
    }
}
#endif
