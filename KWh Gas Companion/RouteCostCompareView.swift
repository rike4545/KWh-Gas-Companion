import SwiftUI

@MainActor
struct RouteCostCompareView: View {
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var adsStore = AdsEntitlementStore.shared

    @AppStorage("routecompare.distance") private var distanceMiles: Double = 220
    @AppStorage("routecompare.whPerMile") private var whPerMile: Double = 280
    @AppStorage("routecompare.fastRate") private var fastRate: Double = 0.42
    @AppStorage("routecompare.slowRate") private var slowRate: Double = 0.18
    @AppStorage("routecompare.fastSpeed") private var fastSpeedKW: Double = 150
    @AppStorage("routecompare.slowSpeed") private var slowSpeedKW: Double = 11
    @AppStorage("routecompare.valueTime") private var valueOfTime: Double = 0

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let kWh = max(0, distanceMiles * whPerMile / 1000.0)
        let fastCost = kWh * max(0, fastRate)
        let slowCost = kWh * max(0, slowRate)
        let fastHours = kWh / max(1, fastSpeedKW)
        let slowHours = kWh / max(1, slowSpeedKW)
        let timeValue = max(0, valueOfTime)
        let fastTotal = fastCost + fastHours * timeValue
        let slowTotal = slowCost + slowHours * timeValue

        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                inputsCard
                resultsCard(
                    kWh: kWh,
                    fastCost: fastCost,
                    slowCost: slowCost,
                    fastHours: fastHours,
                    slowHours: slowHours,
                    fastTotal: fastTotal,
                    slowTotal: slowTotal
                )

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Route Cost Compare")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fast vs slow charging cost")
                .font(.headline)
            Text("Compare total energy cost and time impact for a trip.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldRow("Distance (mi)", value: $distanceMiles)
            fieldRow("Efficiency (Wh/mi)", value: $whPerMile)
            fieldRow("Fast rate ($/kWh)", value: $fastRate)
            fieldRow("Slow rate ($/kWh)", value: $slowRate)
            fieldRow("Fast speed (kW)", value: $fastSpeedKW)
            fieldRow("Slow speed (kW)", value: $slowSpeedKW)
            fieldRow("Value of time ($/hr)", value: $valueOfTime)
        }
        .themedCard()
    }

    private func resultsCard(
        kWh: Double,
        fastCost: Double,
        slowCost: Double,
        fastHours: Double,
        slowHours: Double,
        fastTotal: Double,
        slowTotal: Double
    ) -> some View {
        let currency = Locale.current.currency?.identifier ?? "USD"
        return VStack(alignment: .leading, spacing: 10) {
            Text("Results")
                .font(.headline)

            HStack {
                Text("Energy needed")
                Spacer()
                Text("\(kWh, specifier: "%.1f") kWh")
                    .monospacedDigit()
            }
            .font(.subheadline)

            Divider().opacity(0.2)

            HStack {
                Text("Fast charging cost")
                Spacer()
                Text(fastCost, format: .currency(code: currency))
                    .monospacedDigit()
            }
            HStack {
                Text("Slow charging cost")
                Spacer()
                Text(slowCost, format: .currency(code: currency))
                    .monospacedDigit()
            }
            HStack {
                Text("Fast time")
                Spacer()
                Text("\(fastHours, specifier: "%.1f") hr")
                    .monospacedDigit()
            }
            HStack {
                Text("Slow time")
                Spacer()
                Text("\(slowHours, specifier: "%.1f") hr")
                    .monospacedDigit()
            }

            Divider().opacity(0.2)

            HStack {
                Text("Fast total (w/ time)")
                Spacer()
                Text(fastTotal, format: .currency(code: currency))
                    .monospacedDigit()
            }
            HStack {
                Text("Slow total (w/ time)")
                Spacer()
                Text(slowTotal, format: .currency(code: currency))
                    .monospacedDigit()
            }
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
