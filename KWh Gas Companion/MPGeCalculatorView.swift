// MPGeCalculatorView.swift
// KWh Gas Companion

import SwiftUI

struct MPGeCalculatorView: View {
    // Persisted assumptions (editable)
    @AppStorage("mpge_kWhPerGallon") private var kWhPerGallon: Double = 33.7   // EPA gallon equivalent
    @AppStorage("mpge_miPerKWh")     private var miPerKWh: Double = 3.2        // vehicle efficiency
    @AppStorage("mpge_pricePerKWh")  private var pricePerKWh: Double = 0.18    // $/kWh
    @AppStorage("mpge_iceMPG")       private var iceMPG: Double = 28.0         // comparison car MPG
    @AppStorage("mpge_gasPrice")     private var fuelPricePerGallon: Double = 3.80

    // Derived
    private var mpge: Double { miPerKWh * kWhPerGallon } // mi/kWh * kWh/gal = mi/gal(e)
    private var evCostPer100: Double {
        guard miPerKWh > 0 else { return 0 }
        let kWhPer100 = 100.0 / miPerKWh
        return kWhPer100 * pricePerKWh
    }
    private var iceCostPer100: Double {
        guard iceMPG > 0 else { return 0 }
        return (100.0 / iceMPG) * fuelPricePerGallon
    }
    private var savingsPer100: Double {
        max(0, iceCostPer100 - evCostPer100)
    }

    // Styling
    private let cardBG     = Color(uiColor: .secondarySystemBackground)
    private let cardBorder = Color(uiColor: .separator).opacity(0.25)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                metrics
                comparison
                assumptions
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("MPGe Calculator")
        .toolbarTitleDisplayMode(.inline)
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Miles-per-Gallon Equivalent")
                .font(.title.bold())
            Text("MPGe uses 33.7 kWh as one gallon of gasoline equivalent.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metrics: some View {
        HStack(spacing: 12) {
            MPGEMetricPill(title: "MPGe", value: numberShort(mpge, mpge < 100 ? 1 : 0), icon: "gauge")
            MPGEMetricPill(title: "EV $/100mi", value: currencyShort(evCostPer100), icon: "bolt.fill")
            MPGEMetricPill(title: "ICE $/100mi", value: currencyShort(iceCostPer100), icon: "fuelpump.fill")
        }
    }

    private var comparison: some View {
        MPGECard(title: "Cost per 100 miles", subtitle: "EV vs ICE") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("EV").font(.caption).foregroundStyle(.secondary)
                    Text(currencyShort(evCostPer100)).font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ICE").font(.caption).foregroundStyle(.secondary)
                    Text(currencyShort(iceCostPer100)).font(.headline)
                }
            }
            Divider().opacity(0.2)
            HStack {
                Text("Savings / 100 mi").foregroundStyle(.secondary)
                Spacer()
                Text(currencyShort(savingsPer100)).font(.headline)
            }
        }
    }

    private var assumptions: some View {
        MPGECard(title: "Assumptions", subtitle: "Adjust to match your vehicle & rates") {
            VStack(alignment: .leading, spacing: 10) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text("Efficiency (mi/kWh)").foregroundStyle(.secondary)
                        Stepper(value: $miPerKWh, in: 1.0...8.0, step: 0.1) {
                            Text(numberShort(miPerKWh, 1))
                        }
                    }
                    GridRow {
                        Text("kWh per gallon (e)").foregroundStyle(.secondary)
                        Stepper(value: $kWhPerGallon, in: 20...40, step: 0.1) {
                            Text(numberShort(kWhPerGallon, 1) + " kWh")
                        }
                    }
                    GridRow {
                        Text("Electricity price").foregroundStyle(.secondary)
                        Stepper(value: $pricePerKWh, in: 0...1, step: 0.005) {
                            Text(currencyShort(pricePerKWh) + "/kWh")
                        }
                    }
                    GridRow {
                        Text("ICE MPG").foregroundStyle(.secondary)
                        Stepper(value: $iceMPG, in: 5...100, step: 1) {
                            Text(numberShort(iceMPG, 0))
                        }
                    }
                    GridRow {
                        Text("Gas price").foregroundStyle(.secondary)
                        Stepper(value: $fuelPricePerGallon, in: 0...12, step: 0.05) {
                            Text(currencyShort(fuelPricePerGallon) + "/gal")
                        }
                    }
                }
                .font(.footnote)
            }
        }
    }

    // MARK: Formatting

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

fileprivate struct MPGECard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content
    private let cardBG = Color(uiColor: .secondarySystemBackground)
    private let borderCol = Color(uiColor: .separator).opacity(0.25)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.secondary) }
            }
            content
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(cardBG))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(borderCol, lineWidth: 1))
    }
}

fileprivate struct MPGEMetricPill: View {
    let title: String, value: String, icon: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(uiColor: .secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(uiColor: .separator).opacity(0.25), lineWidth: 1))
    }
}

#if DEBUG
#Preview {
    NavigationStack { MPGeCalculatorView() }
}
#endif
