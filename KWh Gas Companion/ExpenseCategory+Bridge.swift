// ExpenseCategory+Bridge.swift
import Foundation

extension ExpenseEntry {
    /// Canonical enum for this entry’s category.
    /// Priority:
    /// 1) Exact rawValue match (case-insensitive)
    /// 2) Energy hint (isEnergy / isEnergyByCategory) refined by chargeType
    /// 3) Keyword heuristics on the category string
    var categoryEnum: ExpenseCategory {
        let raw = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let lc  = raw.lowercased()
        let ct  = (chargeType ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 1) Exact match against enum raw values
        if let exact = ExpenseCategory.allCases.first(where: { $0.rawValue.lowercased() == lc }) {
            return exact
        }

        // 2) If this looks like an energy/charging entry, refine by chargeType
        if isEnergy || isEnergyByCategory || lc.contains("charg") || lc.contains("energy") || lc.contains("kwh") {
            // Fast/DCFC signals
            let fastHits = ["dcfc","dc fast","fast","supercharger","v2","v3","v4","ccs","chademo","ea","electrify america","tesla"]
            if fastHits.contains(where: { ct.contains($0) || lc.contains($0) }) {
                return .fastDCFC
            }
            // Home signals
            let homeHits = ["home","residential","garage","wall connector","wallbox","nema","dryer","14-50","120v","240v"]
            if homeHits.contains(where: { ct.contains($0) || lc.contains($0) }) {
                return .homeCharging
            }
            // Public L2 / destination
            let publicHits = ["public","destination","l2","level 2","ac","evgo","chargepoint","blink","flo","volta","bp pulse","shell recharge"]
            if publicHits.contains(where: { ct.contains($0) || lc.contains($0) }) {
                return .publicCharging
            }
            // Generic energy
            return .energy
        }

        // 3) Non-energy heuristics by keywords (from your enum)
        if lc.contains("maint") || lc.contains("service") || lc.contains("tire") || lc.contains("align") { return .maintenance }
        if lc.contains("install") || lc.contains("upgrade") || lc.contains("wall connector") { return .installationUpgrades }
        if lc.contains("insur") || lc.contains("registrat") || lc.contains("dmv") { return .insuranceRegistration }
        if lc.contains("accessor") || lc.contains("consumable") || lc.contains("wiper") { return .accessoriesConsumables }
        if lc.contains("park") || lc.contains("toll") || lc.contains("ezpass") { return .parkingTolling }
        if lc.contains("operat") || lc.contains("demand") { return .demandCharges } // Operating Costs
        if lc.contains("subscr") || lc.contains("software") || lc.contains("premium") { return .softwareSubscriptions }
        if lc.contains("roadside") || lc.contains("tow") { return .roadsideAssistance }
        if lc.contains("finance") || lc.contains("loan") || lc.contains("interest") { return .finance }
        if lc.contains("lease") { return .lease }
        if lc.contains("auto pay") || lc.contains("autopay") || lc.contains("payment") { return .autoPayment }

        // Blank or unknown
        if raw.isEmpty { return .other }
        return .other
    }

    /// Convenience setter to keep the stored string in sync, and auto-flag energy.
    mutating func setCategory(_ cat: ExpenseCategory) {
        category = cat.rawValue
        let energyCats: Set<ExpenseCategory> = [.energy, .homeCharging, .publicCharging, .fastDCFC]
        if energyCats.contains(cat) { isEnergy = true }
    }
}
