import SwiftUI

@MainActor
struct MonthlyHeatmapView: View {
    enum Metric: String, CaseIterable, Identifiable {
        case spend
        case energy
        var id: String { rawValue }
        var title: String { self == .spend ? "Spend" : "kWh" }
    }

    @EnvironmentObject private var entriesStore: EntriesStore
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var adsStore = AdsEntitlementStore.shared
    @State private var metric: Metric = .spend

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let month = Calendar.current.dateInterval(of: .month, for: Date())!
        let days = generateDays(in: month)
        let values = valuesByDay(days: days)
        let maxVal = values.values.max() ?? 0.0

        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                metricPicker
                heatmapGrid(days: days, values: values, maxVal: maxVal)

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Monthly Heatmap")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly heatmap")
                .font(.headline)
            Text("See daily spend or energy usage at a glance.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var metricPicker: some View {
        Picker("Metric", selection: $metric) {
            ForEach(Metric.allCases) { m in
                Text(m.title).tag(m)
            }
        }
        .pickerStyle(.segmented)
    }

    private func heatmapGrid(days: [Date], values: [Date: Double], maxVal: Double) -> some View {
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        let startWeekday = Calendar.current.component(.weekday, from: days.first ?? Date())
        let leadingBlanks = (startWeekday + 5) % 7

        return VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 28)
                }

                ForEach(days, id: \.self) { day in
                    let value = values[day] ?? 0
                    let intensity = maxVal > 0 ? value / maxVal : 0
                    let color = theme.accent.opacity(0.15 + 0.65 * intensity)

                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(color)
                        Text("\(Calendar.current.component(.day, from: day))")
                            .font(.caption2)
                            .foregroundStyle(.primary.opacity(intensity > 0.2 ? 1 : 0.65))
                    }
                    .frame(height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(theme.separator.opacity(0.25), lineWidth: 1)
                    )
                }
            }

            Text(metric == .spend ? "Darker = higher spend" : "Darker = higher kWh")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private func generateDays(in interval: DateInterval) -> [Date] {
        var days: [Date] = []
        var current = interval.start
        let cal = Calendar.current
        while current < interval.end {
            days.append(current)
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return days
    }

    private func valuesByDay(days: [Date]) -> [Date: Double] {
        let cal = Calendar.current
        let entries = entriesStore.entries
        var map: [Date: Double] = [:]
        for day in days {
            let dayStart = cal.startOfDay(for: day)
            let next = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let bucket = entries.filter { $0.date >= dayStart && $0.date < next }
            let value: Double
            switch metric {
            case .spend:
                value = bucket.reduce(0) { $0 + $1.amount }
            case .energy:
                value = bucket.compactMap { $0.energyAddedKWh }.reduce(0, +)
            }
            map[day] = value
        }
        return map
    }
}
