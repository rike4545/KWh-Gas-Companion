import SwiftUI

@MainActor
struct HomeVsPublicSplitView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let stats = SplitStats.build(from: entriesStore.energyEntries())

        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                splitCard(stats)
                tipsCard(stats)
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Home vs Public")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Where your charging happens")
                .font(.headline)
            Text("We categorize sessions by Supercharger/fast‑public vs home/other and estimate the cost split.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private func splitCard(_ stats: SplitStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Cost Split", systemImage: "chart.bar")
                    .font(.headline)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Home")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(stats.homeCost, format: .currency(code: stats.currencyCode))
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Public")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(stats.publicCost, format: .currency(code: stats.currencyCode))
                        .font(.headline)
                }
            }

            GeometryReader { geo in
                let total = max(1, stats.homeCost + stats.publicCost)
                let homeWidth = geo.size.width * CGFloat(stats.homeCost / total)
                HStack(spacing: 0) {
                    Rectangle().fill(theme.accent.opacity(0.85)).frame(width: homeWidth)
                    Rectangle().fill(Color.gray.opacity(scheme == .dark ? 0.35 : 0.2))
                }
                .frame(height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .frame(height: 10)

            HStack {
                Text("Home share")
                Spacer()
                Text("\(Int(stats.homeShare * 100))%")
                    .font(.subheadline.weight(.semibold))
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private func tipsCard(_ stats: SplitStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Savings Tips")
                .font(.headline)
            if stats.publicCost > stats.homeCost {
                Text("Public charging is driving most of your cost. Shifting even 10–20% to home can lower your average rate.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Great mix. Maintain your home‑charging share to keep rates low.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .themedCard()
    }
}

private struct SplitStats {
    let homeCost: Double
    let publicCost: Double
    let homeShare: Double
    let currencyCode: String

    static func build(from entries: [ExpenseEntry]) -> SplitStats {
        let currency = Locale.current.currency?.identifier ?? "USD"
        let home = entries.filter { !isPublic($0) }
        let pub = entries.filter { isPublic($0) }
        let homeCost = home.reduce(0) { $0 + $1.amount }
        let publicCost = pub.reduce(0) { $0 + $1.amount }
        let total = max(1, homeCost + publicCost)
        return SplitStats(
            homeCost: homeCost,
            publicCost: publicCost,
            homeShare: homeCost / total,
            currencyCode: currency
        )
    }

    private static func isPublic(_ entry: ExpenseEntry) -> Bool {
        if entry.charging?.isSupercharger == true { return true }
        if let brand = entry.charging?.fastChargerBrand?.lowercased(), !brand.isEmpty { return true }
        if let site = entry.charging?.siteName?.lowercased() {
            if site.contains("supercharger") || site.contains("dc fast") { return true }
        }
        return false
    }
}
