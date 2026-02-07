//
//  MainTabView.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//
//  Regenerated (reduced top empty space + polished + AppThemeSpec-driven surfaces):
//  ✅ Reduced perceived “empty space” by using inline nav titles (content already has its own headers)
//  ✅ Reduced top padding in center screens
//  ✅ AppThemeSpec drives: background, card surfaces, separators, spacing, corners, elevation
//  ✅ AppAppearance drives: accent tint + user preference scheme
//  ✅ Glass/classic supported: .thinMaterial OR theme.cardBackground
//  ✅ Bigger profile photo button (fits real photos better)
//  ✅ Vehicles → Garage opens VehicleProfileListView() (linked correctly)
//  ✅ Tab bar + nav bar themed/material backgrounds
//  ✅ Haptics: selection on tab change, success on avatar updates
//

import SwiftUI
import Foundation
import PhotosUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

fileprivate enum MainTab: Hashable {
    case home
    case charging
    case expenses
    case vehicles
    case tools
}

fileprivate extension MainTab {
    static func from(raw: String) -> MainTab? {
        switch raw.lowercased() {
        case "home": return .home
        case "charging": return .charging
        case "expenses": return .expenses
        case "vehicles": return .vehicles
        case "tools": return .tools
        default: return nil
        }
    }

    var rawString: String {
        switch self {
        case .home: return "home"
        case .charging: return "charging"
        case .expenses: return "expenses"
        case .vehicles: return "vehicles"
        case .tools: return "tools"
        }
    }
}

extension Notification.Name {
    static let mainTabSelect = Notification.Name("MainTabView.mainTabSelect")
}

@MainActor
struct MainTabView: View {

    // MARK: - Environment

    @EnvironmentObject private var appearance: AppAppearance
    @EnvironmentObject private var uiSettings: AppUISettings
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Mirrors SettingsView key
    @AppStorage("uiStyle") private var uiStyleRaw: String = "teslaGlass"

    // Persisted avatar (JPEG, resized)
    @AppStorage("kwh.userAvatarJPEG") private var avatarJPEG: Data = Data()

    // MARK: - State

    @SceneStorage("mainTab.selected") private var tabRaw: String = "home"
    @State private var showingSettings: Bool = false

    // Avatar picker state
    @State private var showAvatarPicker: Bool = false
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var mainTabObserver: NSObjectProtocol?
    @StateObject private var adsStore = AdsEntitlementStore.shared

    // Feedback triggers
    @State private var avatarFeedbackTick: Int = 0

    // If ExpenseListTabView already has its own NavigationStack,
    // set this to false to avoid double navigation bars.
    private let wrapExpensesInNavigationStack: Bool = true

    // MARK: - Theme helpers

    private var theme: any AppThemeSpec { themeBox.base }
    private var accent: Color { appearance.accentColor }

    private var isGlass: Bool {
        let v = uiStyleRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return v == "teslaglass" || v == "glass"
    }

    private var barBackground: AnyShapeStyle {
        isGlass ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(theme.cardBackground)
    }

    private var cardSurface: AnyShapeStyle {
        isGlass ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(theme.cardBackground)
    }

    // Bigger avatar for real profile photos
    private let avatarSize: CGFloat = 40
    private let avatarRingWidth: CGFloat = 1

    var body: some View {
        baseView
    }

    @ViewBuilder
    private var baseView: some View {
        if uiSettings.haptics != .off {
            baseViewCore
                .sensoryFeedback(.success, trigger: avatarFeedbackTick)
        } else {
            baseViewCore
        }
    }

    private var baseViewCore: some View {
        contentView
            .tint(accent)
            .preferredColorScheme(appearance.preferredColorScheme)
            .sheet(isPresented: $showingSettings) { settingsSheet }
            .onOpenURL(perform: handleDeepLink(_:))
            .panelToast(
                isPresented: Binding(
                    get: { adsStore.toastMessage != nil },
                    set: { if !$0 { adsStore.toastMessage = nil } }
                ),
                text: adsStore.toastMessage ?? ""
            )
            .onAppear {
                updateTabBarAppearance()
                if mainTabObserver == nil {
                    mainTabObserver = NotificationCenter.default.addObserver(
                        forName: .mainTabSelect,
                        object: nil,
                        queue: .main
                    ) { note in
                        if let raw = note.userInfo?["tab"] as? String,
                           let next = MainTab.from(raw: raw) {
                            Task { @MainActor in
                                tabRaw = next.rawString
                            }
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
            .onChange(of: uiStyleRaw) { _, _ in
                updateTabBarAppearance()
            }
            .onChange(of: appearance.preferredColorScheme) { _, _ in
                updateTabBarAppearance()
            }
    }

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
            .toolbarBackground(barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(accent)
        .preferredColorScheme(appearance.preferredColorScheme)
    }

    private var avatarPickerToken: String {
        avatarPickerItem?.itemIdentifier ?? ""
    }

    @ViewBuilder
    private var contentView: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                sidebar
            } detail: {
                tabContent
            }
            .navigationSplitViewStyle(.balanced)
            .toolbarBackground(barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        } else {
            if uiSettings.haptics == .off {
                TabView(selection: tabBinding) {
                    homeRoot
                        .tabItem { Label("Home", systemImage: "car") }
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
                        .tabItem { Label("Tools", systemImage: "square.grid.2x2") }
                        .tag(MainTab.tools)
                }
                .toolbarBackground(barBackground, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .transaction { $0.animation = nil }
            } else {
                TabView(selection: tabBinding) {
                    homeRoot
                        .tabItem { Label("Home", systemImage: "car") }
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
                        .tabItem { Label("Tools", systemImage: "square.grid.2x2") }
                        .tag(MainTab.tools)
                }
                .toolbarBackground(barBackground, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .sensoryFeedback(.selection, trigger: tabValue)
                .transaction { $0.animation = nil }
            }
        }
    }

    // MARK: - Expenses root (optional NavigationStack wrapper)

    @ViewBuilder
    private var expensesRoot: some View {
        if wrapExpensesInNavigationStack {
            NavigationStack {
                MainTabThemedRoot(theme: theme, accent: accent, addTabBarInset: true) {
                    ExpenseListTabView()
                }
                .navigationTitle("Expenses")
                .navigationBarTitleDisplayMode(.inline)   // ✅ reduces top whitespace
                .toolbar { profileToolbar }
                .toolbarBackground(barBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
            }
        } else {
            MainTabThemedRoot(theme: theme, accent: accent, addTabBarInset: true) {
                ExpenseListTabView()
            }
            .toolbar { profileToolbar }
        }
    }

    // MARK: - iPad sidebar

    private var sidebar: some View {
        List(selection: tabSelectionBinding) {
            Label("Home", systemImage: "car")
                .tag(MainTab.home)
            Label("Charging", systemImage: "bolt.car")
                .tag(MainTab.charging)
            Label("Expenses", systemImage: "creditcard")
                .tag(MainTab.expenses)
            Label("Vehicles", systemImage: "car.2.fill")
                .tag(MainTab.vehicles)
            Label("Tools", systemImage: "square.grid.2x2")
                .tag(MainTab.tools)
        }
        .listStyle(.sidebar)
        .navigationTitle("KWh Gas")
        .toolbar { profileToolbar }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tabValue {
        case .home:
            homeRoot
        case .charging:
            chargingRoot
        case .expenses:
            expensesRoot
        case .vehicles:
            vehiclesRoot
        case .tools:
            toolsRoot
        }
    }

    private var tabValue: MainTab {
        MainTab.from(raw: tabRaw) ?? .home
    }

    private var tabBinding: Binding<MainTab> {
        Binding(
            get: { MainTab.from(raw: tabRaw) ?? .home },
            set: { tabRaw = $0.rawString }
        )
    }

    private var tabSelectionBinding: Binding<MainTab?> {
        Binding(
            get: { MainTab.from(raw: tabRaw) ?? .home },
            set: { newValue in
                guard let next = newValue else { return }
                tabRaw = next.rawString
            }
        )
    }

    // MARK: - Tab roots

    private var homeRoot: some View {
        NavigationStack {
            MainTabThemedRoot(theme: theme, accent: accent, addTabBarInset: true) {
                DashboardView()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { profileToolbar }
            .toolbarBackground(barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var chargingRoot: some View {
        NavigationStack {
            MainTabThemedRoot(theme: theme, accent: accent, addTabBarInset: true) {
                MainTabChargingCenterScreen(surface: cardSurface)
            }
            .navigationTitle("Charging")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { profileToolbar }
            .toolbarBackground(barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var vehiclesRoot: some View {
        NavigationStack {
            MainTabThemedRoot(theme: theme, accent: accent, addTabBarInset: true) {
                MainTabVehicleCenterScreen(surface: cardSurface, openSettings: { showingSettings = true })
            }
            .navigationTitle("Vehicles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { profileToolbar }
            .toolbarBackground(barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var toolsRoot: some View {
        NavigationStack {
            MainTabThemedRoot(theme: theme, accent: accent, addTabBarInset: true) {
                CalculatorsDashboardView()
            }
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { profileToolbar }
            .toolbarBackground(barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    // MARK: - Profile button (shows avatar, editable)

    @ToolbarContentBuilder
    private var profileToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showingSettings = true } label: {
                avatarButtonLabel
                    .padding(.vertical, 2) // slightly less chrome crowding
            }
            .buttonStyle(MainTabAvatarPressStyle())
            .accessibilityLabel("Settings")
            .contextMenu {
                Button {
                    showingSettings = true
                } label: {
                    Label("Open Settings", systemImage: "gearshape")
                }

                Button {
                    showAvatarPicker = true
                } label: {
                    Label("Choose Photo…", systemImage: "photo")
                }

                if !avatarJPEG.isEmpty {
                    Button(role: .destructive) {
                        avatarJPEG = Data()
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                    }
                }
            }
            .photosPicker(isPresented: $showAvatarPicker, selection: $avatarPickerItem, matching: .images)
        }
    }

    private var avatarButtonLabel: some View {
        ZStack {
            Circle()
                .fill(theme.pillTint.opacity(scheme == .dark ? 0.22 : 0.16))

            if let ui = UIImage(data: avatarJPEG), !avatarJPEG.isEmpty {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                    .clipped()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: avatarSize * 0.62, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.95))
            }

            Circle()
                .strokeBorder(theme.separator.opacity(scheme == .dark ? 0.85 : 0.65),
                              lineWidth: avatarRingWidth)

            Circle()
                .inset(by: avatarRingWidth)
                .strokeBorder(accent.opacity(0.28),
                              lineWidth: avatarRingWidth)
        }
        .frame(width: avatarSize, height: avatarSize)
        .contentShape(Circle())
        .shadow(
            color: theme.separator.opacity(scheme == .dark ? 0.26 : 0.18),
            radius: theme.elevation + 2,
            x: 0,
            y: 3
        )
        .accessibilityHint("Opens Settings. Long-press for photo options.")
    }

    private func loadAndPersistAvatar(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let ui = UIImage(data: data)
            else { return }

            let resized = ui.kwh_resized(maxDimension: 768)
            if let jpeg = resized.jpegData(compressionQuality: 0.85) {
                avatarJPEG = jpeg
            } else {
                avatarJPEG = data
            }
            avatarFeedbackTick &+= 1
        } catch {
            // Silent fail
        }
    }

    // MARK: - Deep links

    private func handleDeepLink(_ url: URL) {
        let scheme = (url.scheme ?? "").lowercased()
        guard scheme.contains("kwh") else { return }

        let host = (url.host ?? "").lowercased()
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let tabQuery = comps?.queryItems?.first(where: { $0.name.lowercased() == "tab" })?.value?.lowercased()
        let target = tabQuery ?? host

        switch target {
        case "home", "dashboard", "overview":
            tabRaw = MainTab.home.rawString
        case "charging":
            tabRaw = MainTab.charging.rawString
        case "expenses":
            tabRaw = MainTab.expenses.rawString
        case "vehicles", "garage":
            tabRaw = MainTab.vehicles.rawString
        case "tools", "calculators":
            tabRaw = MainTab.tools.rawString
        case "settings":
            showingSettings = true
        default:
            break
        }
    }
}

// MARK: - Themed Root Container (AppThemeSpec-driven)

fileprivate struct MainTabThemedRoot<Content: View>: View {
    let theme: any AppThemeSpec
    let accent: Color
    let addTabBarInset: Bool
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var uiSettings: AppUISettings
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let content: Content
    init(theme: any AppThemeSpec, accent: Color, addTabBarInset: Bool = false, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.accent = accent
        self.addTabBarInset = addTabBarInset
        self.content = content()
    }

    var body: some View {
        ZStack {
            Rectangle().fill(theme.screenBackground).ignoresSafeArea()

            switch uiSettings.background {
            case .defaultGlow:
                if uiSettings.motion == .full {
                    RadialGradient(
                        colors: [accent.opacity(scheme == .dark ? 0.18 : 0.10), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 520
                    )
                    .blur(radius: 28)
                    .ignoresSafeArea()

                    RadialGradient(
                        colors: [theme.accent.opacity(scheme == .dark ? 0.10 : 0.06), .clear],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: 620
                    )
                    .blur(radius: 34)
                    .ignoresSafeArea()
                }

            case .aurora:
                if uiSettings.motion == .full {
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
                }

            case .dusk:
                if uiSettings.motion == .full {
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
                }

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
                if uiSettings.motion == .full {
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
                }

            case .lunarNewYear:
                if uiSettings.motion == .full {
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
                }

            case .halloween:
                if uiSettings.motion == .full {
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
                }

            case .thanksgiving:
                if uiSettings.motion == .full {
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
                }

            case .newYear:
                if uiSettings.motion == .full {
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

            content
                .safeAreaInset(edge: .bottom) {
                    if addTabBarInset && horizontalSizeClass == .compact {
                        Color.clear.frame(height: 64)
                    }
                }
        }
    }
}

// MARK: - Tab Bar Appearance

private extension MainTabView {
    func updateTabBarAppearance() {
        #if canImport(UIKit)
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()

        let isDark = (self.appearance.preferredColorScheme == .dark) || (self.appearance.preferredColorScheme == nil && scheme == .dark)
        let baseBackground: UIColor = isGlass
            ? UIColor(white: isDark ? 0.10 : 0.96, alpha: 0.92)
            : UIColor(white: isDark ? 0.08 : 0.98, alpha: 1.0)

        tabAppearance.backgroundColor = baseBackground
        tabAppearance.shadowColor = UIColor.black.withAlphaComponent(isDark ? 0.35 : 0.18)

        let selected = UIColor(accent)
        let unselected = UIColor(white: isDark ? 0.68 : 0.48, alpha: 1.0)

        let item = tabAppearance.stackedLayoutAppearance
        item.normal.iconColor = unselected
        item.normal.titleTextAttributes = [.foregroundColor: unselected]
        item.selected.iconColor = selected
        item.selected.titleTextAttributes = [.foregroundColor: selected]

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        #endif
    }
}

// MARK: - Charging Center

@MainActor
fileprivate struct MainTabChargingCenterScreen: View {

    @EnvironmentObject private var appearance: AppAppearance
    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore
    @Environment(\.appThemeBox) private var themeBox

    let surface: AnyShapeStyle

    private var theme: any AppThemeSpec { themeBox.base }
    private var accent: Color { appearance.accentColor }

    private var topPad: CGFloat { max(4, theme.spacing * 0.35) } // ✅ reduced
    private var bottomPad: CGFloat { max(24, theme.spacing * 2.0) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing + 10) {

                MainTabCard(theme: theme, surface: surface) {
                    HStack(alignment: .top, spacing: 12) {
                        MainTabIconChip(theme: theme, accent: accent, symbol: "bolt.fill")

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Charging Center")
                                .font(.title3.weight(.semibold))
                            Text("Imports, sessions, analysis, and trip tools.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Label("\(teslaFiStore.sessions.count) sessions", systemImage: "bolt.car")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }

                        Spacer()
                    }
                }

                MainTabSectionHeader("Data & imports")

                MainTabCard(theme: theme, surface: surface) {
                    VStack(spacing: 0) {
                        NavigationLink {
                            ChargingDataHubView()
                                .navigationTitle("Charging Data")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            MainTabRow(theme: theme, accent: accent,
                                       title: "Charging Data Hub",
                                       subtitle: "Sessions, integrity, reconciliation",
                                       systemImage: "bolt.car")
                        }
                        .buttonStyle(.plain)

                        Divider().opacity(0.65)

                        NavigationLink {
                            ChargingImportHubView()
                                .navigationTitle("Import Charging")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            MainTabRow(theme: theme, accent: accent,
                                       title: "Import Hub",
                                       subtitle: "CSV sources and imports",
                                       systemImage: "tray.and.arrow.down")
                        }
                        .buttonStyle(.plain)

                        Divider().opacity(0.65)

                        NavigationLink {
                            TeslaFiCSVImportView()
                                .navigationTitle("TeslaFi Import")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            MainTabRow(theme: theme, accent: accent,
                                       title: "TeslaFi CSV Import",
                                       subtitle: "Bring in charging sessions",
                                       systemImage: "doc.text")
                        }
                        .buttonStyle(.plain)

                        Divider().opacity(0.65)

                        NavigationLink {
                            CSVChargingWizardView()
                                .navigationTitle("CSV Wizard")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            MainTabRow(theme: theme, accent: accent,
                                       title: "CSV Charging Wizard",
                                       subtitle: "Clean, validate, then import",
                                       systemImage: "wand.and.stars")
                        }
                        .buttonStyle(.plain)
                    }
                }

                MainTabSectionHeader("Maps & pricing")

                MainTabCard(theme: theme, surface: surface) {
                    VStack(spacing: 0) {
                        NavigationLink {
                            SuperchargerHelperHost()
                                .navigationTitle("Cheapest Charger Finder")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            MainTabRow(theme: theme, accent: accent,
                                       title: "Cheapest Charger Finder",
                                       subtitle: "Find the lowest-cost window",
                                       systemImage: "bolt.circle")
                        }
                        .buttonStyle(.plain)

                        Divider().opacity(0.65)

                        NavigationLink {
                            NearMeView()
                                .navigationTitle("Near Me")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            MainTabRow(theme: theme, accent: accent,
                                       title: "Near Me",
                                       subtitle: "Nearby chargers & superchargers",
                                       systemImage: "location")
                        }
                        .buttonStyle(.plain)

                        Divider().opacity(0.65)

                        NavigationLink {
                            DynamicSuperchargingExplainerView()
                                .navigationTitle("Dynamic Supercharging")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            MainTabRow(theme: theme, accent: accent,
                                       title: "Dynamic Supercharging",
                                       subtitle: "Understand variable pricing",
                                       systemImage: "bolt.badge.clock")
                        }
                        .buttonStyle(.plain)
                    }
                }

                MainTabSectionHeader("Trips")

                MainTabCard(theme: theme, surface: surface) {
                    VStack(spacing: 0) {
                        NavigationLink {
                            TripPlannerView()
                                .navigationTitle("Trip Planner")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            MainTabRow(theme: theme, accent: accent,
                                       title: "Trip Planner",
                                       subtitle: "Route planning + stops",
                                       systemImage: "map")
                        }
                        .buttonStyle(.plain)

                        Divider().opacity(0.65)

                        NavigationLink {
                            TripLoggerView()
                                .navigationTitle("Trip Logger")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            MainTabRow(theme: theme, accent: accent,
                                       title: "Trip Logger",
                                       subtitle: "Record and review drives",
                                       systemImage: "road.lanes")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, topPad)        // ✅ reduced
            .padding(.bottom, bottomPad)
        }
        .tint(accent)
    }
}

// MARK: - Vehicles Center (Garage → VehicleProfileListView)

@MainActor
fileprivate struct MainTabVehicleCenterScreen: View {

    @EnvironmentObject private var appearance: AppAppearance
    @Environment(\.appThemeBox) private var themeBox

    let surface: AnyShapeStyle
    let openSettings: () -> Void

    private var theme: any AppThemeSpec { themeBox.base }
    private var accent: Color { appearance.accentColor }

    private var topPad: CGFloat { max(4, theme.spacing * 0.35) } // ✅ reduced
    private var bottomPad: CGFloat { max(24, theme.spacing * 2.0) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing + 10) {

                MainTabCard(theme: theme, surface: surface) {
                    HStack(alignment: .top, spacing: 12) {
                        MainTabIconChip(theme: theme, accent: accent, symbol: "car.2.fill")

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Vehicle Center")
                                .font(.title3.weight(.semibold))
                            Text("Garage, VIN tools, service, and recall info.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }

                MainTabSectionHeader("Garage")

                MainTabCard(theme: theme, surface: surface) {
                    NavigationLink {
                        VehicleProfileListView()
                            .navigationTitle("Garage")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        MainTabRow(theme: theme, accent: accent,
                                   title: "Garage",
                                   subtitle: "Vehicles, presets, assumptions",
                                   systemImage: "car.2.fill")
                    }
                    .buttonStyle(.plain)
                }

                MainTabSectionHeader("VIN & service")

                MainTabCard(theme: theme, surface: surface) {
                    VStack(spacing: 0) {
                        NavigationLink {
                            TeslaVINDecoderView()
                                .navigationTitle("Tesla VIN Decoder")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            MainTabRow(theme: theme, accent: accent,
                                       title: "Tesla VIN Decoder",
                                       subtitle: "Decode model and details",
                                       systemImage: "textformat.123")
                        }
                        .buttonStyle(.plain)

                        Divider().opacity(0.65)

                        NavigationLink {
                            RivianVINDecoderView()
                                .navigationTitle("Rivian VIN Decoder")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            MainTabRow(theme: theme, accent: accent,
                                       title: "Rivian VIN Decoder",
                                       subtitle: "Decode trim and drivetrain",
                                       systemImage: "textformat.123")
                        }
                        .buttonStyle(.plain)

                        Divider().opacity(0.65)

                        NavigationLink {
                            ServiceRemindersView()
                                .navigationTitle("Service Reminders")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            MainTabRow(theme: theme, accent: accent,
                                       title: "Service Reminders",
                                       subtitle: "Keep maintenance on track",
                                       systemImage: "wrench.and.screwdriver")
                        }
                        .buttonStyle(.plain)

                        Divider().opacity(0.65)

                        NavigationLink {
                            RecallsView()
                                .navigationTitle("Recalls")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            MainTabRow(theme: theme, accent: accent,
                                       title: "Recalls",
                                       subtitle: "Safety and recall checks",
                                       systemImage: "exclamationmark.triangle")
                        }
                        .buttonStyle(.plain)
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
            .padding(.horizontal, 16)
            .padding(.top, topPad)        // ✅ reduced
            .padding(.bottom, bottomPad)
        }
        .tint(accent)
    }
}

// MARK: - Shared UI blocks (AppThemeSpec-driven)

fileprivate struct MainTabSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)
            .padding(.top, 2)
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
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(theme.separator.opacity(scheme == .dark ? 0.80 : 0.55), lineWidth: 1)
                )

            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(accent)
        }
        .frame(width: 42, height: 42)
        .accessibilityHidden(true)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(theme.separator.opacity(scheme == .dark ? 0.78 : 0.55), lineWidth: 1)
                    )

                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
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
        .padding(.vertical, 6) // ✅ slightly tighter than before
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(title)")
    }
}

fileprivate struct MainTabAvatarPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - UIImage helper

#if canImport(UIKit)
fileprivate extension UIImage {
    func kwh_resized(maxDimension: CGFloat) -> UIImage {
        let w = size.width
        let h = size.height
        guard w > 0, h > 0 else { return self }

        let maxSide = max(w, h)
        guard maxSide > maxDimension else { return self }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: w * scale, height: h * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
#endif

#if DEBUG
#Preview {
    MainTabView()
        .environmentObject(AppAppearance())
        .environmentObject(AppUISettings())
        .environmentObject(EntriesStore())
        .environmentObject(TeslaFiSessionStore())
}
#endif

/*
 Info.plist:
 - Add: Privacy - Photo Library Usage Description (NSPhotoLibraryUsageDescription)
   Example: "Select a profile photo for your Settings button."
*/
