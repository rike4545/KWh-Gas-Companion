import SwiftUI

@MainActor
struct WeeklyCostRollupView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore
    @Environment(\.appThemeBox) private var themeBox

    @AppStorage("weekly.alert.enabled") private var alertsEnabled: Bool = true
    @AppStorage("weekly.alert.threshold") private var alertThreshold: Double = 80

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let stats = WeeklyCostRollup.compute(entries: entriesStore.energyEntries(),
                                             sessions: teslaFiStore.sessions)

        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing) {
                summaryCard(stats)
                deltaCard(stats)
                alertCard(stats)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("Weekly Cost Rollup")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summaryCard(_ stats: WeeklyCostRollup.Stats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This Week")
                .font(.headline)
            HStack {
                statBlock(title: "Cost", value: stats.thisWeekCost.formatted(.currency(code: stats.currency)))
                statBlock(title: "Energy", value: String(format: "%.1f kWh", stats.thisWeekKWh))
                statBlock(title: "Sessions", value: "\(stats.thisWeekCount)")
            }
        }
        .themedCard()
    }

    private func deltaCard(_ stats: WeeklyCostRollup.Stats) -> some View {
        let delta = stats.thisWeekCost - stats.lastWeekCost
        let pct = stats.lastWeekCost > 0 ? (delta / stats.lastWeekCost) : 0
        return VStack(alignment: .leading, spacing: 10) {
            Text("Week over Week")
                .font(.headline)
            HStack {
                Text(delta >= 0 ? "Up" : "Down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(delta >= 0 ? Color.red : Color.green)
                Text(delta.formatted(.currency(code: stats.currency)))
                    .font(.subheadline.weight(.semibold))
                Text(String(format: "(%.0f%%)", abs(pct * 100)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text("Last week: \(stats.lastWeekCost.formatted(.currency(code: stats.currency)))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private func alertCard(_ stats: WeeklyCostRollup.Stats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Alerts", systemImage: "bell.badge")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $alertsEnabled)
                    .labelsHidden()
            }
            if alertsEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Alert when weekly cost exceeds:")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Slider(value: $alertThreshold, in: 20...250, step: 5)
                    Text(alertThreshold.formatted(.currency(code: stats.currency)))
                        .font(.caption.weight(.semibold))
                }
                if stats.thisWeekCost >= alertThreshold {
                    Text("This week is above your alert threshold.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } else {
                Text("Weekly alerts are disabled.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .themedCard()
    }

    private func statBlock(title: String, value: String) -> some View {
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
}

enum WeeklyCostRollup {
    struct Stats {
        let thisWeekCost: Double
        let thisWeekKWh: Double
        let thisWeekCount: Int
        let lastWeekCost: Double
        let currency: String
    }

    static func compute(entries: [ExpenseEntry], sessions: [TeslaFiSession]) -> Stats {
        let currency = Locale.current.currency?.identifier ?? "USD"
        let now = Date()
        let cal = Calendar.current
        let thisWeekStart = cal.date(byAdding: .day, value: -7, to: now) ?? now
        let lastWeekStart = cal.date(byAdding: .day, value: -14, to: now) ?? now

        let entriesThis = entries.filter { $0.date >= thisWeekStart }
        let entriesLast = entries.filter { $0.date < thisWeekStart && $0.date >= lastWeekStart }

        let thisCost = entriesThis.map(\.amount).reduce(0, +)
        let thisKWh = entriesThis.compactMap(\.energyAddedKWh).reduce(0, +)
        let thisCount = entriesThis.count

        let lastCost = entriesLast.map(\.amount).reduce(0, +)

        // If no entries, fall back to TeslaFi costs (if any)
        let fallbackCost: Double
        if thisCount == 0 {
            let tfThis = sessions.filter { $0.startDate >= thisWeekStart }
            fallbackCost = tfThis.compactMap(\.cost).reduce(0, +)
        } else {
            fallbackCost = thisCost
        }

        return Stats(
            thisWeekCost: fallbackCost,
            thisWeekKWh: thisKWh,
            thisWeekCount: thisCount,
            lastWeekCost: lastCost,
            currency: currency
        )
    }
}
