//
//  GasToKWhConverterView.swift
//  My KWh Companion / KWh Gas Companion
//
//  Stand-alone converter: price per gallon → equivalent price per kWh,
//  plus comparison to your logged EV $/kWh (optional).
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import Foundation

@MainActor
struct GasToKWhConverterView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.appThemeBox) private var themeBox

    // MARK: - Optional hooks
    // 1) Preferred: provide a direct EV $/kWh provider (fast, no heuristics).
    private let evKWhCostProvider: (() -> Double?)?
    // 2) Fallback: provide raw expenses and we estimate $/kWh (heuristic).
    private let expensesProvider: (() -> [ExpenseEntry])?

    // MARK: - Persistence
    @AppStorage("gasToKwh.lastGasPrice") private var persistedGasPrice: Double = 0
    @AppStorage("gasToKwh.lastMPG") private var persistedMPG: Double = 30

    // MARK: - Inputs (strings for safe typed entry)
    @State private var gasPriceInput: String = ""
    @State private var mpgInput: String = "30"

    @FocusState private var focused: Field?
    private enum Field { case gasPrice, mpg }

    // Physical constant: energy in 1 gallon of gasoline (GGE)
    private let kWhPerGallon: Double = 33.7

    // MARK: - Init
    init(
        expensesProvider: (() -> [ExpenseEntry])? = nil,
        evKWhCostProvider: (() -> Double?)? = nil
    ) {
        self.expensesProvider = expensesProvider
        self.evKWhCostProvider = evKWhCostProvider
    }

    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    // MARK: - Derived (gas)
    private var gasPricePerGallon: Double? { parse(gasPriceInput) }
    private var mpg: Double? { parse(mpgInput) }

    private var gasPricePerKWh: Double? {
        guard let price = gasPricePerGallon else { return nil }
        return price / kWhPerGallon
    }

    private var gasCostPerMile: Double? {
        guard let price = gasPricePerGallon, let mpg, mpg > 0 else { return nil }
        return price / mpg
    }

    private var gasCostPer100Miles: Double? {
        guard let perMile = gasCostPerMile else { return nil }
        return perMile * 100
    }

    // MARK: - Derived (EV)
    private var evKWhCost: Double? {
        if let direct = evKWhCostProvider?() { return direct }
        guard let provider = expensesProvider else { return nil }
        return Self.estimateKWhCost(from: provider())
    }

    // MARK: - View
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                inputCard

                if gasPricePerGallon != nil {
                    resultsCard
                } else {
                    placeholderCard
                }

                explanationCard
            }
            .padding(16)
        }
        .navigationTitle("Gas → kWh")
        .navigationBarTitleDisplayMode(.inline)
        .background(themedBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = nil }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") { reset() }
            }
        }
        .onAppear {
            // Seed inputs from persistence if user hasn't typed yet
            if gasPriceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, persistedGasPrice > 0 {
                gasPriceInput = Self.formatNumber(persistedGasPrice, maxFrac: 3)
            }
            if mpgInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, persistedMPG > 0 {
                mpgInput = Self.formatNumber(persistedMPG, maxFrac: 1)
            }
        }
        .onChange(of: gasPriceInput) { _, new in
            if let v = parse(new), v > 0 { persistedGasPrice = v }
        }
        .onChange(of: mpgInput) { _, new in
            if let v = parse(new), v > 0 { persistedMPG = v }
        }
    }

    // MARK: - Background (theme-driven)
    private var themedBackground: some View {
        let t = themeBox.base
        return Rectangle()
            .fill(t.screenBackground)
            .overlay {
                RadialGradient(
                    colors: [
                        t.accent.opacity(scheme == .dark ? 0.18 : 0.10),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 520
                )
                .blur(radius: scheme == .dark ? 28 : 22)
            }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Price of Gas → kWh")
                .font(.title2.weight(.semibold))

            Text("Convert a gasoline price per gallon into an energy-equivalent $/kWh, then compare it to your EV’s average charging cost if available.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inputs").font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Gas price per gallon").font(.caption).foregroundStyle(.secondary)
                TextField("e.g. 3.75", text: $gasPriceInput)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused, equals: .gasPrice)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Gas car efficiency (MPG)").font(.caption).foregroundStyle(.secondary)
                TextField("e.g. 30", text: $mpgInput)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused, equals: .mpg)

                Text("Used to estimate cost per mile and per 100 miles.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .themedCard()
    }

    @ViewBuilder
    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results").font(.headline)

            if let pricePerKWh = gasPricePerKWh {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Equivalent gasoline price per kWh").font(.caption).foregroundStyle(.secondary)
                    Text("\(pricePerKWh.formatted(.currency(code: currencyCode)))/kWh")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Text("Assumes 1 gallon ≈ \(kWhPerGallon, specifier: "%.1f") kWh (energy equivalence).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let perMile = gasCostPerMile {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gas cost per mile").font(.caption).foregroundStyle(.secondary)
                    Text("\(perMile.formatted(.currency(code: currencyCode)))/mi")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }

            if let per100 = gasCostPer100Miles {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gas cost per 100 miles").font(.caption).foregroundStyle(.secondary)
                    Text("\(per100.formatted(.currency(code: currencyCode))) / 100 mi")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }

            if let gasKWh = gasPricePerKWh {
                Divider().padding(.vertical, 4)

                if let evKWh = evKWhCost {
                    comparisonSection(gasPricePerKWh: gasKWh, evKWhCost: evKWh)
                } else if expensesProvider != nil || evKWhCostProvider != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EV cost comparison").font(.caption).foregroundStyle(.secondary)
                        Text("No usable EV $/kWh available yet. Once you have charging entries with both energy and cost, we’ll compute an average here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .themedCard()
    }

    private var placeholderCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter a gas price to see results").font(.headline)
            Text("Example: type 3.75 to represent $3.75 per gallon.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .themedCard()
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What this is doing").font(.headline)

            Text("1) Treat gasoline as an energy bucket: 1 gallon ≈ 33.7 kWh (energy-equivalent).")
            Text("2) Divide $/gal by 33.7 to estimate $/kWh of gasoline energy.")
            Text("3) With MPG, estimate gas $/mile and $/100 miles.")
            Text("4) If EV data is available, compare gasoline $/kWh to your EV’s average charging $/kWh.")

            Text("This is an energy-price comparison. It does not model engine efficiency, EV charging losses, or time-based pricing.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .font(.subheadline)
        .padding(14)
        .themedCard()
    }

    // MARK: - Comparison
    private func comparisonSection(gasPricePerKWh: Double, evKWhCost: Double) -> some View {
        let diff = gasPricePerKWh - evKWhCost
        let absDiff = abs(diff)
        let pct: Double? = evKWhCost > 0 ? (diff / evKWhCost) * 100.0 : nil

        let relation: String = diff < 0 ? "cheaper" : (diff > 0 ? "more expensive" : "the same")

        return VStack(alignment: .leading, spacing: 6) {
            Text("EV cost comparison").font(.caption).foregroundStyle(.secondary)

            Text("Your EV average: \(evKWhCost.formatted(.currency(code: currencyCode)))/kWh.")
                .font(.footnote)

            if diff == 0 {
                Text("At this gas price, gasoline energy is effectively the same $/kWh as your EV charging average.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                if let pct {
                    Text("Gasoline energy is \(absDiff.formatted(.currency(code: currencyCode)))/kWh \(relation) (\(abs(pct), specifier: "%.0f")% \(relation)).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Gasoline energy is \(absDiff.formatted(.currency(code: currencyCode)))/kWh \(relation).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Text("If you pass expenses instead of a direct EV $/kWh provider, we estimate EV $/kWh as total cost ÷ total kWh across entries where both values are detectable.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private static func formatNumber(_ value: Double, maxFrac: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = maxFrac
        return nf.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func reset() {
        gasPriceInput = ""
        mpgInput = "30"
        focused = nil
    }

    // MARK: - ExpenseEntry heuristic fallback

    private static func estimateKWhCost(from expenses: [ExpenseEntry]) -> Double? {
        guard !expenses.isEmpty else { return nil }

        // Keep deliberately broad to tolerate different ExpenseEntry schemas
        let costKeywords = ["cost", "amount", "total", "price", "paid", "spend"]
        let kwhKeywords  = ["kwh", "energy", "energykwh", "charged", "chargedkwh", "kwhused", "kwh_added", "energyadded"]

        var totalCost: Double = 0
        var totalKWh: Double = 0

        for entry in expenses {
            let mirror = Mirror(reflecting: entry)

            var costValue: Double?
            var kwhValue: Double?

            for child in mirror.children {
                guard let label = child.label else { continue }
                let lower = label.lowercased()

                if costValue == nil,
                   costKeywords.contains(where: { lower.contains($0) }),
                   let v = child.value as? Double {
                    costValue = v
                }

                if kwhValue == nil,
                   kwhKeywords.contains(where: { lower.contains($0) }),
                   let v = child.value as? Double {
                    kwhValue = v
                }
            }

            if let cost = costValue, let kwh = kwhValue, kwh > 0 {
                totalCost += cost
                totalKWh += kwh
            }
        }

        guard totalKWh > 0 else { return nil }
        return totalCost / totalKWh
    }
}

// MARK: - Theme card helper (file-scoped)

fileprivate struct GasKwhThemedCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.appThemeBox) private var themeBox

    func body(content: Content) -> some View {
        let t = themeBox.base
        return content
            .background(
                RoundedRectangle(cornerRadius: t.corner, style: .continuous)
                    .fill(t.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: t.corner, style: .continuous)
                            .strokeBorder(t.separator.opacity(scheme == .dark ? 0.55 : 0.75), lineWidth: 1)
                    )
            )
            .shadow(
                color: Color.black.opacity(scheme == .dark ? 0.28 : 0.10),
                radius: t.elevation,
                x: 0,
                y: 4
            )
    }
}

fileprivate extension View {
    func themedCard() -> some View { modifier(GasKwhThemedCard()) }
}
