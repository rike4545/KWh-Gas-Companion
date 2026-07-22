import Foundation

@MainActor
struct AgentTools {
    let entriesStore: EntriesStore
    let teslaFiStore: TeslaFiSessionStore

    func summarizeLastNDays(_ days: Int) async -> SparkSummaryResult? {
        await SparkyEngine.shared.summary(days: max(1, days), kind: nil, distanceUnit: .miles, locale: .current, cacheTTL: 30)
    }

    func monthlySpendBreakdown(referenceDate: Date = Date()) -> (entrySpend: Double, teslaFiSpend: Double, total: Double, entryCount: Int, teslaFiCount: Int) {
        let range = Self.currentMonthRange(referenceDate: referenceDate)
        let monthEntries = entriesStore.entries.filter { range.contains($0.date) }
        let monthSessions = teslaFiStore.sessions.filter { range.contains($0.startDate) }
        let entrySpend = monthEntries.reduce(0.0) { $0 + max(0, $1.amount) }
        let teslaFiSpend = monthSessions.compactMap(\.cost).reduce(0.0, +)
        return (entrySpend, teslaFiSpend, entrySpend + teslaFiSpend, monthEntries.count, monthSessions.count)
    }

    func detectCostSpike(referenceDate: Date = Date()) -> (spike: Bool, currentAvgDaily: Double, previousAvgDaily: Double, deltaPct: Double) {
        let windows = Self.costWindows(entries: entriesStore.entries, teslaFi: teslaFiStore.sessions, now: referenceDate)
        let prior = max(windows.previousAvgDaily, 0.0001)
        let delta = ((windows.currentAvgDaily - prior) / prior) * 100.0
        return (delta >= 20.0, windows.currentAvgDaily, windows.previousAvgDaily, delta)
    }

    func suggestCheaperChargingWindows() -> String {
        let offPeakStart = UserDefaults.standard.integer(forKey: "planner.offPeakStart")
        let offPeakEnd = UserDefaults.standard.integer(forKey: "planner.offPeakEnd")
        let offPeakRate = UserDefaults.standard.double(forKey: "planner.offPeakRate")
        let peakRate = UserDefaults.standard.double(forKey: "planner.peakRate")

        let hasWindow = (0...23).contains(offPeakStart) && (0...23).contains(offPeakEnd)
        let hasRates = offPeakRate > 0 && peakRate > 0

        guard hasWindow, hasRates else {
            return "Set your off-peak window and rates in Smart Charging Planner so I can optimize your schedule."
        }

        let diff = peakRate - offPeakRate
        if diff <= 0 {
            return "Your off-peak rate is not lower than peak right now. Review your utility plan before shifting schedules."
        }

        return "Best charging window: \(Self.hourLabel(offPeakStart)) to \(Self.hourLabel(offPeakEnd)). Estimated savings vs peak: \(String(format: "$%.2f", diff))/kWh."
    }

    func missingCostCounts() -> (entriesMissing: Int, teslaFiMissing: Int) {
        let entriesMissing = entriesStore.entries.filter { $0.isEnergyEffective && ($0.amount == 0 || $0.amount.isNaN) }.count
        let teslaFiMissing = teslaFiStore.sessions.filter { $0.cost == nil }.count
        return (entriesMissing, teslaFiMissing)
    }

    func chargingBehaviorInsights() -> ChargingBehaviorInsights {
        let sessions = teslaFiStore.canonicalSessions.isEmpty ? teslaFiStore.sessions : teslaFiStore.canonicalSessions
        return ChargingBehaviorInsights.build(entries: entriesStore.entries, teslaFiSessions: sessions)
    }

    func previewAddExpense(from context: AgentContext, now: Date = Date()) -> ExpenseEntry {
        let suggestedAmount = max(context.publicRate, context.homeRate) * 20.0
        return ExpenseEntry(
            date: now,
            amount: suggestedAmount,
            currencyCode: context.currencyCode,
            category: "Charging",
            energyKWh: 20,
            odometer: nil,
            location: "Draft",
            notes: "AI draft: review before saving",
            vehicleName: context.activeVehicleName,
            stateOfCharge: nil,
            chargeType: "Draft",
            vehicleID: nil,
            isBusiness: false,
            vin: nil,
            isEnergy: true,
            charging: nil,
            vatAmount: nil,
            invoiceNumber: nil,
            repeatRule: nil
        )
    }

    static func currentMonthRange(referenceDate: Date) -> ClosedRange<Date> {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: referenceDate)) ?? referenceDate
        let end = cal.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? referenceDate
        return start...end
    }

    static func costWindows(entries: [ExpenseEntry], teslaFi: [TeslaFiSession], now: Date) -> (currentAvgDaily: Double, previousAvgDaily: Double) {
        let cal = Calendar.current
        let startCurrent = cal.date(byAdding: .day, value: -30, to: now) ?? now
        let startPrevious = cal.date(byAdding: .day, value: -60, to: now) ?? now

        let currentEntries = entries.filter { $0.date >= startCurrent && $0.date <= now }
        let previousEntries = entries.filter { $0.date >= startPrevious && $0.date < startCurrent }

        let currentTeslaFi = teslaFi.filter { $0.startDate >= startCurrent && $0.startDate <= now }
        let previousTeslaFi = teslaFi.filter { $0.startDate >= startPrevious && $0.startDate < startCurrent }

        let currentTotal = currentEntries.reduce(0.0) { $0 + max(0, $1.amount) } + currentTeslaFi.compactMap(\.cost).reduce(0.0, +)
        let previousTotal = previousEntries.reduce(0.0) { $0 + max(0, $1.amount) } + previousTeslaFi.compactMap(\.cost).reduce(0.0, +)

        return (currentTotal / 30.0, previousTotal / 30.0)
    }

    static func hourLabel(_ h: Int) -> String {
        let hour = (h % 24 + 24) % 24
        switch hour {
        case 0: return "12 AM"
        case 12: return "12 PM"
        case 13...23: return "\(hour - 12) PM"
        default: return "\(hour) AM"
        }
    }
}
