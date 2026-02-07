//
//  SuperChargerSessionCostCalculatorView.swift
//  KWh Gas Companion
//
//  Focus: Supercharger-only session cost (Tesla app / in-vehicle display)
//  ✅ Uses AppThemeSpec via Environment(\.appThemeBox)
//  ✅ Honors SettingsView keys: uiStyle + defaultCurrencyCode
//  ✅ Card-based layout + summary header
//  ✅ Start→End % OR Add kWh
//  ✅ Optional idle/congestion fees
//  ✅ Optional tax
//  ✅ Effective $/kWh
//  ✅ Persists last-used inputs via @AppStorage
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import Foundation
import UIKit

// MARK: - UI style values (must match ThemeBinder / SettingsView)
private enum ToolsStyle: String {
    case classic
    case teslaGlass
}

// MARK: - Focus (file-scope so helpers can see it)
enum EVCSuperchargeFocusField: Hashable {
    case battery, superRate, addKWh, feePerMin
}

// MARK: - View

@MainActor
public struct SuperChargerSessionCostCalculatorView: View {

    // Theme
    @Environment(\.appThemeBox) private var appThemeBox
    private var theme: any AppThemeSpec { appThemeBox.base }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var scheme

    // SettingsView keys
    @AppStorage("uiStyle") private var uiStyleRaw: String = "teslaGlass"
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String =
        (Locale.current.currency?.identifier ?? "USD")

    private var uiStyle: ToolsStyle {
        let v = uiStyleRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if v == "glass" || v == "teslaglass" { return .teslaGlass }
        // Keep canonical strings too ("classic", "teslaGlass")
        return ToolsStyle(rawValue: uiStyleRaw) ?? .classic
    }

    // Persist last-used values
    @AppStorage("evc_sc_battery_capacity_kwh") private var batteryCapacityStored: String = "75"
    @AppStorage("evc_sc_rate_super_kwh") private var superRateStored: String = "0.40"
    @AppStorage("evc_sc_last_add_kwh") private var addKWhStored: String = "20"
    @AppStorage("evc_sc_fee_per_min") private var feePerMinuteStored: String = "0.50"

    // MARK: - Input mode
    private enum InputMode: String, CaseIterable, Identifiable {
        case percentRange
        case addKWh
        var id: String { rawValue }

        var label: String {
            switch self {
            case .percentRange: return "Start → End %"
            case .addKWh: return "Add kWh"
            }
        }
    }

    @State private var inputMode: InputMode = .percentRange

    // MARK: - Inputs (Text)
    @State private var batteryCapacityText: String = "75"      // kWh (for percent mode & implied end %)
    @State private var superchargerRateText: String = "0.40"   // $/kWh

    // MARK: - Inputs (Percent)
    @State private var startPercent: Double = 10
    @State private var endPercent: Double = 80

    // MARK: - Inputs (Add kWh)
    @State private var addKWhText: String = "20"

    // MARK: - Optional Add-ons
    @State private var includeTax: Bool = false
    @State private var taxPercent: Double = 8.625

    @State private var includeFees: Bool = false
    @State private var feePerMinuteText: String = "0.50"
    @State private var feeMinutes: Double = 0

    @FocusState private var focusField: EVCSuperchargeFocusField?

    public init() {}

    // MARK: - Background (matches SettingsView vibe, but uses AppThemeSpec)
    private var screenBackground: some View {
        let accent = theme.accent
        return ZStack {
            Rectangle()
                .fill(theme.screenBackground)
                .ignoresSafeArea()

            RadialGradient(
                colors: [accent.opacity(scheme == .dark ? 0.28 : 0.18), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
            .blur(radius: 28)
            .ignoresSafeArea()

            if scheme == .dark {
                RadialGradient(
                    colors: [Color.purple.opacity(0.18), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 520
                )
                .blur(radius: 34)
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Parsing + Formatting

    private func parseNumber(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        // Locale-aware decimal parse
        let dec = NumberFormatter()
        dec.locale = .current
        dec.numberStyle = .decimal
        if let n = dec.number(from: trimmed) { return n.doubleValue }

        // Locale-aware currency parse (for pasted "$0.40")
        let cur = NumberFormatter()
        cur.locale = .current
        cur.numberStyle = .currency
        if let n = cur.number(from: trimmed) { return n.doubleValue }

        // Fallback normalize separators
        let allowed = CharacterSet(charactersIn: "0123456789-.,")
        let cleanedScalars = trimmed.unicodeScalars.filter { allowed.contains($0) }
        var cleaned = String(String.UnicodeScalarView(cleanedScalars))

        if cleaned.contains(".") && cleaned.contains(",") {
            let lastComma = cleaned.lastIndex(of: ",")!
            let lastDot = cleaned.lastIndex(of: ".")!
            if lastComma > lastDot {
                cleaned = cleaned.replacingOccurrences(of: ".", with: "")
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            } else {
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
        } else if cleaned.contains(",") && !cleaned.contains(".") {
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        }

        return Double(cleaned)
    }

    private func currency(_ value: Double) -> String {
        value.formatted(.currency(code: defaultCurrencyCode).locale(.current))
    }

    private func number(_ value: Double, decimals: Int) -> String {
        value.formatted(.number.precision(.fractionLength(decimals)).locale(.current))
    }

    private func kWh4(_ value: Double) -> String {
        "\(number(value, decimals: 4)) kWh"
    }

    private func ratePerKWh(_ value: Double) -> String {
        "\(currency(value))/kWh"
    }

    private func dismissKeyboard() {
        focusField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }

    // MARK: - Derived Values

    private var batteryCapacityKWh: Double? {
        guard let v = parseNumber(batteryCapacityText), v > 0 else { return nil }
        return v
    }

    private var superchargerRate: Double? {
        guard let v = parseNumber(superchargerRateText), v >= 0 else { return nil }
        return v
    }

    private var addKWhValue: Double? {
        guard inputMode == .addKWh else { return nil }
        guard let v = parseNumber(addKWhText), v >= 0 else { return nil }
        return v
    }

    private var feePerMinute: Double? {
        guard includeFees else { return nil }
        guard let v = parseNumber(feePerMinuteText), v >= 0 else { return nil }
        return v
    }

    private var percentDelta: Double { max(0, endPercent - startPercent) }

    private var impliedEndPercentFromAddKWh: Double? {
        guard inputMode == .addKWh,
              let cap = batteryCapacityKWh, cap > 0,
              let add = addKWhValue else { return nil }
        let deltaPercent = (add / cap) * 100.0
        return min(100, max(startPercent, startPercent + deltaPercent))
    }

    private var energyAddedKWh: Double? {
        switch inputMode {
        case .percentRange:
            guard let cap = batteryCapacityKWh else { return nil }
            return max(0, cap * (percentDelta / 100.0))
        case .addKWh:
            return addKWhValue
        }
    }

    private var superchargerEnergyCost: Double? {
        guard let e = energyAddedKWh, let r = superchargerRate else { return nil }
        return max(0, e * r)
    }

    private var feeCost: Double? {
        guard includeFees, let perMin = feePerMinute else { return nil }
        return max(0, perMin * feeMinutes)
    }

    private var subtotal: Double? {
        guard let base = superchargerEnergyCost else { return nil }
        return base + (feeCost ?? 0)
    }

    private var taxAmount: Double? {
        guard includeTax, let sub = subtotal else { return nil }
        return max(0, sub * (taxPercent / 100.0))
    }

    private var total: Double? {
        guard let sub = subtotal else { return nil }
        return sub + (taxAmount ?? 0)
    }

    private var effectiveSuperchargerRate: Double? {
        guard let e = energyAddedKWh, e > 0, let t = total else { return nil }
        return t / e
    }

    // MARK: - Validation

    private var capacityError: String? {
        if batteryCapacityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Required" }
        guard let v = parseNumber(batteryCapacityText), v > 0 else { return "Enter a valid kWh value" }
        if v > 250 { return "Unusually high—double check." }
        return nil
    }

    private var superRateError: String? {
        if superchargerRateText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Required" }
        guard let v = parseNumber(superchargerRateText), v >= 0 else { return "Enter a valid $/kWh rate" }
        return nil
    }

    private var addKWhError: String? {
        guard inputMode == .addKWh else { return nil }
        if addKWhText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Required" }
        guard let v = parseNumber(addKWhText), v >= 0 else { return "Enter a valid kWh amount" }
        if let cap = batteryCapacityKWh, v > cap { return "Exceeds battery capacity" }
        return nil
    }

    private var feeError: String? {
        guard includeFees else { return nil }
        if feePerMinuteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Required" }
        guard let v = parseNumber(feePerMinuteText), v >= 0 else { return "Enter a valid $/min" }
        return nil
    }

    private var canCompute: Bool {
        capacityError == nil &&
        superRateError == nil &&
        addKWhError == nil &&
        feeError == nil
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            screenBackground
            page
        }
        .navigationTitle("Supercharge Cost")
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.accent)
        .onAppear { loadLastUsed() }
        .onChange(of: batteryCapacityText) { _, _ in persistLastUsed() }
        .onChange(of: superchargerRateText) { _, _ in persistLastUsed() }
        .onChange(of: addKWhText) { _, _ in persistLastUsed() }
        .onChange(of: feePerMinuteText) { _, _ in persistLastUsed() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
            }
        }
    }

    private var page: some View {
        ScrollView {
            VStack(spacing: theme.spacing) {
                headerSummaryCard
                inputsCard
                ratesCard
                estimatesCard
                actionsCard
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
            .padding(.vertical, 14)
            .frame(maxWidth: horizontalSizeClass == .regular ? 760 : .infinity, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Cards

    private var headerSummaryCard: some View {
        EVCCard(uiStyle: uiStyle) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(theme.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tesla Supercharger Estimate")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Based on Tesla app / in-car rate display.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let t = total, canCompute {
                        Button {
                            UIPasteboard.general.string = currency(t)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.headline)
                        }
                        .accessibilityLabel("Copy total")
                    }
                }

                HStack(spacing: 10) {
                    StatChip(uiStyle: uiStyle, title: "Total",
                             value: (total != nil && canCompute) ? currency(total!) : "—",
                             icon: "creditcard.fill")

                    StatChip(uiStyle: uiStyle, title: "Energy",
                             value: (energyAddedKWh != nil && canCompute) ? kWh4(energyAddedKWh!) : "—",
                             icon: "battery.100percent")

                    StatChip(uiStyle: uiStyle, title: "All‑in",
                             value: (effectiveSuperchargerRate != nil && canCompute) ? ratePerKWh(effectiveSuperchargerRate!) : "—",
                             icon: "chart.bar.fill")
                }
            }
        }
    }

    private var inputsCard: some View {
        EVCCard(uiStyle: uiStyle, title: "Session Inputs", subtitle: "Describe what you added during the session.") {
            VStack(spacing: 12) {
                Picker("Mode", selection: $inputMode) {
                    ForEach(InputMode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                EVCField(
                    uiStyle: uiStyle,
                    title: "Battery Capacity",
                    unit: "kWh",
                    text: $batteryCapacityText,
                    placeholder: "75",
                    keyboard: UIKeyboardType.decimalPad,
                    error: capacityError,
                    focus: $focusField,
                    field: .battery
                )

                switch inputMode {
                case .percentRange:
                    VStack(spacing: 10) {
                        SliderRow(title: "Start Charge", value: $startPercent, range: 0...endPercent, suffix: "%")
                        SliderRow(title: "End Charge", value: $endPercent, range: startPercent...100, suffix: "%")

                        HStack {
                            Text("Session Delta")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(Int(percentDelta))%")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.top, 2)
                    }

                case .addKWh:
                    EVCField(
                        uiStyle: uiStyle,
                        title: "Add Energy",
                        unit: "kWh",
                        text: $addKWhText,
                        placeholder: "20",
                        keyboard: UIKeyboardType.decimalPad,
                        error: addKWhError,
                        focus: $focusField,
                        field: .addKWh
                    )

                    if let implied = impliedEndPercentFromAddKWh {
                        HStack {
                            Text("Implied End %")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(Int(implied.rounded()))%")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }

                    SliderRow(title: "Start Charge", value: $startPercent, range: 0...100, suffix: "%")
                }
            }
            .animation(.snappy, value: inputMode)
        }
    }

    private var ratesCard: some View {
        EVCCard(uiStyle: uiStyle, title: "Pricing", subtitle: "Enter the Supercharger rate shown by Tesla.") {
            VStack(spacing: 12) {
                EVCField(
                    uiStyle: uiStyle,
                    title: "Supercharger Rate",
                    unit: "$/kWh",
                    text: $superchargerRateText,
                    placeholder: "0.40",
                    keyboard: UIKeyboardType.decimalPad,
                    error: superRateError,
                    focus: $focusField,
                    field: .superRate
                )

                Divider().overlay(theme.separator)

                Toggle(isOn: $includeFees.animation(.snappy)) {
                    Label("Include idle / congestion fees", systemImage: "hourglass")
                }

                if includeFees {
                    EVCField(
                        uiStyle: uiStyle,
                        title: "Fees",
                        unit: "$/min",
                        text: $feePerMinuteText,
                        placeholder: "0.50",
                        keyboard: UIKeyboardType.decimalPad,
                        error: feeError,
                        focus: $focusField,
                        field: .feePerMin
                    )

                    SliderRow(title: "Fee minutes", value: $feeMinutes, range: 0...180, suffix: "min")
                }

                Divider().overlay(theme.separator)

                Toggle(isOn: $includeTax.animation(.snappy)) {
                    Label("Include tax", systemImage: "percent")
                }

                if includeTax {
                    SliderRow(title: "Tax rate", value: $taxPercent, range: 0...15, suffix: "%", decimals: 3)
                }
            }
        }
    }

    private var estimatesCard: some View {
        EVCCard(uiStyle: uiStyle, title: "Estimate Breakdown", subtitle: canCompute ? "Calculated from your inputs." : "Fix fields above to compute.") {
            VStack(spacing: 10) {
                if !canCompute {
                    InfoBanner(uiStyle: uiStyle, text: "Fix the highlighted fields to see estimates.", icon: "exclamationmark.triangle.fill")
                }

                if let e = energyAddedKWh, let sr = superchargerRate, canCompute {
                    KeyValueRow(key: "Energy", value: "\(kWh4(e)) @ \(ratePerKWh(sr))")
                }

                if let base = superchargerEnergyCost, canCompute {
                    KeyValueRow(key: "Energy Cost", value: currency(base), emphasizeValue: true)
                }

                if let fee = feeCost, includeFees, canCompute {
                    KeyValueRow(key: "Fees", value: currency(fee))
                }

                if let sub = subtotal, (includeFees || includeTax), canCompute {
                    KeyValueRow(key: "Subtotal", value: currency(sub))
                }

                if let tax = taxAmount, includeTax, canCompute {
                    KeyValueRow(key: "Tax", value: currency(tax))
                }

                if let t = total, canCompute {
                    Divider().overlay(theme.separator)

                    HStack {
                        Text("Estimated Total")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(currency(t))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                    }

                    if let eff = effectiveSuperchargerRate, (includeFees || includeTax) {
                        Text("All‑in rate: \(ratePerKWh(eff))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var actionsCard: some View {
        EVCCard(uiStyle: uiStyle) {
            HStack(spacing: 12) {
                Button {
                    resetDefaults()
                    dismissKeyboard()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EVCPrimaryButtonStyle(
                    uiStyle: uiStyle,
                    accent: theme.accent,
                    onAccent: theme.onAccent,
                    corner: theme.smallCorner,
                    pillTint: theme.pillTint,
                    separator: theme.separator,
                    isSecondary: true
                ))

                Button {
                    if let t = total, canCompute {
                        UIPasteboard.general.string = currency(t)
                    }
                    dismissKeyboard()
                } label: {
                    Label("Copy Total", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EVCPrimaryButtonStyle(
                    uiStyle: uiStyle,
                    accent: theme.accent,
                    onAccent: theme.onAccent,
                    corner: theme.smallCorner,
                    pillTint: theme.pillTint,
                    separator: theme.separator,
                    isSecondary: false
                ))
                .disabled(!(total != nil && canCompute))
            }
        }
    }

    // MARK: - Persistence

    private func loadLastUsed() {
        batteryCapacityText = batteryCapacityStored
        superchargerRateText = superRateStored
        addKWhText = addKWhStored
        feePerMinuteText = feePerMinuteStored
    }

    private func persistLastUsed() {
        batteryCapacityStored = batteryCapacityText
        superRateStored = superchargerRateText
        addKWhStored = addKWhText
        feePerMinuteStored = feePerMinuteText
    }

    private func resetDefaults() {
        batteryCapacityText = "75"
        superchargerRateText = "0.40"
        startPercent = 10
        endPercent = 80
        addKWhText = "20"
        includeFees = false
        feePerMinuteText = "0.50"
        feeMinutes = 0
        includeTax = false
        taxPercent = 8.625
        persistLastUsed()
    }
}

// MARK: - UI Components (AppThemeSpec-backed, glass-aware via uiStyle)

private struct EVCCard<Content: View>: View {
    @Environment(\.appThemeBox) private var appThemeBox
    private var theme: any AppThemeSpec { appThemeBox.base }

    let uiStyle: ToolsStyle
    private let title: String?
    private let subtitle: String?
    private let content: Content

    init(uiStyle: ToolsStyle, title: String? = nil, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.uiStyle = uiStyle
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    private var cardFill: AnyShapeStyle {
        switch uiStyle {
        case .classic:    return AnyShapeStyle(theme.cardBackground)
        case .teslaGlass: return AnyShapeStyle(.thinMaterial)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 3) {
                    if let title {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            content
        }
        .padding(theme.spacing)
        .background(
            RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                .fill(cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                        .strokeBorder(theme.separator.opacity(uiStyle == .teslaGlass ? 0.60 : 0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.10),
                        radius: theme.elevation,
                        x: 0,
                        y: uiStyle == .teslaGlass ? 2 : (theme.elevation * 0.6))
        )
    }
}

private struct EVCField: View {
    @Environment(\.appThemeBox) private var appThemeBox
    private var theme: any AppThemeSpec { appThemeBox.base }

    let uiStyle: ToolsStyle
    let title: String
    let unit: String?
    @Binding var text: String
    let placeholder: String
    let keyboard: UIKeyboardType
    let error: String?
    @FocusState.Binding var focus: EVCSuperchargeFocusField?
    let field: EVCSuperchargeFocusField

    private var hasError: Bool { (error != nil && !(error ?? "").isEmpty) }

    private var controlFill: AnyShapeStyle {
        switch uiStyle {
        case .classic:    return AnyShapeStyle(theme.pillTint.opacity(0.45))
        case .teslaGlass: return AnyShapeStyle(.ultraThinMaterial)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                if let unit {
                    Text(unit)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($focus, equals: field)
                    .font(.system(.body, design: .rounded))
                    .monospacedDigit()

                if hasError {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: theme.smallCorner, style: .continuous)
                    .fill(controlFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.smallCorner, style: .continuous)
                    .strokeBorder(hasError ? Color.red.opacity(0.85) : theme.separator.opacity(uiStyle == .teslaGlass ? 0.65 : 0.35),
                                  lineWidth: hasError ? 1.5 : 1)
            )

            if let error, !error.isEmpty {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct SliderRow: View {
    @Environment(\.appThemeBox) private var appThemeBox
    private var theme: any AppThemeSpec { appThemeBox.base }

    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let suffix: String
    var decimals: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                let shown: String = {
                    if decimals == 0 { return "\(Int(value.rounded()))" }
                    return value.formatted(.number.precision(.fractionLength(decimals)))
                }()
                Text("\(shown) \(suffix)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            let step: Double = (decimals == 0) ? 1 : pow(10, -Double(decimals))
            Slider(value: $value, in: range, step: step)
        }
    }
}

private struct KeyValueRow: View {
    let key: String
    let value: String
    var emphasizeValue: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(emphasizeValue ? .semibold : .regular))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

private struct StatChip: View {
    @Environment(\.appThemeBox) private var appThemeBox
    private var theme: any AppThemeSpec { appThemeBox.base }

    let uiStyle: ToolsStyle
    let title: String
    let value: String
    let icon: String

    private var chipFill: AnyShapeStyle {
        switch uiStyle {
        case .classic:    return AnyShapeStyle(theme.pillTint.opacity(0.45))
        case .teslaGlass: return AnyShapeStyle(.ultraThinMaterial)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.accent)
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.smallCorner, style: .continuous)
                .fill(chipFill)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.smallCorner, style: .continuous)
                        .strokeBorder(theme.separator.opacity(uiStyle == .teslaGlass ? 0.55 : 0.25), lineWidth: 1)
                )
        )
    }
}

private struct InfoBanner: View {
    @Environment(\.appThemeBox) private var appThemeBox
    private var theme: any AppThemeSpec { appThemeBox.base }

    let uiStyle: ToolsStyle
    let text: String
    let icon: String

    private var fill: AnyShapeStyle {
        switch uiStyle {
        case .classic:    return AnyShapeStyle(theme.pillTint.opacity(0.40))
        case .teslaGlass: return AnyShapeStyle(.ultraThinMaterial)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(theme.accent)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: theme.smallCorner, style: .continuous)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.smallCorner, style: .continuous)
                .strokeBorder(theme.separator.opacity(uiStyle == .teslaGlass ? 0.55 : 0.20), lineWidth: 1)
        )
    }
}

private struct EVCPrimaryButtonStyle: ButtonStyle {
    let uiStyle: ToolsStyle
    let accent: Color
    let onAccent: Color
    let corner: CGFloat
    let pillTint: Color
    let separator: Color
    let isSecondary: Bool

    func makeBody(configuration: Configuration) -> some View {
        let secondaryFill: AnyShapeStyle = {
            switch uiStyle {
            case .classic:    return AnyShapeStyle(pillTint.opacity(configuration.isPressed ? 0.55 : 0.40))
            case .teslaGlass: return AnyShapeStyle(.ultraThinMaterial)
            }
        }()

        return configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(
                        isSecondary
                        ? secondaryFill
                        : AnyShapeStyle(accent.opacity(configuration.isPressed ? 0.75 : 0.90))
                    )
            )
            .foregroundStyle(isSecondary ? Color.primary : onAccent)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(isSecondary ? separator.opacity(uiStyle == .teslaGlass ? 0.55 : 0.25) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
