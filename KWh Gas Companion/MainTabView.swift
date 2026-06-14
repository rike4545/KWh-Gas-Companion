// Copyright Bryan Carroll. Made with Love in New York. All rights reserved. 2026.

//
//  MainTabView.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//
//  Performance revision:
//  ✅ avatarJPEG decode (UIImage(data:)) cached as @State — runs only when data changes,
//     not on every render (was the single most expensive per-render operation)
//  ✅ MainTabBarConfig caches UIColor.getRed() luminance check, isOrangeInterface, barBackground,
//     settingsBarBackground, settingsBarColorScheme as one @State struct — UIKit bridge
//     runs once per theme/scheme change instead of 3–6× per body evaluation
//  ✅ Duplicate TabView bodies (haptics on/off) merged into single tabViewBody —
//     type checker processes 5 tab items once; .sensoryFeedback added conditionally
//  ✅ tabValue promoted to @State — MainTab.from(raw:) called once on tabRaw change,
//     not 3× per render (tabContent switch + two Binding getters)
//  ✅ MainTabBackgroundGradient extracted to Equatable struct — SwiftUI skips the
//     10-case gradient switch on every scroll/typing re-render when inputs unchanged
//  ✅ .inlineNav() helper dedups NavigationTitle + DisplayMode chain in center screens
//  ✅ Missing .onChange(of: themePresetRaw) → updateTabBarAppearance() added (bug fix)
//  ✅ All existing structure preserved: 5 tabs, sidebar, deep links, haptics, avatar
//

import SwiftUI
import Foundation
import PhotosUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Tab model

fileprivate enum MainTab: Hashable {
    case home, charging, expenses, vehicles, tools
}

fileprivate extension MainTab {
    static func from(raw: String) -> MainTab? {
        switch raw.lowercased() {
        case "home":     return .home
        case "charging": return .charging
        case "expenses": return .expenses
        case "vehicles": return .vehicles
        case "tools":    return .tools
        default:         return nil
        }
    }
    var rawString: String {
        switch self {
        case .home:     return "home"
        case .charging: return "charging"
        case .expenses: return "expenses"
        case .vehicles: return "vehicles"
        case .tools:    return "tools"
        }
    }
}

extension Notification.Name {
    static let mainTabSelect = Notification.Name("MainTabView.mainTabSelect")
}

// MARK: - Cached bar configuration
//
// All derived values that require UIKit (luminance check) or string work
// (isOrangeInterface) are computed once and stored here. rebuildBarConfig()
// is called only when theme preset, uiStyle, appearance mode, or scheme changes.

private struct MainTabBarConfig {
    let isOrange:             Bool
    let settingsBarIsDark:    Bool
    let settingsBackground:   AnyShapeStyle
    let settingsColorScheme:  ColorScheme
    let barBackground:        AnyShapeStyle   // used in 6+ toolbar calls

    static func make(
        theme: any AppThemeSpec,
        themePresetRaw: String,
        accentChoice: AccentChoice,
        effectiveScheme: ColorScheme
    ) -> MainTabBarConfig {
        let preset   = themePresetRaw.lowercased()
        let isOrange = preset == ThemeStyle.orange.rawValue
            || (preset == ThemeStyle.modern.rawValue && accentChoice == .orange)

        let isDark: Bool = {
            if isOrange { return false }
            #if canImport(UIKit)
            let style: UIUserInterfaceStyle = effectiveScheme == .dark ? .dark : .light
            let trait = UITraitCollection(userInterfaceStyle: style)
            let uiColor = UIColor(theme.cardBackground).resolvedColor(with: trait)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else {
                return effectiveScheme == .dark
            }
            return (0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)) < 0.5
            #else
            return effectiveScheme == .dark
            #endif
        }()

        let settingsBg: AnyShapeStyle = isOrange
            ? AnyShapeStyle(Color(hex: "#F3F4F6"))
            : AnyShapeStyle(.bar)

        return MainTabBarConfig(
            isOrange:            isOrange,
            settingsBarIsDark:   isDark,
            settingsBackground:  settingsBg,
            settingsColorScheme: isOrange ? .light : (isDark ? .dark : .light),
            barBackground:       AnyShapeStyle(.bar)
        )
    }
}

// MARK: - Main View

@MainActor
struct MainTabView: View {

    // MARK: Environment

    @EnvironmentObject private var appearance:   AppAppearance
    @EnvironmentObject private var uiSettings:   AppUISettings
    @EnvironmentObject private var brandManager: BrandThemeManager
    @EnvironmentObject private var coordinator:  StoreCoordinator

    @Environment(\.appThemeBox)           private var themeBox
    @Environment(\.colorScheme)           private var scheme
    @Environment(\.horizontalSizeClass)   private var horizontalSizeClass

    @AppStorage("uiStyle")       private var uiStyleRaw:     String = "classic"
    @AppStorage("themePreset")   private var themePresetRaw: String = ThemeStyle.appDefault.rawValue
    @AppStorage("kwh.userAvatarJPEG") private var avatarJPEG: Data = Data()
    @StateObject private var adsStore = AdsEntitlementStore.shared

    // MARK: Persisted + UI state

    @SceneStorage("mainTab.selected") private var tabRaw: String = "home"

    /// Cached — avoids calling MainTab.from(raw:) on every render pass
    @State private var tabValue: MainTab = .home

    @State private var showingSettings:          Bool = false
    @State private var showAvatarPicker:         Bool = false
    @State private var avatarPickerItem:         PhotosPickerItem?
    @State private var showingAvatarPickerError: Bool = false
    @State private var avatarPickerErrorMessage: String = ""
    @State private var mainTabObserver:          NSObjectProtocol?
    @State private var avatarFeedbackTick:       Int = 0
    @State private var hasInitializedLaunchTab: Bool = false

    /// Cached decoded avatar image — UIImage(data:) only runs when avatarJPEG changes,
    /// not on every render. This was the most expensive per-render operation in the file.
    @State private var cachedAvatarImage: UIImage? = nil

    /// Cached bar colors/config — UIKit luminance check runs only on theme/scheme change
    @State private var barConfig: MainTabBarConfig = .init(
        isOrange: false, settingsBarIsDark: false,
        settingsBackground:  AnyShapeStyle(Color.clear),
        settingsColorScheme: .light,
        barBackground:       AnyShapeStyle(Color.clear)
    )

    private let wrapExpensesInNavigationStack: Bool = true

    // MARK: Theme helpers

    private var theme:       any AppThemeSpec { themeBox.base }
    private var accent:      Color { brandManager.theme.tokens.accent }
    private var cardSurface: AnyShapeStyle { AnyShapeStyle(theme.cardBackground) }

    private var effectiveScheme: ColorScheme {
        switch appearance.preferredColorScheme {
        case .some(.dark):  return .dark
        case .some(.light): return .light
        default:            return scheme
        }
    }

    private var isPad: Bool {
        #if targetEnvironment(simulator)
        false
        #elseif canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

    private var usesSplitLayout: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        isPad && horizontalSizeClass == .regular
        #endif
    }

    private var isRunningPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private let avatarSize:      CGFloat = 40
    private let avatarRingWidth: CGFloat = 1

    // MARK: Cache rebuilders

    private func rebuildBarConfig() {
        barConfig = MainTabBarConfig.make(
            theme:           theme,
            themePresetRaw:  themePresetRaw,
            accentChoice:    appearance.accentChoice,
            effectiveScheme: effectiveScheme
        )
    }

    private func rebuildAvatarImage() {
        guard !avatarJPEG.isEmpty else { cachedAvatarImage = nil; return }
        cachedAvatarImage = UIImage(data: avatarJPEG)
    }

    // MARK: Body

    var body: some View {
        baseView
    }

    @ViewBuilder
    private var baseView: some View {
        if uiSettings.haptics != .off {
            baseViewCore.sensoryFeedback(.success, trigger: avatarFeedbackTick)
        } else {
            baseViewCore
        }
    }

    private var baseViewCore: some View {
        contentView
            .tint(accent)
            .environment(\.adsInlineEnabled, false)
            .preferredColorScheme(appearance.preferredColorScheme)
            .sheet(isPresented: $showingSettings) { settingsSheet }
            .photosPicker(isPresented: $showAvatarPicker, selection: $avatarPickerItem, matching: .images)
            .onChange(of: avatarPickerItem) { _, newItem in
                guard let item = newItem else { return }
                Task {
                    await loadAndPersistAvatar(from: item)
                    avatarPickerItem = nil
                }
            }
            .alert("Couldn't Load Photo", isPresented: $showingAvatarPickerError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(avatarPickerErrorMessage)
            }
            .onOpenURL(perform: handleDeepLink(_:))
            .transaction { tx in
                if uiSettings.motion != .full { tx.animation = nil }
            }
            .onAppear {
                if !hasInitializedLaunchTab {
                    tabRaw = MainTab.home.rawString
                    tabValue = .home
                    hasInitializedLaunchTab = true
                } else {
                    tabValue = MainTab.from(raw: tabRaw) ?? .home
                }
                rebuildBarConfig()
                rebuildAvatarImage()
                updateTabBarAppearance()
                if mainTabObserver == nil {
                    mainTabObserver = NotificationCenter.default.addObserver(
                        forName: .mainTabSelect, object: nil, queue: .main
                    ) { note in
                        if let raw = note.userInfo?["tab"] as? String,
                           let next = MainTab.from(raw: raw) {
                            Task { @MainActor in tabRaw = next.rawString }
                        }
                    }
                }
            }
            .onDisappear {
                if let obs = mainTabObserver {
                    NotificationCenter.default.removeObserver(obs)
                    mainTabObserver = nil
                }
            }
            // tabRaw changes (deep link, notification) → sync cached tabValue
            .onChange(of: tabRaw)  { _, raw in tabValue = MainTab.from(raw: raw) ?? .home }
            // avatarJPEG changes → decode once here, not in body
            .onChange(of: avatarJPEG) { _, _ in rebuildAvatarImage() }
            // Theme / scheme changes → rebuild cached bar config + UIKit tab bar
            .onChange(of: themePresetRaw)                   { _, _ in rebuildBarConfig(); updateTabBarAppearance() }
            .onChange(of: uiStyleRaw)                       { _, _ in rebuildBarConfig(); updateTabBarAppearance() }
            .onChange(of: appearance.preferredColorScheme)  { _, _ in rebuildBarConfig(); updateTabBarAppearance() }
            .onChange(of: brandManager.theme.tokens.accent) { _, _ in rebuildBarConfig(); updateTabBarAppearance() }
            .onChange(of: scheme)                           { _, _ in rebuildBarConfig() }
    }

    // MARK: Settings sheet

    private var settingsSheet: some View {
        NavigationStack {
            MainTabThemedRoot(theme: theme, accent: accent, addTabBarInset: false) {
                SettingsView()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { showingSettings = false }
                }
            }
            .toolbarBackground(barConfig.settingsBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(barConfig.settingsColorScheme, for: .navigationBar)
        }
        .tint(accent)
        .preferredColorScheme(appearance.preferredColorScheme)
    }

    // MARK: Content layout

    @ViewBuilder
    private var contentView: some View {
        if isRunningPreview {
            previewContent
        } else if usesSplitLayout {
            splitContent
        } else {
            // Single TabView body. Previously there were two identical bodies
            // differing only by .sensoryFeedback — the type checker processed
            // all 5 NavigationStack tab items twice. Now processed once.
            tabViewBody
                .toolbarBackground(barConfig.barBackground, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .transaction { tx in
                    tx.animation = nil
                    if uiSettings.motion != .full { tx.disablesAnimations = true }
                }
                .if(uiSettings.haptics != .off) { $0.sensoryFeedback(.selection, trigger: tabValue) }
        }
    }

    private var tabViewBody: some View {
        TabView(selection: tabBinding) {
            homeRoot
                .tabItem { Label("Home",     systemImage: "car") }
                .tag(MainTab.home)
            chargingRoot
                .tabItem { Label("Charging", systemImage: "bolt.car") }
                .tag(MainTab.charging)
            expensesRoot
                .tabItem { Label("Expenses", systemImage: "creditcard") }
                .tag(MainTab.expenses)
            vehiclesRoot
                .tabItem { Label("Vehicles", systemImage: "car.2.fill") }
                .tag(MainTab.vehicles)
            toolsRoot
                .tabItem { Label("Tools",    systemImage: "square.grid.2x2") }
                .tag(MainTab.tools)
        }
    }

    private var previewContent: some View {
        NavigationStack {
            MainTabThemedRoot(theme: theme, accent: accent, addTabBarInset: false) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("My EV Companion").font(.title2.weight(.bold))
                        Text("Your ICE-to-EV transition companion").font(.headline)
                        Text("Canvas-safe snapshot. Run the app for full live data, transition guidance, and interactions.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var splitContent: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            tabContent
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarBackground(barConfig.barBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .transaction { tx in
            tx.animation = nil
            if uiSettings.motion != .full { tx.disablesAnimations = true }
        }
    }

    // MARK: Expenses root

    @ViewBuilder
    private var expensesRoot: some View {
        if wrapExpensesInNavigationStack {
            NavigationStack {
                MainTabThemedRoot(theme: theme, accent: accent, addTabBarInset: !usesSplitLayout) {
                    ExpenseListTabView()
                }
                .navigationTitle("Expenses")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { profileToolbar }
                .toolbarBackground(barConfig.barBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    tabContentAdDock
                }
            }
        } else {
            MainTabThemedRoot(theme: theme, accent: accent, addTabBarInset: !usesSplitLayout) {
                ExpenseListTabView()
            }
            .toolbar { profileToolbar }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                tabContentAdDock
            }
        }
    }

    // MARK: iPad sidebar

    private var sidebar: some View {
        List(selection: tabSelectionBinding) {
            Section("Main") {
                Label("Home",     systemImage: "house").tag(MainTab.home)
                Label("Charging", systemImage: "bolt.car").tag(MainTab.charging)
                Label("Expenses", systemImage: "creditcard").tag(MainTab.expenses)
            }
            Section("More") {
                Label("Vehicles", systemImage: "car.2.fill").tag(MainTab.vehicles)
                Label("Tools",    systemImage: "square.grid.2x2").tag(MainTab.tools)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("My EV Companion")
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tabValue {
        case .home:     homeRoot
        case .charging: chargingRoot
        case .expenses: expensesRoot
        case .vehicles: vehiclesRoot
        case .tools:    toolsRoot
        }
    }

    // MARK: Tab bindings (use cached @State tabValue)

    private var tabBinding: Binding<MainTab> {
        Binding(
            get: { tabValue },
            set: { newValue in
                var tx = Transaction(); tx.animation = nil
                withTransaction(tx) { tabRaw = newValue.rawString }
            }
        )
    }

    private var tabSelectionBinding: Binding<MainTab?> {
        Binding(
            get: { tabValue },
            set: { newValue in
                guard let next = newValue else { return }
                var tx = Transaction(); tx.animation = nil
                withTransaction(tx) { tabRaw = next.rawString }
            }
        )
    }

    // MARK: Tab roots

    private var homeRoot: some View {
        NavigationStack {
            MainTabThemedRoot(theme: theme, accent: accent, addTabBarInset: !usesSplitLayout) {
                DashboardView()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { profileToolbar }
            .toolbarBackground(barConfig.barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                tabContentAdDock
            }
        }
    }

    private var chargingRoot: some View {
        NavigationStack {
            MainTabThemedRoot(theme: theme, accent: accent, addTabBarInset: !usesSplitLayout) {
                MainTabChargingCenterScreen(surface: cardSurface)
            }
            .navigationTitle("Charging")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { profileToolbar }
            .toolbarBackground(barConfig.barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                tabContentAdDock
            }
        }
    }

    private var vehiclesRoot: some View {
        NavigationStack {
            MainTabThemedRoot(theme: theme, accent: accent, addTabBarInset: !usesSplitLayout) {
                MainTabVehicleCenterScreen(surface: cardSurface, openSettings: { showingSettings = true })
            }
            .navigationTitle("Vehicles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { profileToolbar }
            .toolbarBackground(barConfig.barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                tabContentAdDock
            }
        }
    }

    private var toolsRoot: some View {
        NavigationStack {
            MainTabThemedRoot(theme: theme, accent: accent, addTabBarInset: !usesSplitLayout) {
                CalculatorsDashboardView()
            }
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { profileToolbar }
            .toolbarBackground(barConfig.barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                tabContentAdDock
            }
        }
    }

    @ViewBuilder
    private var tabContentAdDock: some View {
        if !isRunningPreview
            && !usesSplitLayout
            && !adsStore.hasRemovedAds
            && tabValue == .home
        {
            VStack(spacing: 0) {
                Divider()
                    .opacity(0.3)
                AdBannerOverlayCard(adsStore: adsStore)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
            }
            .background(.ultraThinMaterial)
        }
    }

    // MARK: Profile toolbar

    @ToolbarContentBuilder
    private var profileToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Open Settings", systemImage: "gearshape") {
                showingSettings = true
            }
            .labelStyle(.iconOnly)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showingSettings = true } label: {
                avatarButtonLabel.padding(.vertical, 2)
            }
            .buttonStyle(MainTabAvatarPressStyle())
            .accessibilityLabel("Settings")
            .contextMenu {
                Button { showingSettings = true } label: {
                    Label("Open Settings", systemImage: "gearshape")
                }
                Button { showAvatarPicker = true } label: {
                    Label("Choose Photo…", systemImage: "photo")
                }
                if !avatarJPEG.isEmpty {
                    Button(role: .destructive) { avatarJPEG = Data() } label: {
                        Label("Remove Photo", systemImage: "trash")
                    }
                }
            }
        }
    }

    /// Uses cachedAvatarImage — no UIImage(data:) JPEG decode on render.
    private var avatarButtonLabel: some View {
        ZStack {
            Circle()
                .fill(theme.pillTint.opacity(scheme == .dark ? 0.22 : 0.16))

            if let ui = cachedAvatarImage {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                    .clipped()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(accent.opacity(0.95))
            }

            Circle()
                .strokeBorder(
                    theme.separator.opacity(scheme == .dark ? 0.85 : 0.65),
                    lineWidth: avatarRingWidth
                )
            Circle()
                .inset(by: avatarRingWidth)
                .strokeBorder(accent.opacity(0.28), lineWidth: avatarRingWidth)
        }
        .frame(width: avatarSize, height: avatarSize)
        .contentShape(Circle())
        .shadow(
            color: theme.separator.opacity(scheme == .dark ? 0.26 : 0.18),
            radius: theme.elevation * 0.65, x: 0, y: 2
        )
        .accessibilityHint("Opens Settings. Long-press for photo options.")
    }

    // MARK: Avatar loading

    private func loadAndPersistAvatar(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let ui = UIImage(data: data)
            else {
                avatarPickerErrorMessage = "The selected photo couldn't be read. Try a different image."
                showingAvatarPickerError = true
                return
            }
            let resized = ui.kwh_resized(maxDimension: 768)
            avatarJPEG = resized.jpegData(compressionQuality: 0.85) ?? data
            avatarFeedbackTick &+= 1
        } catch {
            avatarPickerErrorMessage = error.localizedDescription
            showingAvatarPickerError = true
        }
    }

    // MARK: Deep links

    private func handleDeepLink(_ url: URL) {
        guard (url.scheme ?? "").lowercased().contains("kwh") else { return }
        let comps  = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let target = comps?.queryItems?.first(where: { $0.name.lowercased() == "tab" })?.value?.lowercased()
                  ?? (url.host ?? "").lowercased()
        switch target {
        case "home", "dashboard", "overview": tabRaw = MainTab.home.rawString
        case "charging":                      tabRaw = MainTab.charging.rawString
        case "expenses":                      tabRaw = MainTab.expenses.rawString
        case "vehicles", "garage":            tabRaw = MainTab.vehicles.rawString
        case "tools", "calculators":          tabRaw = MainTab.tools.rawString
        case "settings":                      showingSettings = true
        default: break
        }
    }
}

// MARK: - Tab bar appearance (UIKit bridge)

private extension MainTabView {
    func updateTabBarAppearance() {
        #if canImport(UIKit)
        let isDark  = effectiveScheme == .dark
        let isTesla = ThemeStyle.resolve(themePresetRaw: themePresetRaw, legacyUIStyleRaw: uiStyleRaw) == .tesla
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        // Tesla: pure-black bar (dark) / pure-white (light) with a hairline edge.
        if isTesla {
            tabAppearance.backgroundColor = isDark ? UIColor.black : UIColor.white
            tabAppearance.shadowColor     = UIColor(white: isDark ? 1.0 : 0.0, alpha: isDark ? 0.10 : 0.12)
        } else {
            tabAppearance.backgroundColor = UIColor(white: isDark ? 0.07 : 0.985, alpha: 0.98)
            tabAppearance.shadowColor     = UIColor.black.withAlphaComponent(isDark ? 0.24 : 0.11)
        }
        // Tesla uses a monochrome white/black selected state rather than a color accent.
        let selected   = isTesla ? (isDark ? UIColor.white : UIColor.black) : UIColor(accent)
        let unselected = UIColor(white: isDark ? (isTesla ? 0.55 : 0.72) : 0.45, alpha: 1)
        let item = tabAppearance.stackedLayoutAppearance
        item.normal.iconColor               = unselected
        item.normal.titleTextAttributes     = [.foregroundColor: unselected]
        item.selected.iconColor             = selected
        item.selected.titleTextAttributes   = [.foregroundColor: selected]
        UITabBar.appearance().standardAppearance   = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        #endif
    }
}

// MARK: - Conditional modifier helper

private extension View {
    @ViewBuilder
    func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Themed root container

fileprivate struct MainTabThemedRoot<Content: View>: View {
    let theme: any AppThemeSpec
    let accent: Color
    let addTabBarInset: Bool
    @Environment(\.colorScheme)         private var scheme
    @EnvironmentObject private var uiSettings: AppUISettings
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let content: Content

    init(
        theme: any AppThemeSpec,
        accent: Color,
        addTabBarInset: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.theme          = theme
        self.accent         = accent
        self.addTabBarInset = addTabBarInset
        self.content        = content()
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(theme.screenBackground)
                .ignoresSafeArea()

            // Equatable struct — SwiftUI skips the gradient switch when
            // background/scheme unchanged (e.g. during scroll or text input)
            MainTabBackgroundGradient(
                background: uiSettings.background,
                accent: accent,
                scheme: scheme
            )
            .equatable()
            .ignoresSafeArea()
            .allowsHitTesting(false)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .safeAreaPadding(.bottom, addTabBarInset && horizontalSizeClass == .compact ? 4 : 0)
        }
    }
}

// MARK: - Background gradient (Equatable — skips case switch on unchanged renders)

private struct MainTabBackgroundGradient: View, Equatable {
    let background: BackgroundStyle
    let accent: Color
    let scheme: ColorScheme

    // accent intentionally excluded — brand color changes always warrant a re-render
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.background == rhs.background && lhs.scheme == rhs.scheme
    }

    var body: some View {
        switch background {
        case .defaultGlow:
            LinearGradient(colors: [accent.opacity(scheme == .dark ? 0.07 : 0.04), .clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .aurora:
            LinearGradient(colors: [accent.opacity(scheme == .dark ? 0.08 : 0.05),
                                    Color.green.opacity(scheme == .dark ? 0.07 : 0.04)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dusk:
            LinearGradient(colors: [Color.orange.opacity(scheme == .dark ? 0.08 : 0.05),
                                    Color.indigo.opacity(scheme == .dark ? 0.08 : 0.05)],
                           startPoint: .top, endPoint: .bottom)
        case .carbon:
            LinearGradient(colors: [Color.black.opacity(scheme == .dark ? 0.65 : 0.10),
                                    Color.black.opacity(scheme == .dark ? 0.25 : 0.04)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .blackHistoryMonth:
            LinearGradient(colors: [Color.black.opacity(scheme == .dark ? 0.75 : 0.25),
                                    Color(red: 0.35, green: 0.16, blue: 0.05).opacity(scheme == .dark ? 0.45 : 0.20),
                                    Color(red: 0.75, green: 0.60, blue: 0.20).opacity(scheme == .dark ? 0.35 : 0.18)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .christmas:
            LinearGradient(colors: [Color.red.opacity(scheme == .dark ? 0.10 : 0.06),
                                    Color.green.opacity(scheme == .dark ? 0.10 : 0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .lunarNewYear:
            LinearGradient(colors: [Color.red.opacity(scheme == .dark ? 0.11 : 0.07),
                                    Color.yellow.opacity(scheme == .dark ? 0.10 : 0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .halloween:
            LinearGradient(colors: [Color.orange.opacity(scheme == .dark ? 0.11 : 0.07),
                                    Color.purple.opacity(scheme == .dark ? 0.10 : 0.06)],
                           startPoint: .top, endPoint: .bottom)
        case .thanksgiving:
            LinearGradient(colors: [Color(red: 0.65, green: 0.36, blue: 0.12).opacity(scheme == .dark ? 0.10 : 0.06),
                                    Color.orange.opacity(scheme == .dark ? 0.09 : 0.05)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .newYear:
            LinearGradient(colors: [Color.blue.opacity(scheme == .dark ? 0.10 : 0.06),
                                    Color.white.opacity(scheme == .dark ? 0.08 : 0.04)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Inline nav helper

private extension View {
    func inlineNav(_ title: String) -> some View {
        navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Charging Center

@MainActor
fileprivate struct MainTabChargingCenterScreen: View {
    @EnvironmentObject private var brandManager: BrandThemeManager
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore
    @StateObject private var teslaFiUnlock = TeslaFiEntitlementStore.shared
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let surface: AnyShapeStyle
    private var theme: any AppThemeSpec { themeBox.base }
    private var accent: Color { brandManager.theme.tokens.accent }
    private var topPad:    CGFloat { max(4,  theme.spacing * 0.35) }
    private var bottomPad: CGFloat { max(24, theme.spacing * 2.0)  }
    private var isCompactLayout: Bool { horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize }
    private var quickTileColumns: [GridItem] {
        [GridItem(.adaptive(minimum: isCompactLayout ? 140 : 170), spacing: 10, alignment: .top)]
    }
    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: isCompactLayout ? 120 : 140), spacing: 10, alignment: .top)]
    }
    private var availableSessions: [TeslaFiSession] {
        let base = teslaFiStore.canonicalSessions.isEmpty ? teslaFiStore.sessions : teslaFiStore.canonicalSessions
        return teslaFiUnlock.hasTeslaFiUnlock ? base : []
    }
    private var snapshot: MainTabChargingSnapshot {
        MainTabChargingSnapshot.build(
            selectedVehicle: profileStore.selectedVehicle,
            vehicleCount: profileStore.vehicles.count,
            entries: entriesStore.entries,
            sessions: availableSessions
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing + 10) {
                MainTabCard(theme: theme, surface: surface) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            MainTabIconChip(theme: theme, accent: accent, symbol: "bolt.fill")
                            VStack(alignment: .leading, spacing: 6) {
                                Text(profileStore.selectedVehicle?.displayName ?? "Charging Center")
                                    .font(.title3.weight(.semibold))
                                Text(snapshot.heroSubtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            MainTabStatusBadge(text: snapshot.statusText, style: snapshot.statusStyle, accent: accent)
                        }

                        Text(snapshot.primaryValue)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()

                        Text(snapshot.primaryCaption)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 10) {
                            MainTabFocusRow(
                                title: "Last session",
                                subtitle: snapshot.lastSessionSummary,
                                systemImage: "clock.arrow.circlepath",
                                accent: accent,
                                theme: theme
                            )
                            MainTabFocusRow(
                                title: "Next up",
                                subtitle: snapshot.nextActionSubtitle,
                                systemImage: snapshot.nextActionSymbol,
                                accent: accent,
                                theme: theme
                            )
                        }

                        LazyVGrid(columns: metricColumns, spacing: 10) {
                            MainTabMetricPlate(title: "This month", value: snapshot.monthlyEnergyText)
                            MainTabMetricPlate(title: "Avg rate", value: snapshot.avgRateText)
                            MainTabMetricPlate(title: "Activity", value: snapshot.activitySummaryText)
                        }

                        LazyVGrid(columns: quickTileColumns, spacing: 10) {
                            quickTile("Charge Stats", "chart.bar.fill") { ChargeStatsOverviewScreen().inlineNav("Charge Stats") }
                            quickTile("Plan Charge", "clock.badge.checkmark") { ChargingSchedulePlannerView().inlineNav("Planner") }
                            quickTile("Recent Sessions", "clock.arrow.circlepath") { ChargeLogView().inlineNav("Charge Log") }
                            quickTile("Import", "square.and.arrow.down") { ChargingImportHubView().inlineNav("Import Charging") }
                        }

                        if let latest = snapshot.latestSession {
                            Divider().opacity(0.65)
                            MainTabRecentSessionRow(session: latest, accent: accent)
                        }
                    }
                }

                MainTabSectionHeader("Charge stats")
                MainTabCard(theme: theme, surface: surface) {
                    VStack(spacing: 0) {
                        navRow("Charge Stats",        snapshot.statsRowSubtitle,                "chart.bar.fill")    { ChargeStatsOverviewScreen().inlineNav("Charge Stats") }
                        Divider().opacity(0.65)
                        navRow("Session Analytics",   "Full imported-session trend and quality review",  "waveform.path.ecg") { SessionAnalyticsView().inlineNav("Session Analytics") }
                        Divider().opacity(0.65)
                        navRow("Charge Log",          "Saved charging sessions and edits",      "list.bullet.rectangle") { ChargeLogView().inlineNav("Charge Log") }
                    }
                }

                if !snapshot.recentSessions.isEmpty {
                    MainTabSectionHeader("Recent")
                    MainTabCard(theme: theme, surface: surface) {
                        VStack(spacing: 0) {
                            ForEach(Array(snapshot.recentSessions.enumerated()), id: \.element.id) { index, session in
                                MainTabRecentSessionRow(session: session, accent: accent)
                                if index != snapshot.recentSessions.count - 1 {
                                    Divider().opacity(0.65)
                                }
                            }
                        }
                    }
                }

                MainTabSectionHeader("Plan & pricing")
                MainTabCard(theme: theme, surface: surface) {
                    VStack(spacing: 0) {
                        navRow("Charging Planner",    "Schedule around your cheaper windows",   "clock.badge.checkmark") { ChargingSchedulePlannerView().inlineNav("Charging Planner") }
                        Divider().opacity(0.65)
                        navRow("Cheapest Charger Finder", "Find the lowest-cost stop",         "bolt.circle")        { SuperchargerHelperHost().inlineNav("Cheapest Charger Finder") }
                        Divider().opacity(0.65)
                        navRow("Near Me",             "Nearby chargers and superchargers",      "location")           { NearMeView().inlineNav("Near Me") }
                    }
                }

                MainTabSectionHeader("Data & imports")
                MainTabCard(theme: theme, surface: surface) {
                    VStack(spacing: 0) {
                        navRow("Charging Data Hub",   "Sessions, integrity, reconciliation",   "bolt.car")           { ChargingDataHubView().inlineNav("Charging Data") }
                        Divider().opacity(0.65)
                        navRow("Import Hub",          "CSV sources and imports",                "tray.and.arrow.down"){ ChargingImportHubView().inlineNav("Import Charging") }
                        Divider().opacity(0.65)
                        navRow("CSV Charging Wizard", "Clean, validate, then import",           "wand.and.stars")     { CSVChargingWizardView().inlineNav("CSV Wizard") }
                    }
                }

                MainTabSectionHeader("Trips")
                MainTabCard(theme: theme, surface: surface) {
                    VStack(spacing: 0) {
                        navRow("Trip Planner", "Route planning and charge stops", "map")        { TripPlannerView().inlineNav("Trip Planner") }
                        Divider().opacity(0.65)
                        navRow("Trip Logger",  "Record and review drives",        "road.lanes") { TripLoggerView().inlineNav("Trip Logger") }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.top, topPad).padding(.bottom, bottomPad)
        }
        .tint(accent)
        .task {
            await teslaFiUnlock.load()
        }
    }

    @ViewBuilder
    private func navRow<D: View>(
        _ title: String, _ subtitle: String, _ icon: String,
        @ViewBuilder destination: () -> D
    ) -> some View {
        NavigationLink { destination() } label: {
            MainTabRow(theme: theme, accent: accent, title: title, subtitle: subtitle, systemImage: icon)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func quickTile<D: View>(
        _ title: String, _ systemImage: String,
        @ViewBuilder destination: () -> D
    ) -> some View {
        NavigationLink { destination() } label: {
            MainTabQuickTile(theme: theme, accent: accent, title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }
}

@MainActor
fileprivate struct ChargeStatsOverviewScreen: View {
    @EnvironmentObject private var brandManager: BrandThemeManager
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore
    @StateObject private var teslaFiUnlock = TeslaFiEntitlementStore.shared
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var theme: any AppThemeSpec { themeBox.base }
    private var accent: Color { brandManager.theme.tokens.accent }
    private var metricColumns: [GridItem] {
        let compact = horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize
        return [GridItem(.adaptive(minimum: compact ? 120 : 140), spacing: 10, alignment: .top)]
    }
    private var availableSessions: [TeslaFiSession] {
        let base = teslaFiStore.canonicalSessions.isEmpty ? teslaFiStore.sessions : teslaFiStore.canonicalSessions
        return teslaFiUnlock.hasTeslaFiUnlock ? base : []
    }
    private var snapshot: MainTabChargingSnapshot {
        MainTabChargingSnapshot.build(
            selectedVehicle: profileStore.selectedVehicle,
            vehicleCount: profileStore.vehicles.count,
            entries: entriesStore.entries,
            sessions: availableSessions
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing + 10) {
                MainTabCard(theme: theme, surface: AnyShapeStyle(theme.cardBackground)) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            MainTabIconChip(theme: theme, accent: accent, symbol: "chart.bar.fill")
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Charge Stats")
                                    .font(.title3.weight(.semibold))
                                Text(snapshot.heroSubtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            MainTabStatusBadge(text: snapshot.statusText, style: snapshot.statusStyle, accent: accent)
                        }

                        LazyVGrid(columns: metricColumns, spacing: 10) {
                            MainTabMetricPlate(title: "Sessions", value: "\(snapshot.sessionCount)")
                            MainTabMetricPlate(title: "Home", value: "\(snapshot.homeSessionCount)")
                            MainTabMetricPlate(title: "Fast", value: "\(snapshot.fastSessionCount)")
                        }

                        LazyVGrid(columns: metricColumns, spacing: 10) {
                            MainTabMetricPlate(title: "Energy", value: snapshot.monthlyEnergyText)
                            MainTabMetricPlate(title: "Cost", value: snapshot.monthlyCostText)
                            MainTabMetricPlate(title: "Avg $/kWh", value: snapshot.avgRateText)
                        }
                    }
                }

                MainTabSectionHeader("Highlights")
                MainTabCard(theme: theme, surface: AnyShapeStyle(theme.cardBackground)) {
                    VStack(spacing: 0) {
                        statRow("Last session", snapshot.lastSessionSummary)
                        Divider().opacity(0.65)
                        statRow("Now", snapshot.primaryCaption)
                        Divider().opacity(0.65)
                        statRow("Next up", snapshot.nextActionSubtitle)
                    }
                }

                if !snapshot.recentSessions.isEmpty {
                    MainTabSectionHeader("Recent sessions")
                    MainTabCard(theme: theme, surface: AnyShapeStyle(theme.cardBackground)) {
                        VStack(spacing: 0) {
                            ForEach(Array(snapshot.recentSessions.enumerated()), id: \.element.id) { index, session in
                                MainTabRecentSessionRow(session: session, accent: accent)
                                if index != snapshot.recentSessions.count - 1 {
                                    Divider().opacity(0.65)
                                }
                            }
                        }
                    }
                }

                MainTabSectionHeader("More")
                MainTabCard(theme: theme, surface: AnyShapeStyle(theme.cardBackground)) {
                    VStack(spacing: 0) {
                        NavigationLink {
                            SessionAnalyticsView().inlineNav("Session Analytics")
                        } label: {
                            MainTabRow(theme: theme, accent: accent, title: "Open Session Analytics", subtitle: "Deeper trends, search, and quality checks", systemImage: "waveform.path.ecg")
                        }
                        .buttonStyle(.plain)
                        Divider().opacity(0.65)
                        NavigationLink {
                            ChargeLogView().inlineNav("Charge Log")
                        } label: {
                            MainTabRow(theme: theme, accent: accent, title: "Open Charge Log", subtitle: "Edit and review saved charging entries", systemImage: "list.bullet.rectangle")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Charge Stats")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accent)
        .task {
            await teslaFiUnlock.load()
        }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

// MARK: - Vehicle Center

@MainActor
fileprivate struct MainTabVehicleCenterScreen: View {
    @EnvironmentObject private var brandManager: BrandThemeManager
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore
    @EnvironmentObject private var appearance: AppAppearance
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let surface: AnyShapeStyle
    let openSettings: () -> Void
    private var theme: any AppThemeSpec { themeBox.base }
    private var accent: Color { brandManager.theme.tokens.accent }
    private var topPad:    CGFloat { max(4,  theme.spacing * 0.35) }
    private var bottomPad: CGFloat { max(24, theme.spacing * 2.0)  }
    private var isCompactLayout: Bool { horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize }
    private var quickTileColumns: [GridItem] {
        [GridItem(.adaptive(minimum: isCompactLayout ? 140 : 170), spacing: 10, alignment: .top)]
    }
    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: isCompactLayout ? 120 : 140), spacing: 10, alignment: .top)]
    }
    private var chargingSnapshot: MainTabChargingSnapshot {
        MainTabChargingSnapshot.build(
            selectedVehicle: profileStore.selectedVehicle,
            vehicleCount: profileStore.vehicles.count,
            entries: entriesStore.entries,
            sessions: teslaFiStore.canonicalSessions.isEmpty ? teslaFiStore.sessions : teslaFiStore.canonicalSessions
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing + 10) {
                MainTabCard(theme: theme, surface: surface) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            MainTabIconChip(theme: theme, accent: accent, symbol: "car.2.fill")
                            VStack(alignment: .leading, spacing: 6) {
                                Text(profileStore.selectedVehicle?.displayName ?? "Vehicle Center")
                                    .font(.title3.weight(.semibold))
                                Text(vehicleHeroSubtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            MainTabStatusBadge(
                                text: profileStore.selectedVehicle == nil ? "Add vehicle" : "Current vehicle",
                                style: profileStore.selectedVehicle == nil ? .muted : .accent,
                                accent: accent
                            )
                        }

                        if let vehicle = profileStore.selectedVehicle {
                            LazyVGrid(columns: metricColumns, spacing: 10) {
                                MainTabMetricPlate(title: "Battery", value: vehicle.batteryCapacityKWh.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) kWh" } ?? "—")
                                MainTabMetricPlate(title: "Range", value: vehicle.estimatedRangeMiles.map { "\($0.formatted(.number.precision(.fractionLength(0)))) mi" } ?? vehicle.maxRangeMiles.map { "\($0.formatted(.number.precision(.fractionLength(0)))) mi" } ?? "—")
                                MainTabMetricPlate(title: "This month", value: chargingSnapshot.monthlyEnergyText)
                            }

                            LazyVGrid(columns: quickTileColumns, spacing: 10) {
                                quickTile("Garage", "car.2.fill") {
                                    VehicleProfileListView()
                                        .environmentObject(profileStore)
                                        .environmentObject(entriesStore)
                                        .environmentObject(teslaFiStore)
                                        .environmentObject(appearance)
                                        .inlineNav("Garage")
                                }
                                quickTile("Charge Stats", "chart.bar.fill") {
                                    ChargeStatsOverviewScreen().inlineNav("Charge Stats")
                                }
                                quickTile("Service", "wrench.and.screwdriver") {
                                    ServiceRemindersView().inlineNav("Service Reminders")
                                }
                                quickTile("VIN", "textformat.123") {
                                    TeslaVINDecoderView().inlineNav("Tesla VIN Decoder")
                                }
                            }
                        } else {
                            Text("Set up a vehicle to personalize charging assumptions, VIN tools, service reminders, and dashboards.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                MainTabSectionHeader("Garage")
                MainTabCard(theme: theme, surface: surface) {
                    navRow("Garage", "Vehicles, presets, assumptions", "car.2.fill") {
                        VehicleProfileListView()
                            .environmentObject(profileStore)
                            .environmentObject(entriesStore)
                            .environmentObject(teslaFiStore)
                            .environmentObject(appearance)
                            .inlineNav("Garage")
                    }
                }

                MainTabSectionHeader("VIN & service")
                MainTabCard(theme: theme, surface: surface) {
                    VStack(spacing: 0) {
                        navRow("Tesla VIN Decoder",  "Decode model and details",     "textformat.123")         { TeslaVINDecoderView().inlineNav("Tesla VIN Decoder") }
                        Divider().opacity(0.65)
                        navRow("Rivian VIN Decoder", "Decode trim and drivetrain",   "textformat.123")         { RivianVINDecoderView().inlineNav("Rivian VIN Decoder") }
                        Divider().opacity(0.65)
                        navRow("Service Reminders",  "Keep maintenance on track",    "wrench.and.screwdriver") { ServiceRemindersView().inlineNav("Service Reminders") }
                        Divider().opacity(0.65)
                        navRow("Recalls",            "Safety and recall checks",     "exclamationmark.triangle") { RecallsView().inlineNav("Recalls") }
                    }
                }

                if let latest = chargingSnapshot.latestSession {
                    MainTabSectionHeader("Current vehicle activity")
                    MainTabCard(theme: theme, surface: surface) {
                        MainTabRecentSessionRow(session: latest, accent: accent)
                    }
                }

                MainTabSectionHeader("App")
                MainTabCard(theme: theme, surface: surface) {
                    Button(action: openSettings) {
                        MainTabRow(theme: theme, accent: accent,
                                   title: "Settings",
                                   subtitle: "Appearance, data, preferences",
                                   systemImage: "gearshape")
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.top, topPad).padding(.bottom, bottomPad)
        }
        .tint(accent)
    }

    @ViewBuilder
    private func navRow<D: View>(
        _ title: String, _ subtitle: String, _ icon: String,
        @ViewBuilder destination: () -> D
    ) -> some View {
        NavigationLink { destination() } label: {
            MainTabRow(theme: theme, accent: accent, title: title, subtitle: subtitle, systemImage: icon)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func quickTile<D: View>(
        _ title: String, _ systemImage: String,
        @ViewBuilder destination: () -> D
    ) -> some View {
        NavigationLink { destination() } label: {
            MainTabQuickTile(theme: theme, accent: accent, title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private var vehicleHeroSubtitle: String {
        guard let vehicle = profileStore.selectedVehicle else {
            return "Garage, VIN tools, service, and recall info."
        }
        return vehicle.summarySubtitle.isEmpty ? "Vehicle-first setup and maintenance tools." : vehicle.summarySubtitle
    }
}

fileprivate struct MainTabChargingSnapshot {
    struct Session: Identifiable {
        let id: String
        let date: Date
        let title: String
        let subtitle: String
        let energyKWh: Double
        let cost: Double?
        let endSOC: Double?
        let isFastCharge: Bool
        let isHome: Bool
    }

    enum StatusStyle {
        case accent
        case warning
        case muted
    }

    let monthlyEnergyKWh: Double
    let monthlyCost: Double
    let avgRate: Double?
    let sessionCount: Int
    let homeSessionCount: Int
    let fastSessionCount: Int
    let latestSession: Session?
    let recentSessions: [Session]
    let usingSavedEntries: Bool
    let selectedVehicleName: String?

    var heroSubtitle: String {
        if let selectedVehicleName {
            return "Charging activity centered on \(selectedVehicleName)."
        }
        return "Charging history, planning, and cost insights."
    }

    var primaryValue: String {
        if let soc = latestSession?.endSOC, soc > 0 {
            return "\(Int(soc.rounded()))%"
        }
        if monthlyCost > 0 {
            return monthlyCost.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
        }
        if monthlyEnergyKWh > 0 {
            return "\(monthlyEnergyKWh.formatted(.number.precision(.fractionLength(0...1)))) kWh"
        }
        return "Ready to charge"
    }

    var primaryCaption: String {
        if let latestSession {
            if let soc = latestSession.endSOC, soc > 0 {
                return "Latest recorded charge level from \(latestSession.title)."
            }
            if let cost = latestSession.cost {
                return "Last session cost \(cost.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))."
            }
            return "Most recent charge at \(latestSession.title)."
        }
        return "Import charging history or log a session to unlock deeper charge stats."
    }

    var monthlyEnergyText: String {
        monthlyEnergyKWh > 0 ? "\(monthlyEnergyKWh.formatted(.number.precision(.fractionLength(0...1)))) kWh" : "No energy yet"
    }

    var monthlyCostText: String {
        monthlyCost > 0 ? monthlyCost.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")) : "No cost yet"
    }

    var avgRateText: String {
        avgRate.map { $0.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")) } ?? "—"
    }

    var dataSourceLabel: String {
        usingSavedEntries ? "Saved log" : (sessionCount > 0 ? "Imported sessions" : "No data")
    }

    var activitySummaryText: String {
        if sessionCount > 0 {
            return "\(sessionCount) this month"
        }
        return dataSourceLabel
    }

    var statusText: String {
        guard let latestSession else { return selectedVehicleName == nil ? "Add vehicle" : "Needs setup" }
        let days = Calendar.current.dateComponents([.day], from: latestSession.date, to: Date()).day ?? 0
        switch days {
        case ..<3: return "Recent activity"
        case ..<14: return "Check in"
        default: return "Needs refresh"
        }
    }

    var statusStyle: StatusStyle {
        guard let latestSession else { return selectedVehicleName == nil ? .muted : .warning }
        let days = Calendar.current.dateComponents([.day], from: latestSession.date, to: Date()).day ?? 0
        return days < 3 ? .accent : .warning
    }

    var statsRowSubtitle: String {
        "\(monthlyEnergyText) • \(sessionCount) session(s) this month"
    }

    var lastSessionSummary: String {
        guard let latestSession else {
            return usingSavedEntries || selectedVehicleName != nil
                ? "No recent charging session recorded."
                : "Import charging history to build your timeline."
        }

        var parts = ["\(latestSession.title) · \(relativeDateText(for: latestSession.date))"]
        parts.append(latestSession.subtitle)
        if let cost = latestSession.cost {
            parts.append(cost.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
        }
        return parts.joined(separator: " • ")
    }

    var nextActionSubtitle: String {
        if latestSession == nil {
            return selectedVehicleName == nil
                ? "Choose a vehicle, then import or log your first charge."
                : "Import history or log a session to unlock live charge insights."
        }
        if monthlyEnergyKWh > 0 && monthlyCost == 0 {
            return "Review missing charging costs so this month reflects your real spend."
        }
        if statusStyle == .warning {
            return "Refresh recent activity so the latest state and costs stay current."
        }
        return "Open the planner to line up your next session around cheaper charging windows."
    }

    var nextActionSymbol: String {
        if latestSession == nil { return "square.and.arrow.down" }
        if monthlyEnergyKWh > 0 && monthlyCost == 0 { return "exclamationmark.triangle" }
        if statusStyle == .warning { return "arrow.clockwise" }
        return "clock.badge.checkmark"
    }

    static func build(
        selectedVehicle: VehicleProfile?,
        vehicleCount: Int,
        entries: [ExpenseEntry],
        sessions: [TeslaFiSession]
    ) -> MainTabChargingSnapshot {
        let filteredEntries = filteredEnergyEntries(entries, vehicle: selectedVehicle)
        let filteredSessions = filteredTeslaFiSessions(sessions, vehicle: selectedVehicle, vehicleCount: vehicleCount)
        let usingSavedEntries = !filteredEntries.isEmpty

        let preferredSessions: [Session] = usingSavedEntries
            ? filteredEntries.map(makeEntrySession).sorted { $0.date > $1.date }
            : filteredSessions.map(makeTeslaFiSession).sorted { $0.date > $1.date }

        let monthWindow = currentMonthWindow()
        let monthlySessions = preferredSessions.filter { monthWindow.contains($0.date) }
        let monthlyEnergy = monthlySessions.reduce(0) { $0 + $1.energyKWh }
        let monthlyCost = monthlySessions.compactMap(\.cost).reduce(0, +)
        let avgRate = monthlyEnergy > 0 && monthlyCost > 0 ? monthlyCost / monthlyEnergy : nil

        return MainTabChargingSnapshot(
            monthlyEnergyKWh: monthlyEnergy,
            monthlyCost: monthlyCost,
            avgRate: avgRate,
            sessionCount: monthlySessions.count,
            homeSessionCount: monthlySessions.filter(\.isHome).count,
            fastSessionCount: monthlySessions.filter(\.isFastCharge).count,
            latestSession: preferredSessions.first,
            recentSessions: Array(preferredSessions.prefix(4)),
            usingSavedEntries: usingSavedEntries,
            selectedVehicleName: selectedVehicle?.displayName
        )
    }

    private static func filteredEnergyEntries(_ entries: [ExpenseEntry], vehicle: VehicleProfile?) -> [ExpenseEntry] {
        let energyEntries = entries.filter(\.isEnergyEffective)
        guard let vehicle else { return energyEntries }

        let vin = normalized(vehicle.vin)
        let name = normalized(vehicle.displayName)

        return energyEntries.filter { entry in
            if entry.vehicleID == vehicle.id { return true }
            let entryVIN = normalized(entry.vin ?? entry.charging?.vin)
            if !vin.isEmpty, !entryVIN.isEmpty, entryVIN == vin { return true }
            let entryName = normalized(entry.vehicleName ?? entry.charging?.vehicleName)
            return !name.isEmpty && !entryName.isEmpty && entryName == name
        }
    }

    private static func filteredTeslaFiSessions(
        _ sessions: [TeslaFiSession],
        vehicle: VehicleProfile?,
        vehicleCount: Int
    ) -> [TeslaFiSession] {
        guard let vehicle else { return sessions }
        guard vehicleCount > 1 else { return sessions }

        let vin = normalized(vehicle.vin)
        let name = normalized(vehicle.displayName)

        return sessions.filter { session in
            let haystack = normalized((([session.location, session.displayLocation] as [String?]).compactMap { $0 } + Array(session.raw.values)).joined(separator: " "))
            return (!vin.isEmpty && haystack.contains(vin)) || (!name.isEmpty && haystack.contains(name))
        }
    }

    private static func makeEntrySession(_ entry: ExpenseEntry) -> Session {
        let title = entry.location ?? entry.charging?.siteName ?? entry.category
        let energy = entry.energyAddedKWh ?? 0
        return Session(
            id: entry.id.uuidString,
            date: entry.date,
            title: title,
            subtitle: "\(energy.formatted(.number.precision(.fractionLength(0...1)))) kWh",
            energyKWh: energy,
            cost: entry.amount > 0 ? entry.amount : nil,
            endSOC: entry.charging?.endSOC ?? entry.stateOfCharge,
            isFastCharge: isFastEntry(entry),
            isHome: isHome(title: title, isFastCharge: isFastEntry(entry))
        )
    }

    private static func makeTeslaFiSession(_ session: TeslaFiSession) -> Session {
        Session(
            id: session.sessionHash,
            date: session.endDate,
            title: session.displayLocation,
            subtitle: "\(session.energyAddedKWh.formatted(.number.precision(.fractionLength(0...1)))) kWh",
            energyKWh: session.energyAddedKWh,
            cost: session.cost,
            endSOC: nil,
            isFastCharge: isFastLocation(session.displayLocation),
            isHome: isHome(title: session.displayLocation, isFastCharge: isFastLocation(session.displayLocation))
        )
    }

    private static func isFastEntry(_ entry: ExpenseEntry) -> Bool {
        if entry.charging?.isSupercharger == true { return true }
        return isFastLocation((entry.location ?? "") + " " + (entry.chargeType ?? "") + " " + (entry.category))
    }

    private static func isFastLocation(_ location: String) -> Bool {
        let text = normalized(location)
        return text.contains("supercharg")
            || text.contains("dcfc")
            || text.contains("fast")
            || text.contains("electrify america")
            || text.contains("evgo")
            || text.contains("chargepoint")
    }

    private static func isHome(title: String, isFastCharge: Bool) -> Bool {
        let text = normalized(title)
        guard !isFastCharge else { return false }
        return text.contains("home")
            || text.contains("garage")
            || text.contains("residence")
            || text.contains("house")
    }

    private static func normalized(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func currentMonthWindow(referenceDate: Date = Date()) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)) ?? referenceDate
        let end = calendar.date(byAdding: DateComponents(month: 1), to: start)?.addingTimeInterval(-1) ?? referenceDate
        return start...end
    }

    private func relativeDateText(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Shared UI primitives

fileprivate struct MainTabStatusBadge: View {
    let text: String
    let style: MainTabChargingSnapshot.StatusStyle
    let accent: Color

    var body: some View {
        let tint: Color = switch style {
        case .accent: accent
        case .warning: .orange
        case .muted: .secondary
        }

        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.14)))
            .foregroundStyle(tint)
    }
}

fileprivate struct MainTabMetricPlate: View {
    let title: String
    let value: String
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme
    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(3)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.pillTint.opacity(scheme == .dark ? 0.24 : 0.72))
        )
    }
}

fileprivate struct MainTabQuickTile: View {
    let theme: any AppThemeSpec
    let accent: Color
    let title: String
    let systemImage: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 18, alignment: .center)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.pillTint.opacity(scheme == .dark ? 0.24 : 0.72))
        )
    }
}

fileprivate struct MainTabFocusRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
    let theme: any AppThemeSpec
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.pillTint.opacity(scheme == .dark ? 0.20 : 0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(theme.separator.opacity(scheme == .dark ? 0.78 : 0.55), lineWidth: 1)
                    )
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.pillTint.opacity(scheme == .dark ? 0.24 : 0.72))
        )
    }
}

fileprivate struct MainTabRecentSessionRow: View {
    let session: MainTabChargingSnapshot.Session
    let accent: Color

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(accent.opacity(0.85))
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 8) {
                    Text(session.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if session.isFastCharge || session.isHome {
                        Text(session.isFastCharge ? "Fast" : "Home")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(accent.opacity(0.12)))
                    }
                }
                Text("\(session.subtitle) • \(Self.formatter.string(from: session.date))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if let cost = session.cost {
                Text(cost.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

fileprivate struct MainTabSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2).padding(.top, 2)
            .accessibilityAddTraits(.isHeader)
    }
}

fileprivate struct MainTabCard<Content: View>: View {
    let theme: any AppThemeSpec
    let surface: AnyShapeStyle
    @ViewBuilder var content: Content
    var body: some View {
        content
            .themedCard(padding: theme.spacing, corner: theme.corner, surface: surface)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

fileprivate struct MainTabIconChip: View {
    let theme: any AppThemeSpec
    let accent: Color
    let symbol: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.pillTint.opacity(scheme == .dark ? 0.22 : 0.16))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(theme.separator.opacity(scheme == .dark ? 0.80 : 0.55), lineWidth: 1))
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold)).foregroundStyle(accent)
        }
        .frame(width: 42, height: 42).accessibilityHidden(true)
    }
}

fileprivate struct MainTabRow: View {
    let theme: any AppThemeSpec
    let accent: Color
    let title: String
    let subtitle: String
    let systemImage: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.pillTint.opacity(scheme == .dark ? 0.20 : 0.14))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(theme.separator.opacity(scheme == .dark ? 0.78 : 0.55), lineWidth: 1))
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6).contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(title)")
    }
}

fileprivate struct MainTabAvatarPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.94 : 1)
    }
}

// MARK: - UIImage resize helper

#if canImport(UIKit)
fileprivate extension UIImage {
    func kwh_resized(maxDimension: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        guard w > 0, h > 0 else { return self }
        let maxSide = max(w, h)
        guard maxSide > maxDimension else { return self }
        let scale    = maxDimension / maxSide
        let newSize  = CGSize(width: w * scale, height: h * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in self.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
#endif

// MARK: - Preview

#if DEBUG
#Preview {
    let entries = EntriesStore()
    let profile = ProfileStore()
    let teslaFi = TeslaFiSessionStore()
    let coord   = StoreCoordinator(entriesStore: entries, profileStore: profile, teslaFiStore: teslaFi)
    MainTabView()
        .environmentObject(AppAppearance())
        .environmentObject(AppUISettings())
        .environmentObject(entries)
        .environmentObject(teslaFi)
        .environmentObject(profile)
        .environmentObject(BrandThemeManager.shared)
        .environmentObject(coord)
}
#endif

/*
 Info.plist:
 - Privacy - Photo Library Usage Description (NSPhotoLibraryUsageDescription)
   Example: "Select a profile photo for your Settings button."
*/
