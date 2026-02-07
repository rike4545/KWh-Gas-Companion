//
//  CostOfOwnershipAnalysisView.swift
//  KWh Gas Companion
//
//  Live, store-backed ownership cost analysis.
//  - Pulls entries LIVE from EntriesStore by default
//  - Still supports explicit injection for previews/tests
//  - Optional scope filter (All / Energy / Supercharger)
//  - Category & Month breakdowns respect the active filter
//  - iOS 16+ currency fix
//
//  Swift 6 / iOS 17+ (currency helpers work on iOS 16)
//

import SwiftUI

// MARK: - View

@MainActor
struct CostOfOwnershipAnalysisView: View {
    // Live data source
    @EnvironmentObject private var entriesStore: EntriesStore

    // Optional override for previews/tests. If nil => uses entriesStore.entries
    private let injectedEntries: [ExpenseEntry]?

    // Public init. Pass `nil` (default) to use live store data.
    init(entries: [ExpenseEntry]? = nil) {
        self.injectedEntries = entries
    }

    // Scope filter (local to this view)
    private enum Scope: String, CaseIterable, Identifiable {
        case all, energy, supercharger
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return "All"
            case .energy: return "Energy"
            case .supercharger: return "Supercharger"
            }
        }
        var symbol: String {
            switch self {
            case .all: return "line.3.horizontal.decrease.circle"
            case .energy: return "bolt.fill"
            case .supercharger: return "bolt.circle.fill"
            }
        }
    }
    @State private var scope: Scope = .all

    // MARK: - Data plumbing

    /// The source entries this view analyzes:
    /// - If `injectedEntries` is provided, use that.
    /// - Otherwise, use the LIVE entries from the store.
    private var source: [ExpenseEntry] {
        let base = injectedEntries ?? entriesStore.entries
        return base.sorted { $0.date < $1.date }
    }

    /// Lightweight supercharger detector that relies only on common fields.
    private func isSupercharger(_ e: ExpenseEntry) -> Bool {
        // direct flags if your model sets them
        if let sc = mirrorBool(["isSupercharger", "supercharger"], in: e), sc { return true }
        // string heuristics
        let hay = joinedStrings(e).lowercased()
        if hay.contains("supercharger") { return true }
        if hay.contains("tesla") && (hay.contains("charger") || hay.contains("charging")) { return true }
        return false
    }

    private var filtered: [ExpenseEntry] {
        switch scope {
        case .all:
            return source
        case .energy:
            return source.filter { ($0.energyKWh ?? 0) > 0 || $0.isEnergy }
        case .supercharger:
            return source.filter { isSupercharger($0) }
        }
    }

    // MARK: - Aggregates (based on `filtered`)

    private var totalSpent: Double {
        filtered.reduce(0) { $0 + $1.amount }
    }

    private var energySpent: Double {
        filtered.filter { ($0.energyKWh ?? 0) > 0 || $0.isEnergy }.reduce(0) { $0 + $1.amount }
    }

    private var totalEnergyKWh: Double {
        filtered.reduce(0) { $0 + ($1.energyKWh ?? 0) }
    }

    private var costPerKWh: Double? {
        let k = totalEnergyKWh
        guard k > 0 else { return nil }
        return energySpent / k
    }

    private var monthsCovered: [Date] {
        let cal = Calendar.current
        let comps = Set(filtered.compactMap { cal.date(from: cal.dateComponents([.year, .month], from: $0.date)) })
        return comps.sorted()
    }

    private var avgMonthlySpend: Double {
        let months = max(1, monthsCovered.count)
        return totalSpent / Double(months)
    }

    private var byCategory: [(category: String, total: Double, pct: Double)] {
        let totals = Dictionary(grouping: filtered, by: {
            $0.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Uncategorized" : $0.category
        }).mapValues { $0.reduce(0) { $0 + $1.amount } }

        let sum = max(1e-9, totals.values.reduce(0, +))
        return totals
            .map { (category: $0.key, total: $0.value, pct: $0.value / sum) }
            .sorted { $0.total > $1.total }
    }

    private var byMonth: [(month: Date, total: Double)] {
        let cal = Calendar.current
        let bucketed = Dictionary(grouping: filtered, by: {
            cal.date(from: cal.dateComponents([.year, .month], from: $0.date))!
        }).mapValues { $0.reduce(0) { $0 + $1.amount } }

        return bucketed.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }

    // MARK: - UI

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Scope picker
                HStack(spacing: 10) {
                    Image(systemName: "chart.pie")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                    Picker("Scope", selection: $scope) {
                        ForEach(Scope.allCases) { s in
                            Label(s.title, systemImage: s.symbol).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                .padding(.top, 6)

                if filtered.isEmpty {
                    ContentUnavailableView(
                        injectedEntries == nil ? "No data on device" : "No data in scope",
                        systemImage: "tray",
                        description: Text(
                            injectedEntries == nil
                            ? "Add some expenses to see cost analysis."
                            : "Adjust filters or add expenses to see analysis."
                        )
                    )
                    .padding(.vertical, 40)
                }

                // Summary tiles
                HStack(spacing: 12) {
                    COCMetricTile(title: "Total Spent",
                                  valueText: currencyString(totalSpent),
                                  systemImage: "dollarsign.circle.fill")
                    COCMetricTile(title: "Avg / Month",
                                  valueText: currencyString(avgMonthlySpend),
                                  systemImage: "calendar")
                }

                HStack(spacing: 12) {
                    COCMetricTile(title: "Energy %",
                                  valueText: percentString(totalSpent == 0 ? 0 : energySpent / totalSpent),
                                  systemImage: "bolt.fill")
                    COCMetricTile(title: "Cost / kWh",
                                  valueText: costPerKWh.map(currencyPerKWhString) ?? "—",
                                  systemImage: "gauge")
                }

                COCMetricTile(title: "Total kWh",
                              valueText: kwhString(totalEnergyKWh),
                              systemImage: "battery.100.bolt")

                // Category breakdown
                COCSectionHeader("By Category", systemImage: "chart.pie.fill")
                VStack(spacing: 8) {
                    ForEach(byCategory, id: \.category) { row in
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(row.category).font(.headline)
                                ProgressView(value: row.pct) { EmptyView() } currentValueLabel: {
                                    Text(percentString(row.pct)).font(.caption).foregroundStyle(.secondary)
                                }
                                .progressViewStyle(.linear)
                            }
                            Spacer(minLength: 8)
                            Text(currencyString(row.total)).monospaced()
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                // Monthly totals
                COCSectionHeader("By Month", systemImage: "calendar")
                VStack(spacing: 8) {
                    ForEach(byMonth, id: \.month) { m in
                        HStack {
                            Text(monthShort(m.month))
                            Spacer()
                            Text(currencyString(m.total)).monospaced()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Cost of Ownership")
    }
}

// MARK: - Section header (namespaced to avoid collisions)

private struct COCSectionHeader: View {
    let title: String
    let systemImage: String?

    init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage).imageScale(.medium)
            }
            Text(title).font(.headline)
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Metric tile

private struct COCMetricTile: View {
    let title: String
    let valueText: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .imageScale(.large)
                .foregroundStyle(.tint) // safer than .accent
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(valueText).font(.title3).bold().monospacedDigit()
            }
            Spacer()
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Formatting helpers (with iOS 16 currency fix)

private func currencyString(_ v: Double) -> String {
    let nf = NumberFormatter()
    nf.numberStyle = .currency
    if #available(iOS 16.0, *) {
        nf.currencyCode = Locale.current.currency?.identifier ?? "USD"
    } else {
        nf.currencyCode = Locale.current.currencyCode ?? "USD"
    }
    nf.maximumFractionDigits = 2
    nf.minimumFractionDigits = 0
    return nf.string(from: NSNumber(value: v)) ?? String(format: "$%.2f", v)
}

private func currencyPerKWhString(_ v: Double) -> String {
    currencyString(v) + " / kWh"
}

private func kwhString(_ v: Double) -> String {
    if v == 0 { return "0 kWh" }
    if v < 10 { return String(format: "%.2f kWh", v) }
    if v < 100 { return String(format: "%.1f kWh", v) }
    return String(format: "%.0f kWh", v)
}

private func percentString(_ p: Double) -> String {
    let clamped = max(0, min(1, p))
    let nf = NumberFormatter()
    nf.numberStyle = .percent
    nf.maximumFractionDigits = (clamped == 0 || clamped == 1) ? 0 : 1
    nf.minimumFractionDigits = 0
    return nf.string(from: NSNumber(value: clamped)) ?? "\(Int(clamped * 100))%"
}

private func monthShort(_ d: Date) -> String {
    let df = DateFormatter()
    df.dateFormat = "MMM yyyy"
    return df.string(from: d)
}

// MARK: - Tiny reflection helpers used by the supercharger heuristic

private func joinedStrings(_ v: Any) -> String {
    Mirror(reflecting: v).children.compactMap { c in
        if let s = c.value as? String { return s }
        if let d = c.value as? Double { return String(d) }
        if let i = c.value as? Int { return String(i) }
        if let b = c.value as? Bool { return b ? "true" : "false" }
        if let dt = c.value as? Date {
            let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .none
            return df.string(from: dt)
        }
        return nil
    }.joined(separator: " ")
}

private func mirrorBool(_ keys: [String], in v: Any) -> Bool? {
    for ch in Mirror(reflecting: v).children {
        guard let label = ch.label else { continue }
        if keys.contains(label) {
            if let b = ch.value as? Bool { return b }
            if let s = ch.value as? String { return ["1","true","yes","y"].contains(s.lowercased()) }
            if let n = ch.value as? NSNumber { return n.boolValue }
        }
    }
    return nil
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        // Preview with injected data (no store)
        CostOfOwnershipAnalysisView(entries: CostOfOwnershipAnalysisView.previewEntries)
    }
    .environmentObject(EntriesStore())
}

extension CostOfOwnershipAnalysisView {
    static let previewEntries: [ExpenseEntry] = {
        let now = Date()
        let cal = Calendar.current
        func d(_ offset: Int) -> Date { cal.date(byAdding: .month, value: offset, to: now)! }
        return [
            ExpenseEntry(date: d(-5), amount: 42.30, category: "Charging",   energyKWh: 120, location: "Tesla Supercharger – HomeTown",  vehicleName: "Model 3", chargeType: "DCFC",  isBusiness: false, isEnergy: true),
            ExpenseEntry(date: d(-5), amount: 89.00, category: "Insurance",  energyKWh: nil, location: "Online", vehicleName: "Model 3", isBusiness: false, isEnergy: false),
            ExpenseEntry(date: d(-4), amount: 51.10, category: "Charging",   energyKWh: 140, location: "Home",  vehicleName: "Model 3", chargeType: "Home",  isBusiness: true,  isEnergy: true),
            ExpenseEntry(date: d(-3), amount: 120.00,category: "Maintenance",energyKWh: nil, location: "Service", vehicleName: "Model 3", isBusiness: false, isEnergy: false),
            ExpenseEntry(date: d(-2), amount: 36.50, category: "Charging",   energyKWh: 90,  location: "Home",  vehicleName: "Model 3", chargeType: "Home",  isBusiness: false, isEnergy: true),
            ExpenseEntry(date: d(-1), amount: 15.75, category: "Parking",    energyKWh: nil, location: "City",  vehicleName: "Model 3", isBusiness: false, isEnergy: false),
            ExpenseEntry(date: d( 0), amount: 44.20, category: "Charging",   energyKWh: 130, location: "Tesla Supercharger – Midtown",  vehicleName: "Model 3", chargeType: "DCFC",  isBusiness: true,  isEnergy: true),
        ]
    }()
}
#endif
