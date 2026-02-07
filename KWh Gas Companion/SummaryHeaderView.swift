//  SummaryHeaderView.swift
//  KWh Gas Companion
//
//  A lightweight header of summary tiles. Supply values from your view model
//  (no EnvironmentObject access here to keep compile times snappy).

import SwiftUI

struct SummaryHeaderView: View {
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme
    // MARK: Inputs
    var title: String = "This Month"
    var totalKWh: Double?
    var totalSpendUSD: Double?
    var avgCostPerKWh: Double?
    var sessionsCount: Int?
    /// 0...1 (e.g. 0.35 = 35% business)
    var businessUseRatio: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    SummaryMetricTile(
                        title: "Energy",
                        valueText: totalKWh.map { Self.kwhString($0) } ?? "—",
                        systemImage: "bolt.fill"
                    )

                    SummaryMetricTile(
                        title: "Spend",
                        valueText: totalSpendUSD.map { Self.currencyString($0) } ?? "—",
                        systemImage: "dollarsign.circle.fill"
                    )

                    SummaryMetricTile(
                        title: "Avg $/kWh",
                        valueText: avgCostPerKWh.map { Self.currencyString($0) } ?? "—",
                        systemImage: "chart.bar.xaxis"
                    )

                    SummaryMetricTile(
                        title: "Sessions",
                        valueText: sessionsCount.map { "\($0)" } ?? "—",
                        systemImage: "battery.100"
                    )

                    SummaryMetricTile(
                        title: "Business",
                        valueText: businessUseRatio.map { Self.percentString($0) } ?? "—",
                        systemImage: "briefcase.fill"
                    )
                }
                .padding(.vertical, 4)
            }
        }
        .themedCard(prominent: true)
    }
}

// MARK: - Tile

private struct SummaryMetricTile: View {
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme

    let title: String
    let valueText: String
    let systemImage: String

    var body: some View {
        let theme = themeBox.base
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .imageScale(.large)
                .foregroundStyle(theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(valueText)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.cardBackground.opacity(scheme == .dark ? 0.90 : 1.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(theme.separator.opacity(scheme == .dark ? 0.60 : 0.35), lineWidth: 1)
                )
        )
    }
}

// MARK: - Formatting

private extension SummaryHeaderView {
    static func currencyString(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        return fmt.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }

    static func kwhString(_ kwh: Double) -> String {
        String(format: "%.2f kWh", kwh)
    }

    /// Expects 0...1 (e.g. 0.34 -> "34%")
    static func percentString(_ ratio: Double) -> String {
        let pct = max(0, min(1, ratio)) * 100
        if pct.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f%%", pct)
        } else {
            return String(format: "%.1f%%", pct)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        SummaryHeaderView(
            title: "This Month",
            totalKWh: 162.7,
            totalSpendUSD: 48.23,
            avgCostPerKWh: 0.30,
            sessionsCount: 11,
            businessUseRatio: 0.42
        )

        SummaryHeaderView(
            title: "Last 7 Days",
            totalKWh: nil,
            totalSpendUSD: nil,
            avgCostPerKWh: nil,
            sessionsCount: nil,
            businessUseRatio: nil
        )
    }
    .padding()
}
#endif
