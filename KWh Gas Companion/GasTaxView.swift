//  GasTaxView.swift
//  MyKwH Companion — Regenerated Dec 18, 2025
//
//  Gasoline/Diesel excise & sales-tax calculator with:
//  • Typed inputs (Double-bound TextFields with keyboard toolbar)
//  • Fuel type toggle (auto federal rate)
//  • Searchable state presets (sheet), @AppStorage persistence
//  • Optional sales tax (% of pre-tax fuel price)
//  • Per-mile analytics (fuel-only, tax/mi, all-in)
//  • EV comparison (optional input) + mini breakdown chart
//  • Reset button + 🪙 easter egg coin (hingedpic/unhingedpic)
//

import SwiftUI
import UIKit
#if canImport(Charts)
import Charts
#endif

// MARK: - Engine (testable math)

struct GasTaxEngine {
    struct Inputs: Equatable {
        var gallons: Double
        var pricePerGallon: Double        // $/gal (pre-tax fuel price)
        var stateRate: Double             // $/gal
        var federalCents: Double          // ¢/gal
        var localCents: Double            // ¢/gal
        var salesTaxPct: Double           // % of pre-tax fuel price
        var salesTaxEnabled: Bool
        var mpg: Double
    }

    struct Outputs: Equatable {
        var fuelCost: Double
        var stateTax: Double
        var federalTax: Double
        var localTax: Double
        var salesTax: Double
        var totalTax: Double
        var totalCost: Double
        var effectivePricePerGallon: Double
        var fuelOnlyPerMile: Double
        var taxPerMile: Double
        var allInPerMile: Double
        var taxShareOfPumpPct: Double   // 0–100
    }

    static func compute(_ i: Inputs) -> Outputs {
        let gallons = max(i.gallons, 0)
        let price = max(i.pricePerGallon, 0)
        let statePerGal = max(i.stateRate, 0)
        let federalPerGal = max(i.federalCents, 0) / 100.0
        let localPerGal = max(i.localCents, 0) / 100.0
        let salesPct = max(i.salesTaxPct, 0)

        let fuelCost  = gallons * price
        let stateTax  = gallons * statePerGal
        let federalTax = gallons * federalPerGal
        let localTax   = gallons * localPerGal
        let salesPerGal = i.salesTaxEnabled ? price * (salesPct / 100.0) : 0
        let salesTax   = gallons * salesPerGal

        let totalTax  = stateTax + federalTax + localTax + salesTax
        let totalCost = fuelCost + totalTax

        let effectivePricePerGallon = price + statePerGal + federalPerGal + localPerGal + salesPerGal

        let miles = max(gallons * max(i.mpg, 0), 0.000001)
        let fuelOnlyPerMile = price / max(i.mpg, 0.000001)
        let taxPerMile      = totalTax / miles
        let allInPerMile    = effectivePricePerGallon / max(i.mpg, 0.000001)

        let taxShareOfPumpPct = (effectivePricePerGallon <= 0)
        ? 0
        : ((statePerGal + federalPerGal + localPerGal + salesPerGal) / effectivePricePerGallon) * 100

        return Outputs(
            fuelCost: fuelCost,
            stateTax: stateTax,
            federalTax: federalTax,
            localTax: localTax,
            salesTax: salesTax,
            totalTax: totalTax,
            totalCost: totalCost,
            effectivePricePerGallon: effectivePricePerGallon,
            fuelOnlyPerMile: fuelOnlyPerMile,
            taxPerMile: taxPerMile,
            allInPerMile: allInPerMile,
            taxShareOfPumpPct: taxShareOfPumpPct
        )
    }
}

// MARK: - State preset model & loader

struct GasStatePreset: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    var rate: Double                 // $ per gallon
    var description: String?

    enum CodingKeys: String, CodingKey { case name, rate, description }
}

enum FuelKind: String, CaseIterable, Identifiable, Codable {
    case gasoline, diesel
    var id: Self { self }
    var title: String { rawValue.capitalized }
    var defaultFederalCents: Double { self == .gasoline ? 18.4 : 24.4 }
}

struct GasTaxPresetLoader {
    static func loadFromBundle() -> [GasStatePreset]? {
        guard let url = Bundle.main.url(forResource: "gas_tax_presets", withExtension: "json") else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let items = try JSONDecoder().decode([GasStatePreset].self, from: data)
            return items
        } catch { return nil }
    }
}

// MARK: - View

@MainActor
struct GasTaxView: View {
    // Persistence
    @AppStorage("gasTax.lastStateName") private var lastStateName: String = ""
    @AppStorage("gasTax.lastKind") private var lastKindRaw: String = FuelKind.gasoline.rawValue
    @AppStorage("gasTax.salesEnabled") private var salesTaxEnabled: Bool = false
    @AppStorage("gasTax.salesPct") private var salesTaxPct: Double = 0.0
    @AppStorage("gasTax.mpg") private var persistedMPG: Double = 30
    @AppStorage("gasTax.evCostPerMile") private var persistedEvCostPerMile: Double = 0.0

    // Use Settings currency if you have it
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String =
        (Locale.current.currency?.identifier ?? "USD")

    // Presets
    private var defaultPresets: [GasStatePreset] = [
        .init(name: "Alabama (AL)", rate: 0.30, description: "AL: $0.30/gal"),
        .init(name: "Alaska (AK)", rate: 0.0895, description: "AK: $0.0895/gal"),
        .init(name: "Arizona (AZ)", rate: 0.18, description: "AZ: $0.18/gal"),
        .init(name: "Arkansas (AR)", rate: 0.247, description: "AR: $0.247/gal"),
        .init(name: "California (CA)", rate: 0.612, description: "CA: $0.612/gal (effective July 2025–June 2026)"),
        .init(name: "Colorado (CO)", rate: 0.22, description: "CO: $0.22/gal"),
        .init(name: "Connecticut (CT)", rate: 0.25, description: "CT: $0.25/gal"),
        .init(name: "Delaware (DE)", rate: 0.23, description: "DE: $0.23/gal"),
        .init(name: "District of Columbia (DC)", rate: 0.235, description: "DC: $0.235/gal"),
        .init(name: "Florida (FL)", rate: 0.37325, description: "FL: $0.37325/gal"),
        .init(name: "Georgia (GA)", rate: 0.331, description: "GA: $0.331/gal"),
        .init(name: "Hawaii (HI)", rate: 0.16, description: "HI: $0.16/gal (state; county add-ons not included)"),
        .init(name: "Idaho (ID)", rate: 0.32, description: "ID: $0.32/gal"),
        .init(name: "Illinois (IL)", rate: 0.483, description: "IL: $0.483/gal"),
        .init(name: "Indiana (IN)", rate: 0.36, description: "IN: $0.36/gal"),
        .init(name: "Iowa (IA)", rate: 0.30, description: "IA: Between $0.265–$0.30/gal (varies by blend); using $0.30"),
        .init(name: "Kansas (KS)", rate: 0.240, description: "KS: $0.240/gal"),
        .init(name: "Kentucky (KY)", rate: 0.25, description: "KY: $0.25/gal"),
        .init(name: "Louisiana (LA)", rate: 0.20, description: "LA: $0.20/gal"),
        .init(name: "Maine (ME)", rate: 0.30, description: "ME: $0.30/gal"),
        .init(name: "Maryland (MD)", rate: 0.46, description: "MD: $0.46/gal"),
        .init(name: "Massachusetts (MA)", rate: 0.24, description: "MA: $0.24/gal"),
        .init(name: "Michigan (MI)", rate: 0.31, description: "MI: $0.31/gal"),
        .init(name: "Minnesota (MN)", rate: 0.318, description: "MN: $0.318/gal"),
        .init(name: "Mississippi (MS)", rate: 0.21, description: "MS: $0.21/gal"),
        .init(name: "Missouri (MO)", rate: 0.295, description: "MO: $0.295/gal"),
        .init(name: "Montana (MT)", rate: 0.33, description: "MT: $0.33/gal"),
        .init(name: "Nebraska (NE)", rate: 0.318, description: "NE: $0.318/gal"),
        .init(name: "Nevada (NV)", rate: 0.23, description: "NV: $0.23/gal"),
        .init(name: "New Hampshire (NH)", rate: 0.222, description: "NH: $0.222/gal"),
        .init(name: "New Jersey (NJ)", rate: 0.449, description: "NJ: $0.449/gal"),
        .init(name: "New Mexico (NM)", rate: 0.17, description: "NM: $0.17/gal"),
        .init(name: "New York (NY)", rate: 0.2455, description: "NY: $0.2455/gal"),
        .init(name: "North Carolina (NC)", rate: 0.403, description: "NC: $0.403/gal"),
        .init(name: "North Dakota (ND)", rate: 0.230, description: "ND: $0.230/gal"),
        .init(name: "Ohio (OH)", rate: 0.385, description: "OH: $0.385/gal"),
        .init(name: "Oklahoma (OK)", rate: 0.19, description: "OK: $0.19/gal"),
        .init(name: "Oregon (OR)", rate: 0.38, description: "OR: $0.38/gal"),
        .init(name: "Pennsylvania (PA)", rate: 0.576, description: "PA: $0.576/gal"),
        .init(name: "Rhode Island (RI)", rate: 0.40, description: "RI: $0.40/gal"),
        .init(name: "South Carolina (SC)", rate: 0.28, description: "SC: $0.28/gal"),
        .init(name: "South Dakota (SD)", rate: 0.28, description: "SD: $0.28/gal"),
        .init(name: "Tennessee (TN)", rate: 0.26, description: "TN: $0.26/gal"),
        .init(name: "Texas (TX)", rate: 0.20, description: "TX: $0.20/gal"),
        .init(name: "Utah (UT)", rate: 0.385, description: "UT: $0.385/gal"),
        .init(name: "Vermont (VT)", rate: 0.3139, description: "VT: $0.3139/gal"),
        .init(name: "Virginia (VA)", rate: 0.317, description: "VA: $0.317/gal"),
        .init(name: "Washington (WA)", rate: 0.554, description: "WA: $0.554/gal"),
        .init(name: "West Virginia (WV)", rate: 0.357, description: "WV: $0.357/gal"),
        .init(name: "Wisconsin (WI)", rate: 0.309, description: "WI: $0.309/gal"),
        .init(name: "Wyoming (WY)", rate: 0.24, description: "WY: $0.24/gal")
    ]
    @State private var presets: [GasStatePreset] = []

    // Inputs
    @State private var gallons: Double = 10
    @State private var pricePerGallon: Double = 3.50
    @State private var stateRate: Double = 0.00
    @State private var federalCents: Double = 18.4
    @State private var localCents: Double = 5.0
    @State private var mpg: Double = 30
    @State private var kind: FuelKind = .gasoline

    // EV comparison
    @State private var evCostPerMileText: String = ""

    // Preset selection sheet
    @State private var showingPresetSheet = false
    @State private var presetQuery = ""
    @State private var selectedPreset: GasStatePreset? = nil

    // Focus
    @FocusState private var focusedField: Field?
    enum Field { case gallons, price, state, federal, local, mpg, ev }

    init() {
        let fromBundle = GasTaxPresetLoader.loadFromBundle()
        _presets = State(initialValue: fromBundle ?? defaultPresets)
    }

    private var engineInputs: GasTaxEngine.Inputs {
        .init(
            gallons: gallons,
            pricePerGallon: pricePerGallon,
            stateRate: stateRate,
            federalCents: federalCents,
            localCents: localCents,
            salesTaxPct: salesTaxPct,
            salesTaxEnabled: salesTaxEnabled,
            mpg: mpg
        )
    }
    private var out: GasTaxEngine.Outputs { GasTaxEngine.compute(engineInputs) }
    private var currencyCode: String { defaultCurrencyCode }

    private var evCostPerMile: Double {
        let raw = evCostPerMileText.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return persistedEvCostPerMile }
        let normalized = raw
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
        return Double(normalized) ?? persistedEvCostPerMile
    }

    var body: some View {
        Form {
            Section("About") {
                Text("Excise taxes are per-gallon charges. This tool estimates total taxes and effective price including excise and optional sales tax.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Fuel Details") {
                HStack {
                    Text("Gallons")
                    Spacer(minLength: 12)
                    TextField("Gallons", value: $gallons, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .gallons)
                        .monospacedDigit()
                }

                Stepper(value: $gallons, in: 0...500, step: 1) {
                    Text("\(gallons, format: .number.precision(.fractionLength(0))) gal")
                }

                HStack {
                    Text("Price/gal")
                    Spacer(minLength: 12)
                    TextField("Price", value: $pricePerGallon, format: .currency(code: currencyCode))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .price)
                        .monospacedDigit()
                }

                Picker("Fuel", selection: $kind) {
                    ForEach(FuelKind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: kind, initial: false) { _, newKind in
                    federalCents = newKind.defaultFederalCents
                    lastKindRaw = newKind.rawValue
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }

            Section("State Tax ($/gal)") {
                Button {
                    presetQuery = ""
                    showingPresetSheet = true
                } label: {
                    HStack {
                        Label("Choose State", systemImage: "list.bullet")
                        Spacer()
                        if let selectedPreset {
                            Text(selectedPreset.name).foregroundStyle(.secondary)
                        } else if !lastStateName.isEmpty {
                            Text(lastStateName).foregroundStyle(.secondary)
                        } else {
                            Text("Custom").foregroundStyle(.secondary)
                        }
                    }
                }

                if let p = selectedPreset, let desc = p.description {
                    Text(desc).font(.caption).foregroundStyle(.secondary)
                }

                HStack {
                    Text("State rate")
                    Spacer()
                    Text("\(stateRate, format: .number.precision(.fractionLength(3))) $/gal")
                        .monospacedDigit()
                }

                Slider(value: $stateRate, in: 0...1, step: 0.005)
                    .onChange(of: stateRate, initial: false) { _, newVal in
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.25)
                        if let p = selectedPreset, abs(newVal - p.rate) > 0.001 {
                            selectedPreset = nil
                            lastStateName = ""
                        }
                    }
            }

            Section("Federal & Local (¢/gal)") {
                HStack { Text("Federal"); Spacer(); Text("\(federalCents, format: .number.precision(.fractionLength(1)))¢").monospacedDigit() }
                Slider(value: $federalCents, in: 0...50, step: 0.1)
                    .onChange(of: federalCents, initial: false) { _, new in
                        let marks: [Double] = [18.4, 24.4]
                        if marks.contains(where: { abs($0 - new) < 0.05 }) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }

                HStack { Text("Local"); Spacer(); Text("\(localCents, format: .number.precision(.fractionLength(1)))¢").monospacedDigit() }
                Slider(value: $localCents, in: 0...30, step: 0.1)
            }

            Section("Sales Tax") {
                Toggle("Apply sales tax (% of pre-tax fuel price)", isOn: $salesTaxEnabled)

                HStack {
                    Text("Rate")
                    Spacer()
                    Text("\(salesTaxPct, format: .number.precision(.fractionLength(1)))%")
                        .foregroundStyle(salesTaxEnabled ? .primary : .secondary)
                        .monospacedDigit()
                }
                .accessibilityHidden(!salesTaxEnabled)

                Slider(value: $salesTaxPct, in: 0...12, step: 0.1)
                    .disabled(!salesTaxEnabled)

                Text("Many states exempt gasoline from general sales tax; others levy it. Check your jurisdiction.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Efficiency & Comparison") {
                HStack {
                    Text("MPG")
                    Spacer()
                    TextField("MPG", value: $mpg, format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .mpg)
                        .monospacedDigit()
                }

                Stepper(value: $mpg, in: 5...80, step: 1) {
                    Text("\(mpg, format: .number.precision(.fractionLength(0))) mpg")
                }
                .onChange(of: mpg, initial: false) { _, new in
                    persistedMPG = new
                }

                HStack {
                    Text("EV $/mi (optional)")
                    Spacer()
                    TextField("e.g. 0.06", text: $evCostPerMileText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .ev)
                        .monospacedDigit()
                }
                .onChange(of: evCostPerMileText, initial: false) { _, _ in
                    persistedEvCostPerMile = max(0, evCostPerMile)
                }

                if let (delta, miles) = comparisonDelta() {
                    if delta > 0 {
                        Text("Gas is \(delta, format: .currency(code: currencyCode))/mo more than EV at \(Int(miles)) mi.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else if delta < 0 {
                        Text("Gas is \(-delta, format: .currency(code: currencyCode))/mo less than EV at \(Int(miles)) mi.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Text("Gas and EV are about the same at \(Int(miles)) mi/mo.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Results") {
                MoneyRow("Fuel Cost", out.fuelCost, currencyCode)
                MoneyRow("State Tax", out.stateTax, currencyCode)
                MoneyRow("Federal Tax", out.federalTax, currencyCode)
                MoneyRow("Local Tax", out.localTax, currencyCode)
                if salesTaxEnabled { MoneyRow("Sales Tax", out.salesTax, currencyCode) }
                Divider()
                MoneyRow("Total Tax", out.totalTax, currencyCode, bold: true)
                MoneyRow("Total Cost", out.totalCost, currencyCode, bold: true)

                LabeledContent("Effective Price/gal") {
                    Text(out.effectivePricePerGallon, format: .currency(code: currencyCode)).monospacedDigit()
                }
                LabeledContent("Tax share of pump") {
                    Text(out.taxShareOfPumpPct / 100, format: .percent.precision(.fractionLength(1))).monospacedDigit()
                }
            }

            Section("Per-Mile") {
                LabeledContent("Fuel only $/mi") { Text(out.fuelOnlyPerMile, format: .currency(code: currencyCode)).monospacedDigit() }
                LabeledContent("Tax $/mi") { Text(out.taxPerMile, format: .currency(code: currencyCode)).monospacedDigit() }
                LabeledContent("All-in $/mi") { Text(out.allInPerMile, format: .currency(code: currencyCode)).monospacedDigit().bold() }
            }

            #if canImport(Charts)
            Section("Breakdown") {
                Chart {
                    BarMark(x: .value("Part", "Fuel"),    y: .value("Amount", out.fuelCost))
                    BarMark(x: .value("Part", "State"),   y: .value("Amount", out.stateTax))
                    BarMark(x: .value("Part", "Federal"), y: .value("Amount", out.federalTax))
                    BarMark(x: .value("Part", "Local"),   y: .value("Amount", out.localTax))
                    if salesTaxEnabled {
                        BarMark(x: .value("Part", "Sales"), y: .value("Amount", out.salesTax))
                    }
                }
                .frame(height: 160)
                .accessibilityLabel("Cost breakdown chart")
            }
            #endif

            Section {
                Text("Estimates only; consult official sources for current rates in your area.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Gas Tax Calculator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Reset") { resetDefaults() }
                    .accessibilityLabel("Reset inputs to defaults")

                // 🪙 Easter egg coin
                EasterEggCoinButton(
                    hingedAssetName: "hingedpic",
                    unhingedAssetName: "unhingedpic",
                    size: 30
                )
                .accessibilityLabel("Easter egg coin")
            }
        }
        .onAppear {
            if let k = FuelKind(rawValue: lastKindRaw) {
                kind = k
                federalCents = k.defaultFederalCents
            }
            mpg = persistedMPG

            if !lastStateName.isEmpty, let found = presets.first(where: { $0.name == lastStateName }) {
                applyPreset(found)
            }

            if evCostPerMileText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, persistedEvCostPerMile > 0 {
                evCostPerMileText = String(format: "%.3f", persistedEvCostPerMile)
            }
        }
        .onChange(of: selectedPreset, initial: false) { _, new in
            if let p = new { applyPreset(p) }
        }
        .sheet(isPresented: $showingPresetSheet) {
            NavigationStack {
                List(filteredPresetsSorted(), id: \.id) { p in
                    Button {
                        selectedPreset = p
                        showingPresetSheet = false
                    } label: {
                        HStack {
                            Text(p.name)
                            Spacer()
                            Text("$\(p.rate, format: .number.precision(.fractionLength(3)))/gal")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
                .searchable(text: $presetQuery, placement: .navigationBarDrawer(displayMode: .always))
                .navigationTitle("State Presets")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showingPresetSheet = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Helpers

    private func filteredPresetsSorted() -> [GasStatePreset] {
        let q = presetQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = q.isEmpty ? presets : presets.filter { $0.name.lowercased().contains(q) }
        return base.sorted { $0.name < $1.name }
    }

    private func applyPreset(_ p: GasStatePreset) {
        selectedPreset = p
        stateRate = p.rate
        lastStateName = p.name
    }

    private func resetDefaults() {
        gallons = 10
        pricePerGallon = 3.50
        stateRate = 0.00
        kind = .gasoline
        federalCents = kind.defaultFederalCents
        localCents = 5.0
        salesTaxEnabled = false
        salesTaxPct = 0.0
        mpg = 30
        evCostPerMileText = ""
        selectedPreset = nil
        lastStateName = ""
        presetQuery = ""
        persistedEvCostPerMile = 0.0
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Returns (delta per month, miles used) if EV comparison is provided.
    private func comparisonDelta(monthlyMiles: Double = 1000) -> (Double, Double)? {
        let ev = max(0, evCostPerMile)
        guard ev > 0 else { return nil }
        let deltaPerMile = out.allInPerMile - ev
        return (deltaPerMile * monthlyMiles, monthlyMiles)
    }
}

// MARK: - Row components

private struct MoneyRow: View {
    var title: String
    var amount: Double
    var currencyCode: String
    var bold: Bool = false

    init(_ title: String, _ amount: Double, _ currencyCode: String, bold: Bool = false) {
        self.title = title; self.amount = amount; self.currencyCode = currencyCode; self.bold = bold
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            let text = Text(amount, format: .currency(code: currencyCode)).monospacedDigit()
            if bold { text.bold() } else { text }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(amount, format: .currency(code: currencyCode))")
    }
}

// MARK: - Preview

#Preview { NavigationStack { GasTaxView() } }
