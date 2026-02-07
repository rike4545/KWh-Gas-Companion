import SwiftUI

@MainActor
struct CostPerMileVsGasView: View {
    @Environment(\.appThemeBox) private var themeBox
    private var theme: any AppThemeSpec { themeBox.base }

    @State private var gasPrice: Double = 3.50
    @State private var mpg: Double = 28
    @State private var kwhPrice: Double = 0.30
    @State private var kwhPerMile: Double = 0.30

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing) {
                header
                inputs
                results
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("Cost per Mile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EV vs Gas cost per mile")
                .font(.headline)
            Text("Use your local prices and efficiency to compare running costs.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private var inputs: some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledField("Gas price ($/gal)", value: $gasPrice)
            labeledField("Gas MPG", value: $mpg)
            labeledField("Electricity ($/kWh)", value: $kwhPrice)
            labeledField("EV kWh per mile", value: $kwhPerMile)
        }
        .themedCard()
    }

    private var results: some View {
        let currency = Locale.current.currency?.identifier ?? "USD"
        let gasCostPerMile = mpg > 0 ? gasPrice / mpg : 0
        let evCostPerMile = kwhPrice * kwhPerMile
        return VStack(alignment: .leading, spacing: 8) {
            Text("Results")
                .font(.headline)
            HStack {
                stat("Gas", gasCostPerMile.formatted(.currency(code: currency)) + "/mi")
                stat("EV", evCostPerMile.formatted(.currency(code: currency)) + "/mi")
            }
            let delta = gasCostPerMile - evCostPerMile
            Text(delta >= 0 ? "EV saves \(delta.formatted(.currency(code: currency)))/mi"
                            : "Gas saves \(abs(delta).formatted(.currency(code: currency)))/mi")
                .font(.footnote)
                .foregroundStyle(delta >= 0 ? Color.green : Color.red)
        }
        .themedCard()
    }

    private func labeledField(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number.precision(.fractionLength(2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
        }
        .font(.subheadline)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
