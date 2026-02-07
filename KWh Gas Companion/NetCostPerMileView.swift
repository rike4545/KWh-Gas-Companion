import SwiftUI

@MainActor
struct NetCostPerMileView: View {
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var adsStore = AdsEntitlementStore.shared

    @AppStorage("netcost.price") private var purchasePrice: Double = 52000
    @AppStorage("netcost.currentValue") private var currentValue: Double = 36000
    @AppStorage("netcost.milesPerYear") private var milesPerYear: Double = 12000
    @AppStorage("netcost.whPerMile") private var whPerMile: Double = 280
    @AppStorage("netcost.rate") private var ratePerKWh: Double = 0.26
    @AppStorage("netcost.insuranceMonthly") private var insuranceMonthly: Double = 140
    @AppStorage("netcost.maintenanceMonthly") private var maintenanceMonthly: Double = 35

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let depreciationAnnual = max(0, purchasePrice - currentValue) / 3.0
        let energyAnnual = (milesPerYear * whPerMile / 1000.0) * ratePerKWh
        let insuranceAnnual = insuranceMonthly * 12
        let maintenanceAnnual = maintenanceMonthly * 12
        let totalAnnual = depreciationAnnual + energyAnnual + insuranceAnnual + maintenanceAnnual
        let costPerMile = totalAnnual / max(1, milesPerYear)
        let currency = Locale.current.currency?.identifier ?? "USD"

        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                inputsCard
                summaryCard(totalAnnual: totalAnnual, costPerMile: costPerMile, currency: currency)

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Net Cost / Mile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("True ownership cost per mile")
                .font(.headline)
            Text("Includes depreciation, energy, insurance, and maintenance.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldRow("Purchase price", value: $purchasePrice)
            fieldRow("Current value", value: $currentValue)
            fieldRow("Miles per year", value: $milesPerYear)
            fieldRow("Efficiency (Wh/mi)", value: $whPerMile)
            fieldRow("Rate ($/kWh)", value: $ratePerKWh)
            fieldRow("Insurance / month", value: $insuranceMonthly)
            fieldRow("Maintenance / month", value: $maintenanceMonthly)
        }
        .themedCard()
    }

    private func summaryCard(totalAnnual: Double, costPerMile: Double, currency: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Summary")
                .font(.headline)
            Text("Annual total: \(totalAnnual, format: .currency(code: currency))")
                .font(.subheadline)
            Text("Net cost per mile")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(costPerMile, format: .currency(code: currency))
                .font(.title3.weight(.bold))
        }
        .themedCard()
    }

    private func fieldRow(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 140)
        }
    }
}
