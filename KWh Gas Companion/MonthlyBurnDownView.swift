import SwiftUI

@MainActor
struct MonthlyBurnDownView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @Environment(\.appThemeBox) private var themeBox

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String =
        (Locale.current.currency?.identifier ?? "USD")
    @AppStorage("monthlyBudgetLimit") private var monthlyBudgetLimit: Double = 0

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let stats = MonthlyBurnDown.compute(entries: entriesStore.entries, budget: monthlyBudgetLimit)
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing) {
                header(stats)
                projectionCard(stats)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("Monthly Burn‑Down")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ stats: MonthlyBurnDown.Stats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Month to date")
                .font(.headline)
            Text("Spent \(stats.spent.formatted(.currency(code: defaultCurrencyCode))) across \(stats.count) entries.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private func projectionCard(_ stats: MonthlyBurnDown.Stats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Projected total")
                .font(.headline)
            Text(stats.projected.formatted(.currency(code: defaultCurrencyCode)))
                .font(.title3.weight(.semibold))
            if monthlyBudgetLimit > 0 {
                let remaining = monthlyBudgetLimit - stats.projected
                Text(remaining >= 0 ? "On track (buffer \(remaining.formatted(.currency(code: defaultCurrencyCode))))"
                                   : "Over budget by \(abs(remaining).formatted(.currency(code: defaultCurrencyCode)))")
                    .font(.footnote)
                    .foregroundStyle(remaining >= 0 ? Color.green : Color.red)
            } else {
                Text("Set a monthly budget in Settings to compare.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .themedCard()
    }
}

enum MonthlyBurnDown {
    struct Stats {
        let spent: Double
        let count: Int
        let projected: Double
    }

    static func compute(entries: [ExpenseEntry], budget: Double) -> Stats {
        let now = Date()
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let daysElapsed = max(1, cal.dateComponents([.day], from: monthStart, to: now).day ?? 1)
        let daysInMonth = cal.range(of: .day, in: .month, for: now)?.count ?? 30

        let monthEntries = entries.filter { $0.date >= monthStart }
        let spent = monthEntries.reduce(0) { $0 + $1.amount }
        let projected = spent * (Double(daysInMonth) / Double(daysElapsed))
        return Stats(spent: spent, count: monthEntries.count, projected: projected)
    }
}
