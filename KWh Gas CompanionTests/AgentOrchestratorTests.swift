import Testing
@testable import KWh_Gas_Companion

struct AgentOrchestratorTests {

    @Test func parsesCoreIntents() {
        #expect(AgentOrchestrator.parseIntent("summarize my last 7 days") == .summarize7)
        #expect(AgentOrchestrator.parseIntent("monthly breakdown so far") == .monthlyBreakdown)
        #expect(AgentOrchestrator.parseIntent("detect cost spike") == .costSpike)
        #expect(AgentOrchestrator.parseIntent("suggest cheaper off-peak window") == .cheaperWindows)
        #expect(AgentOrchestrator.parseIntent("show missing costs") == .missingCosts)
        #expect(AgentOrchestrator.parseIntent("draft expense") == .draftExpense)
    }
}
