import SwiftUI

@MainActor
struct ShareableReportsView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var adsStore = AdsEntitlementStore.shared

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let weekly = WeeklyHealthReport.build(from: entriesStore.energyEntries())
        let totalCost = entriesStore.entries.reduce(0) { $0 + $1.amount }
        let totalKWh = entriesStore.entries.compactMap { $0.energyAddedKWh }.reduce(0, +)
        let currency = Locale.current.currency?.identifier ?? "USD"

        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                reportCard(
                    title: "Weekly Health",
                    subtitle: "Last 7 days",
                    body: weeklyReportText(weekly, currency: currency)
                )
                reportCard(
                    title: "Cost Summary",
                    subtitle: "All time",
                    body: costSummaryText(totalCost: totalCost, totalKWh: totalKWh, currency: currency)
                )
                reportCard(
                    title: "Savings Snapshot",
                    subtitle: "Quick share",
                    body: savingsSnapshotText(weekly, currency: currency)
                )

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Shareable Reports")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Share insights")
                .font(.headline)
            Text("Generate ready‑to‑share summaries.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private func reportCard(title: String, subtitle: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                ShareLink(item: body) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                }
            }
            Text(body)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private func weeklyReportText(_ report: WeeklyHealthReport, currency: String) -> String {
        let cost = report.totalCost.formatted(.currency(code: currency))
        let kwh = String(format: "%.1f", report.totalKWh)
        let avg = report.avgCostPerKWh?.formatted(.currency(code: currency)) ?? "—"
        return "Weekly Health: \(report.totalSessions) sessions · \(kwh) kWh · \(cost) total · Avg \(avg)/kWh"
    }

    private func costSummaryText(totalCost: Double, totalKWh: Double, currency: String) -> String {
        let cost = totalCost.formatted(.currency(code: currency))
        let kwh = String(format: "%.1f", totalKWh)
        return "Cost Summary: \(cost) total · \(kwh) kWh logged"
    }

    private func savingsSnapshotText(_ report: WeeklyHealthReport, currency: String) -> String {
        let avg = report.avgCostPerKWh ?? 0
        let note = avg > 0 ? "Avg \(avg.formatted(.currency(code: currency)))/kWh" : "No charging cost data"
        return "Savings Snapshot: \(note) · \(report.totalSessions) sessions last 7 days"
    }
}
