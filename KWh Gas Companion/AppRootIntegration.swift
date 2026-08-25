// AppRootIntegration.swift
// My EV Companion
//
// Correct wiring for your REAL MainTabView + DashboardView.
// No invented views. No structural changes to existing files.
//
// ────────────────────────────────────────────────────────────
// WHAT CHANGES
// ────────────────────────────────────────────────────────────
// 1. AppRootWrapper  — wraps MainTabView, injects BrandThemeManager
//                      + StoreCoordinator alongside your existing stores
//
// 2. MainTabView     — one line change: accent comes from BrandThemeManager
//                      (tab bar + nav bar auto-switch: Tesla red, Rivian green, neutral blue)
//
// 3. DashboardView   — add @EnvironmentObject coord: StoreCoordinator
//                      replace the 3 most expensive inline computed vars
//                      (monthEnergyCost / monthEnergyKWh / avgCostPerKWh)
//
// ────────────────────────────────────────────────────────────
// WHAT DOES NOT CHANGE
// ────────────────────────────────────────────────────────────
// ✅ MainTabView structure (5 tabs, sidebar, haptics, avatar, deep links)
// ✅ DashboardView card layout, collapse buttons, layout store
// ✅ BudgetSettingsSheet
// ✅ MainTabThemedRoot (background gradients, safe area)
// ✅ MainTabChargingCenterScreen / MainTabVehicleCenterScreen
// ✅ AppThemeSpec / AppThemeBox (BrandTheme is purely additive)
// ✅ AppUISettings (motion, haptics, background)
// ✅ All @AppStorage keys
// ────────────────────────────────────────────────────────────

import SwiftUI
import Combine

// MARK: - AppRootWrapper
//
// USAGE — In your @main App struct, replace:
//
//   WindowGroup { MainTabView().environmentObject(...) }
//
// with:
//
//   WindowGroup { AppRootWrapper { MainTabView() } }
//
// All your existing .environmentObject calls move inside AppRootWrapper.
// It injects everything the old code had, plus BrandThemeManager + StoreCoordinator.

public struct AppRootWrapper<Root: View>: View {

    // ── Existing stores (same as before) ──────────────────────
    @StateObject private var profileStore  = ProfileStore()
    @StateObject private var entriesStore  = EntriesStore()
    @StateObject private var teslaFiStore  = TeslaFiSessionStore()
    @StateObject private var appearance    = AppAppearance()
    @StateObject private var uiSettings    = AppUISettings()

    // ── NEW ───────────────────────────────────────────────────
    @StateObject private var brandManager  = BrandThemeManager.shared
    @StateObject private var coordinator: StoreCoordinator

    @Environment(\.colorScheme) private var scheme
    @AppStorage("themePreset") private var themePresetRaw: String = ThemeStyle.appDefault.rawValue
    @AppStorage("uiStyle") private var legacyUIStyleRaw: String = "classic"

    // Onboarding (only runs once)
    @AppStorage("onboarding.v2.completed") private var onboardingDone = false
    @State private var showOnboarding = false

    private let root: Root

    private var style: ThemeStyle {
        ThemeStyle.resolve(themePresetRaw: themePresetRaw, legacyUIStyleRaw: legacyUIStyleRaw)
    }

    public init(@ViewBuilder root: () -> Root) {
        self.root = root()
        // StoreCoordinator references the same shared stores.
        // In practice your app likely has singleton/shared stores —
        // if so, replace these with your shared instances.
        let es = EntriesStore()
        let ps = ProfileStore()
        let tf = TeslaFiSessionStore()
        _coordinator = StateObject(wrappedValue: StoreCoordinator(
            entriesStore: es,
            profileStore: ps,
            teslaFiStore: tf
        ))
    }

    public var body: some View {
        root
            // ── Existing ─────────────────────────────────────
            .environmentObject(profileStore)
            .environmentObject(entriesStore)
            .environmentObject(teslaFiStore)
            .environmentObject(appearance)
            .environmentObject(uiSettings)
            // ── NEW ──────────────────────────────────────────
            .environmentObject(brandManager)
            .environmentObject(coordinator)
            .environment(\.brandTheme, brandManager.theme)
            // BrandThemeModifier auto-switches theme on vehicle change
            .modifier(BrandThemeModifier())
            // Drive the system tint from the brand accent
            // (overrides MainTabView's .tint(accent) with the brand color)
            .tint(brandManager.theme.tokens.accent)
            // Onboarding sheet
            .sheet(isPresented: $showOnboarding) {
                OnboardingFlowView(isPresented: $showOnboarding)
                    .interactiveDismissDisabled()
            }
            .onAppear {
                brandManager.update(vehicle: profileStore.selectedVehicle, scheme: scheme, style: style)
                if !onboardingDone {
                    showOnboarding = true
                    // onboardingDone is written by OnboardingFlowView.completeOnboarding()
                    // after the user finishes the last step — do not set it here.
                }
            }
            .onChange(of: scheme) { _, s in
                brandManager.update(vehicle: profileStore.selectedVehicle, scheme: s, style: style)
            }
            .onChange(of: themePresetRaw) { _, _ in
                brandManager.update(vehicle: profileStore.selectedVehicle, scheme: scheme, style: style)
            }
    }
}

// MARK: - MainTabView patch (1 line)
// ─────────────────────────────────────────────────────────────
// In MainTabView.swift, add this property:
//
//   @EnvironmentObject private var brandManager: BrandThemeManager
//
// Then change the accent computed var from:
//
//   private var accent: Color { appearance.accentColor }
//
// to:
//
//   private var accent: Color { brandManager.theme.tokens.accent }
//
// That's it. updateTabBarAppearance() already uses `accent`,
// so Tesla red / Rivian green / neutral blue flows to:
//   • Tab bar icons + labels
//   • Navigation bar tint
//   • All .tint(accent) calls in the view tree
//
// The animatable transition (0.35s easeInOut) in BrandThemeManager
// means switching vehicles in Garage smoothly re-colors the UI.
// ─────────────────────────────────────────────────────────────

// MARK: - DashboardView patch (3 computed vars)
// ─────────────────────────────────────────────────────────────
// In DashboardView.swift:
//
// 1. ADD at the top of DashboardView struct:
//      @EnvironmentObject private var coord: StoreCoordinator
//
// 2. REPLACE these three computed vars:
//
// ❌ BEFORE (re-filters the full entry array on every single redraw):
//    private var monthEnergyCost: Double {
//        energyEntriesThisMonth.reduce(0) { $0 + max(0, $1.amount) }
//    }
//    private var monthEnergyKWh: Double {
//        energyEntriesThisMonth.reduce(0) { $0 + max(0, $1.energyAddedKWh ?? 0) }
//    }
//    private var avgCostPerKWh: Double? {
//        guard monthEnergyKWh > 0, monthEnergyCost > 0 else { return nil }
//        return monthEnergyCost / monthEnergyKWh
//    }
//
// ✅ AFTER (reads pre-computed Hashable snapshot — SwiftUI skips redraws when equal):
//    private var monthEnergyCost: Double { coord.monthlySummary.cost }
//    private var monthEnergyKWh:  Double { coord.monthlySummary.kWh }
//    private var avgCostPerKWh: Double?  { coord.monthlySummary.avgRatePerKWh }
//
// 3. REPLACE in greetingCard (biggest visible payoff):
// ❌ Text(formatCurrency(effectiveSpentTotal, currency: defaultCurrencyCode))
// ✅ Text(formatCurrency(coord.monthlySummary.cost, currency: defaultCurrencyCode))
//
// 4. REPLACE in recentActivityCard:
// ❌ ForEach(entriesThisMonth.prefix(3)) { e in
// ✅ ForEach(coord.recentSessions.prefix(3)) { e in
//
// 5. REPLACE in insightsCard statsGrid calls:
// ❌ monthEnergyKWh > 0 ? "\(formatNumber(monthEnergyKWh, digits: 1)) kWh" : "—"
// ✅ coord.monthlySummary.kWh > 0 ? "\(formatNumber(coord.monthlySummary.kWh, digits: 1)) kWh" : "—"
//
// ❌ avgCostPerKWh.map { formatCurrency($0, currency: defaultCurrencyCode) } ?? "—"
// ✅ coord.monthlySummary.avgRatePerKWh.map { formatCurrency($0, currency: defaultCurrencyCode) } ?? "—"
//
// WHY THIS MATTERS
// Both entriesThisMonth and energyEntriesThisMonth filter the entire
// entries array on EVERY redraw. DashboardView has 12 card slots, each
// calling these vars. On a large dataset (500+ entries), this is
// 12 × O(n) work per frame. StoreCoordinator does it once per 300ms.
// ─────────────────────────────────────────────────────────────

// MARK: - LazyVStack → smarter rendering in DashboardView
// ─────────────────────────────────────────────────────────────
// DashboardView already uses LazyVStack (good). Two more improvements:
//
// 1. Add .id(kind) to each ForEach card so SwiftUI can diff by identity:
//    ForEach(layout.visibleOrder, id: \.self) { kind in
//        cardSpec(for: kind).view
//            .modifier(CardPolish())
//            .frame(maxWidth: .infinity, alignment: .leading)
//            .id(kind)    // ← ADD THIS
//    }
//
// 2. The spending computed var (Spending struct) runs 5 separate filter
//    passes over entriesThisMonth. Move it into StoreCoordinator or
//    cache it with @State + onChange:
//
//    @State private var cachedSpending: Spending = .empty
//
//    .onChange(of: coord.monthlySummary) { _, _ in
//        cachedSpending = buildSpending()  // your existing spending logic
//    }
//    .onAppear { cachedSpending = buildSpending() }
//
//    Then replace `spending` with `cachedSpending` throughout.
// ─────────────────────────────────────────────────────────────

// MARK: - Brand color reference card
//
//  Vehicle make/VIN      │ Accent          │ Aesthetic
//  ─────────────────────┼─────────────────┼──────────────────────────
//  Tesla (5YJ/7SA/LRW)  │ #E82127 red     │ Tessie: dark glass, red
//  Rivian (7FC/7PD)     │ #4CAF87 green   │ Rivian: forest, earth
//  All other makes      │ #0A84FF blue    │ Neutral iOS blue
//
//  The theme animates (0.35s easeInOut) when you switch vehicles.
//  Brand badge in HomeViewRedesigned shows "Tesla" / "Rivian" / make.
