import SwiftUI

@MainActor
struct TripBudgetPlannerView: View {
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var adsStore = AdsEntitlementStore.shared

    @AppStorage("tripBudget.distance") private var distanceMiles: Double = 250
    @AppStorage("tripBudget.whPerMile") private var whPerMile: Double = 280
    @AppStorage("tripBudget.rate") private var ratePerKWh: Double = 0.28
    @AppStorage("tripBudget.overrideKWh") private var plannedKWh: Double = 0

    @AppStorage("tripBudget.lodgingNights") private var lodgingNights: Int = 2
    @AppStorage("tripBudget.lodgingPerNight") private var lodgingPerNight: Double = 160
    @AppStorage("tripBudget.foodPerDay") private var foodPerDay: Double = 40
    @AppStorage("tripBudget.tolls") private var tolls: Double = 0
    @AppStorage("tripBudget.misc") private var misc: Double = 0

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let energyKWh = plannedKWh > 0 ? plannedKWh : max(0, distanceMiles * whPerMile / 1000.0)
        let chargingCost = energyKWh * max(0, ratePerKWh)
        let lodgingCost = Double(lodgingNights) * max(0, lodgingPerNight)
        let foodCost = Double(lodgingNights + 1) * max(0, foodPerDay)
        let total = chargingCost + lodgingCost + foodCost + max(0, tolls) + max(0, misc)
        let currency = Locale.current.currency?.identifier ?? "USD"

        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                inputsCard
                costsCard(chargingCost: chargingCost, lodgingCost: lodgingCost, foodCost: foodCost, currency: currency)
                totalCard(total: total, nights: lodgingNights, currency: currency)

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Trip Budget Planner")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plan the full cost of a road trip")
                .font(.headline)
            Text("Estimate charging, lodging, food, and extras in one place.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                fieldRow(title: "Distance (mi)", value: $distanceMiles)
                fieldRow(title: "Efficiency (Wh/mi)", value: $whPerMile)
                fieldRow(title: "Rate ($/kWh)", value: $ratePerKWh)
                fieldRow(title: "Charging target (kWh, optional)", value: $plannedKWh)
            }

            Divider().opacity(0.2)

            HStack {
                Text("Lodging nights")
                Spacer()
                Stepper("\(lodgingNights)", value: $lodgingNights, in: 0...30)
                    .labelsHidden()
            }

            fieldRow(title: "Lodging per night", value: $lodgingPerNight)
            fieldRow(title: "Food per day", value: $foodPerDay)
            fieldRow(title: "Tolls", value: $tolls)
            fieldRow(title: "Misc", value: $misc)
        }
        .themedCard()
    }

    private func costsCard(chargingCost: Double, lodgingCost: Double, foodCost: Double, currency: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Breakdown")
                .font(.headline)

            costRow("Charging", chargingCost, currency: currency)
            costRow("Lodging", lodgingCost, currency: currency)
            costRow("Food", foodCost, currency: currency)
            costRow("Tolls", max(0, tolls), currency: currency)
            costRow("Misc", max(0, misc), currency: currency)
        }
        .themedCard()
    }

    private func totalCard(total: Double, nights: Int, currency: String) -> some View {
        let days = max(1, nights + 1)
        let perDay = total / Double(days)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Total Trip Cost")
                .font(.headline)
            Text(total, format: .currency(code: currency))
                .font(.title2.weight(.bold))
            Text("≈ \(perDay, format: .currency(code: currency)) /day")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private func fieldRow(title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
        }
    }

    private func costRow(_ title: String, _ amount: Double, currency: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(amount, format: .currency(code: currency))
                .monospacedDigit()
        }
        .font(.subheadline)
    }
}
