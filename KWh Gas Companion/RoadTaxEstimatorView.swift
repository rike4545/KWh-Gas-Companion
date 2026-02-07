import SwiftUI

@MainActor
struct RoadTaxEstimatorView: View {
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var adsStore = AdsEntitlementStore.shared

    @AppStorage("roadtax.state") private var stateName: String = ""
    @AppStorage("roadtax.miles") private var milesPerYear: Double = 12000
    @AppStorage("roadtax.gasTax") private var gasTaxCents: Double = 30
    @AppStorage("roadtax.mpg") private var mpg: Double = 28
    @AppStorage("roadtax.evFee") private var evFeeAnnual: Double = 150

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let gallons = max(0.0, milesPerYear / max(1.0, mpg))
        let gasTax = gallons * (gasTaxCents / 100.0)
        let diff = evFeeAnnual - gasTax
        let currency = Locale.current.currency?.identifier ?? "USD"

        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                inputsCard
                resultsCard(gasTax: gasTax, diff: diff, currency: currency)

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("EV Road‑Tax")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EV fee vs gas tax")
                .font(.headline)
            Text("Enter your state’s current gas tax and EV fee to compare.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("State (optional)")
                Spacer()
                TextField("e.g. CA", text: $stateName)
                    .textInputAutocapitalization(.characters)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }

            fieldRow("Miles per year", value: $milesPerYear)
            fieldRow("Gas tax (cents/gal)", value: $gasTaxCents)
            fieldRow("Gas MPG", value: $mpg)
            fieldRow("EV fee (annual)", value: $evFeeAnnual)
        }
        .themedCard()
    }

    private func resultsCard(gasTax: Double, diff: Double, currency: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Result")
                .font(.headline)
            costRow("Estimated gas tax", gasTax, currency: currency)
            costRow("EV annual fee", max(0, evFeeAnnual), currency: currency)
            Divider().opacity(0.2)
            Text(diff >= 0 ? "EV fee is higher by" : "Gas tax is higher by")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(abs(diff), format: .currency(code: currency))
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
