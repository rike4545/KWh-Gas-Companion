import Foundation
import Testing
@testable import KWh_Gas_Companion

struct AgentToolsTests {

    @Test func computesCostWindows() {
        let now = Date()
        let recentEntry = ExpenseEntry(date: now.addingTimeInterval(-5 * 24 * 3600), amount: 60)
        let previousEntry = ExpenseEntry(date: now.addingTimeInterval(-40 * 24 * 3600), amount: 30)

        let recentSession = TeslaFiSession(
            startDate: now.addingTimeInterval(-2 * 24 * 3600),
            endDate: now.addingTimeInterval(-2 * 24 * 3600 + 1800),
            energyAddedKWh: 15,
            cost: 15,
            location: "A"
        )
        let previousSession = TeslaFiSession(
            startDate: now.addingTimeInterval(-50 * 24 * 3600),
            endDate: now.addingTimeInterval(-50 * 24 * 3600 + 1800),
            energyAddedKWh: 10,
            cost: 10,
            location: "B"
        )

        let result = AgentTools.costWindows(
            entries: [recentEntry, previousEntry],
            teslaFi: [recentSession, previousSession],
            now: now
        )

        #expect(result.currentAvgDaily > result.previousAvgDaily)
    }

    @Test func formatsHours() {
        #expect(AgentTools.hourLabel(0) == "12 AM")
        #expect(AgentTools.hourLabel(12) == "12 PM")
        #expect(AgentTools.hourLabel(23) == "11 PM")
    }
}
