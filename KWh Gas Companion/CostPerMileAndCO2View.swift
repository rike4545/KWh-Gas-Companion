//  CostPerMileAndCO2View.swift
//  KWh Gas Companion

import SwiftUI
import Charts

struct CostPerMileAndCO2View: View {
    // Optional injection for call sites that prefer it
    private let injectedEntries: [ExpenseEntry]?
    init(entries: [ExpenseEntry]? = nil) { self.injectedEntries = entries }

    @EnvironmentObject private var entriesStore: EntriesStore

    // Assumptions persisted for convenience
    @AppStorage("cmp_elec_rate") private var electricityRate: Double = 0.15   // $/kWh
    @AppStorage("cmp_kwh_per_100") private var kWhPer100mi: Double = 28       // kWh/100mi fallback
    @AppStorage("cmp_grid_kg_per_kwh") private var gridCO2kgPerKWh: Double = 0.40 // kg CO₂ / kWh

    @AppStorage("cmp_ice_mpg") private var iceMPG: Double = 28                 // mpg
    @AppStorage("cmp_gas_price") private var fuelPricePerGallon: Double = 3.80 // $/gal
    @AppStorage("cmp_gas_kg_per_gal") private var gasCO2kgPerGallon: Double = 8.887 // kg CO₂ / gal (EPA)
    @AppStorage("cmp_ev_maint_per_mi") private var evMaintPerMile: Double = 0.04
    @AppStorage("cmp_ice_maint_per_mi") private var iceMaintPerMile: Double = 0.08
    @AppStorage("cmp_annual_miles") private var annualMiles: Double = 12_000
    @AppStorage("cmp_ev_price_premium") private var evPricePremium: Double = 0

    @State private var preferDataWhenAvailable: Bool = true

    // MARK: - Source data
    private var entries: [ExpenseEntry] { injectedEntries ?? entriesStore.entries }
    private var energyEntries: [ExpenseEntry] { entries.filter { $0.isEnergy } }

    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    // MARK: - Derived from data
    private var energySpend: Double { energyEntries.reduce(0.0) { $0 + $1.amount } }

    private var milesSpan: Double? {
        let odos = entries.compactMap { $0.odometer }.sorted()
        guard let first = odos.first, let last = odos.last, last > first else { return nil }
        return last - first
    }

    /// Sum of energy in kWh if your model carries it (fields: `energyKWh` or `kWh`).
    private var energyKWhTotal: Double? {
        let totals: [Double] = energyEntries.compactMap { e in
            extractDouble(from: e, key: "energyKWh") ?? extractDouble(from: e, key: "kWh")
        }
        guard !totals.isEmpty else { return nil }
        return totals.reduce(0, +)
    }

    /// Data-derived EV metrics
    private var evCostPerMileData: Double? {
        guard let span = milesSpan, span > 0 else { return nil }
        return energySpend / span
    }
    private var evKWhPerMileData: Double? {
        guard let span = milesSpan, span > 0, let kwh = energyKWhTotal, kwh > 0 else { return nil }
        return kwh / span
    }

    /// Assumption-based EV metrics
    private var evKWhPerMileAssumed: Double { max(kWhPer100mi, 0) / 100.0 }
    private var evCostPerMileAssumed: Double { evKWhPerMileAssumed * max(electricityRate, 0) }

    /// Final EV metrics (prefer data if available and toggled)
    private var evEnergyCostPerMile: Double {
        if preferDataWhenAvailable, let v = evCostPerMileData { return max(v, 0) }
        return max(evCostPerMileAssumed, 0)
    }

    private var evCostPerMile: Double {
        evEnergyCostPerMile + max(evMaintPerMile, 0)
    }
    private var evCO2PerMileKg: Double {
        let kWhPerMile = (preferDataWhenAvailable ? (evKWhPerMileData ?? evKWhPerMileAssumed) : evKWhPerMileAssumed)
        return max(kWhPerMile, 0) * max(gridCO2kgPerKWh, 0)
    }

    // ICE metrics
    private var iceFuelCostPerMile: Double {
        guard iceMPG > 0 else { return 0 }
        return max(fuelPricePerGallon, 0) / iceMPG
    }
    private var iceCostPerMile: Double {
        iceFuelCostPerMile + max(iceMaintPerMile, 0)
    }
    private var iceCO2PerMileKg: Double {
        guard iceMPG > 0 else { return 0 }
        let galPerMile = 1.0 / iceMPG
        return galPerMile * max(gasCO2kgPerGallon, 0)
    }

    // Deltas (ICE - EV)
    private var deltaCostPerMile: Double { iceCostPerMile - evCostPerMile }
    private var deltaCO2PerMileKg: Double { iceCO2PerMileKg - evCO2PerMileKg }

    private var annualSavings: Double {
        deltaCostPerMile * max(annualMiles, 0)
    }
    private var monthlySavings: Double { annualSavings / 12.0 }

    private var paybackYears: Double? {
        guard evPricePremium > 0, annualSavings > 0 else { return nil }
        return evPricePremium / annualSavings
    }
    private var paybackMonths: Double? {
        guard let years = paybackYears else { return nil }
        return years * 12.0
    }

    // MARK: - UI
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if energyEntries.isEmpty && evCostPerMileData == nil {
                    EmptyStateCard(
                        title: "Not enough data",
                        message: "Add charging entries with costs and at least two odometer values to compute EV $/mi. You can still use assumptions below."
                    )
                }
                metricsRow
                costBars
                co2Bars
                savingsCard
                breakevenCard
                assumptions
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Cost & CO₂ per Mile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cost & CO₂ per Mile").font(.title.bold())
            Text(summaryLine).font(.footnote).foregroundStyle(.secondary)
            if evCostPerMileData != nil || evKWhPerMileData != nil {
                Toggle("Prefer data-derived metrics when available", isOn: $preferDataWhenAvailable)
                    .toggleStyle(.switch)
                    .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryLine: String {
        let evCost = currencyShort(evCostPerMile) + "/mi"
        let iceCost = currencyShort(iceCostPerMile) + "/mi"
        let evCO2 = kgShort(evCO2PerMileKg) + "/mi"
        let iceCO2 = kgShort(iceCO2PerMileKg) + "/mi"
        return "EV: \(evCost), \(evCO2)  •  ICE: \(iceCost), \(iceCO2)"
    }

    private var metricsRow: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                MetricPill(title: "EV $/mi", value: currencyShort(evCostPerMile), icon: "bolt.fill")
                MetricPill(title: "ICE $/mi", value: currencyShort(iceCostPerMile), icon: "fuelpump.fill")
                MetricPill(title: "Δ $/mi", value: currencyShort(deltaCostPerMile), icon: "arrow.left.and.right.circle")
            }
            HStack(spacing: 12) {
                MetricPill(title: "EV CO₂/mi", value: kgShort(evCO2PerMileKg), icon: "leaf")
                MetricPill(title: "ICE CO₂/mi", value: kgShort(iceCO2PerMileKg), icon: "smoke")
                MetricPill(title: "Δ CO₂/mi", value: kgShort(deltaCO2PerMileKg), icon: "arrow.left.and.right.circle")
            }
        }
    }

    private var costBars: some View {
        Card(title: "Cost per Mile", subtitle: "EV vs ICE") {
            let rows: [Pair] = [
                Pair(label: "EV", value: evCostPerMile),
                Pair(label: "ICE", value: iceCostPerMile)
            ]
            Chart(rows) { r in
                BarMark(x: .value("Type", r.label), y: .value("$/mi", r.value))
                    .annotation(position: .top) { Text(currencyShort(r.value)).font(.caption2) }
                    .foregroundStyle(by: .value("Type", r.label))
            }
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    if let d = v.as(Double.self) { AxisValueLabel(currencyShort(d)) }
                }
            }
            .frame(height: 220)
        }
    }

    private var savingsCard: some View {
        Card(title: "Savings Impact", subtitle: "Based on annual miles") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Annual miles")
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("", value: $annualMiles, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                    Text("mi").foregroundStyle(.secondary)
                }

                HStack {
                    Text("Monthly savings")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currencyShort(monthlySavings))
                        .font(.headline)
                        .foregroundStyle(monthlySavings >= 0 ? .green : .red)
                }

                HStack {
                    Text("Annual savings")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currencyShort(annualSavings))
                        .font(.headline)
                        .foregroundStyle(annualSavings >= 0 ? .green : .red)
                }
            }
            .font(.footnote)
        }
    }

    private var breakevenCard: some View {
        Card(title: "Breakeven", subtitle: "EV price premium payback") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("EV price premium")
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("", value: $evPricePremium, format: .currency(code: currencyCode))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 140)
                }

                if let years = paybackYears, let months = paybackMonths {
                    HStack {
                        Text("Payback time")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(months, specifier: "%.0f") months (~\(years, specifier: "%.1f") years)")
                            .font(.headline)
                    }
                } else {
                    Text("Enter a premium and ensure EV savings are positive.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
        }
    }

    private var co2Bars: some View {
        Card(title: "CO₂ per Mile", subtitle: "EV vs ICE") {
            let rows: [Pair] = [
                Pair(label: "EV", value: evCO2PerMileKg),
                Pair(label: "ICE", value: iceCO2PerMileKg)
            ]
            Chart(rows) { r in
                BarMark(x: .value("Type", r.label), y: .value("kg CO₂/mi", r.value))
                    .annotation(position: .top) { Text(kgShort(r.value)).font(.caption2) }
                    .foregroundStyle(by: .value("Type", r.label))
            }
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    if let d = v.as(Double.self) { AxisValueLabel(kgShort(d)) }
                }
            }
            .frame(height: 220)
        }
    }

    private var assumptions: some View {
        Card(title: "Assumptions", subtitle: "Used when data is missing or preference is off") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Electricity Rate").foregroundStyle(.secondary)
                    Stepper(value: $electricityRate, in: 0...1_000, step: 0.005) {
                        Text(currencyShort(electricityRate) + "/kWh")
                    }
                }
                GridRow {
                    Text("EV kWh/100mi").foregroundStyle(.secondary)
                    Stepper(value: $kWhPer100mi, in: 5...100, step: 1) {
                        Text("\(Int(kWhPer100mi)) kWh/100mi")
                    }
                }
                GridRow {
                    Text("Grid CO₂").foregroundStyle(.secondary)
                    Stepper(value: $gridCO2kgPerKWh, in: 0...2, step: 0.01) {
                        Text(kgShort(gridCO2kgPerKWh) + "/kWh")
                    }
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    Text("ICE MPG").foregroundStyle(.secondary)
                    Stepper(value: $iceMPG, in: 5...100, step: 1) {
                        Text("\(Int(iceMPG)) mpg")
                    }
                }
                GridRow {
                    Text("EV Maint.").foregroundStyle(.secondary)
                    Stepper(value: $evMaintPerMile, in: 0...1, step: 0.01) {
                        Text(currencyShort(evMaintPerMile) + "/mi")
                    }
                }
                GridRow {
                    Text("ICE Maint.").foregroundStyle(.secondary)
                    Stepper(value: $iceMaintPerMile, in: 0...2, step: 0.01) {
                        Text(currencyShort(iceMaintPerMile) + "/mi")
                    }
                }
                GridRow {
                    Text("Gas Price").foregroundStyle(.secondary)
                    Stepper(value: $fuelPricePerGallon, in: 0...20, step: 0.05) {
                        Text(currencyShort(fuelPricePerGallon) + "/gal")
                    }
                }
                GridRow {
                    Text("Gasoline CO₂").foregroundStyle(.secondary)
                    Stepper(value: $gasCO2kgPerGallon, in: 0...20, step: 0.01) {
                        Text(kgShort(gasCO2kgPerGallon) + "/gal")
                    }
                }
            }
            .font(.footnote)
        }
    }

    // MARK: - Helpers

    private func extractDouble(from entry: ExpenseEntry, key: String) -> Double? {
        let mirror = Mirror(reflecting: entry)
        for child in mirror.children {
            if child.label == key { return child.value as? Double }
        }
        return nil
    }

    private func currencyShort(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = currencyCode
        f.maximumFractionDigits = v < 1 ? 3 : 2
        return f.string(from: NSNumber(value: v)) ?? "$0.00"
    }
    private func kgShort(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.1f t", v/1000) }
        return String(format: "%.2f kg", v)
    }
}

// MARK: - Small Types & UI helpers

private struct Pair: Identifiable { let id = UUID(); let label: String; let value: Double }

private struct Card<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.secondary) }
            }
            content
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(uiColor: .separator).opacity(0.25), lineWidth: 1))
    }
}

private struct MetricPill: View {
    let title: String, value: String, icon: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(uiColor: .secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(uiColor: .separator).opacity(0.25), lineWidth: 1))
    }
}

private struct EmptyStateCard: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .imageScale(.large)
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .tertiarySystemBackground)))
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CostPerMileAndCO2View()
            .environmentObject(EntriesStore())
    }
}
#endif
