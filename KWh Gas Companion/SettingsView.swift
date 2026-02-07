//
//  SettingsView 2.swift
//  KWh Gas Companion
//
//  Created by Bryan on 1/26/26.
//


//
//  SettingsView.swift
//  KWh Gas Companion
//
//  Glass-mode correctness:
//  - When uiStyle == "teslaGlass", settings surfaces render on .thinMaterial (glass)
//  - When classic, settings surfaces use theme.cardBackground
//  - Screen background uses theme.screenBackground + subtle accent glow
//
//  Swift 6 • iOS 17+
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct SettingsView: View {

    // Theme + look
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var appearance: AppAppearance
    @EnvironmentObject private var uiSettings: AppUISettings

    // Data stores (used for counts + hub links)
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore
    @StateObject private var adsStore = AdsEntitlementStore.shared
    @StateObject private var proStore = TeslaMateProStore.shared
    @StateObject private var teslaFiUnlock = TeslaFiEntitlementStore.shared

    // ThemeBinder reads/writes this key
    @AppStorage("uiStyle") private var uiStyleRaw: String = "teslaGlass"

    // ✅ App Icon selection (primary + alternates)
    @AppStorage("appearance.appIcon") private var appIconRaw: String = AppIconChoice.appIcon.rawValue
    @State private var showingIconError: Bool = false
    @State private var iconErrorMessage: String = ""

    // Common preferences
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String =
        (Locale.current.currency?.identifier ?? "USD")
    @AppStorage("settings.measurementSystem") private var measurementSystem: String = "auto" // auto|imperial|metric
    @AppStorage("settings.notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("categorize.enabled") private var autoCategorizeEnabled: Bool = true
    @AppStorage("categorize.autoApply") private var autoCategorizeAutoApply: Bool = true
    @AppStorage("categorize.learn") private var autoCategorizeLearn: Bool = true

    @State private var showingResetConfirm: Bool = false

    private var theme: any AppThemeSpec { themeBox.base }
    private var uiStyle: ToolsStyle { ToolsStyle(rawValue: uiStyleRaw) ?? .classic }
    private var selectedAppIcon: AppIconChoice { AppIconChoice(rawValue: appIconRaw) ?? .appIcon }

    private var appVersionText: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    // MARK: - Glass + Background

    private var cardBackground: AnyShapeStyle {
        switch uiStyle {
        case .classic:
            return AnyShapeStyle(theme.cardBackground)
        case .teslaGlass:
            return AnyShapeStyle(.thinMaterial)
        }
    }

    private enum ThemePreset: String, CaseIterable, Identifiable {
        case teslaOfficial
        case tesla
        case minimal
        case neon
        case classic

        var id: String { rawValue }

        var title: String {
            switch self {
            case .teslaOfficial: return "Tesla Official"
            case .tesla: return "Tesla"
            case .minimal: return "Minimal"
            case .neon: return "Neon"
            case .classic: return "Classic"
            }
        }

        var subtitle: String {
            switch self {
            case .teslaOfficial: return "Crisp, tight, low‑chrome"
            case .tesla: return "Glass + red glow"
            case .minimal: return "Low chrome"
            case .neon: return "Bold accent"
            case .classic: return "System surfaces"
            }
        }
    }

    private var presetRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Theme Presets")
                .font(.subheadline.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ThemePreset.allCases) { preset in
                        Button {
                            applyPreset(preset)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(presetAccent(preset).opacity(0.25))
                                        .overlay(
                                            Image(systemName: presetSymbol(preset))
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(presetAccent(preset))
                                        )
                                        .frame(width: 26, height: 26)

                                    Text(preset.title)
                                        .font(.footnote.weight(.semibold))

                                    Spacer()

                                    if isPresetActive(preset) {
                                        Text("Active")
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(appearance.accentColor.opacity(0.18)))
                                    }
                                }

                                Text(preset.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .frame(width: 150, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(theme.cardBackground.opacity(isPresetActive(preset) ? 0.95 : 0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(
                                                isPresetActive(preset) ? appearance.accentColor.opacity(0.6)
                                                : theme.separator.opacity(0.5),
                                                lineWidth: isPresetActive(preset) ? 1.5 : 1
                                            )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func presetSymbol(_ preset: ThemePreset) -> String {
        switch preset {
        case .teslaOfficial: return "bolt.circle.fill"
        case .tesla: return "bolt.fill"
        case .minimal: return "circle.dashed"
        case .neon: return "sparkles"
        case .classic: return "square.grid.2x2"
        }
    }

    private func presetAccent(_ preset: ThemePreset) -> Color {
        switch preset {
        case .neon: return .cyan
        case .minimal: return .gray
        case .classic: return .blue
        default: return appearance.accentColor
        }
    }

    private func isPresetActive(_ preset: ThemePreset) -> Bool {
        switch preset {
        case .teslaOfficial:
            return uiStyleRaw == ToolsStyle.teslaGlass.rawValue
                && appearance.accentChoice == .red
                && uiSettings.cardStyle == .glass
                && uiSettings.background == .carbon
                && uiSettings.typography == .bold
                && uiSettings.density == .compact
                && uiSettings.cardCorner == .crisp
                && uiSettings.cardPadding == .tight
                && uiSettings.motion == .reduced
        case .tesla:
            return uiStyleRaw == ToolsStyle.teslaGlass.rawValue
                && appearance.accentChoice == .red
                && uiSettings.cardStyle == .glass
                && uiSettings.background == .defaultGlow
        case .minimal:
            return uiSettings.cardStyle == .flat && uiSettings.background == .defaultGlow
        case .neon:
            return appearance.accentChoice != .red && uiSettings.background == .aurora
        case .classic:
            return uiStyleRaw == ToolsStyle.classic.rawValue
        }
    }

    private var appearanceSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Appearance Summary", systemImage: "paintbrush")
                    .font(.headline)
                Spacer()
                Text("Live preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                summaryChip("Theme", appearance.scheme.title)
                summaryChip("Accent", appearance.accentChoice.title)
                summaryChip("Motion", uiSettings.motion.title)
            }

            HStack(spacing: 8) {
                summaryChip("Density", uiSettings.density.title)
                summaryChip("Corners", uiSettings.cardCorner.title)
                summaryChip("Padding", uiSettings.cardPadding.title)
            }
        }
        .themedCard()
    }

    private func summaryChip(_ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(theme.pillTint.opacity(0.6)))
    }

    private var screenBackground: some View {
        let accent = appearance.accentColor
        return ZStack {
            Rectangle()
                .fill(theme.screenBackground)
                .ignoresSafeArea()

            switch uiSettings.background {
            case .defaultGlow:
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

            case .aurora:
                RadialGradient(
                    colors: [accent.opacity(scheme == .dark ? 0.22 : 0.14), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 640
                )
                .blur(radius: 32)
                .ignoresSafeArea()

                RadialGradient(
                    colors: [Color.green.opacity(scheme == .dark ? 0.20 : 0.12), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 680
                )
                .blur(radius: 36)
                .ignoresSafeArea()

            case .dusk:
                RadialGradient(
                    colors: [Color.orange.opacity(scheme == .dark ? 0.18 : 0.12), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 520
                )
                .blur(radius: 30)
                .ignoresSafeArea()

                RadialGradient(
                    colors: [Color.purple.opacity(scheme == .dark ? 0.18 : 0.10), .clear],
                    center: .bottom,
                    startRadius: 0,
                    endRadius: 620
                )
                .blur(radius: 36)
                .ignoresSafeArea()

            case .carbon:
                LinearGradient(
                    colors: [
                        Color.black.opacity(scheme == .dark ? 0.65 : 0.10),
                        Color.black.opacity(scheme == .dark ? 0.25 : 0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.overlay)
                .ignoresSafeArea()

            case .blackHistoryMonth:
                LinearGradient(
                    colors: [
                        Color.black.opacity(scheme == .dark ? 0.75 : 0.25),
                        Color(red: 0.35, green: 0.16, blue: 0.05).opacity(scheme == .dark ? 0.45 : 0.20),
                        Color(red: 0.75, green: 0.60, blue: 0.20).opacity(scheme == .dark ? 0.35 : 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.overlay)
                .ignoresSafeArea()

            case .christmas:
                RadialGradient(
                    colors: [Color.red.opacity(scheme == .dark ? 0.28 : 0.18), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 520
                )
                .blur(radius: 30)
                .ignoresSafeArea()
                RadialGradient(
                    colors: [Color.green.opacity(scheme == .dark ? 0.24 : 0.14), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 620
                )
                .blur(radius: 34)
                .ignoresSafeArea()

            case .lunarNewYear:
                RadialGradient(
                    colors: [Color.red.opacity(scheme == .dark ? 0.30 : 0.20), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 560
                )
                .blur(radius: 30)
                .ignoresSafeArea()
                RadialGradient(
                    colors: [Color.yellow.opacity(scheme == .dark ? 0.26 : 0.16), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 640
                )
                .blur(radius: 36)
                .ignoresSafeArea()

            case .halloween:
                RadialGradient(
                    colors: [Color.orange.opacity(scheme == .dark ? 0.28 : 0.18), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 520
                )
                .blur(radius: 30)
                .ignoresSafeArea()
                RadialGradient(
                    colors: [Color.purple.opacity(scheme == .dark ? 0.26 : 0.16), .clear],
                    center: .bottom,
                    startRadius: 0,
                    endRadius: 620
                )
                .blur(radius: 36)
                .ignoresSafeArea()

            case .thanksgiving:
                RadialGradient(
                    colors: [Color(red: 0.65, green: 0.36, blue: 0.12).opacity(scheme == .dark ? 0.28 : 0.18), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 520
                )
                .blur(radius: 30)
                .ignoresSafeArea()
                RadialGradient(
                    colors: [Color.orange.opacity(scheme == .dark ? 0.20 : 0.12), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 620
                )
                .blur(radius: 34)
                .ignoresSafeArea()

            case .newYear:
                RadialGradient(
                    colors: [Color.blue.opacity(scheme == .dark ? 0.24 : 0.14), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 560
                )
                .blur(radius: 30)
                .ignoresSafeArea()
                RadialGradient(
                    colors: [Color.white.opacity(scheme == .dark ? 0.18 : 0.10), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 640
                )
                .blur(radius: 36)
                .ignoresSafeArea()
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing + 12) {
                appearanceSummaryCard

                // MARK: Appearance
                SettingsCard(title: "Appearance", icon: "paintbrush", theme: theme, background: cardBackground) {

                    presetRow

                    Divider().opacity(0.7)

                    NavigationLink {
                        ThemeModePickerView(selection: $appearance.scheme)
                            .navigationTitle("Theme")
                            .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
                    } label: {
                        SettingsRow(
                            title: "Theme",
                            subtitle: appearance.scheme.title,
                            systemImage: "circle.lefthalf.filled",
                            accent: appearance.accentColor
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().opacity(0.7)

                    NavigationLink {
                        AccentPickerView(selection: $appearance.accentChoice)
                            .navigationTitle("Accent")
                            .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(systemImage: "paintpalette", accent: appearance.accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Accent")
                                    .font(.body.weight(.semibold))
                                Text(appearance.accentChoice.title)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Circle()
                                .fill(appearance.accentColor)
                                .frame(width: 14, height: 14)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider().opacity(0.7)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            SettingsIcon(systemImage: "square.on.square", accent: appearance.accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("UI Style")
                                    .font(.body.weight(.semibold))
                                Text(uiStyle == .teslaGlass ? "Glass surfaces (material)" : "Classic surfaces")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }

                        Picker("UI Style", selection: $uiStyleRaw) {
                            Text("Classic").tag(ToolsStyle.classic.rawValue)
                            Text("Glass").tag(ToolsStyle.teslaGlass.rawValue)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("UI Style")
                    }

                    Divider().opacity(0.7)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            SettingsIcon(systemImage: "textformat.size", accent: appearance.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Typography")
                                    .font(.body.weight(.semibold))
                                Text(uiSettings.typography.title)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        Picker("Typography", selection: $uiSettings.typography) {
                            ForEach(TypographyMode.allCases) { t in
                                Text(t.title).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Divider().opacity(0.7)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            SettingsIcon(systemImage: "rectangle.3.offgrid", accent: appearance.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Card Style")
                                    .font(.body.weight(.semibold))
                                Text(uiSettings.cardStyle.title)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        Picker("Card Style", selection: $uiSettings.cardStyle) {
                            ForEach(CardStyleMode.allCases) { s in
                                Text(s.title).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Divider().opacity(0.7)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            SettingsIcon(systemImage: "squareroot", accent: appearance.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Corner Radius")
                                    .font(.body.weight(.semibold))
                                Text(uiSettings.cardCorner.title)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        Picker("Corner Radius", selection: $uiSettings.cardCorner) {
                            ForEach(CardCornerMode.allCases) { c in
                                Text(c.title).tag(c)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Divider().opacity(0.7)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            SettingsIcon(systemImage: "arrow.up.left.and.arrow.down.right", accent: appearance.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Card Padding")
                                    .font(.body.weight(.semibold))
                                Text(uiSettings.cardPadding.title)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        Picker("Card Padding", selection: $uiSettings.cardPadding) {
                            ForEach(CardPaddingMode.allCases) { p in
                                Text(p.title).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Divider().opacity(0.7)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            SettingsIcon(systemImage: "arrow.up.and.down.text.horizontal", accent: appearance.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Density")
                                    .font(.body.weight(.semibold))
                                Text(uiSettings.density.title)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        Picker("Density", selection: $uiSettings.density) {
                            ForEach(DensityMode.allCases) { d in
                                Text(d.title).tag(d)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Divider().opacity(0.7)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            SettingsIcon(systemImage: "sun.max", accent: appearance.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Background")
                                    .font(.body.weight(.semibold))
                                Text(uiSettings.background.title)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        Picker("Background", selection: $uiSettings.background) {
                            ForEach(BackgroundStyle.allCases) { b in
                                Text(b.title).tag(b)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Divider().opacity(0.7)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            SettingsIcon(systemImage: "sparkles", accent: appearance.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Motion")
                                    .font(.body.weight(.semibold))
                                Text(uiSettings.motion.title)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        Picker("Motion", selection: $uiSettings.motion) {
                            ForEach(MotionMode.allCases) { m in
                                Text(m.title).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // ✅ NEW: App Icon picker (includes AppIconFunny)
                    Divider().opacity(0.7)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            SettingsIcon(systemImage: "app.badge", accent: appearance.accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("App Icon")
                                    .font(.body.weight(.semibold))
                                Text(selectedAppIcon.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }

                        if supportsAlternateIcons {
                            Picker("App Icon", selection: $appIconRaw) {
                                ForEach(AppIconChoice.allCases) { choice in
                                    Text(choice.title).tag(choice.rawValue)
                                }
                            }
                            .pickerStyle(.menu) // 4 options reads better than segmented
                            .onChange(of: appIconRaw) { oldValue, newValue in
                                applyAppIcon(oldRaw: oldValue, newRaw: newValue)
                            }
                            .accessibilityLabel("App Icon")
                        } else {
                            Text("Alternate app icons aren’t available on this device.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: Display & Units
                SettingsCard(title: "Display & Units", icon: "ruler", theme: theme, background: cardBackground) {

                    SettingsPickerRow(
                        title: "Currency",
                        systemImage: "dollarsign.circle",
                        accent: appearance.accentColor
                    ) {
                        Picker("Currency", selection: $defaultCurrencyCode) {
                            Text("USD").tag("USD")
                            Text("CAD").tag("CAD")
                            Text("EUR").tag("EUR")
                            Text("GBP").tag("GBP")
                            Text("JPY").tag("JPY")
                        }
                        .pickerStyle(.menu)
                    }

                    Divider().opacity(0.7)

                    SettingsPickerRow(
                        title: "Measurement",
                        systemImage: "speedometer",
                        accent: appearance.accentColor
                    ) {
                        Picker("Measurement", selection: $measurementSystem) {
                            Text("Auto").tag("auto")
                            Text("Imperial").tag("imperial")
                            Text("Metric").tag("metric")
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // MARK: Data
                SettingsCard(title: "Data", icon: "tray.and.arrow.down", theme: theme, background: cardBackground) {

                    NavigationLink {
                        ChargingDataHubView()
                            .navigationTitle("Charging Data")
                            .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
                    } label: {
                        SettingsRow(
                            title: "Charging Data Hub",
                            subtitle: "Sessions, integrity, reconciliation",
                            systemImage: "bolt.car",
                            accent: appearance.accentColor
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().opacity(0.7)

                    NavigationLink {
                        ChargingImportHubView()
                            .navigationTitle("Import Charging")
                            .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
                    } label: {
                        SettingsRow(
                            title: "Import Charging Data",
                            subtitle: "CSV + sources",
                            systemImage: "tray.and.arrow.down",
                            accent: appearance.accentColor
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().opacity(0.7)

                    NavigationLink {
                        TeslaFiCSVImportView()
                            .navigationTitle("TeslaFi Import")
                            .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
                    } label: {
                        SettingsRow(
                            title: "Import TeslaFi CSV",
                            subtitle: teslaFiUnlock.hasTeslaFiUnlock ? "Charging sessions" : "Requires $0.99 unlock",
                            systemImage: "doc.text",
                            accent: appearance.accentColor
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().opacity(0.7)

                    NavigationLink {
                        CSVChargingWizardView()
                            .navigationTitle("CSV Wizard")
                            .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
                    } label: {
                        SettingsRow(
                            title: "CSV Charging Wizard",
                            subtitle: "Clean + validate + import",
                            systemImage: "wand.and.stars",
                            accent: appearance.accentColor
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().opacity(0.7)

                    SettingsValueRow(title: "Entries", value: "\(entriesStore.entries.count)", systemImage: "list.bullet.rectangle")
                    if teslaFiUnlock.hasTeslaFiUnlock {
                        SettingsValueRow(title: "TeslaFi Sessions", value: "\(teslaFiStore.sessions.count)", systemImage: "bolt.car")
                    } else {
                        SettingsValueRow(title: "TeslaFi Sessions", value: "Locked", systemImage: "bolt.car")
                    }

                    if teslaFiUnlock.hasTeslaFiUnlock, !teslaFiStore.canonicalSessions.isEmpty {
                        SettingsValueRow(title: "Canonical Sessions", value: "\(teslaFiStore.canonicalSessions.count)", systemImage: "checkmark.shield")
                    }
                }

                // MARK: Preferences
                SettingsCard(title: "Preferences", icon: "slider.horizontal.3", theme: theme, background: cardBackground) {

                    Toggle(isOn: $notificationsEnabled) {
                        HStack(spacing: 12) {
                            SettingsIcon(systemImage: "bell.badge", accent: appearance.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Notifications")
                                    .font(.body.weight(.semibold))
                                Text("Alerts and reminders")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .toggleStyle(.switch)

                    Divider().opacity(0.7)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            SettingsIcon(systemImage: "hand.tap", accent: appearance.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Haptics")
                                    .font(.body.weight(.semibold))
                                Text("Tactile feedback")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        Picker("Haptics", selection: $uiSettings.haptics) {
                            ForEach(HapticsLevel.allCases) { h in
                                Text(h.title).tag(h)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Divider().opacity(0.7)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            SettingsIcon(systemImage: "brain.head.profile", accent: appearance.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Smart Categorization")
                                    .font(.body.weight(.semibold))
                                Text("Suggest and learn expense categories")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        Toggle("Enable suggestions", isOn: $autoCategorizeEnabled)
                        Toggle("Auto‑apply suggestion", isOn: $autoCategorizeAutoApply)
                        Toggle("Learn my choices", isOn: $autoCategorizeLearn)
                    }
                }

                // MARK: Pro
                SettingsCard(title: "Pro", icon: "bolt.fill", theme: theme, background: cardBackground) {
                    HStack(spacing: 12) {
                        SettingsIcon(systemImage: "bolt.fill", accent: appearance.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TeslaMate Client")
                                .font(.body.weight(.semibold))
                            Text(proStore.isProActive ? "Active" : "Locked")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    Divider().opacity(0.7)

                    Text("Connect directly to your TeslaMate server for dashboards, activities, geofence costs, widgets, and Live Activities.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    NavigationLink {
                        TeslaMateProClientView()
                    } label: {
                        SettingsRow(
                            title: "Open TeslaMate Client",
                            subtitle: proStore.isProActive ? "Manage connection and dashboards" : "Subscribe to unlock",
                            systemImage: "server.rack",
                            accent: appearance.accentColor
                        )
                    }
                    .buttonStyle(.plain)

                    if let error = proStore.lastError, !error.isEmpty {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                // MARK: Ads
                SettingsCard(title: "Ads", icon: "megaphone", theme: theme, background: cardBackground) {
                    HStack(spacing: 12) {
                        SettingsIcon(systemImage: "megaphone", accent: appearance.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Banner Ads")
                                .font(.body.weight(.semibold))
                            Text(adsStore.hasRemovedAds ? "Removed" : "Active")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    Divider().opacity(0.7)

                    if adsStore.hasRemovedAds {
                        Text("Thanks for supporting the app. Ads are disabled on this device.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Remove banner ads for a one‑time purchase.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack {
                            Button {
                                Task { await adsStore.purchaseRemoveAds() }
                            } label: {
                                HStack(spacing: 6) {
                                    if adsStore.purchaseInFlight {
                                        ProgressView().scaleEffect(0.9)
                                    }
                                    Text(adsStore.purchaseInFlight ? "Processing…" : "Remove Ads \(adsStore.displayPrice)")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(adsStore.purchaseInFlight)

                            Button("Restore Purchases") {
                                Task { await adsStore.restore() }
                            }
                            .buttonStyle(.bordered)
                            .disabled(adsStore.purchaseInFlight)
                        }
                    }

                    if let error = adsStore.lastError, !error.isEmpty {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }

                // MARK: About
                SettingsCard(title: "About", icon: "info.circle", theme: theme, background: cardBackground) {

                    SettingsValueRow(title: "Version", value: appVersionText, systemImage: "number")

                    Divider().opacity(0.7)

                    Button(role: .destructive) {
                        showingResetConfirm = true
                    } label: {
                        SettingsRow(
                            title: "Reset Appearance",
                            subtitle: "Theme + UI style (accent stays as-is)",
                            systemImage: "arrow.counterclockwise",
                            accent: .red
                        )
                    }
                    .buttonStyle(.plain)
                }

                Link(destination: URL(string: "https://qualtricsxmm8q5gxrhq.qualtrics.com/jfe/form/SV_1TvkCrIKgaEYHPM")!) {
                    HStack(spacing: 10) {
                        Image(systemName: "paperplane")
                            .font(.body.weight(.semibold))
                        Text("Submit a Bug / Suggestion")
                            .font(.footnote.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(screenBackground)
        .tint(appearance.accentColor)
        .preferredColorScheme(appearance.preferredColorScheme)
        .task {
            syncAppIconSelectionFromSystem()
            await adsStore.load()
            await proStore.load()
            await proStore.refreshEntitlements()
            await teslaFiUnlock.load()
        }
        .alert("Couldn’t Change App Icon", isPresented: $showingIconError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(iconErrorMessage)
        }
        .confirmationDialog(
            "Reset appearance settings?",
            isPresented: $showingResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { resetAppearanceDefaults() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This resets Theme and UI Style back to defaults.")
        }
    }

    // MARK: - App Icon

    private var supportsAlternateIcons: Bool {
        #if canImport(UIKit)
        return UIApplication.shared.supportsAlternateIcons
        #else
        return false
        #endif
    }

    private func syncAppIconSelectionFromSystem() {
        guard supportsAlternateIcons else { return }
        #if canImport(UIKit)
        let current = UIApplication.shared.alternateIconName // nil means primary icon
        if let current, AppIconChoice(rawValue: current) != nil {
            appIconRaw = current
        } else {
            appIconRaw = AppIconChoice.appIcon.rawValue
        }
        #endif
    }

    private func applyAppIcon(oldRaw: String, newRaw: String) {
        guard supportsAlternateIcons else { return }
        guard let choice = AppIconChoice(rawValue: newRaw) else { return }

        #if canImport(UIKit)
        // If already set, no-op
        if UIApplication.shared.alternateIconName == choice.alternateIconName { return }

        UIApplication.shared.setAlternateIconName(choice.alternateIconName) { error in
            guard let error else { return }
            Task { @MainActor in
                // revert UI selection
                appIconRaw = oldRaw
                iconErrorMessage = error.localizedDescription
                showingIconError = true
            }
        }
        #endif
    }

    // MARK: - Reset

    private func applyPreset(_ preset: ThemePreset) {
        switch preset {
        case .teslaOfficial:
            uiStyleRaw = ToolsStyle.teslaGlass.rawValue
            appearance.accentChoice = .red
            uiSettings.cardStyle = .glass
            uiSettings.background = .carbon
            uiSettings.typography = .bold
            uiSettings.density = .compact
            uiSettings.cardCorner = .crisp
            uiSettings.cardPadding = .tight
            uiSettings.motion = .reduced
        case .tesla:
            uiStyleRaw = ToolsStyle.teslaGlass.rawValue
            appearance.accentChoice = .red
            uiSettings.cardStyle = .glass
            uiSettings.background = .defaultGlow
            uiSettings.typography = .bold
            uiSettings.density = .comfortable
            uiSettings.haptics = .standard
        case .minimal:
            uiStyleRaw = ToolsStyle.classic.rawValue
            appearance.accentChoice = .gray
            uiSettings.cardStyle = .flat
            uiSettings.background = .carbon
            uiSettings.typography = .classic
            uiSettings.density = .compact
            uiSettings.haptics = .low
        case .neon:
            uiStyleRaw = ToolsStyle.teslaGlass.rawValue
            appearance.accentChoice = .teal
            uiSettings.cardStyle = .glass
            uiSettings.background = .aurora
            uiSettings.typography = .bold
            uiSettings.density = .comfortable
            uiSettings.haptics = .standard
        case .classic:
            uiStyleRaw = ToolsStyle.classic.rawValue
            appearance.accentChoice = .blue
            uiSettings.cardStyle = .elevated
            uiSettings.background = .defaultGlow
            uiSettings.typography = .classic
            uiSettings.density = .comfortable
            uiSettings.haptics = .standard
        }
    }

    private func resetAppearanceDefaults() {
        let d = UserDefaults.standard

        // Reset keys that drive glass + theme mode
        d.removeObject(forKey: "uiStyle")
        d.removeObject(forKey: "appearance.scheme")
        d.removeObject(forKey: "ui.typography")
        d.removeObject(forKey: "ui.cardStyle")
        d.removeObject(forKey: "ui.density")
        d.removeObject(forKey: "ui.backgroundStyle")
        d.removeObject(forKey: "ui.hapticsLevel")

        // Do NOT assume any AccentChoice cases exist.
        // If you also store accent by key, clear it best-effort:
        d.removeObject(forKey: "appearance.accent")

        // Immediate in-memory reset for a consistent UI
        uiStyleRaw = ToolsStyle.classic.rawValue
        appearance.scheme = .system
        uiSettings.typography = .classic
        uiSettings.cardStyle = .elevated
        uiSettings.density = .comfortable
        uiSettings.background = .defaultGlow
        uiSettings.haptics = .standard

        // Accent remains whatever your AppAppearance default currently is.
    }
}

// MARK: - Cards & Rows (glass-aware)

fileprivate struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let theme: any AppThemeSpec
    let background: AnyShapeStyle
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .accessibilityAddTraits(.isHeader)

            content
        }
        .padding(theme.spacing)
        .background(background, in: RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                .strokeBorder(theme.separator.opacity(0.85), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: theme.elevation, x: 0, y: 2)
    }
}

fileprivate struct SettingsIcon: View {
    let systemImage: String
    let accent: Color

    var body: some View {
        ZStack {
            Circle().fill(accent.opacity(0.14))
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: 32, height: 32)
    }
}

fileprivate struct SettingsRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemImage: systemImage, accent: accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

fileprivate struct SettingsValueRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)

            Text(title)
                .font(.body.weight(.semibold))

            Spacer()

            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }
}

fileprivate struct SettingsPickerRow<PickerContent: View>: View {
    let title: String
    let systemImage: String
    let accent: Color
    @ViewBuilder let picker: PickerContent

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemImage: systemImage, accent: accent)
            Text(title)
                .font(.body.weight(.semibold))
            Spacer()
            picker
        }
    }
}

// MARK: - Selection Screens

fileprivate struct ThemeModePickerView: View {
    @Binding var selection: AppearanceMode

    var body: some View {
        List {
            ForEach(AppearanceMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    HStack {
                        Text(mode.title)
                        Spacer()
                        if selection == mode {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

fileprivate struct AccentPickerView: View {
    @Binding var selection: AccentChoice

    var body: some View {
        List {
            ForEach(AccentChoice.allCases) { choice in
                Button {
                    selection = choice
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(choice.color)
                            .frame(width: 14, height: 14)
                        Text(choice.title)
                        Spacer()
                        if selection == choice {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - UI style values (must match ThemeBinder’s accepted strings)

fileprivate enum ToolsStyle: String {
    case classic
    case teslaGlass
}

// MARK: - App Icon choices (Info.plist keys must match these raw values)

fileprivate enum AppIconChoice: String, CaseIterable, Identifiable {
    case appIcon = "AppIcon"                 // primary
    case appIconOld = "AppIconOld"           // alternate icon key
    case appIconGlobal = "AppIconGlobal"     // alternate icon key
    case appIconFunny = "AppIconFunny"       // ✅ NEW alternate icon key

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appIcon: return "Default"
        case .appIconOld: return "Old"
        case .appIconGlobal: return "Global"
        case .appIconFunny: return "Funny"
        }
    }

    var subtitle: String {
        switch self {
        case .appIcon: return "Primary icon (default)"
        case .appIconOld: return "Alternate: AppIconOld"
        case .appIconGlobal: return "Alternate: AppIconGlobal"
        case .appIconFunny: return "Alternate: AppIconFunny"
        }
    }

    /// Pass this to `setAlternateIconName`. Nil means "use primary".
    var alternateIconName: String? {
        switch self {
        case .appIcon: return nil
        case .appIconOld, .appIconGlobal, .appIconFunny: return rawValue
        }
    }
}
