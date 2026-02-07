//  EVvsCarComparisonView.swift
//  KWh Gas Companion
//
//  EV vs ICE cost-per-mile comparison.
//  - Zero-arg init works, optional CPM overrides supported
//  - Computes EV $/mi from your charging entries + odometer span
//  - Persists assumptions via @AppStorage
//  - iOS 16+: uses Charts

import SwiftUI
import Charts

struct EVvsCarComparisonView: View {
    // Optional overrides so older call sites keep working
    private let evCostPerMileOverride: Double?
    private let carCostPerMileOverride: Double?

    init(evCostPerMile: Double? = nil, carCostPerMile: Double? = nil) {
        self.evCostPerMileOverride = evCostPerMile
        self.carCostPerMileOverride = carCostPerMile
    }

    // MARK: - Data
    @EnvironmentObject private var entriesStore: EntriesStore

    // Persisted assumptions (tweak to taste)
    @AppStorage("comp_mpg")            private var iceMPG: Double = 28
    @AppStorage("comp_fuel_price")     private var fuelPricePerGallon: Double = 3.80
    @AppStorage("comp_miles_per_year") private var milesPerYear: Double = 12_000
    @AppStorage("comp_ev_maint_per_mi") private var evMaintPerMile: Double = 0.04
    @AppStorage("comp_ice_maint_per_mi") private var iceMaintPerMile: Double = 0.08
    @AppStorage("comp_ev_price_premium") private var evPricePremium: Double = 0

    // MARK: - Derived from store
    private var energyCost: Double {
        entriesStore.entries.filter { $0.isEnergy }.reduce(0.0) { $0 + $1.amount }
    }

    private var milesTraveled: Double? {
        let odos = entriesStore.entries.compactMap { $0.odometer }.sorted()
        guard let first = odos.first, let last = odos.last, last > first else { return nil }
        return last - first
    }

    private var autoEvCPM: Double? {
        guard let miles = milesTraveled, miles > 0 else { return nil }
        return energyCost / miles
    }

    // Final CPMs (apply overrides if provided)
    private var evCPM: Double? {
        let base = evCostPerMileOverride ?? autoEvCPM
        guard let base else { return nil }
        return base + max(evMaintPerMile, 0)
    }
    private var carCPM: Double {
        if let override = carCostPerMileOverride { return max(override, 0) }
        guard iceMPG > 0 else { return 0 }
        return (max(fuelPricePerGallon, 0) / iceMPG) + max(iceMaintPerMile, 0)
    }

    private var savingsPerMile: Double? {
        guard let ev = evCPM else { return nil }
        return carCPM - ev
    }
    private var annualSavings: Double? {
        guard let s = savingsPerMile else { return nil }
        return s * max(milesPerYear, 0)
    }
    private var paybackYears: Double? {
        guard let annual = annualSavings, annual > 0, evPricePremium > 0 else { return nil }
        return evPricePremium / annual
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    // MARK: - UI
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                if evCPM == nil {
                    EmptyStateCard(
                        title: "Need more data",
                        message: "To estimate EV cost per mile, add charging entries with costs and at least two odometer values."
                    )
                } else {
                    metricsRow
                    costBarChart
                    breakevenCard
                    assumptionsCard
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("EV vs ICE")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EV vs ICE Cost per Mile").font(.title.bold())
            Text(summaryLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryLine: String {
        let ev = evCPM.map(currencyShort) ?? "—"
        let ice = currencyShort(carCPM)
        return "EV \(ev) • ICE \(ice)"
    }

    private var metricsRow: some View {
        HStack(spacing: 12) {
            MetricPill(title: "EV $/mi", value: evCPM.map(currencyShort) ?? "—", icon: "bolt.fill")
            MetricPill(title: "ICE $/mi", value: currencyShort(carCPM), icon: "fuelpump.fill")
            MetricPill(title: "Δ $/mi", value: savingsPerMile.map(currencyShort) ?? "—", icon: "arrow.left.and.right.circle")
            MetricPill(title: "Annual Δ", value: annualSavings.map(currencyShort) ?? "—", icon: "calendar")
        }
    }

    private var costBarChart: some View {
        Card(title: "Cost per Mile", subtitle: "EV vs ICE") {
            let rows: [Pair] = [
                Pair(label: "EV", value: evCPM ?? 0),
                Pair(label: "ICE", value: carCPM)
            ]
            Chart(rows) { r in
                BarMark(
                    x: .value("Type", r.label),
                    y: .value("$ / mi", r.value)
                )
                .annotation(position: .top) {
                    Text(currencyShort(r.value)).font(.caption2)
                }
                .foregroundStyle(by: .value("Type", r.label))
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    if let v = value.as(Double.self) {
                        AxisGridLine()
                        AxisValueLabel(currencyShort(v))
                    }
                }
            }
            .frame(height: 220)
        }
    }

    private var assumptionsCard: some View {
        Card(title: "Assumptions", subtitle: "ICE & annual mileage") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("ICE MPG").foregroundStyle(.secondary)
                    Stepper(value: $iceMPG, in: 5...100, step: 1) {
                        Text("\(Int(iceMPG)) mpg")
                    }
                }
                GridRow {
                    Text("Fuel Price").foregroundStyle(.secondary)
                    Stepper(value: $fuelPricePerGallon, in: 0...12, step: 0.05) {
                        Text(currencyShort(fuelPricePerGallon) + "/gal")
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
                    Text("Miles / Year").foregroundStyle(.secondary)
                    Stepper(value: $milesPerYear, in: 1_000...100_000, step: 500) {
                        Text(numberShort(milesPerYear, 0))
                    }
                }
                GridRow {
                    Text("EV Price Premium").foregroundStyle(.secondary)
                    Stepper(value: $evPricePremium, in: 0...100_000, step: 500) {
                        Text(currencyShort(evPricePremium))
                    }
                }
            }
            .font(.footnote)
        }
    }

    private var breakevenCard: some View {
        Card(title: "Breakeven", subtitle: "EV price premium payback") {
            VStack(alignment: .leading, spacing: 8) {
                if let years = paybackYears {
                    Text("Estimated payback: \(years, specifier: "%.1f") years")
                        .font(.headline)
                } else {
                    Text("Enter a premium and ensure EV savings are positive.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Formatting

    private func currencyShort(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        f.maximumFractionDigits = v < 1 ? 3 : 2
        return f.string(from: NSNumber(value: v)) ?? "$0.00"
    }

    private func numberShort(_ v: Double, _ digits: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = digits
        f.minimumFractionDigits = digits
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
}

// MARK: - Small types & UI helpers

private struct Pair: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

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
        EVvsCarComparisonView()
            .environmentObject(EntriesStore())
    }
}
#endif
