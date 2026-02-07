import SwiftUI

@MainActor
struct AnnualCostSimulatorView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @Environment(\.appThemeBox) private var themeBox

    @AppStorage("annualSim.weeklyCost") private var weeklyCost: Double = 0
    @AppStorage("annualSim.weeklyKWh") private var weeklyKWh: Double = 0

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                inputsCard
                estimateCard
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Annual Cost Simulator")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let stats = WeeklyForecastSummary.build(from: entriesStore.energyEntries())
            if weeklyCost == 0 { weeklyCost = stats.forecastCost }
            if weeklyKWh == 0 { weeklyKWh = stats.forecastKWh }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Project yearly charging cost")
                .font(.headline)
            Text("Use your recent weekly averages to project an annual total.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly cost")
                Spacer()
                TextField("$", value: $weeklyCost, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("Weekly kWh")
                Spacer()
                TextField("kWh", value: $weeklyKWh, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
        .themedCard()
    }

    private var estimateCard: some View {
        let annualCost = weeklyCost * 52
        let annualKWh = weeklyKWh * 52
        let currency = Locale.current.currency?.identifier ?? "USD"

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Annual cost")
                Spacer()
                Text(annualCost, format: .currency(code: currency))
                    .font(.title3.weight(.semibold))
            }

            HStack {
                Text("Annual energy")
                Spacer()
                Text("\(annualKWh, specifier: "%.0f") kWh")
                    .font(.headline)
            }
        }
        .themedCard()
    }
}
