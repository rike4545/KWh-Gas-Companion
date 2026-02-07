//
//  WhatIfForecastView.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//
//  “What If?” — fast monthly charging cost simulator.
//  - No placeholder data
//  - Settings persist on-device via AppStorage
//  - Clean, card-based UI (less clunky than Form)
//  - Simple breakdown: Home vs Public + energy + $/mi
//

import SwiftUI
import Foundation

@MainActor
public struct WhatIfForecastView: View {

    // Theme (matches your other views like TripPlannerView)
    @Environment(\.appThemeBox) private var themeBox
    private var T: any AppThemeSpec { themeBox.base }

    // Persisted knobs (on-device)
    @AppStorage("whatif.monthly_miles") private var monthlyMiles: Double = 1000
    @AppStorage("whatif.home_ratio") private var homeRatio: Double = 0.70
    @AppStorage("whatif.home_rate") private var homeRate: Double = 0.11
    @AppStorage("whatif.public_rate") private var publicRate: Double = 0.42

    // Efficiency + losses
    @AppStorage("whatif.wh_per_mile") private var whPerMile: Double = 310   // 310 Wh/mi default
    @AppStorage("whatif.loss_multiplier") private var lossMultiplier: Double = 1.08 // ~8% charging losses

    // UI state
    @State private var showAdvanced = false

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: T.spacing) {

                header

                // Summary tiles
                summaryGrid

                // Main controls
                controlsCard

                if showAdvanced {
                    advancedCard
                }

                notesCard
            }
            .padding(16)
        }
        .navigationTitle("What If?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.snappy) { showAdvanced.toggle() }
                } label: {
                    Label(showAdvanced ? "Less" : "More", systemImage: showAdvanced ? "chevron.up" : "slider.horizontal.3")
                }
            }
        }
        .background(T.screenBackground, ignoresSafeAreaEdges: .all)
    }

    // MARK: - Derived

    private var forecast: ForecastBreakdown {
        ForecastBreakdown(
            monthlyMiles: monthlyMiles,
            whPerMile: whPerMile,
            lossMultiplier: lossMultiplier,
            homeRatio: homeRatio,
            homeRate: homeRate,
            publicRate: publicRate
        )
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Monthly Charging Forecast")
                .font(.title2.weight(.semibold))
            Text("Adjust miles, home vs public split, and rates to estimate this month’s charging cost.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Summary

    private var summaryGrid: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
            MetricTile(
                title: "Total Cost",
                value: fmtCurrency(forecast.totalCost),
                systemImage: "dollarsign.circle.fill",
                accent: T.accent
            )

            MetricTile(
                title: "Total Energy",
                value: "\(fmtNumber(forecast.totalEnergyKWh, digits: 1)) kWh",
                systemImage: "bolt.fill",
                accent: T.accent
            )

            MetricTile(
                title: "Home Cost",
                value: fmtCurrency(forecast.homeCost),
                systemImage: "house.fill",
                accent: T.accent
            )

            MetricTile(
                title: "Public Cost",
                value: fmtCurrency(forecast.publicCost),
                systemImage: "mappin.circle.fill",
                accent: T.accent
            )

            MetricTile(
                title: "Cost / mile",
                value: fmtCurrency(forecast.costPerMile),
                systemImage: "road.lanes",
                accent: T.accent
            )

            MetricTile(
                title: "$ / kWh",
                value: fmtCurrency(forecast.avgCostPerKWh),
                systemImage: "chart.line.uptrend.xyaxis",
                accent: T.accent
            )
        }
    }

    // MARK: - Controls

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader(title: "Simulation Settings", systemImage: "wrench.and.screwdriver.fill")

            SliderRow(
                title: "Miles this month",
                valueText: "\(Int(monthlyMiles)) mi",
                value: $monthlyMiles,
                range: 200...6000,
                step: 50
            )

            SliderRow(
                title: "Home charging share",
                valueText: "\(Int(homeRatio * 100))%",
                value: $homeRatio,
                range: 0...1,
                step: 0.05
            ) {
                HStack(spacing: 8) {
                    quickPill("0%") { homeRatio = 0.0 }
                    quickPill("50%") { homeRatio = 0.5 }
                    quickPill("100%") { homeRatio = 1.0 }
                    Spacer()
                }
                .padding(.top, 2)
            }

            Divider().opacity(0.5)

            SliderRow(
                title: "Home rate",
                valueText: "\(fmtCurrency(homeRate))/kWh",
                value: $homeRate,
                range: 0.05...0.35,
                step: 0.005
            )

            SliderRow(
                title: "Public rate",
                valueText: "\(fmtCurrency(publicRate))/kWh",
                value: $publicRate,
                range: 0.10...0.90,
                step: 0.01
            )

            HStack(spacing: 10) {
                Button {
                    withAnimation(.snappy) { showAdvanced.toggle() }
                } label: {
                    Label(showAdvanced ? "Hide Advanced" : "Show Advanced", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(role: .destructive) {
                    resetDefaults()
                } label: {
                    Label("Reset", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 2)
        }
        .cardStyle(corner: T.corner)
    }

    private var advancedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader(title: "Advanced", systemImage: "gearshape.fill")

            SliderRow(
                title: "Efficiency",
                valueText: "\(Int(whPerMile)) Wh/mi",
                value: $whPerMile,
                range: 180...520,
                step: 5
            )

            SliderRow(
                title: "Charging losses",
                valueText: "\(Int((lossMultiplier - 1) * 100))%",
                value: $lossMultiplier,
                range: 1.00...1.20,
                step: 0.01
            ) {
                Text("Losses account for energy that doesn’t reach the battery (heat, conversion, etc.).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            Divider().opacity(0.5)

            VStack(alignment: .leading, spacing: 6) {
                Text("Energy Breakdown")
                    .font(.headline)

                LabeledContent("Home energy") {
                    Text("\(fmtNumber(forecast.homeEnergyKWh, digits: 1)) kWh")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Public energy") {
                    Text("\(fmtNumber(forecast.publicEnergyKWh, digits: 1)) kWh")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Total energy (incl. losses)") {
                    Text("\(fmtNumber(forecast.totalEnergyKWh, digits: 1)) kWh")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle(corner: T.corner)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader(title: "Notes", systemImage: "info.circle.fill")

            Text("This tool is a quick simulator. It does not import or assume any real trip route data.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("For best results, set Efficiency (Wh/mi) close to what your vehicle actually averages in your area and season.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardStyle(corner: T.corner)
    }

    // MARK: - UI Helpers

    private func cardHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(T.accent)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }

    private func quickPill(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
                .overlay { Capsule().strokeBorder(.quaternary) }
        }
        .buttonStyle(.plain)
    }

    private func resetDefaults() {
        monthlyMiles = 1000
        homeRatio = 0.70
        homeRate = 0.11
        publicRate = 0.42
        whPerMile = 310
        lossMultiplier = 1.08
    }

    // MARK: - Formatting

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 3 // lets home rates show nicely
        return f
    }()

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    private func fmtCurrency(_ v: Double) -> String {
        let f = Self.currencyFormatter
        f.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return f.string(from: NSNumber(value: v)) ?? String(format: "$%.2f", v)
    }

    private func fmtNumber(_ v: Double, digits: Int) -> String {
        let f = Self.numberFormatter
        f.maximumFractionDigits = digits
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
}

// MARK: - Breakdown

private struct ForecastBreakdown: Sendable {
    let monthlyMiles: Double
    let whPerMile: Double
    let lossMultiplier: Double
    let homeRatio: Double
    let homeRate: Double
    let publicRate: Double

    private var baseEnergyKWh: Double {
        // miles * (Wh/mi) -> Wh -> kWh
        max(0, monthlyMiles) * max(0, whPerMile) / 1000.0
    }

    var totalEnergyKWh: Double {
        baseEnergyKWh * max(1.0, lossMultiplier)
    }

    var homeEnergyKWh: Double {
        totalEnergyKWh * clamp01(homeRatio)
    }

    var publicEnergyKWh: Double {
        totalEnergyKWh * (1.0 - clamp01(homeRatio))
    }

    var homeCost: Double {
        homeEnergyKWh * max(0, homeRate)
    }

    var publicCost: Double {
        publicEnergyKWh * max(0, publicRate)
    }

    var totalCost: Double { homeCost + publicCost }

    var costPerMile: Double {
        guard monthlyMiles > 0 else { return 0 }
        return totalCost / monthlyMiles
    }

    var avgCostPerKWh: Double {
        guard totalEnergyKWh > 0 else { return 0 }
        return totalCost / totalEnergyKWh
    }

    private func clamp01(_ v: Double) -> Double { min(max(v, 0), 1) }
}

// MARK: - Components

private struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.quaternary) }
    }
}

private struct SliderRow<Footer: View>: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    @ViewBuilder var footer: Footer

    init(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.title = title
        self.valueText = valueText
        self._value = value
        self.range = range
        self.step = step
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(valueText).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }

            Slider(value: $value, in: range, step: step)

            footer
        }
    }
}

private extension View {
    func cardStyle(corner: CGFloat) -> some View {
        self
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: corner, style: .continuous).strokeBorder(.quaternary) }
    }
}
