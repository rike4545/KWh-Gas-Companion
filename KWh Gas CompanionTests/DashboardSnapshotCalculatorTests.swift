import Foundation
import Testing
@testable import KWh_Gas_Companion

struct DashboardSnapshotCalculatorTests {
    @Test
    func snapshotFiltersToCurrentMonthAndBuildsSpendingBuckets() {
        let now = Date(timeIntervalSince1970: 1_767_225_600)
        let currentCharge = ExpenseEntry(
            date: now,
            amount: 18,
            category: "Supercharging",
            energyKWh: 45,
            location: "Newark Supercharger",
            isEnergy: true
        )
        let currentInsurance = ExpenseEntry(
            date: now,
            amount: 120,
            category: "Insurance",
            isEnergy: false
        )
        let priorMonth = ExpenseEntry(
            date: now.addingTimeInterval(-40 * 86_400),
            amount: 999,
            category: "Misc",
            isEnergy: false
        )

        let snapshot = DashboardSnapshotCalculator.make(
            entries: [currentCharge, currentInsurance, priorMonth],
            energyEntries: [currentCharge],
            importedSessions: [],
            selectedVehicle: nil,
            includeImportedSessions: false,
            now: now
        )

        #expect(snapshot.entriesThisMonth.map(\.id).contains(currentCharge.id))
        #expect(snapshot.entriesThisMonth.map(\.id).contains(currentInsurance.id))
        #expect(!snapshot.entriesThisMonth.map(\.id).contains(priorMonth.id))
        #expect(snapshot.spending.superchargingEntries == 18)
        #expect(snapshot.spending.insurance == 120)
        #expect(snapshot.monthEnergyKWh == 45)
    }

    @Test
    func snapshotHonorsImportedSessionEntitlement() {
        let now = Date(timeIntervalSince1970: 1_767_225_600)
        let session = TeslaFiSession(
            startDate: now.addingTimeInterval(-3_600),
            endDate: now,
            energyAddedKWh: 40,
            cost: 16,
            location: "Newark Supercharger"
        )

        let locked = DashboardSnapshotCalculator.make(
            entries: [],
            energyEntries: [],
            importedSessions: [session],
            selectedVehicle: nil,
            includeImportedSessions: false,
            now: now
        )
        let unlocked = DashboardSnapshotCalculator.make(
            entries: [],
            energyEntries: [],
            importedSessions: [session],
            selectedVehicle: nil,
            includeImportedSessions: true,
            now: now
        )

        #expect(locked.importedSessionsThisMonth.isEmpty)
        #expect(unlocked.importedSessionsThisMonth.map(\.id) == [session.id])
        #expect(unlocked.spending.superchargingTeslaFi == 16)
    }
}
