// SettingsView.swift
// My EV Companion
//
// Brand-aware Settings screen.
// • Auto-switching theme preview
// • Performance revision:
//   ✅ SettingsColors cached as @State struct — UIKit color resolution runs once per theme/scheme
//      change instead of on every render pass (was: called 8+ times per body evaluation)
//   ✅ interfaceIsDark computed inside SettingsColors.make(), not as a live computed property
//   ✅ themePreviewCard extracted to Equatable struct — skips re-render when inputs unchanged
//   ✅ OnboardingFlowView.pages promoted to static let — array not reconstructed per render
//   ✅ resolvedThemeStyle cached as @State to avoid ThemeStyle.resolve() on every render
//   ✅ sectionHeader extracted to a tiny Equatable struct (avoids Text() rebuild per render)

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Cached color bundle

/// All derived colors for SettingsView, computed once per theme+scheme combination.
/// Avoids calling UIKit `UIColor.resolvedColor` on every render pass.
private struct SettingsColors: Equatable {
    let primary: Color
    let secondary: Color
    let rowBackground: Color
    let rowSeparator: Color
    let accent: Color

    static func make(theme: any AppThemeSpec, effectiveScheme: ColorScheme) -> SettingsColors {
        let isDark = Self.computeIsDark(cardBackground: theme.cardBackground, scheme: effectiveScheme)
        return SettingsColors(
            primary:      isDark ? Color(hex: "#F4F5F8") : Color(hex: "#15171B"),
            secondary:    isDark ? Color(hex: "#A2A8B5") : Color(hex: "#616A78"),
            rowBackground: theme.cardBackground,
            rowSeparator:  theme.separator,
            accent:        theme.accent
        )
    }

    // UIKit luminance check — called only when colors are rebuilt, not per-render
    private static func computeIsDark(cardBackground: Color, scheme: ColorScheme) -> Bool {
        #if canImport(UIKit)
        let style: UIUserInterfaceStyle = scheme == .dark ? .dark : .light
        let trait = UITraitCollection(userInterfaceStyle: style)
        let uiColor = UIColor(cardBackground).resolvedColor(with: trait)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return scheme == .dark }
        return (0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)) < 0.45
        #else
        return scheme == .dark
        #endif
    }
}

// MARK: - Theme preview card (Equatable — skips re-render when inputs unchanged)

private struct SettingsThemePreviewCard: View, Equatable {
    let themeName: String
    let themeIcon: String
    let subtitle: String
    let accent: Color
    let primary: Color
    let secondary: Color
    let rowBackground: Color
    let corner: CGFloat

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.themeName == rhs.themeName &&
        lhs.themeIcon == rhs.themeIcon &&
        lhs.subtitle  == rhs.subtitle &&
        lhs.corner    == rhs.corner
        // Colors intentionally excluded — if theme/scheme changes, SettingsColors rebuilds
        // and the parent re-renders, so this struct gets fresh inputs anyway.
    }

    var body: some View {
        let cardCorner = min(22, max(14, corner))
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(accent.opacity(0.22)).blur(radius: 10)
                Circle().fill(accent.opacity(0.15))
                Image(systemName: themeIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(themeName + " Theme")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(secondary)
            }

            Spacer()

            Circle()
                .fill(accent)
                .frame(width: 12, height: 12)
                .shadow(color: accent.opacity(0.28), radius: 6)
        }
        .padding(14)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Section header (tiny Equatable struct avoids Text() rebuild per render)

private struct SettingsSectionHeader: View, Equatable {
    let title: String
    let color: Color

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.title == rhs.title }

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
    }
}

// MARK: - Main View

@MainActor
public struct SettingsView: View {

    // MARK: - Dependencies
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore
    @EnvironmentObject private var budgetStore: BudgetStore
    @EnvironmentObject private var toolUsage: ToolUsageStore
    @EnvironmentObject private var uiSettings: AppUISettings
    @EnvironmentObject private var appearance:   AppAppearance
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme

    // MARK: - Settings state
    @AppStorage("settings.useMetric")        private var useMetric:        Bool   = false
    @AppStorage("settings.defaultHomeRate")  private var homeRate:          Double = 0.11
    @AppStorage("settings.defaultPublicRate") private var publicRate:       Double = 0.42
    @AppStorage("settings.efficiencyWhMi")   private var efficiencyWhMi:    Double = 310
    @AppStorage("settings.alertWeekly")      private var alertWeekly:       Bool   = true
    @AppStorage("settings.alertThreshold")   private var alertThreshold:    Double = 80
    @AppStorage("settings.dataRefresh")      private var dataRefreshMins:   Double = 30
    @AppStorage("weekly.alert.enabled")      private var weeklyAlert:        Bool   = true
    @AppStorage("weekly.alert.threshold")    private var weeklyThreshold:    Double = 80
    @AppStorage("themePreset")               private var themePresetRaw:    String = ThemeStyle.appDefault.rawValue
    @AppStorage("uiStyle")                   private var legacyUIStyleRaw:  String = "classic"
    @AppStorage("themePreset.userSet")       private var themePresetUserSet: Bool  = false
    @AppStorage(AppLocalization.Keys.marketRaw) private var marketRaw:      String = ""
    @AppStorage(AppLocalization.Keys.autoApplyMarketDefaults) private var autoApplyMarketDefaults: Bool = true
    @AppStorage(CoreMLFeatureFlags.liveSuperchargerPricingEnabledKey)
    private var useCoreMLLivePricing: Bool = CoreMLFeatureFlags.liveSuperchargerPricingEnabledDefault
    @AppStorage(CoreMLFeatureFlags.semanticToolSearchEnabledKey)
    private var useSemanticToolSearch: Bool = CoreMLFeatureFlags.semanticToolSearchEnabledDefault
    @AppStorage("ml.eval.lastSummary")
    private var mlEvalLastSummary: String = ""
    @AppStorage("ml.eval.lastRunTS")
    private var mlEvalLastRunTS: Double = 0
    @AppStorage("agent.enabled")
    private var agentEnabled: Bool = true

    // MARK: - UI state
    @State private var showingVehicleList = false
    @State private var isRunningMLEvaluation = false
    @State private var mlEvalStatusMessage: String = ""
    @State private var showResetConfirmation = false

    // MARK: - Cached derived state (recomputed only on theme/scheme change)

    @State private var colors: SettingsColors = .init(
        primary: .primary, secondary: .secondary,
        rowBackground: .clear, rowSeparator: .gray.opacity(0.3), accent: .accentColor
    )

    // Cache resolved theme style to avoid calling ThemeStyle.resolve() every render
    @State private var cachedThemeStyle: ThemeStyle = .classic

    // MARK: - Convenience accessors into cached colors

    private var theme: any AppThemeSpec { themeBox.base }

    private var effectiveColorScheme: ColorScheme {
        switch appearance.scheme {
        case .automatic: return scheme
        case .light:     return .light
        case .dark:      return .dark
        }
    }

    /// Rebuilds the color cache — called only when theme or scheme actually changes
    private func rebuildColors() {
        colors = SettingsColors.make(theme: theme, effectiveScheme: effectiveColorScheme)
        cachedThemeStyle = ThemeStyle.resolve(themePresetRaw: themePresetRaw, legacyUIStyleRaw: legacyUIStyleRaw)
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            ThemeBackground()

            List {
                themePreviewSection
                vehicleSection
                defaultRatesSection
                alertsSection
                displaySection
                localizationSection
                adsSection
                agentSection
                mlDiagnosticsSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .brandNavTitle("Settings")
        .sheet(isPresented: $showingVehicleList) {
            NavigationStack { VehicleProfileListView() }
        }
        .confirmationDialog(
            "Reset all app data?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset All Data", role: .destructive) {
                resetAllAppData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears vehicles, charging entries, imported session history, budgets, tool history, onboarding state, avatar, and saved settings on this device.")
        }
        .onAppear {
            if marketRaw.trimmedNonEmpty == nil {
                marketRaw = AppLocalization.inferredMarket().rawValue
            }
            rebuildColors()
        }
        .onChange(of: scheme) { _, _ in rebuildColors() }
        .onChange(of: themePresetRaw) { _, _ in rebuildColors() }
        .onChange(of: legacyUIStyleRaw) { _, _ in rebuildColors() }
        .onChange(of: appearance.scheme) { _, _ in rebuildColors() }
        .onChange(of: marketRaw) { _, _ in
            guard autoApplyMarketDefaults else { return }
            applyMarketDefaultsNow()
        }
        .onChange(of: autoApplyMarketDefaults) { _, enabled in
            if enabled { applyMarketDefaultsNow() }
        }
    }

    // MARK: - Theme preview section

    private var themePreviewSection: some View {
        Section {
            SettingsThemePreviewCard(
                themeName: cachedThemeStyle.title,
                themeIcon: themeIcon(for: cachedThemeStyle),
                subtitle:  themePreviewSubtitle,
                accent:    colors.accent,
                primary:   colors.primary,
                secondary: colors.secondary,
                rowBackground: colors.rowBackground,
                corner:    theme.corner
            )
            .equatable()
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    // MARK: - Vehicle section

    private var vehicleSection: some View {
        Section {
            if let v = profileStore.selectedVehicle {
                HStack {
                    Label(v.displayName, systemImage: "car.fill")
                        .font(.subheadline)
                        .foregroundStyle(colors.primary)
                    Spacer()
                    BrandBadge(
                        v.detectedBrand == .tesla ? "Tesla" : v.detectedBrand == .rivian ? "Rivian" : v.make,
                        style: v.detectedBrand == .tesla ? .danger : v.detectedBrand == .rivian ? .success : .muted
                    )
                }
                .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)
            }

            Button {
                showingVehicleList = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "car.2.fill")
                        .font(.subheadline.weight(.semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(colors.secondary)
                    Text("Manage Vehicles")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(colors.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(colors.secondary)
                }
            }
            .buttonStyle(.plain)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)
        } header: {
            SettingsSectionHeader(title: "Vehicle", color: colors.secondary).equatable()
        }
    }

    // MARK: - Default rates

    private var defaultRatesSection: some View {
        Section {
            rateRow("Home charging",  binding: $homeRate,       unit: "/kWh")
            rateRow("Public charging", binding: $publicRate,    unit: "/kWh")
            rateRow("Efficiency",      binding: $efficiencyWhMi, unit: " Wh/mi")
        } header: {
            SettingsSectionHeader(title: "Default Rates", color: colors.secondary).equatable()
        }
    }

    private func rateRow(_ label: String, binding: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(colors.primary)
            Spacer()
            TextField("0", value: binding, format: .number.precision(.fractionLength(2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(colors.accent)
            Text(unit).font(.footnote).foregroundStyle(colors.secondary)
        }
        .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        Section {
            Toggle(isOn: $weeklyAlert) {
                Label {
                    Text("Weekly cost alert").foregroundStyle(colors.primary)
                } icon: {
                    Image(systemName: "bell.badge.fill")
                        .symbolRenderingMode(.monochrome).foregroundStyle(colors.secondary)
                }
            }
            .tint(colors.accent)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            if weeklyAlert {
                HStack {
                    Label {
                        Text("Alert threshold").font(.subheadline).foregroundStyle(colors.primary)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .symbolRenderingMode(.monochrome).foregroundStyle(colors.secondary)
                    }
                    Spacer()
                    Text(weeklyThreshold.formatted(.currency(code: AppLocalization.currencyCode)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(colors.accent)
                        .monospacedDigit()
                }
                .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

                Slider(value: $weeklyThreshold, in: 20...500, step: 5)
                    .tint(colors.accent)
                    .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)
            }
        } header: {
            SettingsSectionHeader(title: "Alerts", color: colors.secondary).equatable()
        }
    }

    // MARK: - Display

    private var displaySection: some View {
        Section {
            Picker("Theme", selection: themeStyleBinding) {
                ForEach(ThemeStyle.allCases) { style in Text(style.title).tag(style) }
            }
            .tint(colors.accent)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            Picker("Appearance", selection: appearanceModeBinding) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(appearanceLabel(for: mode)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .tint(colors.accent)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            LabeledContent("Current") {
                Text(effectiveAppearanceLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(colors.secondary)
            }
            .foregroundStyle(colors.primary)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            Toggle(isOn: $useMetric) {
                Label {
                    Text("Metric units (km)").foregroundStyle(colors.primary)
                } icon: {
                    Image(systemName: "ruler.fill")
                        .symbolRenderingMode(.monochrome).foregroundStyle(colors.secondary)
                }
            }
            .tint(colors.accent)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            HStack {
                Label {
                    Text("Accent color").font(.subheadline).foregroundStyle(colors.primary)
                } icon: {
                    Image(systemName: "paintpalette.fill")
                        .symbolRenderingMode(.monochrome).foregroundStyle(colors.secondary)
                }
                Spacer()
                Text("Auto (brand)").font(.footnote).foregroundStyle(colors.secondary)
                Circle().fill(colors.accent).frame(width: 20, height: 20)
            }
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)
        } header: {
            SettingsSectionHeader(title: "Display & Units", color: colors.secondary).equatable()
        }
    }

    // MARK: - Localization

    private var localizationSection: some View {
        Section {
            Picker("Market", selection: selectedMarketBinding) {
                ForEach(AppMarket.allCases) { market in Text(market.title).tag(market) }
            }
            .foregroundStyle(colors.primary)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            Toggle(isOn: $autoApplyMarketDefaults) {
                Label {
                    Text("Auto-apply market defaults").foregroundStyle(colors.primary)
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .symbolRenderingMode(.monochrome).foregroundStyle(colors.secondary)
                }
            }
            .tint(colors.accent)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            LabeledContent("Locale") {
                Text(selectedMarket.localeIdentifier)
                    .font(.footnote.monospaced()).foregroundStyle(colors.secondary)
            }
            .foregroundStyle(colors.primary)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            LabeledContent("Currency") {
                Text(selectedMarket.currencyCode)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(colors.accent)
            }
            .foregroundStyle(colors.primary)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            LabeledContent("Distance units") {
                Text(selectedMarket.defaultDistanceUnit == .kilometers ? "Kilometers" : "Miles")
                    .foregroundStyle(colors.secondary)
            }
            .foregroundStyle(colors.primary)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            if !autoApplyMarketDefaults {
                Button {
                    applyMarketDefaultsNow()
                } label: {
                    Label("Apply Market Defaults Now", systemImage: "checkmark.circle")
                }
                .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)
            }
        } header: {
            SettingsSectionHeader(title: "Localization", color: colors.secondary).equatable()
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)
                .font(.subheadline).foregroundStyle(colors.primary)
                .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            Link(destination: URL(string: "https://qualtricsxmm8q5gxrhq.qualtrics.com/jfe/form/SV_1TvkCrIKgaEYHPM")!) {
                Label("Suggestions & Bug Reports", systemImage: "exclamationmark.bubble.fill")
                    .font(.subheadline)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(colors.accent)
            }
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label("Reset App Data", systemImage: "trash.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.85, green: 0.23, blue: 0.20))
            }
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)
        } header: {
            SettingsSectionHeader(title: "About", color: colors.secondary).equatable()
        }
    }

    // MARK: - Ads

    private var adsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Ad experience", systemImage: "megaphone.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colors.primary)

                Text("Banner ads appear on supported screens to help fund ongoing development.")
                    .font(.subheadline)
                    .foregroundStyle(colors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            LabeledContent("Active banner unit") {
                Text(AdsConfig.bannerAdUnitID)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(colors.secondary)
            }
            .foregroundStyle(colors.primary)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            if GoogleMobileAdsConsentManager.shared.isPrivacyOptionsRequired {
                Button {
                    Task {
                        await GoogleMobileAdsConsentManager.shared.presentPrivacyOptionsForm()
                    }
                } label: {
                    Label {
                        Text("Manage ad privacy choices").foregroundStyle(colors.primary)
                    } icon: {
                        Image(systemName: "hand.raised.fill")
                            .symbolRenderingMode(.monochrome).foregroundStyle(colors.secondary)
                    }
                }
                .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)
            }
        } header: {
            SettingsSectionHeader(title: "Ads", color: colors.secondary).equatable()
        }
    }

    private var agentSection: some View {
        Section {
            Toggle(isOn: $agentEnabled) {
                Label {
                    Text("Enable AI Copilot").foregroundStyle(colors.primary)
                } icon: {
                    Image(systemName: "sparkles")
                        .symbolRenderingMode(.monochrome).foregroundStyle(colors.secondary)
                }
            }
            .tint(colors.accent)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            Text("Copilot currently runs on-device and action-gates writes back into your data.")
                .font(.footnote)
                .foregroundStyle(colors.secondary)
                .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)
        } header: {
            SettingsSectionHeader(title: "Agent", color: colors.secondary).equatable()
        }
    }

    // MARK: - ML & Diagnostics

    private var livePricingEngineForSettings: any SuperchargerLivePriceEngine {
        if useCoreMLLivePricing {
            return CoreMLSuperchargerLivePriceEnginePlaceholder()
        }
        return RuleBasedSuperchargerLivePriceEngine()
    }

    private var toolRankingEngineForSettings: any ToolSemanticRankingEngine {
        if useSemanticToolSearch {
            return CoreMLToolSemanticRankingEnginePlaceholder()
        }
        return DisabledToolSemanticRankingEngine()
    }

    private var mlDiagnosticsSection: some View {
        Section {
            Toggle(isOn: $useCoreMLLivePricing) {
                Label {
                    Text("Core ML live pricing").foregroundStyle(colors.primary)
                } icon: {
                    Image(systemName: "bolt.badge.clock")
                        .symbolRenderingMode(.monochrome).foregroundStyle(colors.secondary)
                }
            }
            .tint(colors.accent)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            Toggle(isOn: $useSemanticToolSearch) {
                Label {
                    Text("Semantic tool search").foregroundStyle(colors.primary)
                } icon: {
                    Image(systemName: "magnifyingglass.circle")
                        .symbolRenderingMode(.monochrome).foregroundStyle(colors.secondary)
                }
            }
            .tint(colors.accent)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            LabeledContent("Live pricing engine") {
                Text(livePricingEngineForSettings.healthReport.state.rawValue.capitalized)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(colors.secondary)
            }
            .foregroundStyle(colors.primary)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            LabeledContent("Tool ranking engine") {
                Text(toolRankingEngineForSettings.healthReport.state.rawValue.capitalized)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(colors.secondary)
            }
            .foregroundStyle(colors.primary)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            Button {
                guard !isRunningMLEvaluation else { return }
                Task { await runOfflineMLEvaluation() }
            } label: {
                HStack {
                    if isRunningMLEvaluation {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Label("Run Offline ML Evaluation", systemImage: "waveform.path.ecg")
                }
                .foregroundStyle(colors.accent)
            }
            .disabled(isRunningMLEvaluation)
            .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)

            if !mlEvalStatusMessage.isEmpty {
                Text(mlEvalStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(colors.secondary)
                    .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)
            }

            if mlEvalLastRunTS > 0 {
                let ts = Date(timeIntervalSince1970: mlEvalLastRunTS)
                Text("Last run: \(ts.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(colors.secondary)
                    .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)
            }
            if !mlEvalLastSummary.isEmpty {
                Text(mlEvalLastSummary)
                    .font(.footnote)
                    .foregroundStyle(colors.secondary)
                    .settingsListRow(background: colors.rowBackground, separator: colors.rowSeparator)
            }
        } header: {
            SettingsSectionHeader(title: "ML & Diagnostics", color: colors.secondary).equatable()
        }
    }

    // MARK: - Helpers (pure, no UIKit)

    private func themeIcon(for style: ThemeStyle) -> String {
        switch style {
        case .classic: return "sparkles"
        case .tesla:   return "bolt.car.fill"
        case .rivian:  return "leaf.fill"
        case .tessie:  return "chart.line.uptrend.xyaxis"
        case .modern:  return "square.grid.2x2.fill"
        case .orange:  return "sun.max.fill"
        }
    }

    private var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "—"
    }

    private var selectedMarket: AppMarket { AppLocalization.market(fromRaw: marketRaw) }

    private var selectedMarketBinding: Binding<AppMarket> {
        Binding(get: { selectedMarket }, set: { marketRaw = $0.rawValue })
    }

    private var appearanceModeBinding: Binding<AppearanceMode> {
        Binding(get: { appearance.scheme }, set: { appearance.scheme = $0 })
    }

    private var themeStyleBinding: Binding<ThemeStyle> {
        Binding(get: { cachedThemeStyle }, set: { applyThemePreset($0) })
    }

    private var themePreviewSubtitle: String {
        switch appearance.scheme {
        case .automatic: return "Selected in Settings, follows system Light/Dark"
        case .light:     return "Selected in Settings, currently Light mode"
        case .dark:      return "Selected in Settings, currently Dark mode"
        }
    }

    private var effectiveAppearanceLabel: String {
        switch appearance.scheme {
        case .automatic: return effectiveColorScheme == .dark ? "System Dark" : "System Light"
        case .light:     return "Light"
        case .dark:      return "Dark"
        }
    }

    private func appearanceLabel(for mode: AppearanceMode) -> String {
        switch mode {
        case .automatic: return "System"
        case .light:     return "Light"
        case .dark:      return "Dark"
        }
    }

    private func applyThemePreset(_ style: ThemeStyle) {
        themePresetRaw    = style.rawValue
        themePresetUserSet = true
        switch style {
        case .classic: appearance.accentChoice = .red
        case .tessie:  appearance.accentChoice = .blue
        case .tesla:   appearance.accentChoice = .blue
        case .rivian:  appearance.accentChoice = .yellow
        case .modern:  appearance.accentChoice = .yellow
        case .orange:  appearance.accentChoice = .orange
        }
    }

    private func applyMarketDefaultsNow() {
        AppLocalization.applyMarketDefaults(selectedMarket, profileStore: profileStore)
    }

    private func runOfflineMLEvaluation() async {
        isRunningMLEvaluation = true
        defer { isRunningMLEvaluation = false }

        let toolSnapshot = CoreMLEvaluationHarness.evaluateToolSearch(
            semanticEnabled: useSemanticToolSearch,
            rankingEngine: toolRankingEngineForSettings
        )

        let historySnapshot = CoreMLEvaluationHarness.evaluateSuperchargerHistory(
            samples: SuperchargerPriceStore.shared.allSamples
        )

        do {
            let toolURL = try CoreMLEvaluationHarness.writeSnapshot(toolSnapshot, prefix: "tool_search_eval")
            let historyURL = try CoreMLEvaluationHarness.writeSnapshot(historySnapshot, prefix: "supercharger_history_eval")

            let summary = String(
                format: "MRR %.3f · Hit@3 %.1f%% · Hit@5 %.1f%% · samples %d across %d stations",
                toolSnapshot.meanReciprocalRank,
                toolSnapshot.hitRateAt3 * 100.0,
                toolSnapshot.hitRateAt5 * 100.0,
                historySnapshot.totalSamples,
                historySnapshot.stationCount
            )

            mlEvalLastSummary = summary
            mlEvalLastRunTS = Date().timeIntervalSince1970
            mlEvalStatusMessage = "Saved: \(toolURL.lastPathComponent), \(historyURL.lastPathComponent)"
        } catch {
            mlEvalStatusMessage = "Evaluation failed: \(error.localizedDescription)"
        }
    }

    private func resetAllAppData() {
        entriesStore.clearAll()
        teslaFiStore.clear()
        profileStore.vehicles = []
        profileStore.setSelected(nil as UUID?)
        budgetStore.clearAllPlans()
        toolUsage.clearAllData()

        let defaults = UserDefaults.standard
        let resetKeys = [
            "settings.useMetric",
            "settings.defaultHomeRate",
            "settings.defaultPublicRate",
            "settings.efficiencyWhMi",
            "settings.alertWeekly",
            "settings.alertThreshold",
            "settings.dataRefresh",
            "weekly.alert.enabled",
            "weekly.alert.threshold",
            "themePreset",
            "uiStyle",
            "themePreset.userSet",
            AppLocalization.Keys.marketRaw,
            AppLocalization.Keys.autoApplyMarketDefaults,
            CoreMLFeatureFlags.liveSuperchargerPricingEnabledKey,
            CoreMLFeatureFlags.semanticToolSearchEnabledKey,
            "ml.eval.lastSummary",
            "ml.eval.lastRunTS",
            "agent.enabled",
            "agent.cloudEnabled",
            "defaultCurrencyCode",
            "dashboard.moreCardsPrompted",
            "budget_useCategoryBudgets",
            "monthlyBudgetLimit",
            "budget_supercharging",
            "budget_lease",
            "budget_insurance",
            "budget_misc",
            "onboarding.v2.completed",
            "permissions.bootstrap.completed",
            "kwh.userAvatarJPEG"
        ]

        for key in resetKeys {
            defaults.removeObject(forKey: key)
        }

        appearance.resetToDefaults()
        uiSettings.resetToDefaults()

        useMetric = false
        homeRate = 0.11
        publicRate = 0.42
        efficiencyWhMi = 310
        alertWeekly = true
        alertThreshold = 80
        dataRefreshMins = 30
        weeklyAlert = true
        weeklyThreshold = 80
        themePresetRaw = ThemeStyle.appDefault.rawValue
        legacyUIStyleRaw = "classic"
        themePresetUserSet = false
        marketRaw = AppLocalization.inferredMarket().rawValue
        autoApplyMarketDefaults = true
        useCoreMLLivePricing = CoreMLFeatureFlags.liveSuperchargerPricingEnabledDefault
        useSemanticToolSearch = CoreMLFeatureFlags.semanticToolSearchEnabledDefault
        mlEvalLastSummary = ""
        mlEvalLastRunTS = 0
        agentEnabled = true
        mlEvalStatusMessage = ""

        applyMarketDefaultsNow()
        rebuildColors()
    }
}

// MARK: - Row modifier

private struct SettingsListRowModifier: ViewModifier {
    let background: Color
    let separator: Color

    func body(content: Content) -> some View {
        content
            .listRowBackground(background)
            .listRowSeparatorTint(separator)
    }
}

private extension View {
    func settingsListRow(background: Color, separator: Color) -> some View {
        modifier(SettingsListRowModifier(background: background, separator: separator))
    }
}
