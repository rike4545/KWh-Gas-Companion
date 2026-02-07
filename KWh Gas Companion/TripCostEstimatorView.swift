import SwiftUI

@MainActor
struct TripCostEstimatorView: View {
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var adsStore = AdsEntitlementStore.shared

    @AppStorage("tripCost.distanceMiles") private var distanceMiles: Double = 120
    @AppStorage("tripCost.whPerMile") private var whPerMile: Double = 280
    @AppStorage("tripCost.ratePerKWh") private var ratePerKWh: Double = 0.26

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                inputsCard
                estimateCard

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Trip Cost Estimator")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estimate EV trip cost")
                .font(.headline)
            Text("Enter distance, efficiency, and rate to compute a quick trip estimate.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Distance (mi)")
                Spacer()
                TextField("0", value: $distanceMiles, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("Efficiency (Wh/mi)")
                Spacer()
                TextField("0", value: $whPerMile, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("Rate ($/kWh)")
                Spacer()
                TextField("0.00", value: $ratePerKWh, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
        .themedCard()
    }

    private var estimateCard: some View {
        let kWh = max(0, distanceMiles * whPerMile / 1000.0)
        let cost = kWh * max(0, ratePerKWh)
        let currency = Locale.current.currency?.identifier ?? "USD"

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Energy needed")
                Spacer()
                Text("\(kWh, specifier: "%.1f") kWh")
                    .font(.headline)
            }

            HStack {
                Text("Estimated cost")
                Spacer()
                Text(cost, format: .currency(code: currency))
                    .font(.title3.weight(.semibold))
            }
        }
        .themedCard()
    }
}
