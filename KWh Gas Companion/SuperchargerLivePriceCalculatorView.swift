//
//  SuperchargerLivePriceCalculatorView.swift
//  KWh Gas Companion
//
//  Live Price Predictor (occupancy tiers + optional daily curve)
//  Swift 6 • iOS 17+
//

import SwiftUI
import Foundation

@MainActor
public struct SuperchargerLivePriceCalculatorView: View {

    public init() {}

    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var appearance: AppAppearance

    // Match this key to whatever your SettingsView uses (if different, rename it there + here).
    @AppStorage("evc_currency_code")
    private var currencyCode: String = Locale.current.currency?.identifier ?? "USD"

    @StateObject private var presetStore = SuperchargerLocationPresetStore(seedDefaultsIfEmpty: true)

    @State private var selectedPresetID: UUID?
    @State private var occupiedStalls: Int = 1
    @State private var when: Date = .now

    @State private var showEditor: Bool = false
    @State private var editorDraft: SuperchargerLocationPreset? = nil

    private var theme: any AppThemeSpec { themeBox.base }
    private var accent: Color { appearance.accentColor }

    private var preset: SuperchargerLocationPreset? {
        presetStore.preset(id: selectedPresetID) ?? presetStore.presets.first
    }

    private var effectivePresetID: UUID? {
        selectedPresetID ?? presetStore.presets.first?.id
    }

    private var tierText: String {
        guard let p = preset else { return "—" }
        let t = p.thresholds.tier(occupiedStalls: occupiedStalls, totalStalls: p.totalStalls)
        return t.title
    }

    private var predictedPriceNow: Double? {
        guard let p = preset else { return nil }
        return p.predictedPrice(occupiedStalls: occupiedStalls, at: when)
    }

    private var predictedLow: Double? {
        guard let p = preset else { return nil }
        return p.predictedPrice(occupiedStalls: 0, at: when)
    }

    private var predictedNormal: Double? {
        guard let p = preset else { return nil }
        let mid = max(0, min(p.totalStalls, max(2, p.totalStalls / 2)))
        return p.predictedPrice(occupiedStalls: mid, at: when)
    }

    private var predictedHigh: Double? {
        guard let p = preset else { return nil }
        return p.predictedPrice(occupiedStalls: p.totalStalls, at: when)
    }

    private var forecastRows: [ForecastRow] {
        guard let p = preset else { return [] }
        let cal = Calendar.current
        let start = Date()
        var out: [ForecastRow] = []
        out.reserveCapacity(24)

        for h in 0..<24 {
            if let d = cal.date(byAdding: .hour, value: h, to: start) {
                let price = p.predictedPrice(occupiedStalls: occupiedStalls, at: d)
                out.append(.init(date: d, price: price))
            }
        }
        return out
    }

    private var cheapestForecast: ForecastRow? {
        forecastRows.min(by: { $0.price < $1.price })
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing) {
                headerCard

                selectorCard

                if let p = preset {
                    occupancyCard(p: p)
                    predictionCard(p: p)
                    forecastCard
                    tuningSummaryCard(p: p)
                } else {
                    emptyStateCard
                }

                disclaimerCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(backgroundView)
        .navigationTitle("Live Price Predictor")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accent)
        .onAppear {
            // Ensure selection is stable.
            if selectedPresetID == nil {
                selectedPresetID = presetStore.presets.first?.id
            }
        }
        .sheet(isPresented: $showEditor) {
            if let draft = editorDraft {
                SuperchargerPresetEditorSheet(
                    theme: theme,
                    accent: accent,
                    currencyCode: currencyCode,
                    initial: draft,
                    onCancel: { showEditor = false },
                    onSave: { saved in
                        presetStore.upsert(saved)
                        selectedPresetID = saved.id
                        showEditor = false
                    }
                )
            }
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            Rectangle().fill(theme.screenBackground).ignoresSafeArea()

            RadialGradient(
                colors: [theme.accent.opacity(scheme == .dark ? 0.22 : 0.14), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
            .blur(radius: 26)
            .ignoresSafeArea()
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        Card(theme: theme) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(accent.opacity(0.16))
                    Image(systemName: "bolt.badge.clock")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Predict what you’ll pay before you plug in.")
                        .font(.headline)
                    Text("Uses your preset’s baseline price, occupancy tiers, and optional daily curve.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private var selectorCard: some View {
        Card(theme: theme) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Location preset")
                        .font(.headline)
                    Spacer()
                    Button {
                        let starter = preset ?? SuperchargerLocationPreset(
                            name: "New Supercharger",
                            totalStalls: 12,
                            basePriceNormal: 0.40
                        )
                        editorDraft = starter
                        showEditor = true
                    } label: {
                        Label("Edit", systemImage: "slider.horizontal.3")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(theme.pillTint.opacity(0.28), in: Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                if presetStore.presets.isEmpty {
                    Text("No presets found. Tap Edit to create one.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Preset", selection: Binding(
                        get: { effectivePresetID },
                        set: { selectedPresetID = $0 }
                    )) {
                        ForEach(presetStore.presets) { p in
                            Text(p.name).tag(Optional(p.id))
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack(spacing: 10) {
                    DatePicker("When", selection: $when, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                    Spacer()
                }
            }
        }
    }

    private func occupancyCard(p: SuperchargerLocationPreset) -> some View {
        Card(theme: theme) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Occupancy")
                        .font(.headline)
                    Spacer()
                    Text("\(occupiedStalls)/\(p.totalStalls) · \(tierText)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Stepper(
                    value: $occupiedStalls,
                    in: 0...p.totalStalls,
                    step: 1
                ) {
                    Text("Occupied stalls")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { Double(occupiedStalls) },
                        set: { occupiedStalls = Int($0.rounded()) }
                    ),
                    in: 0...Double(p.totalStalls),
                    step: 1
                )
                .accessibilityValue("\(occupiedStalls) of \(p.totalStalls)")
            }
        }
    }

    private func predictionCard(p: SuperchargerLocationPreset) -> some View {
        Card(theme: theme) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Predicted price")
                        .font(.headline)
                    Spacer()
                }

                if let price = predictedPriceNow {
                    HStack(alignment: .firstTextBaseline) {
                        Text(formatCurrency(price))
                            .font(.title2.weight(.semibold))
                        Text("/kWh")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Tier: \(tierText)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Divider().opacity(0.6)

                    VStack(spacing: 8) {
                        miniRow(label: "Low tier", value: predictedLow)
                        miniRow(label: "Normal tier", value: predictedNormal)
                        miniRow(label: "High tier", value: predictedHigh)
                    }
                } else {
                    Text("Select or create a preset to see pricing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var forecastCard: some View {
        Card(theme: theme) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Next 24 hours (same occupancy)")
                        .font(.headline)
                    Spacer()
                    if let best = cheapestForecast {
                        Text("Cheapest: \(timeString(best.date))")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if forecastRows.isEmpty {
                    Text("No forecast available.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 6) {
                        ForEach(forecastRows.prefix(12)) { row in
                            HStack {
                                Text(timeString(row.date))
                                    .font(.footnote.monospacedDigit())
                                Spacer()
                                Text("\(formatCurrency(row.price))/kWh")
                                    .font(.footnote.weight(row.isCheapest(cheapestForecast) ? .semibold : .regular))
                                    .foregroundStyle(row.isCheapest(cheapestForecast) ? accent : .secondary)
                            }
                            .padding(.vertical, 2)
                        }

                        if forecastRows.count > 12 {
                            Text("Open the preset editor to enable/adjust the daily curve for more variation.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
            }
        }
    }

    private func tuningSummaryCard(p: SuperchargerLocationPreset) -> some View {
        Card(theme: theme) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Preset summary")
                    .font(.headline)

                VStack(spacing: 8) {
                    HStack {
                        Text("Base (normal)")
                        Spacer()
                        Text("\(formatCurrency(p.basePriceNormal))/kWh")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Mode")
                        Spacer()
                        Text(p.baseMode == .manual ? "Manual" : "Curve multiplier")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Low tier delta")
                        Spacer()
                        Text("\(signedCurrency(p.offsets.lowDelta))/kWh")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("High tier delta")
                        Spacer()
                        Text("\(signedCurrency(p.offsets.highDelta))/kWh")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Low tier if occupied ≤")
                        Spacer()
                        Text("\(p.thresholds.lowMaxOccupiedStalls)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("High tier if fill ≥")
                        Spacer()
                        Text("\(Int(p.thresholds.highMinFillFraction * 100))%")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.footnote)
            }
        }
    }

    private var emptyStateCard: some View {
        Card(theme: theme) {
            VStack(alignment: .leading, spacing: 8) {
                Text("No preset selected")
                    .font(.headline)
                Text("Tap Edit to create a location preset (stalls + typical base price).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var disclaimerCard: some View {
        Card(theme: theme) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.headline)
                Text("This is a heuristic predictor. Actual Supercharger pricing can change by location, time, congestion, and policy. Price shown in the Tesla app / car UI before charging begins is the source of truth.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Helpers

    private func miniRow(label: String, value: Double?) -> some View {
        HStack {
            Text(label)
                .font(.footnote)
            Spacer()
            Text(value.map { "\(formatCurrency($0))/kWh" } ?? "—")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        // Uses the app’s saved currency code, falling back to locale if needed.
        // If your SettingsView uses a different key, change @AppStorage above.
        return value.formatted(.currency(code: currencyCode))
    }

    private func signedCurrency(_ value: Double) -> String {
        let absStr = abs(value).formatted(.currency(code: currencyCode))
        return value >= 0 ? "+\(absStr)" : "−\(absStr)"
    }

    private func timeString(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - Forecast model

    private struct ForecastRow: Identifiable, Hashable {
        let id = UUID()
        let date: Date
        let price: Double

        func isCheapest(_ cheapest: ForecastRow?) -> Bool {
            guard let cheapest else { return false }
            return abs(price - cheapest.price) < 0.000_000_1
        }
    }
}

// MARK: - Editor Sheet (simple, avoids heavy binding chains)

@MainActor
fileprivate struct SuperchargerPresetEditorSheet: View {
    let theme: any AppThemeSpec
    let accent: Color
    let currencyCode: String

    let initial: SuperchargerLocationPreset
    let onCancel: () -> Void
    let onSave: (SuperchargerLocationPreset) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var totalStalls: Int
    @State private var basePrice: Double
    @State private var baseMode: SuperchargerBasePriceMode

    @State private var curveEnabled: Bool
    @State private var curveKind: SuperchargerDailyCurveModel.Kind
    @State private var peakMult: Double
    @State private var offMult: Double
    @State private var weekendMult: Double

    @State private var lowDelta: Double
    @State private var highDelta: Double

    @State private var lowMaxOcc: Int
    @State private var highFillPct: Double

    init(
        theme: any AppThemeSpec,
        accent: Color,
        currencyCode: String,
        initial: SuperchargerLocationPreset,
        onCancel: @escaping () -> Void,
        onSave: @escaping (SuperchargerLocationPreset) -> Void
    ) {
        self.theme = theme
        self.accent = accent
        self.currencyCode = currencyCode
        self.initial = initial
        self.onCancel = onCancel
        self.onSave = onSave

        _name = State(initialValue: initial.name)
        _totalStalls = State(initialValue: initial.totalStalls)
        _basePrice = State(initialValue: initial.basePriceNormal)
        _baseMode = State(initialValue: initial.baseMode)

        _curveEnabled = State(initialValue: initial.curve.enabled)
        _curveKind = State(initialValue: initial.curve.kind)
        _peakMult = State(initialValue: initial.curve.peakMultiplier)
        _offMult = State(initialValue: initial.curve.offPeakMultiplier)
        _weekendMult = State(initialValue: initial.curve.weekendMultiplier)

        _lowDelta = State(initialValue: initial.offsets.lowDelta)
        _highDelta = State(initialValue: initial.offsets.highDelta)

        _lowMaxOcc = State(initialValue: initial.thresholds.lowMaxOccupiedStalls)
        _highFillPct = State(initialValue: initial.thresholds.highMinFillFraction * 100.0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name", text: $name)

                    Stepper(value: $totalStalls, in: 1...200, step: 1) {
                        HStack {
                            Text("Total stalls")
                            Spacer()
                            Text("\(totalStalls)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Base (normal)")
                        Spacer()
                        TextField("0.40", value: $basePrice, format: .number.precision(.fractionLength(2)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }

                    Picker("Mode", selection: $baseMode) {
                        Text("Manual").tag(SuperchargerBasePriceMode.manual)
                        Text("Curve multiplier").tag(SuperchargerBasePriceMode.curveMultiplier)
                    }
                }

                Section("Daily curve") {
                    Toggle("Enable curve", isOn: $curveEnabled)

                    Picker("Shape", selection: $curveKind) {
                        ForEach(SuperchargerDailyCurveModel.Kind.allCases) { k in
                            Text(k.title).tag(k)
                        }
                    }

                    HStack {
                        Text("Peak multiplier")
                        Spacer()
                        TextField("1.08", value: $peakMult, format: .number.precision(.fractionLength(2)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }

                    HStack {
                        Text("Off-peak multiplier")
                        Spacer()
                        TextField("0.96", value: $offMult, format: .number.precision(.fractionLength(2)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }

                    HStack {
                        Text("Weekend multiplier")
                        Spacer()
                        TextField("1.00", value: $weekendMult, format: .number.precision(.fractionLength(2)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }

                    Text("Tip: If you don’t want time-based variation, leave the curve disabled or keep multipliers near 1.0.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Occupancy tiers") {
                    Stepper(value: $lowMaxOcc, in: 0...max(0, totalStalls), step: 1) {
                        HStack {
                            Text("Low tier if occupied ≤")
                            Spacer()
                            Text("\(lowMaxOcc)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("High tier if fill ≥")
                        Spacer()
                        TextField("80", value: $highFillPct, format: .number.precision(.fractionLength(0)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                        Text("%")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Tier deltas") {
                    HStack {
                        Text("Low delta ($/kWh)")
                        Spacer()
                        TextField("-0.06", value: $lowDelta, format: .number.precision(.fractionLength(2)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("High delta ($/kWh)")
                        Spacer()
                        TextField("0.10", value: $highDelta, format: .number.precision(.fractionLength(2)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Edit Preset")
            .navigationBarTitleDisplayMode(.inline)
            .tint(accent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = initial
                        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.totalStalls = max(1, totalStalls)
                        updated.basePriceNormal = max(0, basePrice)

                        updated.baseMode = baseMode
                        updated.curve = SuperchargerDailyCurveModel(
                            enabled: curveEnabled,
                            kind: curveKind,
                            peakMultiplier: max(0.10, peakMult),
                            offPeakMultiplier: max(0.10, offMult),
                            weekendMultiplier: max(0.10, weekendMult)
                        )
                        updated.offsets = SuperchargerTierOffsets(
                            lowDelta: lowDelta,
                            highDelta: highDelta
                        )
                        updated.thresholds = SuperchargerTierThresholds(
                            lowMaxOccupiedStalls: max(0, lowMaxOcc),
                            highMinFillFraction: max(0, min(1, highFillPct / 100.0))
                        )

                        if updated.name.isEmpty { updated.name = "Unnamed" }

                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Lightweight card helper

fileprivate struct Card<Content: View>: View {
    let theme: any AppThemeSpec
    let content: Content
    @Environment(\.colorScheme) private var scheme

    init(theme: any AppThemeSpec, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.content = content()
    }

    var body: some View {
        content
            .padding(theme.spacing)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                    .strokeBorder(theme.separator.opacity(0.85), lineWidth: 1)
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0.10 : 0.16), radius: theme.elevation, x: 0, y: 2)
    }
}
