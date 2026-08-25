import Foundation
import Testing
@testable import KWh_Gas_Companion

struct CaughtaKWHEngineTests {
    @Test
    func emptyHistoryProducesLearningState() {
        let summary = CaughtaKWHEngine.summarize(entries: [], sessions: [])

        #expect(summary.caughtCount == 0)
        #expect(summary.cleanRowCount == 0)
        #expect(summary.baselineRate == nil)
        #expect(summary.worstRate == nil)
    }

    @Test
    func chargingEntryWithoutEnergyIsCaught() {
        let entry = ExpenseEntry(
            date: .now,
            amount: 18.50,
            category: "Supercharging",
            energyKWh: nil,
            location: "Newark Supercharger",
            isEnergy: true
        )

        let summary = CaughtaKWHEngine.summarize(entries: [entry], sessions: [])

        #expect(summary.caughtCount == 1)
        #expect(summary.missingEnergyEntries.map(\.id) == [entry.id])
        #expect(summary.issueRows.count == 1)
    }

    @Test
    func expensiveImportedSessionIsCaughtAgainstBaseline() {
        let normal = TeslaFiSession(
            startDate: .now.addingTimeInterval(-7_200),
            endDate: .now.addingTimeInterval(-5_400),
            energyAddedKWh: 40,
            cost: 16,
            location: "Normal Supercharger"
        )
        let expensive = TeslaFiSession(
            startDate: .now.addingTimeInterval(-3_600),
            endDate: .now.addingTimeInterval(-1_800),
            energyAddedKWh: 10,
            cost: 12,
            location: "Expensive Supercharger"
        )

        let summary = CaughtaKWHEngine.summarize(entries: [], sessions: [normal, expensive])

        #expect(summary.highRateSessions.map(\.session.id) == [expensive.id])
        #expect(summary.worstRate == 1.2)
        #expect(summary.issueRows.count == 1)
    }
}
