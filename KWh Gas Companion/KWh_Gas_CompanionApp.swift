//
//  KWh_Gas_CompanionApp.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//
//  Performance-focused revision
//  - Avoids doing heavy startup work during first render.
//  - Removes launch-time Supercharger directory prewarm from the root view.
//  - Builds DeepDepth provider once (not every body recompute).
//  - Reduces Mirror/reflection overhead in DeepDepth provider (single pass per entry).
//

import SwiftUI
import os.log
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct KWh_Gas_CompanionApp: App {

    // Core stores/managers — created exactly once here
    @StateObject private var profileStore: ProfileStore
    @StateObject private var entriesStore: EntriesStore
    @StateObject private var teslaFiStore: TeslaFiSessionStore
    @StateObject private var budgetStore: BudgetStore
    @StateObject private var appearance: AppAppearance
    @StateObject private var toolUsage: ToolUsageStore
    @StateObject private var uiSettings: AppUISettings

    // Tesla Supercharger: Apple Maps nearby + Tesla Find Us directory/pricing
    @StateObject private var superchargerStore: SuperchargePricingInfoStore
    @StateObject private var teslaPricingStore: TeslaOfficialSuperchargerPricingStore

    // App-level model
    @StateObject private var appModel: KWhGasCompanionAppModel

    // Build once (prevents re-creating closures on body recompute)
    private let deepDepthProvider: DeepDepthDataProvider

    // Startup coordinator (runs optional warmups later, not during first frame)
    @StateObject private var startup = AppStartupCoordinator()

    init() {
        #if canImport(GoogleMobileAds)
        MobileAds.shared.start(completionHandler: nil)
        #endif
        // IMPORTANT: Store inits MUST be "cheap".
        // If any of these perform disk I/O / parsing / networking in init, move that into async bootstrap methods.
        let profile = ProfileStore()
        let entries = EntriesStore()
        let teslaFi = TeslaFiSessionStore()

        _profileStore = StateObject(wrappedValue: profile)
        _entriesStore = StateObject(wrappedValue: entries)
        _teslaFiStore = StateObject(wrappedValue: teslaFi)
        _budgetStore  = StateObject(wrappedValue: BudgetStore())
        _appearance   = StateObject(wrappedValue: AppAppearance())
        _toolUsage    = StateObject(wrappedValue: ToolUsageStore())
        _uiSettings   = StateObject(wrappedValue: AppUISettings())

        _superchargerStore = StateObject(wrappedValue: SuperchargePricingInfoStore())
        _teslaPricingStore = StateObject(wrappedValue: TeslaOfficialSuperchargerPricingStore())

        _appModel = StateObject(
            wrappedValue: KWhGasCompanionAppModel(
                teslaFiStore: teslaFi,
                profileStore: profile,
                entriesStore: entries
            )
        )

        // Build provider ONCE using the concrete store instances created above
        self.deepDepthProvider = Self.makeDeepDepthProvider(
            teslaFiStore: teslaFi,
            entriesStore: entries
        )
    }

    var body: some Scene {
        WindowGroup {
            // Wrap MainTabView in a host that can run warmups AFTER first frame / when active
            AppRootHostView(
                main: MainTabView(),
                startup: startup,
                superchargerStore: superchargerStore
            )
            .appPolish()
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

            .bindAppTheme(using: appearance)
            .environment(\.deepDepthProvider, Optional(deepDepthProvider))
            .preferredColorScheme(appearance.preferredColorScheme)
        }
        .commands {
            SidebarCommands()
            CommandGroup(after: .toolbar) {
                Button("Home") {
                    NotificationCenter.default.post(name: .mainTabSelect, object: nil, userInfo: ["tab": "home"])
                }
                .keyboardShortcut("1", modifiers: .command)
                Button("Charging") {
                    NotificationCenter.default.post(name: .mainTabSelect, object: nil, userInfo: ["tab": "charging"])
                }
                .keyboardShortcut("2", modifiers: .command)
                Button("Expenses") {
                    NotificationCenter.default.post(name: .mainTabSelect, object: nil, userInfo: ["tab": "expenses"])
                }
                .keyboardShortcut("3", modifiers: .command)
                Button("Vehicles") {
                    NotificationCenter.default.post(name: .mainTabSelect, object: nil, userInfo: ["tab": "vehicles"])
                }
                .keyboardShortcut("4", modifiers: .command)
                Button("Tools") {
                    NotificationCenter.default.post(name: .mainTabSelect, object: nil, userInfo: ["tab": "tools"])
                }
                .keyboardShortcut("5", modifiers: .command)
            }
        }
    }

    // MARK: - DeepDepth provider (built once)

    private static func makeDeepDepthProvider(
        teslaFiStore: TeslaFiSessionStore,
        entriesStore: EntriesStore
    ) -> DeepDepthDataProvider {
        DeepDepthDataProvider(fetch: { start, end in
            let lower = min(start, end)
            let upper = max(start, end)
            let window = lower...upper

            // Copy data on MainActor to match your stores’ threading model, then compute off-main.
            let (sessions, entries) = await MainActor.run { () -> ([TeslaFiSession], [ExpenseEntry]) in
                let preferred = teslaFiStore.canonicalSessions.isEmpty
                    ? teslaFiStore.sessions
                    : teslaFiStore.canonicalSessions
                return (preferred, entriesStore.entries)
            }

            let fromTeslaFi: [DeepDepthSession] = sessions.compactMap { s in
                guard s.startDate <= upper, s.endDate >= lower else { return nil }

                let loc = (s.location ?? "").lowercased()
                let isSC =
                    loc.contains("supercharg") ||
                    loc.contains("dcfc") ||
                    loc.contains("electrify america") ||
                    loc.contains("evgo") ||
                    loc.contains("chargepoint")

                return DeepDepthSession(
                    start: s.startDate,
                    end: s.endDate,
                    energyKWh: max(0, s.energyAddedKWh),
                    cost: s.cost,
                    miles: 0,
                    isSupercharging: isSC
                )
            }

            let fromEntries: [DeepDepthSession] = entries.compactMap { e in
                guard window.contains(e.date) else { return nil }

                // Single Mirror pass per entry (much cheaper than multiple passes)
                let mirror = Mirror(reflecting: e)

                var isEnergyEffective: Bool? = nil
                var energyKWh: Double? = nil
                var miles: Double? = nil
                var merchant: String? = nil
                var note: String? = nil
                var category: String? = nil

                for child in mirror.children {
                    guard let label = child.label?.lowercased() else { continue }

                    switch label {
                    case "isenergyeffective":
                        isEnergyEffective = child.value as? Bool
                    case "energykwh", "kwh":
                        energyKWh = child.value as? Double
                    case "miles":
                        miles = child.value as? Double
                    case "merchant":
                        merchant = child.value as? String
                    case "note":
                        note = child.value as? String
                    case "category":
                        category = child.value as? String
                    default:
                        continue
                    }
                }

                // Preserve your previous heuristic:
                // - If isEnergyEffective exists, respect it
                // - Else: consider non-zero amount as "energy-like"
                let isEnergy: Bool = {
                    if let explicit = isEnergyEffective { return explicit }
                    return e.amount != 0
                }()

                guard isEnergy else { return nil }

                let kWh = max(0, energyKWh ?? 0)
                let mi  = max(0, miles ?? 0)

                let merch = (merchant ?? "").lowercased()
                let nt    = (note ?? "").lowercased()
                let cat   = (category ?? "").lowercased()

                let isSC =
                    merch.contains("supercharg") ||
                    nt.contains("supercharg") ||
                    cat.contains("dcfc") ||
                    cat.contains("supercharg")

                let endDate = max(e.date, e.date.addingTimeInterval(45 * 60))

                return DeepDepthSession(
                    start: e.date,
                    end: endDate,
                    energyKWh: kWh,
                    cost: e.amount,
                    miles: mi,
                    isSupercharging: isSC
                )
            }

            return (fromTeslaFi + fromEntries).sorted { $0.start < $1.start }
        })
    }
}

// MARK: - Root Host (runs warmups later, once)

@MainActor
private struct AppRootHostView<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase

    let main: Content
    @ObservedObject var startup: AppStartupCoordinator
    let superchargerStore: SuperchargePricingInfoStore

    var body: some View {
        main
            .onAppear {
                startup.noteRootAppeared()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    startup.runWarmupsIfNeeded(superchargerStore: superchargerStore)
                }
            }
            // If you want, you can start warmups on first appear instead of waiting for active:
            // .task { startup.runWarmupsIfNeeded(superchargerStore: superchargerStore) }
    }
}

// MARK: - Startup Coordinator

@MainActor
private final class AppStartupCoordinator: ObservableObject {
    private let log = Logger(subsystem: "KWhGasCompanion", category: "Startup")

    private var didRunWarmups = false
    private var rootAppearedAt: Date? = nil

    func noteRootAppeared() {
        if rootAppearedAt == nil {
            rootAppearedAt = Date()
            log.debug("Root appeared.")
        }
    }

    func runWarmupsIfNeeded(superchargerStore: SuperchargePricingInfoStore) {
        guard !didRunWarmups else { return }
        didRunWarmups = true

        Task(priority: .utility) { [log] in
            // Give the UI time to render and become interactive first.
            try? await Task.sleep(nanoseconds: 650_000_000) // ~0.65s
            await Task.yield()

            // 🔥 IMPORTANT:
            // Prewarming the Tesla directory can freeze the UI if the store does heavy parsing on MainActor.
            // Default = OFF. Flip to true only after you confirm the store parses off-main.
            let prewarmTeslaDirectory = UserDefaults.standard.bool(forKey: "prewarmTeslaDirectory")

            if prewarmTeslaDirectory {
                log.debug("Prewarming Tesla directory…")
                await superchargerStore.loadDirectoryIfNeeded(force: false)
                log.debug("Tesla directory prewarm done.")
            } else {
                log.debug("Tesla directory prewarm skipped (recommended).")
            }
        }
    }
}
