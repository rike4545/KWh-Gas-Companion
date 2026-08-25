import Foundation
import Testing
@testable import KWh_Gas_Companion

struct AgentContextBuilderTests {

    @MainActor
    @Test func buildsContextFromStores() {
        let entriesStore = EntriesStore()
        let profileStore = ProfileStore()
        let teslaFiStore = TeslaFiSessionStore()

        profileStore.vehicles = [
            VehicleProfile(name: "Model 3", make: "Tesla", model: "3", vin: "5YJTEST", plateOrMarker: "ABC123")
        ]
        profileStore.selectedVehicleID = profileStore.vehicles.first?.id

        let now = Date()
        entriesStore.replaceAll([
            ExpenseEntry(date: now.addingTimeInterval(-2 * 24 * 3600), amount: 25, energyKWh: 8)
        ])

        teslaFiStore.replaceAll(with: [
            TeslaFiSession(
                startDate: now.addingTimeInterval(-3 * 24 * 3600),
                endDate: now.addingTimeInterval(-3 * 24 * 3600 + 1800),
                energyAddedKWh: 20,
                cost: 12,
                location: "Site"
            )
        ])

        let builder = AgentContextBuilder(
            entriesStore: entriesStore,
            profileStore: profileStore,
            teslaFiStore: teslaFiStore
        )

        let context = builder.build(now: now)

        #expect(context.activeVehicleName == "Model 3")
        #expect(context.entriesCount == 1)
        #expect(context.teslaFiSessionsCount == 1)
        #expect(context.recent30DaySpend >= 37)
        #expect(context.recent30DayEnergyKWh >= 28)
    }
}
