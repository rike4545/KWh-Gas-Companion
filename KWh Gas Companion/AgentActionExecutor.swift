import Foundation

@MainActor
struct AgentActionExecutor {
    let entriesStore: EntriesStore

    func execute(_ action: AgentAction) {
        switch action {
        case .addExpenseDraft(let entry):
            entriesStore.add(entry)
        }
    }
}
