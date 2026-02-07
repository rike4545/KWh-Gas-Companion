//
//  UnitConversionView.swift
//  My KWh Companion
//
//  Swift 6 • iOS 17+
//
//  Converter + budget helper with collapsible “cards”
//  - Energy/quantity conversion via Joule backbone
//  - Optional “cost per unit” equivalence
//  - Gas fill-up budget + EV budget/visits
//  - Cross-comparison (what your gas budget buys in EV sessions, and vice versa)
//  - Theme-aware (AppThemeSpec) + keyboard Done toolbar
//

import SwiftUI

// MARK: - Units

/// Supported energy/quantity units for conversion
enum UnitType: String, CaseIterable, Identifiable {
    case btu = "BTU"
    case calorie = "Calorie"
    case erg = "Erg"
    case gallongas = "Gallon of Gas"
    case literGas = "Liter of Gas"
    case joule = "Joule"
    case kilojoule = "Kilojoule"
    case kilowattHour = "Kilowatt-hour"

    var id: String { rawValue }

    /// Multiply an amount in this unit by `toJoulesFactor` to get Joules.
    ///
    /// Notes:
    /// - "Gallon of Gas" here is energy-equivalence (≈ gasoline gallon equivalent).
    ///   We use ~120 MJ/US gallon as a practical round number.
    var toJoulesFactor: Double {
        switch self {
        case .btu: return 1055.06
        case .calorie: return 4.184
        case .erg: return 1e-7
        case .gallongas: return 120_000_000 // ~120 MJ per US gallon (energy equivalence)
        case .literGas: return 120_000_000 / 3.78541
        case .joule: return 1
        case .kilojoule: return 1_000
        case .kilowattHour: return 3_600_000
        }
    }

    var short: String {
        switch self {
        case .btu: return "BTU"
        case .calorie: return "cal"
        case .erg: return "erg"
        case .gallongas: return "gal"
        case .literGas: return "L"
        case .joule: return "J"
        case .kilojoule: return "kJ"
        case .kilowattHour: return "kWh"
        }
    }
}

// MARK: - Timeframe

enum TimeFrame: String, CaseIterable, Identifiable {
    case daily = "Day"
    case weekly = "Week"
    case monthly = "Month"
    case yearly = "Year"
    var id: String { rawValue }

    /// Only used for helper conversions (e.g. turning an EV budget into a monthly equivalent)
    var toMonthlyFactor: Double {
        switch self {
        case .daily: return 30.437
        case .weekly: return 52.0 / 12.0
        case .monthly: return 1
        case .yearly: return 1.0 / 12.0
        }
    }
}

// MARK: - Collapsible Card

struct CollapsibleCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.appThemeBox) private var themeBox

    let icon: String
    let title: String
    let subtitle: String?
    @Binding var isExpanded: Bool
    let content: Content

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        let t = themeBox.base

        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy(duration: 0.22)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(t.pillTint.opacity(scheme == .dark ? 0.60 : 0.90))
                        Image(systemName: icon)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(t.accent)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().opacity(0.25)
                content
            }
        }
        .padding(14)
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
        .padding(.horizontal, 16)
    }
}

// MARK: - Main View

@MainActor
struct UnitConversionView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.appThemeBox) private var themeBox

    // MARK: - State (Strings for safe typed input)

    @State private var inputValue = ""
    @State private var fromUnit: UnitType = .kilowattHour
    @State private var toUnit: UnitType = .gallongas
    @State private var decimalPlaces = 2

    @State private var costPerFromUnit = ""         // e.g. $/kWh
    @State private var costPerFillUp = ""           // e.g. $65
    @State private var fillUpsPerPeriod = 1         // count in selected gas period
    @State private var gasBudgetAmount = ""         // optional budget

    @State private var evBudgetAmount = ""          // optional EV budget
    @State private var budgetTimeFrame: TimeFrame = .monthly

    @State private var avgSessionAmount = ""        // optional session kWh
    @State private var fullCapacity = ""            // kWh
    @State private var desiredPercent: Double = 80

    @State private var showConversion = true
    @State private var showCost = false
    @State private var showGasBudget = false
    @State private var showEVBudget = false
    @State private var showComparison = false

    @FocusState private var focusedField: Field?
    enum Field { case input, costPer, fillupCost, gasBudget, evBudget, session, capacity }

    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    // MARK: - Parsing helpers

    private func parseDouble(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Allow commas as decimal separators for quick entry.
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    // MARK: - Computed

    private var inputDouble: Double? { parseDouble(inputValue) }

    private var convertedValue: Double? {
        guard let val = inputDouble else { return nil }
        return (val * fromUnit.toJoulesFactor) / toUnit.toJoulesFactor
    }

    /// If user provides a cost per FROM unit (e.g. $/kWh), what is the equivalent cost per TO unit
    /// assuming you're comparing on an energy-equivalent basis.
    private var costToUnit: Double? {
        guard let cost = parseDouble(costPerFromUnit) else { return nil }
        // $/fromUnit => $/J => $/toUnit
        // costPerJ = cost / fromJ
        // costPerTo = costPerJ * toJ
        return cost * (toUnit.toJoulesFactor / fromUnit.toJoulesFactor)
    }

    // Gas calculations
    private var fillUpCostValue: Double? { parseDouble(costPerFillUp) }
    private var gasBudgetValue: Double? { parseDouble(gasBudgetAmount) }

    private var gasPeriodTotal: Double? {
        guard let c = fillUpCostValue else { return nil }
        return c * Double(fillUpsPerPeriod)
    }

    private var possibleGasFillUpsFromGasBudget: Double? {
        guard let budget = gasBudgetValue, let cost = fillUpCostValue, cost > 0 else { return nil }
        return budget / cost
    }

    // EV calculations
    private var evBudgetValue: Double? { parseDouble(evBudgetAmount) }
    private var costPerFromUnitValue: Double? { parseDouble(costPerFromUnit) }

    private var affordableUnits: Double? {
        guard let budget = evBudgetValue, budget > 0,
              let cost = costPerFromUnitValue, cost > 0 else { return nil }
        return budget / cost
    }

    private var sessionSize: Double? {
        if let ses = parseDouble(avgSessionAmount), ses > 0 { return ses }
        guard let cap = parseDouble(fullCapacity), cap > 0 else { return nil }
        return cap * (desiredPercent / 100.0)
    }

    private var possibleVisits: Double? {
        guard let units = affordableUnits,
              let ses = sessionSize, ses > 0 else { return nil }
        return units / ses
    }

    // Comparison
    private var possibleEVVisitsFromGasBudget: Double? {
        guard let gb = gasBudgetValue, gb > 0,
              let ses = sessionSize, ses > 0,
              let cost = costPerFromUnitValue, cost > 0 else { return nil }
        return gb / (ses * cost)
    }

    private var possibleGasFillUpsFromEVBudget: Double? {
        guard let evb = evBudgetValue, evb > 0,
              let cost = fillUpCostValue, cost > 0 else { return nil }
        return evb / cost
    }

    // MARK: - View

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(spacing: 16) {
                        quickPresets

                        CollapsibleCard(
                            icon: "function",
                            title: "Conversion",
                            subtitle: "Convert between energy/quantity units using Joules as the baseline.",
                            isExpanded: $showConversion
                        ) {
                            conversionCardBody
                        }

                        CollapsibleCard(
                            icon: "dollarsign.circle",
                            title: "Cost Equivalence",
                            subtitle: "If you know $ per unit (like $/kWh), see an energy-equivalent $ per other unit.",
                            isExpanded: $showCost
                        ) {
                            costCardBody
                        }

                        CollapsibleCard(
                            icon: "fuelpump.fill",
                            title: "Gas Fill-up Budget",
                            subtitle: "Estimate spend from fill-up cost and frequency; optionally reverse from a budget.",
                            isExpanded: $showGasBudget
                        ) {
                            gasBudgetBody
                        }

                        CollapsibleCard(
                            icon: "bolt.car.fill",
                            title: "EV Budget & Visits",
                            subtitle: "Given an EV budget and $/unit, estimate how many charging visits you can afford.",
                            isExpanded: $showEVBudget
                        ) {
                            evBudgetBody
                        }

                        CollapsibleCard(
                            icon: "chart.bar.xaxis",
                            title: "Cross-Comparison",
                            subtitle: "Translate budgets across gas vs EV assumptions (best-effort).",
                            isExpanded: $showComparison
                        ) {
                            comparisonBody
                        }

                        footerNote
                    }
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("Converter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") { reset() }
                }
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        let t = themeBox.base
        return Rectangle()
            .fill(t.screenBackground)
            .overlay {
                RadialGradient(
                    colors: [t.accent.opacity(scheme == .dark ? 0.18 : 0.10), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 520
                )
                .blur(radius: scheme == .dark ? 28 : 22)
            }
            .ignoresSafeArea()
    }

    // MARK: - Quick Presets

    private var quickPresets: some View {
        let t = themeBox.base

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Quick Presets")
                    .font(.headline)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    presetButton("kWh → gal (gas eq.)", systemImage: "bolt.fill") {
                        fromUnit = .kilowattHour
                        toUnit = .gallongas
                        if inputValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            inputValue = "33.7" // common reference point people recognize
                        }
                        showConversion = true
                    }
                    presetButton("kWh → kJ", systemImage: "arrow.left.arrow.right") {
                        fromUnit = .kilowattHour
                        toUnit = .kilojoule
                        showConversion = true
                    }
                    presetButton("BTU → kWh", systemImage: "flame.fill") {
                        fromUnit = .btu
                        toUnit = .kilowattHour
                        showConversion = true
                    }
                    presetButton("Swap", systemImage: "arrow.left.arrow.right.circle") {
                        swap(&fromUnit, &toUnit)
                    }
                }
                .padding(.horizontal, 16)
            }

            Text("Tip: For best comparisons, also fill in Cost ($/\(fromUnit.short)) and a typical EV session size.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
        }
        .padding(.bottom, 4)
        .foregroundStyle(.primary)
        .background(
            RoundedRectangle(cornerRadius: t.corner, style: .continuous)
                .fill(Color.clear)
        )
    }

    private func presetButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Card bodies

    private var conversionCardBody: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                TextField("Enter amount", text: $inputValue)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .input)

                Button {
                    swap(&fromUnit, &toUnit)
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.headline)
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .accessibilityLabel("Swap units")
            }

            HStack(spacing: 10) {
                Picker("From", selection: $fromUnit) {
                    ForEach(UnitType.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)

                Spacer()

                Picker("To", selection: $toUnit) {
                    ForEach(UnitType.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Text("Result")
                Spacer()
                Text(resultString(convertedValue))
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
            }

            Stepper("Precision: \(decimalPlaces)", value: $decimalPlaces, in: 0...6)

            Text("This is an energy/quantity equivalence based on Joules. For “Gallon of Gas”, we treat it as energy-equivalent (~120 MJ per gallon).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var costCardBody: some View {
        VStack(spacing: 12) {
            TextField("Cost per \(fromUnit.short) (e.g. 0.32)", text: $costPerFromUnit)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .costPer)

            if let ct = costToUnit {
                HStack {
                    Text("Equivalent cost per \(toUnit.short)")
                    Spacer()
                    Text(ct, format: .currency(code: currencyCode))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
            } else {
                Text("Enter a numeric cost to see the equivalence.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Example: If electricity is $/kWh, this estimates the energy-equivalent $/gal (gas eq.). It does *not* account for drivetrain efficiency differences.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var gasBudgetBody: some View {
        VStack(spacing: 12) {
            TextField("Cost per fill-up (e.g. 65)", text: $costPerFillUp)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .fillupCost)

            Stepper("Fill-ups per \(budgetTimeFrame.rawValue): \(fillUpsPerPeriod)", value: $fillUpsPerPeriod, in: 0...100)

            if let total = gasPeriodTotal {
                HStack {
                    Text("\(budgetTimeFrame.rawValue) gas spend")
                    Spacer()
                    Text(total, format: .currency(code: currencyCode))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
            }

            TextField("Gas budget (optional)", text: $gasBudgetAmount)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .gasBudget)

            if let possible = possibleGasFillUpsFromGasBudget {
                HStack {
                    Text("Fill-ups from budget")
                    Spacer()
                    Text(String(format: "%.1f", possible))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
            } else {
                Text("Optional: enter a gas budget to estimate how many fill-ups it covers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var evBudgetBody: some View {
        VStack(spacing: 12) {
            TextField("EV budget (optional)", text: $evBudgetAmount)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .evBudget)

            Picker("Budget Period", selection: $budgetTimeFrame) {
                ForEach(TimeFrame.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if let units = affordableUnits {
                HStack {
                    Text("Affordable \(fromUnit.short)")
                    Spacer()
                    Text(resultString(units))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
            }

            TextField("Typical session size in \(fromUnit.short) (optional)", text: $avgSessionAmount)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .session)

            TextField("Full battery capacity in \(fromUnit.short) (optional)", text: $fullCapacity)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .capacity)

            HStack {
                Text("Charge target: \(Int(desiredPercent))%")
                Spacer()
            }
            Slider(value: $desiredPercent, in: 0...100, step: 1)

            if let ses = sessionSize {
                HStack {
                    Text("Assumed session size")
                    Spacer()
                    Text(resultString(ses) + " \(fromUnit.short)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }

            if let visits = possibleVisits {
                HStack {
                    Text("Possible visits per \(budgetTimeFrame.rawValue)")
                    Spacer()
                    Text(resultString(visits))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
            } else {
                Text("To estimate visits: enter EV budget + $/\(fromUnit.short), and either session size or capacity + target%.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var comparisonBody: some View {
        VStack(spacing: 12) {
            if possibleEVVisitsFromGasBudget == nil && possibleGasFillUpsFromEVBudget == nil {
                Text("Enter: gas budget + fill-up cost, and EV budget + $/\(fromUnit.short) + session size.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let evVisits = possibleEVVisitsFromGasBudget {
                HStack {
                    Text("EV visits from gas budget")
                    Spacer()
                    Text(String(format: "%.1f", evVisits))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
            }

            if let gasFills = possibleGasFillUpsFromEVBudget {
                HStack {
                    Text("Gas fill-ups from EV budget")
                    Spacer()
                    Text(String(format: "%.1f", gasFills))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
            }

            if let evb = evBudgetValue, evb > 0 {
                let monthlyEq = evb * budgetTimeFrame.toMonthlyFactor
                HStack {
                    Text("EV budget (monthly equivalent)")
                    Spacer()
                    Text(monthlyEq, format: .currency(code: currencyCode))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
    }

    private var footerNote: some View {
        Text("Estimates only. This tool does not model drivetrain efficiency, charging losses, or real-world fuel economy variance.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 6)
    }

    // MARK: - Formatting

    private func resultString(_ value: Double?) -> String {
        guard let value else { return "––" }
        return String(format: "%.\(decimalPlaces)f", value)
    }

    // MARK: - Reset

    private func reset() {
        inputValue = ""
        fromUnit = .kilowattHour
        toUnit = .gallongas
        decimalPlaces = 2

        costPerFromUnit = ""
        costPerFillUp = ""
        fillUpsPerPeriod = 1
        gasBudgetAmount = ""

        evBudgetAmount = ""
        budgetTimeFrame = .monthly
        avgSessionAmount = ""
        fullCapacity = ""
        desiredPercent = 80

        focusedField = nil
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        UnitConversionView()
    }
    .appTheme(DefaultAppTheme())
}
