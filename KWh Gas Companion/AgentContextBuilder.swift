import Foundation

@MainActor
struct AgentContextBuilder {
    let entriesStore: EntriesStore
    let profileStore: ProfileStore
    let teslaFiStore: TeslaFiSessionStore

    func build(now: Date = Date()) -> AgentContext {
        let cal = Calendar.current
        let start30 = cal.date(byAdding: .day, value: -30, to: now) ?? now

        let recentEntries = entriesStore.entries.filter { $0.date >= start30 && $0.date <= now }
        let recentSessions = teslaFiStore.sessions.filter { $0.startDate >= start30 && $0.startDate <= now }

        let recentEntrySpend = recentEntries.reduce(0.0) { $0 + max(0, $1.amount) }
        let recentTeslaFiSpend = recentSessions.compactMap(\.cost).reduce(0.0, +)
        let recentEntryKWh = recentEntries.compactMap(\.energyAddedKWh).reduce(0.0, +)
        let recentTeslaFiKWh = recentSessions.reduce(0.0) { $0 + max(0, $1.energyAddedKWh) }
        let defaults = UserDefaults.standard
        let homeRate = defaults.object(forKey: "settings.defaultHomeRate") as? Double ?? 0.11
        let publicRate = defaults.object(forKey: "settings.defaultPublicRate") as? Double ?? 0.42
        let monthlyBudgetLimit = defaults.object(forKey: "monthlyBudgetLimit") as? Double ?? 0
        let defaultCurrencyCode = defaults.string(forKey: "defaultCurrencyCode") ?? (Locale.current.currency?.identifier ?? "USD")

        return AgentContext(
            generatedAt: now,
            activeVehicleName: profileStore.selectedVehicle?.displayName ?? "Vehicle",
            currencyCode: defaultCurrencyCode,
            entriesCount: entriesStore.entries.count,
            teslaFiSessionsCount: teslaFiStore.sessions.count,
            recent30DaySpend: recentEntrySpend + recentTeslaFiSpend,
            recent30DayEnergyKWh: recentEntryKWh + recentTeslaFiKWh,
            homeRate: homeRate,
            publicRate: publicRate,
            monthlyBudget: monthlyBudgetLimit
        )
    }
}
