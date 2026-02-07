import SwiftUI

/// Compact KPI grid used on analytics screens.
/// Provide a `Snapshot` with your already-computed metrics.
struct AnalyticsTilesSection: View {
    let snapshot: Snapshot
    var onTileTap: ((Tile) -> Void)? = nil

    // MARK: - Layout

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 12, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = snapshot.title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(makeTiles()) { tile in
                    TileView(tile: tile)
                        .onTapGesture { onTileTap?(tile) }
                        .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.vertical, 8)
        .animation(.default, value: snapshot)
    }
}

// MARK: - Snapshot (input model)

extension AnalyticsTilesSection {
    /// Minimal, unopinionated container for analytics values.
    struct Snapshot: Equatable, Sendable {
        // Optional section title (shown above the grid)
        var title: String? = nil
        // Totals
        var totalSpend: Double?            // currency
        var totalKWh: Double?              // kWh
        var totalMiles: Double?            // miles
        var sessionsCount: Int?            // number of charge sessions

        // Rates / averages
        var avgCostPerKWh: Double?         // currency/kWh
        var avgCostPerMile: Double?        // currency/mile
        var avgWhPerMile: Double?          // Wh/mile

        // Shares (0…1)
        var homeShare: Double?             // %
        var fastShare: Double?             // %

        // Environment
        var co2SavedKg: Double?            // kg

        // Battery
        var batteryHealthPercent: Double?  // 0…100

        // Date range or hint to show on each tile (optional)
        var periodLabel: String? = nil
    }
}

// MARK: - Tile building

private extension AnalyticsTilesSection {
    func makeTiles() -> [Tile] {
        var tiles: [Tile] = []

        tiles.append(.metric(
            id: "spend",
            title: "Total Spend",
            value: snapshot.totalSpend.map { $0.asCurrency() } ?? "—",
            caption: snapshot.periodLabel
        ))

        tiles.append(.metric(
            id: "kwh",
            title: "Energy Used",
            value: snapshot.totalKWh.map { $0.asKWh() } ?? "—",
            caption: snapshot.periodLabel
        ))

        tiles.append(.metric(
            id: "miles",
            title: "Miles Driven",
            value: snapshot.totalMiles.map { $0.asNumber(0) + " mi" } ?? "—",
            caption: snapshot.periodLabel
        ))

        tiles.append(.metric(
            id: "c_kwh",
            title: "Avg Cost / kWh",
            value: snapshot.avgCostPerKWh.map { $0.asCurrency() + "/kWh" } ?? "—",
            caption: nil
        ))

        tiles.append(.metric(
            id: "c_mile",
            title: "Avg Cost / Mile",
            value: snapshot.avgCostPerMile.map { $0.asCurrency() + "/mi" } ?? "—",
            caption: nil
        ))

        tiles.append(.metric(
            id: "eff",
            title: "Efficiency",
            value: snapshot.avgWhPerMile.map { $0.asNumber(0) + " Wh/mi" } ?? "—",
            caption: nil
        ))

        tiles.append(.metric(
            id: "home_share",
            title: "Home Charging",
            value: snapshot.homeShare.map { $0.asPercent0() } ?? "—",
            caption: nil
        ))

        tiles.append(.metric(
            id: "fast_share",
            title: "Fast Charging",
            value: snapshot.fastShare.map { $0.asPercent0() } ?? "—",
            caption: nil
        ))

        tiles.append(.metric(
            id: "sessions",
            title: "Sessions",
            value: snapshot.sessionsCount.map { "\($0)" } ?? "—",
            caption: snapshot.periodLabel
        ))

        tiles.append(.metric(
            id: "co2",
            title: "CO₂ Avoided",
            value: snapshot.co2SavedKg.map { $0.asNumber(1) + " kg" } ?? "—",
            caption: nil
        ))

        tiles.append(.metric(
            id: "health",
            title: "Battery Health",
            value: snapshot.batteryHealthPercent.map { $0.asNumber(0) + "%" } ?? "—",
            caption: nil
        ))

        return tiles
    }
}

// MARK: - Tile model & view

extension AnalyticsTilesSection {
    struct Tile: Identifiable, Equatable {
        enum Kind: Equatable { case metric }
        let id: String
        let kind: Kind
        let title: String
        let value: String
        let caption: String?

        static func metric(id: String, title: String, value: String, caption: String?) -> Tile {
            .init(id: id, kind: .metric, title: title, value: value, caption: caption)
        }
    }
}

private struct TileView: View {
    let tile: AnalyticsTilesSection.Tile

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tile.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(tile.value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            if let c = tile.caption, !c.isEmpty {
                Text(c)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.25))
        )
        .accessibilityLabel("\(tile.title), \(tile.value)" + (tile.caption.map { ", \($0)" } ?? ""))
    }
}

// MARK: - Formatting helpers

private extension Double {
    func asCurrency(locale: Locale = .current) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = locale
        return f.string(from: NSNumber(value: self)) ?? String(format: "%.2f", self)
    }

    func asNumber(_ fractionDigits: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = fractionDigits
        f.maximumFractionDigits = fractionDigits
        return f.string(from: NSNumber(value: self)) ?? String(format: "%.\(fractionDigits)f", self)
    }

    func asPercent0() -> String {
        let p = max(0, min(1, self))
        return (p * 100).asNumber(0) + "%"
    }

    func asKWh() -> String {
        // If it's a whole number, show no decimals; otherwise 1 decimal looks nice.
        let whole = floor(self) == self
        return asNumber(whole ? 0 : 1) + " kWh"
    }
}

// MARK: - Preview

#if DEBUG
struct AnalyticsTilesSection_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            AnalyticsTilesSection(
                snapshot: .init(
                    title: "Last 90 Days",
                    totalSpend: 182.43,
                    totalKWh: 612.7,
                    totalMiles: 1785,
                    sessionsCount: 46,
                    avgCostPerKWh: 0.298,
                    avgCostPerMile: 0.102,
                    avgWhPerMile: 343,
                    homeShare: 0.72,
                    fastShare: 0.28,
                    co2SavedKg: 128.4,
                    batteryHealthPercent: 94,
                    periodLabel: "90d"
                )
            )
            .padding()
        }
        .previewDisplayName("Analytics Tiles")
    }
}
#endif
