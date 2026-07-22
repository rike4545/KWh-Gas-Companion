import SwiftUI

@MainActor
struct EVGasComparisonHubView: View {
    @Environment(\.appThemeBox) private var themeBox
    @EnvironmentObject private var entriesStore: EntriesStore

    @AppStorage("evgas.gasPricePerGallon") private var gasPricePerGallon: Double = 3.80
    @AppStorage("evgas.iceMPG") private var iceMPG: Double = 28
    @AppStorage("evgas.electricityRate") private var electricityRate: Double = 0.15
    @AppStorage("evgas.kwhPer100Miles") private var kWhPer100Miles: Double = 28
    @AppStorage("evgas.evMaintPerMile") private var evMaintPerMile: Double = 0.04
    @AppStorage("evgas.iceMaintPerMile") private var iceMaintPerMile: Double = 0.08
    @AppStorage("evgas.customMiles") private var customMiles: Double = 10000
    @AppStorage("evgas.preferData") private var preferDataWhenAvailable: Bool = true

    private let presetMiles: [Double] = [1500, 5000, 15000, 20000, 25000]
    private var theme: any AppThemeSpec { themeBox.base }
    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    private var energyEntries: [ExpenseEntry] {
        entriesStore.entries.filter { $0.isEnergyEffective }
    }

    private var totalChargingCost: Double {
        energyEntries.reduce(0.0) { $0 + max(0, $1.amount) }
    }

    private var totalChargingKWh: Double? {
        let kWh = energyEntries.compactMap(\.energyAddedKWh)
        guard !kWh.isEmpty else { return nil }
        return kWh.reduce(0, +)
    }

    private var loggedMiles: Double? {
        let odometers = entriesStore.entries.compactMap(\.odometer).sorted()
        guard let first = odometers.first, let last = odometers.last, last > first else { return nil }
        return last - first
    }

    private var dataDerivedEVEnergyPerMile: Double? {
        guard let miles = loggedMiles, miles > 0 else { return nil }
        return totalChargingCost / miles
    }

    private var dataDerivedEVKWhPerMile: Double? {
        guard let miles = loggedMiles, miles > 0, let totalChargingKWh, totalChargingKWh > 0 else { return nil }
        return totalChargingKWh / miles
    }

    private var assumedEVEnergyPerMile: Double {
        max(0, electricityRate) * max(0, kWhPer100Miles) / 100.0
    }

    private var effectiveEVEnergyPerMile: Double {
        if preferDataWhenAvailable, let value = dataDerivedEVEnergyPerMile {
            return max(0, value)
        }
        return assumedEVEnergyPerMile
    }

    private var effectiveEVTotalPerMile: Double {
        effectiveEVEnergyPerMile + max(0, evMaintPerMile)
    }

    private var effectiveICEPerMile: Double {
        guard iceMPG > 0 else { return max(0, iceMaintPerMile) }
        return max(0, gasPricePerGallon) / iceMPG + max(0, iceMaintPerMile)
    }

    private var loggedRangeComparison: ScenarioComparison? {
        guard let miles = loggedMiles, miles > 0 else { return nil }
        return scenario(for: miles)
    }

    private var scenarioRows: [ScenarioComparison] {
        let merged = presetMiles + [customMiles]
        let unique = Array(Set(merged.filter { $0 > 0 })).sorted()
        return unique.map(scenario(for:))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing) {
                headerCard
                inputsCard
                dataSnapshotCard
                scenarioTableCard
                annualizedCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(theme.screenBackground)
        .navigationTitle("EV vs Gas")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unified EV vs gas comparison")
                .font(.headline)
            Text("Compare your saved charging spend against equivalent gas cost, then explore preset or custom mileage ranges with today’s fuel price.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inputs")
                .font(.headline)

            fieldRow("Gas price ($/gal)", value: $gasPricePerGallon)
            fieldRow("Gas vehicle MPG", value: $iceMPG)
            fieldRow("Electricity ($/kWh)", value: $electricityRate)
            fieldRow("EV kWh / 100 mi", value: $kWhPer100Miles)
            fieldRow("EV maint. $/mi", value: $evMaintPerMile)
            fieldRow("Gas maint. $/mi", value: $iceMaintPerMile)
            fieldRow("Custom miles", value: $customMiles, digits: 0)

            Toggle("Prefer saved charging data when available", isOn: $preferDataWhenAvailable)
                .font(.footnote)

            if let dataDerivedEVEnergyPerMile {
                Text("Saved data currently implies about \(currency(dataDerivedEVEnergyPerMile))/mi in charging energy.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Saved charging data does not yet include enough odometer coverage for a true data-derived cost per mile, so assumptions are being used.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .themedCard()
    }

    private var dataSnapshotCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current charging total")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                metric("Charging spend", currency(totalChargingCost))
                metric("Logged miles", loggedMiles.map { number($0, 0) + " mi" } ?? "Need odometer data")
                metric("EV total $/mi", currency(effectiveEVTotalPerMile))
                metric("Gas total $/mi", currency(effectiveICEPerMile))
            }

            if let comparison = loggedRangeComparison {
                Divider().opacity(0.2)
                Text("Using your logged distance of \(number(comparison.miles, 0)) miles, gas would be about \(currency(comparison.gasTotalCost)) at current assumptions versus EV total cost of \(currency(comparison.evTotalCost)).")
                    .font(.subheadline)

                Text(comparison.savings >= 0
                    ? "Estimated EV advantage so far: \(currency(comparison.savings))."
                    : "Estimated gas advantage so far: \(currency(abs(comparison.savings))).")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(comparison.savings >= 0 ? .green : .red)
            } else {
                Text("Add charging entries with odometer values if you want the app to compare your actual accumulated charging spend against an equivalent gas total over the same logged distance.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .themedCard()
    }

    private var scenarioTableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mileage scenarios")
                .font(.headline)

            VStack(spacing: 0) {
                scenarioHeaderRow
                ForEach(Array(scenarioRows.enumerated()), id: \.element.id) { index, row in
                    Divider().opacity(0.15)
                    scenarioRow(row, highlight: row.miles == customMiles)
                    if index == scenarioRows.count - 1 {
                        Divider().opacity(0.15)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.cardBackground)
            )

            Text("Rows include operating cost assumptions for both EV and gas. EV totals use either saved charging data or the fallback electricity assumptions above.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private var annualizedCard: some View {
        let annual = scenario(for: 12000)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Annualized reference")
                .font(.headline)
            Text("At 12,000 miles, EV operating cost is about \(currency(annual.evTotalCost)) versus gas at \(currency(annual.gasTotalCost)).")
                .font(.subheadline)
            Text(annual.savings >= 0
                ? "Estimated annual EV savings: \(currency(annual.savings))."
                : "Estimated annual gas advantage: \(currency(abs(annual.savings))).")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(annual.savings >= 0 ? .green : .red)
        }
        .themedCard()
    }

    private var scenarioHeaderRow: some View {
        HStack(alignment: .center, spacing: 8) {
            headerCell("Miles")
            headerCell("EV total")
            headerCell("Gas total")
            headerCell("Difference")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func scenarioRow(_ row: ScenarioComparison, highlight: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            valueCell(number(row.miles, 0) + " mi", emphasize: highlight)
            valueCell(currency(row.evTotalCost), emphasize: false)
            valueCell(currency(row.gasTotalCost), emphasize: false)
            valueCell(
                row.savings >= 0 ? currency(row.savings) : "-" + currency(abs(row.savings)),
                color: row.savings >= 0 ? .green : .red,
                emphasize: true
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func headerCell(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func valueCell(_ value: String, color: Color? = nil, emphasize: Bool) -> some View {
        Text(value)
            .font(emphasize ? .subheadline.weight(.semibold) : .subheadline)
            .foregroundStyle(color ?? .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
    }

    private func fieldRow(_ title: String, value: Binding<Double>, digits: Int = 2) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number.precision(.fractionLength(0...digits)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
        }
        .font(.subheadline)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.pillTint.opacity(0.2))
        )
    }

    private func scenario(for miles: Double) -> ScenarioComparison {
        let clippedMiles = max(0, miles)
        let ev = clippedMiles * effectiveEVTotalPerMile
        let gas = clippedMiles * effectiveICEPerMile
        return ScenarioComparison(
            miles: clippedMiles,
            evTotalCost: ev,
            gasTotalCost: gas,
            savings: gas - ev
        )
    }

    private func currency(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode))
    }

    private func number(_ value: Double, _ digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)))
    }
}

private struct ScenarioComparison: Identifiable {
    let miles: Double
    let evTotalCost: Double
    let gasTotalCost: Double
    let savings: Double

    var id: String { String(format: "%.0f", miles) }
}
