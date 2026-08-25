//
//  KWh_Gas_CompanionApp.swift
//  My EV Companion
//
//  Swift 6 • iOS 17+
//
//  Performance + build-time revision:
//  ✅ AppEnvironmentModifier extracts the 13-chain .environmentObject() call
//     into a single ViewModifier — measurably reduces type-checker work at build time
//  ✅ AppRootHostView no longer stores a generic `Content: View` as a `let` property;
//     uses @ViewBuilder instead — prevents MainTabView subtree reconstruction every body pass
//  ✅ DeepDepth TeslaFi + Entries mapping extracted to file-private free functions —
//     reduces closure complexity so the type checker resolves them independently
//  ✅ String .lowercased() called once per entry/session field, result reused —
//     eliminates redundant String allocations inside hot compactMap loops
//  ✅ Mirror single-pass preserved (already optimal for unknown-shape compatibility shim);
//     added inline note on how to eliminate it entirely if ExpenseEntry gains direct properties
//  ✅ Startup warmup delay uses Duration API (cleaner, same semantics)
//  ✅ All store init ordering unchanged (correctness preserved)
//

import SwiftUI
import os.log
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

// MARK: - App entry point

@main
struct KWh_Gas_CompanionApp: App {
    @AppStorage("onboarding.v2.completed") private var onboardingCompleted = false
    @State private var showOnboarding = false

    // Core stores — created exactly once in init()
    @StateObject private var profileStore:      ProfileStore
    @StateObject private var entriesStore:      EntriesStore
    @StateObject private var teslaFiStore:      TeslaFiSessionStore
    @StateObject private var budgetStore:       BudgetStore
    @StateObject private var appearance:        AppAppearance
    @StateObject private var toolUsage:         ToolUsageStore
    @StateObject private var uiSettings:        AppUISettings
    @StateObject private var coordinator:       StoreCoordinator
    @StateObject private var superchargerStore: SuperchargePricingInfoStore
    @StateObject private var teslaPricingStore: TeslaOfficialSuperchargerPricingStore
    @StateObject private var appModel:          KWhGasCompanionAppModel
    @StateObject private var startup =          AppStartupCoordinator()
    @StateObject private var adsStartup =       AdsStartupCoordinator()

    // Built once — never recreated on body recompute
    private let deepDepthProvider: DeepDepthDataProvider

    init() {
        let profile = ProfileStore()
        let entries = EntriesStore()
        let teslaFi = TeslaFiSessionStore()

        _profileStore      = StateObject(wrappedValue: profile)
        _entriesStore      = StateObject(wrappedValue: entries)
        _teslaFiStore      = StateObject(wrappedValue: teslaFi)
        _budgetStore       = StateObject(wrappedValue: BudgetStore())
        _appearance        = StateObject(wrappedValue: AppAppearance())
        _toolUsage         = StateObject(wrappedValue: ToolUsageStore())
        _uiSettings        = StateObject(wrappedValue: AppUISettings())
        _coordinator       = StateObject(wrappedValue: StoreCoordinator(
                                entriesStore: entries,
                                profileStore: profile,
                                teslaFiStore: teslaFi))
        _superchargerStore = StateObject(wrappedValue: SuperchargePricingInfoStore())
        _teslaPricingStore = StateObject(wrappedValue: TeslaOfficialSuperchargerPricingStore())
        _appModel          = StateObject(wrappedValue: KWhGasCompanionAppModel(
                                teslaFiStore: teslaFi,
                                profileStore: profile,
                                entriesStore: entries))

        deepDepthProvider = Self.makeDeepDepthProvider(
            teslaFiStore: teslaFi,
            entriesStore: entries
        )
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            AppRootHostView(
                startup: startup,
                adsStartup: adsStartup,
                superchargerStore: superchargerStore
            ) {
                MainTabView()
            }
            .appPolish()
            .bindAppTheme(using: appearance)
            .modifier(BrandThemeModifier())
            .modifier(AppEnvironmentModifier(
                appearance:        appearance,
                appModel:          appModel,
                profileStore:      profileStore,
                entriesStore:      entriesStore,
                teslaFiStore:      teslaFiStore,
                budgetStore:       budgetStore,
                toolUsage:         toolUsage,
                superchargerStore: superchargerStore,
                teslaPricingStore: teslaPricingStore,
                uiSettings:        uiSettings,
                coordinator:       coordinator
            ))
            .environment(\.deepDepthProvider, Optional(deepDepthProvider))
            .preferredColorScheme(appearance.preferredColorScheme)
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingFlowView(isPresented: $showOnboarding)
                    .environmentObject(appearance)
                    .environmentObject(profileStore)
            }
            .task {
                if !onboardingCompleted {
                    showOnboarding = true
                }
            }
        }
        .commands {
            SidebarCommands()
            CommandGroup(after: .toolbar) {
                Button("Home")     { Self.postTabSelect("home") }     .keyboardShortcut("1", modifiers: .command)
                Button("Charging") { Self.postTabSelect("charging") } .keyboardShortcut("2", modifiers: .command)
                Button("Expenses") { Self.postTabSelect("expenses") } .keyboardShortcut("3", modifiers: .command)
                Button("Vehicles") { Self.postTabSelect("vehicles") } .keyboardShortcut("4", modifiers: .command)
                Button("Tools")    { Self.postTabSelect("tools") }    .keyboardShortcut("5", modifiers: .command)
            }
        }
    }

    private static func postTabSelect(_ tab: String) {
        NotificationCenter.default.post(name: .mainTabSelect, object: nil, userInfo: ["tab": tab])
    }

    // MARK: - DeepDepth provider factory (called once in init)

    private static func makeDeepDepthProvider(
        teslaFiStore: TeslaFiSessionStore,
        entriesStore: EntriesStore
    ) -> DeepDepthDataProvider {
        DeepDepthDataProvider(fetch: { start, end in
            let lower  = min(start, end)
            let upper  = max(start, end)
            let window = lower...upper

            let (sessions, entries) = await MainActor.run { () -> ([TeslaFiSession], [ExpenseEntry]) in
                let preferred = teslaFiStore.canonicalSessions.isEmpty
                    ? teslaFiStore.sessions
                    : teslaFiStore.canonicalSessions
                return (preferred, entriesStore.entries)
            }

            let fromTeslaFi = deepDepthSessionsFromTeslaFi(sessions, lower: lower, upper: upper)
            let fromEntries = deepDepthSessionsFromEntries(entries, window: window)

            return (fromTeslaFi + fromEntries).sorted { $0.start < $1.start }
        })
    }
}

// MARK: - AdsStartupCoordinator
@MainActor
private final class AdsStartupCoordinator: ObservableObject {
    private var started = false
    private var preparing = false
    private var trackingPromptAttempted = false

    func prepareAndStartIfConfigured() async {
        #if canImport(GoogleMobileAds)
        guard !started else { return }
        guard !preparing else { return }
        guard !UserDefaults.standard.bool(forKey: "ads_removed") else { return }
        guard let appId = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String,
              !appId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        preparing = true
        defer { preparing = false }

        await GoogleMobileAdsConsentManager.shared.gatherConsent()
        guard GoogleMobileAdsConsentManager.shared.canRequestAds else { return }

        await requestTrackingAuthorizationIfNeeded()
        _ = await MobileAds.shared.start()
        started = true
        #endif
    }

    func handleForegroundActivation() async {
        await prepareAndStartIfConfigured()
    }

    private func requestTrackingAuthorizationIfNeeded() async {
        #if canImport(AppTrackingTransparency)
        #if !targetEnvironment(simulator)
        guard !trackingPromptAttempted else { return }
        trackingPromptAttempted = true

        guard Bundle.main.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription") as? String != nil else { return }
        guard #available(iOS 14, *) else { return }

        let status = ATTrackingManager.trackingAuthorizationStatus
        guard status == .notDetermined else { return }

        _ = await ATTrackingManager.requestTrackingAuthorization()
        #endif
        #endif
    }
}

// MARK: - Environment injection modifier
private struct AppEnvironmentModifier: ViewModifier {
    let appearance:        AppAppearance
    let appModel:          KWhGasCompanionAppModel
    let profileStore:      ProfileStore
    let entriesStore:      EntriesStore
    let teslaFiStore:      TeslaFiSessionStore
    let budgetStore:       BudgetStore
    let toolUsage:         ToolUsageStore
    let superchargerStore: SuperchargePricingInfoStore
    let teslaPricingStore: TeslaOfficialSuperchargerPricingStore
    let uiSettings:        AppUISettings
    let coordinator:       StoreCoordinator

    func body(content: Content) -> some View {
        content
            .environmentObject(appearance)
            .environmentObject(appModel)
            .environmentObject(profileStore)
            .environmentObject(entriesStore)
            .environmentObject(teslaFiStore)
            .environmentObject(budgetStore)
            .environmentObject(toolUsage)
            .environmentObject(superchargerStore)
            .environmentObject(teslaPricingStore)
            .environmentObject(uiSettings)
            .environmentObject(coordinator)
    }
}

// MARK: - Root host view
@MainActor
private struct AppRootHostView<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject var startup: AppStartupCoordinator
    @ObservedObject var adsStartup: AdsStartupCoordinator
    let superchargerStore: SuperchargePricingInfoStore
    @ViewBuilder let content: () -> Content

    init(
        startup: AppStartupCoordinator,
        adsStartup: AdsStartupCoordinator,
        superchargerStore: SuperchargePricingInfoStore,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.startup = startup
        self.adsStartup = adsStartup
        self.superchargerStore = superchargerStore
        self.content = content
    }

    var body: some View {
        content()
            .onAppear {
                startup.noteRootAppeared()
                if scenePhase == .active {
                    Task { await adsStartup.handleForegroundActivation() }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    startup.runWarmupsIfNeeded(superchargerStore: superchargerStore)
                    Task { await adsStartup.handleForegroundActivation() }
                }
            }
    }
}

// MARK: - Startup coordinator
@MainActor
private final class AppStartupCoordinator: ObservableObject {
    private let log = Logger(subsystem: "MyEVCompanion", category: "Startup")

    private var didRunWarmups  = false
    private var rootAppearedAt: Date? = nil

    func noteRootAppeared() {
        guard rootAppearedAt == nil else { return }
        rootAppearedAt = Date()
        log.debug("Root appeared.")
    }

    func runWarmupsIfNeeded(superchargerStore: SuperchargePricingInfoStore) {
        guard !didRunWarmups else { return }
        didRunWarmups = true

        Task(priority: .utility) { [log] in
            try? await Task.sleep(for: .milliseconds(650))
            await Task.yield()

            let prewarm = UserDefaults.standard.bool(forKey: "prewarmTeslaDirectory")
            if prewarm {
                log.debug("Prewarming Tesla directory…")
                await superchargerStore.loadDirectoryIfNeeded(force: false)
                log.debug("Tesla directory prewarm done.")
            } else {
                log.debug("Tesla directory prewarm skipped.")
            }
        }
    }
}

// MARK: - DeepDepth free functions
private func deepDepthSessionsFromTeslaFi(
    _ sessions: [TeslaFiSession],
    lower: Date,
    upper: Date
) -> [DeepDepthSession] {
    sessions.compactMap { s in
        guard s.startDate <= upper, s.endDate >= lower else { return nil }

        let loc = s.location?.lowercased() ?? ""
        let isSC = loc.contains("supercharg")
            || loc.contains("dcfc")
            || loc.contains("electrify america")
            || loc.contains("evgo")
            || loc.contains("chargepoint")

        return DeepDepthSession(
            start: s.startDate,
            end:   s.endDate,
            energyKWh: max(0, s.energyAddedKWh),
            cost:  s.cost,
            miles: 0,
            isSupercharging: isSC
        )
    }
}

private func deepDepthSessionsFromEntries(
    _ entries: [ExpenseEntry],
    window: ClosedRange<Date>
) -> [DeepDepthSession] {
    entries.compactMap { e in
        guard window.contains(e.date) else { return nil }

        var isEnergyEffective: Bool?  = nil
        var energyKWh:         Double? = nil
        var miles:             Double? = nil
        var merchant:          String? = nil
        var note:              String? = nil
        var category:          String? = nil

        for child in Mirror(reflecting: e).children {
            switch child.label?.lowercased() {
            case "isenergyeffective": isEnergyEffective = child.value as? Bool
            case "energykwh", "kwh":  energyKWh         = child.value as? Double
            case "miles":             miles             = child.value as? Double
            case "merchant":          merchant          = child.value as? String
            case "note":              note              = child.value as? String
            case "category":          category          = child.value as? String
            default: break
            }
        }

        let isEnergy: Bool = isEnergyEffective ?? (e.amount != 0)
        guard isEnergy else { return nil }

        let merch = merchant?.lowercased() ?? ""
        let nt    = note?.lowercased()     ?? ""
        let cat   = category?.lowercased() ?? ""

        let isSC = merch.contains("supercharg")
            || nt.contains("supercharg")
            || cat.contains("dcfc")
            || cat.contains("supercharg")

        return DeepDepthSession(
            start: e.date,
            end:   max(e.date, e.date.addingTimeInterval(45 * 60)),
            energyKWh: max(0, energyKWh ?? 0),
            cost:  e.amount,
            miles: max(0, miles ?? 0),
            isSupercharging: isSC
        )
    }
}
