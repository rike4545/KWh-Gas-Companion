import SwiftUI

@MainActor
struct WeeklyChargingForecastView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme
    @StateObject private var adsStore = AdsEntitlementStore.shared

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                forecastCard

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Weekly Forecast")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rolling 4‑week projection")
                .font(.headline)
            Text("Uses a tiny on-device neural net over your recent charging history to forecast next week’s cost and energy.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var forecastCard: some View {
        let stats = WeeklyForecastSummary.build(from: entriesStore.energyEntries())

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Next Week Forecast", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                Spacer()
            }

            HStack {
                Text("Projected cost")
                Spacer()
                Text(stats.forecastCost, format: .currency(code: stats.currencyCode))
                    .font(.title3.weight(.semibold))
            }

            HStack {
                Text("Projected energy")
                Spacer()
                Text("\(stats.forecastKWh, specifier: "%.1f") kWh")
                    .font(.headline)
            }

            if stats.confidenceText != nil {
                Text(stats.confidenceText ?? "")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let modelSummary = stats.modelSummary {
                Text(modelSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let reinforcementSummary = stats.reinforcementSummary {
                Label(reinforcementSummary, systemImage: "scope")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .themedCard()
    }
}
