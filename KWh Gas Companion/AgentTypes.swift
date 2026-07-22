import Foundation

struct AgentContext {
    let generatedAt: Date
    let activeVehicleName: String
    let currencyCode: String
    let entriesCount: Int
    let teslaFiSessionsCount: Int
    let recent30DaySpend: Double
    let recent30DayEnergyKWh: Double
    let homeRate: Double
    let publicRate: Double
    let monthlyBudget: Double
}

enum AgentIntent: String {
    case summarize7
    case summarize31
    case monthlyBreakdown
    case costSpike
    case cheaperWindows
    case missingCosts
    case chargingHabits
    case batteryHealthFactors
    case batterySuggestions
    case draftExpense
    case unknown
}

struct AgentProposedAction {
    let title: String
    let detail: String
    let action: AgentAction
}

enum AgentAction {
    case addExpenseDraft(ExpenseEntry)
}

struct AgentResponse {
    let text: String
    let dataUsed: [String]
    let proposedAction: AgentProposedAction?
}
