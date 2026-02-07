//  ForecastBreakdownCard.swift
//  KWh Gas Companion
//
//  A compact breakdown card that shows monthly projections and source mix.
//  - Self-contained. No shared helper type names.
//  - Safe formatting (Double only) with fallbacks for older OS versions.

import SwiftUI

struct ForecastBreakdownCard: View {

    // MARK: - Models (local to avoid collisions)

    struct MonthStat: Identifiable, Hashable {
        var id: UUID = UUID()
        var month: Date                 // first day of month preferred
        var projectedKWh: Double        // kWh projected
        var projectedCost: Double       // currency
    }

    struct SourceShare: Identifiable, Hashable {
        enum Kind: String {
            case home = "Home"
            case supercharger = "Supercharger"
            case work = "Work"
            case publicL2 = "Public L2"
            case other = "Other"
        }
        var id: UUID = UUID()
        /// Value in 0...1
        var kind: Kind
        var share: Double
        /// Optional cost/kWh for annotation
        var avgCostPerKWh: Double?
    }

    // MARK: - Inputs

    var title: String = "Forecast Breakdown"
    var monthly: [MonthStat]
    var mix: [SourceShare]

    // Optional headline metrics
    var totalProjectedKWh: Double?
    var totalProjectedCost: Double?
    var avgCostPerKWh: Double?

    // MARK: - UI

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
            }

            if totalProjectedKWh != nil || totalProjectedCost != nil || avgCostPerKWh != nil {
                FBMetricGrid(
                    totalKWh: totalProjectedKWh,
                    totalCost: totalProjectedCost,
                    avgCostPerKWh: avgCostPerKWh
                )
            }

            if !monthly.isEmpty {
                SectionHeader("By Month")
                VStack(spacing: 8) {
                    ForEach(monthly.sorted(by: { $0.month < $1.month })) { m in
                        FBMonthRow(stat: m)
                    }
                }
            }

            if !mix.isEmpty {
                SectionHeader("By Source")
                VStack(spacing: 8) {
                    ForEach(mix.sorted(by: { $0.share > $1.share })) { s in
                        FBSourceRow(share: s)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06))
        )
    }

    // MARK: - Subviews

    private struct SectionHeader: View {
        var text: String
        init(_ text: String) { self.text = text }
        var body: some View {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    private struct FBMetricGrid: View {
        var totalKWh: Double?
        var totalCost: Double?
        var avgCostPerKWh: Double?

        var body: some View {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                FBMetricTile(
                    title: "Total kWh",
                    valueText: ForecastBreakdownCard.kwhString(totalKWh)
                )
                FBMetricTile(
                    title: "Total Cost",
                    valueText: ForecastBreakdownCard.currencyString(totalCost)
                )
                FBMetricTile(
                    title: "Avg $/kWh",
                    valueText: ForecastBreakdownCard.currencyPerKWhString(avgCostPerKWh)
                )
            }
        }
    }

    private struct FBMetricTile: View {
        var title: String
        var valueText: String

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(valueText)
                    .font(.headline)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.06))
            )
        }
    }

    private struct FBMonthRow: View {
        var stat: MonthStat

        var body: some View {
            HStack(spacing: 12) {
                Text(ForecastBreakdownCard.monthShort(stat.month))
                    .font(.subheadline)
                    .frame(width: 56, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        let width = max(0, min(1, normalizedKWh(stat.projectedKWh))) * geo.size.width
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.gray.opacity(0.15))
                            Capsule().fill(Color.accentColor).frame(width: width)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text(ForecastBreakdownCard.kwhString(stat.projectedKWh))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(ForecastBreakdownCard.currencyString(stat.projectedCost))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        private func normalizedKWh(_ value: Double) -> CGFloat {
            let visualMax = max(100.0, value * 1.2)
            return CGFloat(min(1.0, value / visualMax))
        }
    }

    private struct FBSourceRow: View {
        var share: SourceShare

        var body: some View {
            HStack(spacing: 10) {
                Label(share.kind.rawValue, systemImage: icon(for: share.kind))
                    .labelStyle(.titleAndIcon)
                Spacer()
                if let c = share.avgCostPerKWh {
                    Text(ForecastBreakdownCard.currencyPerKWhString(c))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(ForecastBreakdownCard.percentString(share.share))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
        }

        private func icon(for kind: SourceShare.Kind) -> String {
            switch kind {
            case .home: return "house"
            case .supercharger: return "bolt.car"
            case .work: return "building.2"
            case .publicL2: return "bolt.fill"
            case .other: return "ellipsis"
            }
        }
    }

    // MARK: - Formatting (internal so nested views can access)

    static func currencyString(_ value: Double?) -> String {
        guard let value = value else { return "—" }
        if #available(iOS 15.0, macOS 12.0, *) {
            return value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
        } else {
            let nf = NumberFormatter()
            nf.numberStyle = .currency
            nf.currencyCode = Locale.current.currencyCode ?? "USD"
            return nf.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
        }
    }

    static func currencyPerKWhString(_ value: Double?) -> String {
        guard let value = value else { return "—" }
        return currencyString(value) + "/kWh"
    }

    static func kwhString(_ value: Double?) -> String {
        guard let value = value else { return "—" }
        if #available(iOS 15.0, macOS 12.0, *) {
            return value.formatted(.number.precision(.fractionLength(0...2))) + " kWh"
        } else {
            let nf = NumberFormatter()
            nf.minimumFractionDigits = 0
            nf.maximumFractionDigits = 2
            return (nf.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)) + " kWh"
        }
    }

    static func monthShort(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale.current
        df.setLocalizedDateFormatFromTemplate("MMM")
        return df.string(from: date)
    }

    static func percentString(_ unitValue: Double, fraction: ClosedRange<Int> = 0...0) -> String {
        let clamped = max(0, min(1, unitValue))
        if #available(iOS 15.0, macOS 12.0, *) {
            return clamped.formatted(.percent.precision(.fractionLength(fraction)))
        } else {
            let nf = NumberFormatter()
            nf.numberStyle = .percent
            nf.minimumFractionDigits = fraction.lowerBound
            nf.maximumFractionDigits = fraction.upperBound
            return nf.string(from: NSNumber(value: clamped)) ?? String(format: "%.0f%%", clamped * 100)
        }
    }
}

#if DEBUG
struct ForecastBreakdownCard_Previews: PreviewProvider {
    static var previews: some View {
        let now = Date()
        let base = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now))!
        let months = (0..<6).map { i -> ForecastBreakdownCard.MonthStat in
            let d = Calendar.current.date(byAdding: .month, value: i, to: base)!
            return .init(month: d, projectedKWh: Double.random(in: 120...320), projectedCost: Double.random(in: 20...90))
        }
        let mix: [ForecastBreakdownCard.SourceShare] = [
            .init(kind: .home, share: 0.62, avgCostPerKWh: 0.14),
            .init(kind: .supercharger, share: 0.25, avgCostPerKWh: 0.35),
            .init(kind: .work, share: 0.08, avgCostPerKWh: 0.00),
            .init(kind: .publicL2, share: 0.03, avgCostPerKWh: 0.20),
            .init(kind: .other, share: 0.02, avgCostPerKWh: nil)
        ]
        return Group {
            ForecastBreakdownCard(
                title: "Forecast Breakdown",
                monthly: months,
                mix: mix,
                totalProjectedKWh: months.map(\.projectedKWh).reduce(0,+),
                totalProjectedCost: months.map(\.projectedCost).reduce(0,+),
                avgCostPerKWh: 0.18
            )
            .padding()
            .previewLayout(.sizeThatFits)

            ForecastBreakdownCard(
                title: "Forecast Breakdown",
                monthly: [],
                mix: []
            )
            .padding()
            .previewLayout(.sizeThatFits)
        }
    }
}
#endif
