import SwiftUI

@MainActor
struct BatteryHealthTimelineView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @Environment(\.appThemeBox) private var themeBox

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let buckets = BatteryHealthTimeline.compute(entries: entriesStore.energyEntries())

        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing) {
                header
                ForEach(buckets) { b in
                    timelineRow(b)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("Battery Health")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Charging health trend")
                .font(.headline)
            Text("Uses your logged sessions to show trends in energy per session and cost per kWh. This is an estimate, not a diagnostic.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private func timelineRow(_ b: BatteryHealthTimeline.Bucket) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(b.label)
                .font(.subheadline.weight(.semibold))
            HStack {
                stat("Avg kWh/session", String(format: "%.1f", b.avgKWh))
                stat("Avg $/kWh", b.avgCostPerKWh?.formatted(.currency(code: b.currency)) ?? "—")
                stat("Sessions", "\(b.count)")
            }
        }
        .themedCard()
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum BatteryHealthTimeline {
    struct Bucket: Identifiable {
        let id = UUID()
        let label: String
        let avgKWh: Double
        let avgCostPerKWh: Double?
        let count: Int
        let currency: String
    }

    static func compute(entries: [ExpenseEntry]) -> [Bucket] {
        let currency = Locale.current.currency?.identifier ?? "USD"
        let cal = Calendar.current
        let now = Date()
        var out: [Bucket] = []

        for i in 0..<12 {
            let end = cal.date(byAdding: .day, value: -7 * i, to: now) ?? now
            let start = cal.date(byAdding: .day, value: -7, to: end) ?? end

            let slice = entries.filter { $0.date >= start && $0.date < end }
            let kWh = slice.compactMap(\.energyAddedKWh)
            let avgKWh = kWh.isEmpty ? 0 : kWh.reduce(0, +) / Double(kWh.count)
            let costPer = slice.compactMap(\.costPerKWh)
            let avgCost = costPer.isEmpty ? nil : costPer.reduce(0, +) / Double(costPer.count)

            let label = start.formatted(date: .abbreviated, time: .omitted)
            out.append(Bucket(label: label, avgKWh: avgKWh, avgCostPerKWh: avgCost, count: slice.count, currency: currency))
        }

        return out
    }
}
