//
//  EnergyConversion 2.swift
//  KWh Gas Companion
//
//  Created by Bryan on 8/11/25.
//


// EnergyConversion.swift
// KWh Gas Companion

import SwiftUI

struct EnergyConversion: View {
    // Persisted assumptions (editable in the UI)
    @AppStorage("ec_miPerKWh") private var miPerKWh: Double = 3.0
    @AppStorage("ec_gridKgPerKWh") private var gridKgPerKWh: Double = 0.40
    @AppStorage("ec_pricePerKWh") private var pricePerKWh: Double = 0.18

    // Inputs (kept minimal; no placeholders needed to compile)
    @State private var energyKWh_A: Double = 0       // for Energy → Distance
    @State private var miles_B: Double = 0           // for Distance → Energy
    @State private var energyKWh_C: Double = 0       // for Energy → CO₂
    @State private var energyKWh_D: Double = 0       // for Energy → Cost

    // Semantic colors for good Light/Dark contrast
    private let cardBG     = Color(uiColor: .secondarySystemBackground)
    private let borderCol  = Color(uiColor: .separator).opacity(0.25)

    // MARK: - Derived
    private var whPerMile: Double {
        miPerKWh > 0 ? 1000.0 / miPerKWh : 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                assumptions

                // Energy → Distance
                ECCard(title: "Energy → Distance", subtitle: "kWh to miles") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Energy")
                                .foregroundStyle(.secondary)
                            Spacer()
                            ECLabeledNumberField(value: $energyKWh_A, suffix: "kWh")
                        }
                        Divider().opacity(0.2)
                        HStack {
                            Text("Distance")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(numberShort(energyKWh_A * miPerKWh, 1) + " mi")
                                .font(.headline)
                        }
                    }
                }

                // Distance → Energy
                ECCard(title: "Distance → Energy", subtitle: "miles to kWh") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Distance")
                                .foregroundStyle(.secondary)
                            Spacer()
                            ECLabeledNumberField(value: $miles_B, suffix: "mi")
                        }
                        Divider().opacity(0.2)
                        HStack {
                            Text("Energy")
                                .foregroundStyle(.secondary)
                            Spacer()
                            let kwh = miPerKWh > 0 ? miles_B / miPerKWh : 0
                            Text(numberShort(kwh, 2) + " kWh")
                                .font(.headline)
                        }
                    }
                }

                // Energy → CO₂
                ECCard(title: "Energy → CO₂", subtitle: "kWh to kg CO₂") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Energy")
                                .foregroundStyle(.secondary)
                            Spacer()
                            ECLabeledNumberField(value: $energyKWh_C, suffix: "kWh")
                        }
                        Divider().opacity(0.2)
                        HStack {
                            Text("CO₂ Emissions")
                                .foregroundStyle(.secondary)
                            Spacer()
                            let kg = energyKWh_C * gridKgPerKWh
                            Text(numberShort(kg, kg < 1 ? 3 : 2) + " kg")
                                .font(.headline)
                        }
                    }
                }

                // Energy → Cost
                ECCard(title: "Energy → Cost", subtitle: "kWh to currency") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Energy")
                                .foregroundStyle(.secondary)
                            Spacer()
                            ECLabeledNumberField(value: $energyKWh_D, suffix: "kWh")
                        }
                        Divider().opacity(0.2)
                        HStack {
                            Text("Cost")
                                .foregroundStyle(.secondary)
                            Spacer()
                            let cost = energyKWh_D * pricePerKWh
                            Text(currencyShort(cost))
                                .font(.headline)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Energy Conversion")
        .toolbarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Energy • Distance • CO₂")
                .font(.title.bold())
            Text("Quick conversions with adjustable assumptions")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var assumptions: some View {
        ECCard(title: "Assumptions", subtitle: "Applies to all conversions") {
            VStack(alignment: .leading, spacing: 12) {
                // Efficiency
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Efficiency")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(numberShort(miPerKWh, 2) + " mi/kWh")
                            .font(.headline)
                    }
                    HStack {
                        Stepper(value: $miPerKWh, in: 0.5...8, step: 0.1) {
                            Text("Adjust")
                        }
                        Spacer()
                        Text(numberShort(whPerMile, 0) + " Wh/mi")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().opacity(0.2)

                // Grid emissions
                HStack {
                    Text("Grid CO₂ intensity")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper(value: $gridKgPerKWh, in: 0...1, step: 0.01) {
                        Text(numberShort(gridKgPerKWh, gridKgPerKWh < 1 ? 3 : 2) + " kg/kWh")
                    }
                    .labelsHidden()
                }

                // Energy price
                HStack {
                    Text("Electricity price")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper(value: $pricePerKWh, in: 0...1, step: 0.005) {
                        Text(currencyShort(pricePerKWh) + "/kWh")
                    }
                    .labelsHidden()
                }
            }
        }
    }

    // MARK: - Formatting

    private func currencyShort(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = Locale.current.currency?.identifier ?? "USD"
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

// MARK: - Local UI helpers (namespaced to avoid collisions)

fileprivate struct ECCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content
    private let cardBG = Color(uiColor: .secondarySystemBackground)
    private let borderCol = Color(uiColor: .separator).opacity(0.25)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(cardBG))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(borderCol, lineWidth: 1))
    }
}

fileprivate struct ECLabeledNumberField: View {
    @Binding var value: Double
    let suffix: String

    var body: some View {
        HStack(spacing: 6) {
            TextField("0", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 80)
            Text(suffix).foregroundStyle(.secondary)
        }
        .font(.headline)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        EnergyConversion()
    }
}
#endif
