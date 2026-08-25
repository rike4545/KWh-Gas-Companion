// StoreCoordinator.swift
// My EV Companion
//
// Single source of truth that debounces, deduplicates, and caches derived
// values from EntriesStore + ProfileStore + TeslaFiSessionStore.
// Views subscribe to THIS instead of calling store methods directly,
// eliminating the O(n) recomputation that fires on every redraw.
//
// Usage:
//   @EnvironmentObject private var coord: StoreCoordinator
//   let summary = coord.weeklySummary        // pre-computed, cached

import SwiftUI
import Combine

@MainActor
public final class StoreCoordinator: ObservableObject {

    // MARK: - Published derived state (views bind here)

    @Published public private(set) var weeklySummary: WeeklySummarySnapshot   = .empty
    @Published public private(set) var monthlySummary: MonthlySummarySnapshot = .empty
    @Published private(set) var recentSessions: [ExpenseEntry]                = []
    @Published public private(set) var allTimeStats: AllTimeSnapshot          = .empty
    @Published public private(set) var isRecomputing: Bool                    = false

    // MARK: - Dependencies (weak refs to your existing stores)

    private weak var entriesStore: EntriesStore?
    private weak var profileStore: ProfileStore?
    private weak var teslaFiStore: TeslaFiSessionStore?

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()
    private var recomputeTask: Task<Void, Never>?

    // MARK: - Init

    init(
        entriesStore: EntriesStore,
        profileStore: ProfileStore,
        teslaFiStore: TeslaFiSessionStore
    ) {
        self.entriesStore = entriesStore
        self.profileStore = profileStore
        self.teslaFiStore = teslaFiStore
        bind()
    }

    // MARK: - Binding (debounced — 300 ms)

    private func bind() {
        guard let es = entriesStore, let ps = profileStore, let tf = teslaFiStore else { return }

        // Merge changes from all stores into one signal, debounce 300 ms.
        let entriesSignal  = es.objectWillChange.map { _ in () }.eraseToAnyPublisher()
        let profileSignal  = ps.objectWillChange.map { _ in () }.eraseToAnyPublisher()
        let sessionSignal  = tf.objectWillChange.map { _ in () }.eraseToAnyPublisher()

        Publishers.MergeMany(entriesSignal, profileSignal, sessionSignal)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleRecompute() }
            .store(in: &cancellables)

        // Initial load
        scheduleRecompute()
    }

    // MARK: - Recompute (off main thread)

    private func scheduleRecompute() {
        recomputeTask?.cancel()
        recomputeTask = Task {
            guard !Task.isCancelled else { return }
            await recompute()
        }
    }

    private func recompute() async {
        guard let es = entriesStore else { return }
        isRecomputing = true

        let entries = es.energyEntries()   // snapshot on main
        let currency = AppLocalization.currencyCode
        let cal = Calendar.current
        let now = Date()

        // Run heavy work off main
        let (weekly, monthly, recent, allTime) = await Task.detached(priority: .utility) {
            let weekly  = Self.buildWeekly(entries: entries, now: now, cal: cal, currency: currency)
            let monthly = Self.buildMonthly(entries: entries, now: now, cal: cal, currency: currency)
            let recent  = Array(entries.sorted { $0.date > $1.date }.prefix(20))
            let allTime = Self.buildAllTime(entries: entries, currency: currency)
            return (weekly, monthly, recent, allTime)
        }.value

        guard !Task.isCancelled else { return }

        self.weeklySummary   = weekly
        self.monthlySummary  = monthly
        self.recentSessions  = recent
        self.allTimeStats    = allTime
        self.isRecomputing   = false
    }

    // MARK: - Static builders (run off main)

    nonisolated private static func buildWeekly(entries: [ExpenseEntry], now: Date, cal: Calendar, currency: String) -> WeeklySummarySnapshot {
        let start  = cal.date(byAdding: .day, value: -7, to: now) ?? now
        let prev   = cal.date(byAdding: .day, value: -14, to: now) ?? now
        let recent = entries.filter { $0.date >= start }
        let last   = entries.filter { $0.date >= prev && $0.date < start }

        let cost   = recent.reduce(0) { $0 + $1.amount }
        let kwh    = recent.compactMap(\.energyAddedKWh).reduce(0, +)
        let count  = recent.count
        let lastCost = last.reduce(0) { $0 + $1.amount }
        let delta  = lastCost > 0 ? (cost - lastCost) / lastCost : 0
        let avgRate = kwh > 0 ? cost / kwh : nil
        let avgSession = count > 0 ? cost / Double(count) : nil

        return WeeklySummarySnapshot(
            cost: cost, kWh: kwh, sessions: count,
            costDeltaPct: delta, avgRatePerKWh: avgRate,
            avgCostPerSession: avgSession, currency: currency
        )
    }

    nonisolated private static func buildMonthly(entries: [ExpenseEntry], now: Date, cal: Calendar, currency: String) -> MonthlySummarySnapshot {
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) else {
            return .empty
        }
        let prevMonthStart = cal.date(byAdding: .month, value: -1, to: monthStart) ?? monthStart
        let recent = entries.filter { $0.date >= monthStart }
        let prev   = entries.filter { $0.date >= prevMonthStart && $0.date < monthStart }

        let cost    = recent.reduce(0) { $0 + $1.amount }
        let kwh     = recent.compactMap(\.energyAddedKWh).reduce(0, +)
        let prevCost = prev.reduce(0) { $0 + $1.amount }
        let delta   = prevCost > 0 ? (cost - prevCost) / prevCost : 0
        let avgRate = kwh > 0 ? cost / kwh : nil

        // Day-of-month projection
        let dom = cal.component(.day, from: now)
        let daysInMonth = cal.range(of: .day, in: .month, for: now)?.count ?? 30
        let projected = dom > 0 ? cost / Double(dom) * Double(daysInMonth) : cost

        return MonthlySummarySnapshot(
            cost: cost, kWh: kwh, sessions: recent.count,
            costDeltaPct: delta, avgRatePerKWh: avgRate,
            projectedMonthCost: projected, currency: currency
        )
    }

    nonisolated private static func buildAllTime(entries: [ExpenseEntry], currency: String) -> AllTimeSnapshot {
        let cost   = entries.reduce(0) { $0 + $1.amount }
        let kwh    = entries.compactMap(\.energyAddedKWh).reduce(0, +)
        let count  = entries.count
        let avgRate = kwh > 0 ? cost / kwh : nil
        let first  = entries.map(\.date).min()
        return AllTimeSnapshot(
            cost: cost, kWh: kwh, sessions: count,
            avgRatePerKWh: avgRate, firstSession: first, currency: currency
        )
    }
}

// MARK: - Snapshot value types (Sendable, Hashable → no unnecessary redraws)

public struct WeeklySummarySnapshot: Hashable, Sendable {
    public let cost: Double
    public let kWh: Double
    public let sessions: Int
    public let costDeltaPct: Double     // fraction, e.g. 0.12 = +12%
    public let avgRatePerKWh: Double?
    public let avgCostPerSession: Double?
    public let currency: String

    public static let empty = WeeklySummarySnapshot(
        cost: 0, kWh: 0, sessions: 0,
        costDeltaPct: 0, avgRatePerKWh: nil,
        avgCostPerSession: nil, currency: "USD"
    )
}

public struct MonthlySummarySnapshot: Hashable, Sendable {
    public let cost: Double
    public let kWh: Double
    public let sessions: Int
    public let costDeltaPct: Double
    public let avgRatePerKWh: Double?
    public let projectedMonthCost: Double
    public let currency: String

    public static let empty = MonthlySummarySnapshot(
        cost: 0, kWh: 0, sessions: 0,
        costDeltaPct: 0, avgRatePerKWh: nil,
        projectedMonthCost: 0, currency: "USD"
    )
}

public struct AllTimeSnapshot: Hashable, Sendable {
    public let cost: Double
    public let kWh: Double
    public let sessions: Int
    public let avgRatePerKWh: Double?
    public let firstSession: Date?
    public let currency: String

    public static let empty = AllTimeSnapshot(
        cost: 0, kWh: 0, sessions: 0,
        avgRatePerKWh: nil, firstSession: nil, currency: "USD"
    )
}

// MARK: - Environment key

private struct StoreCoordinatorKey: EnvironmentKey {
    // Crash-safe default — replace with real stores at root
    static let defaultValue: StoreCoordinator? = nil
}

public extension EnvironmentValues {
    var storeCoordinator: StoreCoordinator? {
        get { self[StoreCoordinatorKey.self] }
        set { self[StoreCoordinatorKey.self] = newValue }
    }
}
