import SwiftUI

@MainActor
struct OwnershipTimelineMonthlyView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var adsStore = AdsEntitlementStore.shared

    @AppStorage("tco.purchaseDateTimestamp") private var purchaseDateTimestamp: Double =
        (Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()).timeIntervalSince1970

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let rows = monthlyRows()
        let currency = Locale.current.currency?.identifier ?? "USD"

        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                timelineCard(rows: rows, currency: currency)

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("TCO Timeline")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly ownership cost since purchase")
                .font(.headline)
            DatePicker(
                "Purchase date",
                selection: Binding(
                    get: { Date(timeIntervalSince1970: purchaseDateTimestamp) },
                    set: { purchaseDateTimestamp = $0.timeIntervalSince1970 }
                ),
                displayedComponents: .date
            )
                .font(.footnote)
        }
        .themedCard(prominent: true)
    }

    private func timelineCard(rows: [MonthlyRow], currency: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Timeline")
                .font(.headline)

            if rows.isEmpty {
                Text("No expense data yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows) { row in
                    HStack {
                        Text(row.label)
                        Spacer()
                        Text(row.total, format: .currency(code: currency))
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                }
            }
        }
        .themedCard()
    }

    private func monthlyRows() -> [MonthlyRow] {
        let cal = Calendar.current
        let start = cal.startOfMonth(for: Date(timeIntervalSince1970: purchaseDateTimestamp))
        let end = cal.startOfMonth(for: Date())

        var rows: [MonthlyRow] = []
        var cursor = start
        while cursor <= end {
            let next = cal.date(byAdding: .month, value: 1, to: cursor) ?? cursor
            let total = entriesStore.entries
                .filter { $0.date >= cursor && $0.date < next }
                .reduce(0) { $0 + $1.amount }
            let label = cursor.formatted(.dateTime.year().month())
            rows.append(MonthlyRow(id: cursor, label: label, total: total))
            cursor = next
        }
        return rows.reversed()
    }
}

private struct MonthlyRow: Identifiable {
    let id: Date
    let label: String
    let total: Double
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
