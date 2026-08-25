import Foundation

@MainActor
struct AgentOrchestrator {
    let contextBuilder: AgentContextBuilder
    let tools: AgentTools

    func run(query: String) async -> AgentResponse {
        let context = contextBuilder.build()
        let intent = Self.parseIntent(query)

        switch intent {
        case .summarize7:
            let summary = await tools.summarizeLastNDays(7)
            let text = summary?.message ?? "I could not build a 7-day summary yet. Add or import more entries first."
            return AgentResponse(
                text: text,
                dataUsed: [
                    "Window: last 7 days",
                    "Vehicle: \(context.activeVehicleName)",
                    "Sources: Spark entries + on-device stores"
                ],
                proposedAction: nil
            )

        case .summarize31:
            let summary = await tools.summarizeLastNDays(31)
            let text = summary?.message ?? "I could not build a 31-day summary yet. Add or import more entries first."
            return AgentResponse(
                text: text,
                dataUsed: [
                    "Window: last 31 days",
                    "Vehicle: \(context.activeVehicleName)",
                    "Sources: Spark entries + on-device stores"
                ],
                proposedAction: nil
            )

        case .monthlyBreakdown:
            let m = tools.monthlySpendBreakdown()
            let text = "This month so far: \(formatCurrency(m.total, currency: context.currencyCode)). Entries: \(formatCurrency(m.entrySpend, currency: context.currencyCode)) across \(m.entryCount) rows. Imported sessions: \(formatCurrency(m.teslaFiSpend, currency: context.currencyCode)) across \(m.teslaFiCount) sessions."
            return AgentResponse(
                text: text,
                dataUsed: [
                    "Window: current calendar month",
                    "EntriesStore + imported session store"
                ],
                proposedAction: nil
            )

        case .costSpike:
            let spike = tools.detectCostSpike()
            let text: String
            if spike.spike {
                text = "Cost spike detected. Avg daily cost moved from \(formatCurrency(spike.previousAvgDaily, currency: context.currencyCode)) to \(formatCurrency(spike.currentAvgDaily, currency: context.currencyCode)) (\(String(format: "%.1f", spike.deltaPct))%)."
            } else {
                text = "No major spike detected. Avg daily cost is \(formatCurrency(spike.currentAvgDaily, currency: context.currencyCode)) vs \(formatCurrency(spike.previousAvgDaily, currency: context.currencyCode)) in the prior window (\(String(format: "%.1f", spike.deltaPct))%)."
            }
            return AgentResponse(
                text: text,
                dataUsed: [
                    "Window compare: last 30 days vs prior 30 days",
                    "Entries + imported session costs"
                ],
                proposedAction: nil
            )

        case .cheaperWindows:
            return AgentResponse(
                text: tools.suggestCheaperChargingWindows(),
                dataUsed: ["Smart Charging Planner settings"],
                proposedAction: nil
            )

        case .missingCosts:
            let missing = tools.missingCostCounts()
            let text = "Missing charging costs: \(missing.entriesMissing) entry row(s), \(missing.teslaFiMissing) imported session(s)."
            return AgentResponse(
                text: text,
                dataUsed: ["EntriesStore + imported session store"],
                proposedAction: nil
            )

        case .chargingHabits:
            let insights = tools.chargingBehaviorInsights()
            return AgentResponse(
                text: insights.whereAndHowSummary,
                dataUsed: chargingInsightDataUsed(insights),
                proposedAction: nil
            )

        case .batteryHealthFactors:
            let insights = tools.chargingBehaviorInsights()
            return AgentResponse(
                text: insights.batteryHealthSummary,
                dataUsed: chargingInsightDataUsed(insights),
                proposedAction: nil
            )

        case .batterySuggestions:
            let insights = tools.chargingBehaviorInsights()
            return AgentResponse(
                text: insights.suggestionsSummary,
                dataUsed: chargingInsightDataUsed(insights),
                proposedAction: nil
            )

        case .draftExpense:
            let draft = tools.previewAddExpense(from: context)
            let detail = "Draft \(draft.category) entry for \(context.activeVehicleName) at \(formatCurrency(draft.amount, currency: context.currencyCode)) and \(String(format: "%.0f", draft.energyAddedKWh ?? 0)) kWh."
            return AgentResponse(
                text: "I created a draft expense preview. Confirm to save it.",
                dataUsed: ["Vehicle profile + default rates"],
                proposedAction: AgentProposedAction(
                    title: "Add Draft Expense",
                    detail: detail,
                    action: .addExpenseDraft(draft)
                )
            )

        case .unknown:
            return AgentResponse(
                text: "Try: summarize last 7 days, monthly breakdown, detect cost spike, suggest cheaper window, missing costs, or draft expense.",
                dataUsed: ["Intent parser"],
                proposedAction: nil
            )
        }
    }

    static func parseIntent(_ query: String) -> AgentIntent {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return .unknown }

        if q.contains("draft") && q.contains("expense") { return .draftExpense }
        if (q.contains("where") && q.contains("charg")) || q.contains("charge most often") || q.contains("how does this owner charge") || q.contains("charging habits") {
            return .chargingHabits
        }
        if q.contains("battery health") || q.contains("long-term battery") || q.contains("degradation") || q.contains("affecting battery") {
            return .batteryHealthFactors
        }
        if q.contains("missing") && q.contains("cost") { return .missingCosts }
        if q.contains("cheaper") || q.contains("off peak") || q.contains("off-peak") || q.contains("window") { return .cheaperWindows }
        if q.contains("suggestion") || q.contains("what should i do") || q.contains("recommend") || q.contains("battery tips") || (q.contains("concrete") && q.contains("suggest")) {
            return .batterySuggestions
        }
        if q.contains("spike") || q.contains("higher") || q.contains("increase") { return .costSpike }
        if q.contains("month") && (q.contains("breakdown") || q.contains("so far")) { return .monthlyBreakdown }
        if q.contains("31") || q.contains("30") || q.contains("month summary") { return .summarize31 }
        if q.contains("7") || q.contains("week") || q.contains("summary") { return .summarize7 }

        return .unknown
    }

    private func formatCurrency(_ value: Double, currency: String) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = currency
        return nf.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }

    private func chargingInsightDataUsed(_ insights: ChargingBehaviorInsights) -> [String] {
        var lines = ["EntriesStore + imported session store"]
        lines.append("Analyzed sessions: \(insights.totalSessions)")

        if let top = insights.dominantLocation {
            lines.append("Primary location signal: \(top.displayName)")
        }

        if let high90 = insights.highSOC90Share {
            let percent = Int((high90 * 100).rounded())
            lines.append("SOC-tagged high-charge share: \(percent)% at 90%+")
        }

        return lines
    }
}
