import SwiftUI

@MainActor
struct BestValueChargersView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @Environment(\.appThemeBox) private var themeBox

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let items = BestValueChargers.compute(entries: entriesStore.energyEntries())

        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing) {
                header
                ForEach(items) { item in
                    row(item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("Best Value Chargers")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Lowest average $/kWh")
                .font(.headline)
            Text("Based on your logged sessions with price per kWh.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private func row(_ item: BestValueChargers.Item) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(item.avgCostPerKWh.formatted(.currency(code: item.currency)))
                    .font(.subheadline.weight(.semibold))
            }
            Text("\(item.count) sessions • avg \(String(format: "%.1f", item.avgKWh)) kWh")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }
}

enum BestValueChargers {
    struct Item: Identifiable {
        let id = UUID()
        let name: String
        let avgCostPerKWh: Double
        let avgKWh: Double
        let count: Int
        let currency: String
    }

    static func compute(entries: [ExpenseEntry]) -> [Item] {
        let currency = Locale.current.currency?.identifier ?? "USD"
        let groups = Dictionary(grouping: entries) { entry in
            entry.charging?.siteName?.trimmedNonEmpty ?? entry.location?.trimmedNonEmpty ?? "Unknown"
        }

        var out: [Item] = []
        for (name, group) in groups {
            let cpk = group.compactMap(\.costPerKWh).filter { $0 > 0 }
            guard !cpk.isEmpty else { continue }
            let avgCPK = cpk.reduce(0, +) / Double(cpk.count)
            let avgKWh = group.compactMap(\.energyAddedKWh).reduce(0, +) / Double(max(1, group.count))
            out.append(Item(name: name, avgCostPerKWh: avgCPK, avgKWh: avgKWh, count: group.count, currency: currency))
        }

        return out.sorted { $0.avgCostPerKWh < $1.avgCostPerKWh }.prefix(10).map { $0 }
    }
}
