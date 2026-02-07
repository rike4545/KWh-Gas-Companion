//
//  WeeklyEVVsGasCostView.swift
//  KWh Gas Companion
//
//  Weekly EV vs Gas operating cost comparison
//  Swift 6 • iOS 17+
//

import SwiftUI

@MainActor
struct WeeklyEVVsGasCostView: View {
    @Environment(\.appThemeBox) private var themeBox
    private var theme: any AppThemeSpec { themeBox.base }
    @EnvironmentObject private var entriesStore: EntriesStore

    // MARK: - Gas inputs
    @State private var gasPricePerGallon: Double = 3.75
    @State private var weeklyMilesDriven: Double = 250
    @State private var vehicleMPG: Double = 28
    @State private var iceMaintPerMile: Double = 0.08

    // MARK: - EV inputs
    @State private var weeklyKWhUsed: Double = 75
    @State private var useMilesForEV: Bool = true
    @State private var evKWhPer100mi: Double = 28
    @State private var averageKWhRate: Double = 0.34
    @State private var evMaintPerMile: Double = 0.04

    // MARK: - Computed values
    private var weeklyGasFuelCost: Double {
        guard vehicleMPG > 0 else { return 0 }
        return (weeklyMilesDriven / vehicleMPG) * gasPricePerGallon
    }

    private var effectiveWeeklyKWh: Double {
        if useMilesForEV {
            return max(0, weeklyMilesDriven) * max(evKWhPer100mi, 0) / 100.0
        }
        return max(0, weeklyKWhUsed)
    }

    private var weeklyEVKWhCost: Double {
        effectiveWeeklyKWh * averageKWhRate
    }

    private var weeklyICEMaintCost: Double {
        max(0, weeklyMilesDriven) * max(iceMaintPerMile, 0)
    }

    private var weeklyEVMaintCost: Double {
        max(0, weeklyMilesDriven) * max(evMaintPerMile, 0)
    }

    private var weeklyGasCost: Double {
        weeklyGasFuelCost + weeklyICEMaintCost
    }

    private var weeklyEVTotalCost: Double {
        weeklyEVKWhCost + weeklyEVMaintCost
    }

    private var weeklySavings: Double {
        weeklyGasCost - weeklyEVTotalCost
    }

    private var monthlySavings: Double {
        weeklySavings * 4.33
    }

    private var annualSavings: Double {
        weeklySavings * 52.0
    }

    // MARK: - Recent EV charging data

    private var recentEVData: (cost: Double, kWh: Double, avgRate: Double?) {
        let range = lastNDaysRange(7)
        let entries = entriesStore.entries.filter { e in
            range.contains(e.date) && e.isEnergyEffective
        }
        let cost = entries.reduce(0) { $0 + max(0, $1.amount) }
        let kWh = entries.reduce(0) { $0 + max(0, $1.energyAddedKWh ?? 0) }
        let avg = kWh > 0 ? cost / kWh : nil
        return (cost, kWh, avg)
    }

    private var recentEVAvgWeeklyCost: Double? {
        // Avg weekly cost over last 4 weeks
        let range = lastNDaysRange(28)
        let entries = entriesStore.entries.filter { e in
            range.contains(e.date) && e.isEnergyEffective
        }
        let cost = entries.reduce(0) { $0 + max(0, $1.amount) }
        guard cost > 0 else { return nil }
        return cost / 4.0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing) {

                costCard(
                    title: "Gas Vehicle",
                    fields: [
                        .init(label: "Price / gallon", value: $gasPricePerGallon, suffix: nil),
                        .init(label: "Weekly miles", value: $weeklyMilesDriven, suffix: "mi"),
                        .init(label: "Vehicle MPG", value: $vehicleMPG, suffix: nil),
                        .init(label: "Maint. $/mi", value: $iceMaintPerMile, suffix: nil)
                    ],
                    totalLabel: "Weekly Gas Cost",
                    total: weeklyGasCost
                )

                costCard(
                    title: "Electric Vehicle",
                    fields: [
                        .init(label: "Avg kWh rate", value: $averageKWhRate, suffix: nil),
                        .init(label: "Maint. $/mi", value: $evMaintPerMile, suffix: nil)
                    ],
                    totalLabel: "Weekly EV Cost",
                    total: weeklyEVTotalCost,
                    extra: AnyView(
                        VStack(alignment: .leading, spacing: 10) {
                            evEstimatorBlock
                            recentDataBlock
                        }
                    )
                )

                comparisonCard
            }
            .padding(.horizontal, theme.spacing)
            .padding(.vertical, theme.spacing)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.screenBackground)
        .navigationTitle("Weekly EV vs Gas")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - UI

    private struct Field {
        let label: String
        let value: Binding<Double>
        let suffix: String?
    }

    private func costCard(
        title: String,
        fields: [Field],
        totalLabel: String,
        total: Double,
        extra: AnyView? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing) {
            Text(title)
                .font(.headline)

            ForEach(Array(fields.enumerated()), id: \.offset) { _, f in
                HStack(spacing: 10) {
                    Text(f.label)
                    Spacer()
                    TextField("", value: f.value, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 110)

                    if let suffix = f.suffix, !suffix.isEmpty {
                        Text(suffix)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 34, alignment: .leading)
                    }
                }
            }

            Divider().background(theme.separator)

            HStack {
                Text(totalLabel)
                Spacer()
                Text(total, format: .currency(code: "USD"))
                    .fontWeight(.semibold)
            }

            if let extra {
                extra
            }
        }
        .padding(theme.spacing)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
        .shadow(radius: theme.elevation * 0.25)
    }

    private var comparisonCard: some View {
        VStack(spacing: 8) {
            Text("Weekly Difference")
                .font(.headline)

            Text(weeklySavings, format: .currency(code: "USD"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(weeklySavings >= 0 ? Color.green : Color.red)

            Text(weeklySavings >= 0 ? "EV is cheaper per week" : "Gas is cheaper per week")
                .foregroundStyle(.secondary)

            Divider().padding(.vertical, 4)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(monthlySavings, format: .currency(code: "USD"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(monthlySavings >= 0 ? .green : .red)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Annual")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(annualSavings, format: .currency(code: "USD"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(annualSavings >= 0 ? .green : .red)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacing)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
        .shadow(radius: theme.elevation * 0.25)
    }

    private var evEstimatorBlock: AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Estimate kWh from miles", isOn: $useMilesForEV)
                    .font(.footnote)

                if useMilesForEV {
                    HStack {
                        Text("EV kWh / 100 mi")
                        Spacer()
                        TextField("", value: $evKWhPer100mi, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                        Text("kWh")
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 34, alignment: .leading)
                    }

                    HStack {
                        Text("Estimated weekly kWh")
                        Spacer()
                        Text(effectiveWeeklyKWh, format: .number.precision(.fractionLength(1)))
                            .fontWeight(.semibold)
                        Text("kWh")
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                } else {
                    HStack(spacing: 10) {
                        Text("Weekly kWh used")
                        Spacer()
                        TextField("", value: $weeklyKWhUsed, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                        Text("kWh")
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 34, alignment: .leading)
                    }
                }
            }
            .font(.footnote)
        )
    }

    private var recentDataBlock: AnyView {
        let cost = recentEVData.cost
        let kWh = recentEVData.kWh
        let avg = recentEVData.avgRate
        let weeklyAvg = recentEVAvgWeeklyCost
        let code = Locale.current.currency?.identifier ?? "USD"

        return AnyView(
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent EV charging (last 7 days)")
                    .font(.footnote.weight(.semibold))
                if cost == 0 && kWh == 0 {
                    Text("No recent charging entries found.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text("Cost")
                        Spacer()
                        Text(cost, format: .currency(code: "USD"))
                            .fontWeight(.semibold)
                    }
                    .font(.footnote)

                    HStack {
                        Text("Energy")
                        Spacer()
                        Text("\(kWh, specifier: "%.1f") kWh")
                            .fontWeight(.semibold)
                    }
                    .font(.footnote)

                    if let avg {
                        HStack {
                            Text("Avg $/kWh")
                            Spacer()
                            Text(avg, format: .currency(code: "USD"))
                                .fontWeight(.semibold)
                        }
                        .font(.footnote)
                    }
                }

                if let weeklyAvg {
                    Text("4-week average: \(weeklyAvg, format: .currency(code: code)) /week")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        )
    }

    private func lastNDaysRange(_ days: Int) -> ClosedRange<Date> {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        return start...end
    }
}
