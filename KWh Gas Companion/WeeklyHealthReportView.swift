import SwiftUI

@MainActor
struct WeeklyHealthReportView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var adsStore = AdsEntitlementStore.shared

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let report = WeeklyHealthReport.build(from: entriesStore.energyEntries())

        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard(report)
                statsCard(report)
                highlightsCard(report)

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Weekly Health")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
    }

    private func headerCard(_ report: WeeklyHealthReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last 7 days summary")
                .font(.headline)
            Text(report.totalSessions == 0 ? "No charging sessions logged." : "Review your best and most expensive sessions.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private func statsCard(_ report: WeeklyHealthReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Totals")
                    .font(.headline)
                Spacer()
            }
            HStack {
                stat("Sessions", "\(report.totalSessions)")
                stat("Energy", String(format: "%.1f kWh", report.totalKWh))
            }
            HStack {
                stat("Cost", report.totalCost.formatted(.currency(code: report.currencyCode)))
                stat("Avg $/kWh", report.avgCostPerKWh?.formatted(.currency(code: report.currencyCode)) ?? "—")
            }
        }
        .themedCard()
    }

    private func highlightsCard(_ report: WeeklyHealthReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Highlights")
                .font(.headline)

            if let best = report.bestSession {
                highlightRow("Best value", best)
            } else {
                Text("No sessions to highlight.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let worst = report.worstSession {
                highlightRow("Most expensive", worst)
            }

            if let note = report.highlight {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .themedCard()
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func highlightRow(_ title: String, _ session: WeeklyHealthReport.SessionHighlight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(session.title)
                    .font(.subheadline.weight(.semibold))
                Text(session.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(session.trailing)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
        }
    }
}

struct WeeklyHealthReport: Hashable, Sendable {
    struct SessionHighlight: Hashable, Sendable {
        let title: String
        let subtitle: String
        let trailing: String
    }

    let totalSessions: Int
    let totalKWh: Double
    let totalCost: Double
    let avgCostPerKWh: Double?
    let currencyCode: String
    let bestSession: SessionHighlight?
    let worstSession: SessionHighlight?
    let highlight: String?

    static func build(from entries: [ExpenseEntry]) -> WeeklyHealthReport {
        let currency = Locale.current.currency?.identifier ?? "USD"
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
        let recent = entries.filter { $0.date >= start && $0.date <= end }

        let totalSessions = recent.count
        let totalKWh = recent.compactMap { $0.energyAddedKWh }.reduce(0, +)
        let totalCost = recent.reduce(0) { $0 + $1.amount }
        let avgCostPerKWh = totalKWh > 0 ? totalCost / totalKWh : nil

        let best = recent
            .compactMap { entry -> (ExpenseEntry, Double)? in
                guard let cpk = entry.costPerKWh, cpk > 0 else { return nil }
                return (entry, cpk)
            }
            .min { $0.1 < $1.1 }

        let worst = recent
            .compactMap { entry -> (ExpenseEntry, Double)? in
                guard let cpk = entry.costPerKWh, cpk > 0 else { return nil }
                return (entry, cpk)
            }
            .max { $0.1 < $1.1 }

        let bestSession = best.map { entry, cpk in
            SessionHighlight(
                title: entry.location ?? entry.charging?.siteName ?? "Charging session",
                subtitle: entry.date.formatted(date: .abbreviated, time: .omitted),
                trailing: cpk.formatted(.currency(code: currency))
            )
        }

        let worstSession = worst.map { entry, cpk in
            SessionHighlight(
                title: entry.location ?? entry.charging?.siteName ?? "Charging session",
                subtitle: entry.date.formatted(date: .abbreviated, time: .omitted),
                trailing: cpk.formatted(.currency(code: currency))
            )
        }

        let highlight: String?
        if let avg = avgCostPerKWh, avg > 0.35 {
            highlight = "Average cost is elevated this week. Consider shifting more charging to off‑peak windows."
        } else if totalSessions > 0 {
            highlight = "Charging costs are stable this week."
        } else {
            highlight = nil
        }

        return WeeklyHealthReport(
            totalSessions: totalSessions,
            totalKWh: totalKWh,
            totalCost: totalCost,
            avgCostPerKWh: avgCostPerKWh,
            currencyCode: currency,
            bestSession: bestSession,
            worstSession: worstSession,
            highlight: highlight
        )
    }
}
