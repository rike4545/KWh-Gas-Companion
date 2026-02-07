import SwiftUI

@MainActor
struct ChargingSchedulePlannerView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var adsStore = AdsEntitlementStore.shared

    @AppStorage("planner.offPeakStart") private var offPeakStart: Int = 22
    @AppStorage("planner.offPeakEnd") private var offPeakEnd: Int = 6
    @AppStorage("planner.offPeakRate") private var offPeakRate: Double = 0.18
    @AppStorage("planner.peakRate") private var peakRate: Double = 0.32
    @AppStorage("planner.targetKWh") private var targetKWh: Double = 42

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                plannerCard
                estimateCard

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Smart Charging Planner")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plan your lowest‑cost charge window")
                .font(.headline)
            Text("Set your utility rates once. We’ll recommend the cheapest window and estimate session cost.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var plannerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Off‑Peak Window", systemImage: "clock")
                    .font(.headline)
                Spacer()
                Text(windowText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Picker("Start", selection: $offPeakStart) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(hourLabel(h)).tag(h)
                    }
                }
                .pickerStyle(.menu)

                Picker("End", selection: $offPeakEnd) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(hourLabel(h)).tag(h)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Text("Off‑peak rate")
                Spacer()
                TextField("$", value: $offPeakRate, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("Peak rate")
                Spacer()
                TextField("$", value: $peakRate, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
        .themedCard()
    }

    private var estimateCard: some View {
        let avgKWh = averageSessionKWh ?? targetKWh
        let offPeakCost = avgKWh * offPeakRate
        let peakCost = avgKWh * peakRate
        let savings = max(0, peakCost - offPeakCost)
        let currencyCode = Locale.current.currency?.identifier ?? "USD"

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Estimated Session", systemImage: "bolt.fill")
                    .font(.headline)
                Spacer()
                Text("\(avgKWh, specifier: "%.1f") kWh")
                    .font(.subheadline.monospacedDigit())
            }

            HStack {
                Text("Off‑peak cost")
                Spacer()
                Text(offPeakCost, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.headline)
            }

            HStack {
                Text("Peak cost")
                Spacer()
                Text(peakCost, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if savings > 0 {
                Text("Estimated savings per session: \(savings, format: .currency(code: currencyCode))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .themedCard()
    }

    private var windowText: String {
        "\(hourLabel(offPeakStart)) → \(hourLabel(offPeakEnd))"
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 24
        let suffix = h < 12 ? "AM" : "PM"
        let hour12 = h % 12 == 0 ? 12 : h % 12
        return "\(hour12)\(suffix)"
    }

    private var averageSessionKWh: Double? {
        let energy = entriesStore.energyEntries()
        guard !energy.isEmpty else { return nil }
        let recent = energy.sorted { $0.date > $1.date }.prefix(12)
        let kwh = recent.compactMap { $0.energyAddedKWh }.filter { $0 > 0 }
        guard !kwh.isEmpty else { return nil }
        let avg = kwh.reduce(0, +) / Double(kwh.count)
        return max(5, avg)
    }
}
