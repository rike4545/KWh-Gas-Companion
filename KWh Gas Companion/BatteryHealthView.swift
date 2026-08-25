// BatteryHealthView.swift
// KWh Gas Companion
//
// Estimates battery capacity + health from charge logs,
// using energyAddedKWh and start/end state of charge.
// Shows summary tiles and a simple trend chart.
//
// Assumptions:
// - ExpenseEntry has: date, energyAddedKWh(Double?), stateOfCharge(Double?),
//   notes/chargeType(String?) where "Supercharger" hints DCFC.
// - EntriesStore exposes public var entries: [ExpenseEntry].
//

import SwiftUI
#if canImport(Charts)
import Charts
#endif

// MARK: - Percent formatting helpers

private let pct0: FloatingPointFormatStyle<Double>.Percent =
    .percent.precision(.fractionLength(0...0))

private let pct1: FloatingPointFormatStyle<Double>.Percent =
    .percent.precision(.fractionLength(0...1))

@inline(__always)
private func asPct(_ unitValue: Double, oneDecimal: Bool = false) -> String {
    unitValue.formatted(oneDecimal ? pct1 : pct0) // expects 0.0...1.0
}

@inline(__always)
private func asPctFrom100(_ percentValue: Double, oneDecimal: Bool = false) -> String {
    asPct(percentValue / 100.0, oneDecimal: oneDecimal)
}

// MARK: - View

struct BatteryHealthView: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var entriesStore: EntriesStore

    // Tuning knobs
    private let minDeltaSOC: Double = 5.0        // ignore tiny partials (<5% delta)
    private let maxDeltaSOC: Double = 85.0       // ignore weird >85% jumps
    private let recentDays: TimeInterval = 90 * 24 * 3600

    // Derived data
    private var capPoints: [CapPoint] {
        let items = entriesStore.entries           // <— adjust if your store uses a different name
        return Self.estimateCapacityPoints(
            from: items,
            minDeltaSOC: minDeltaSOC,
            maxDeltaSOC: maxDeltaSOC
        )
    }

    private var baselineCapacityKWh: Double? {
        Self.estimateBaseline(from: capPoints)
    }

    private var currentHealth: Double? {
        guard let last = capPoints.sorted(by: { $0.date < $1.date }).last,
              let base = baselineCapacityKWh,
              base > 0
        else { return nil }
        return min(max(last.capacityKWh / base, 0.0), 2.0) // clamp to [0, 200%] just in case
    }

    private var recentHealthAvg: Double? {
        guard let base = baselineCapacityKWh, base > 0 else { return nil }
        let cutoff = Date().addingTimeInterval(-recentDays)
        let recent = capPoints.filter { $0.date >= cutoff }
        guard !recent.isEmpty else { return nil }
        let avgCap = recent.map(\.capacityKWh).reduce(0, +) / Double(recent.count)
        return min(max(avgCap / base, 0.0), 2.0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if capPoints.count >= 2, let base = baselineCapacityKWh {
                    tiles(base: base)
                    chart(points: capPoints, base: base)
                    tips
                } else {
                    emptyState
                }
            }
            .padding()
        }
        .navigationTitle("Battery Health")
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Battery Health (Estimated)")
                .font(.title2).bold()
            Text("Derived from charge logs using energy added and SOC change.")
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
    }

    @ViewBuilder
    private func tiles(base: Double) -> some View {
        let lastCap = capPoints.sorted(by: { $0.date < $1.date }).last?.capacityKWh
        let lastHealth = (lastCap != nil && base > 0) ? lastCap! / base : nil

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            Tile(
                title: "Current health",
                value: lastHealth.map { asPct($0, oneDecimal: true) } ?? "—",
                caption: "vs. baseline"
            )
            Tile(
                title: "Recent avg (90d)",
                value: recentHealthAvg.map { asPct($0, oneDecimal: true) } ?? "—",
                caption: "smoothed"
            )
            Tile(
                title: "Baseline cap",
                value: base > 0 ? "\(String(format: "%.1f", base)) kWh" : "—",
                caption: "top-quartile"
            )
            Tile(
                title: "Samples",
                value: "\(capPoints.count)",
                caption: "usable charges"
            )
        }
    }

    @ViewBuilder
    private func chart(points: [CapPoint], base: Double) -> some View {
        #if canImport(Charts)
        let sorted = points.sorted { $0.date < $1.date }
        Chart {
            ForEach(sorted) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Capacity (kWh)", p.capacityKWh)
                )
                .interpolationMethod(.monotone)
            }
            RuleMark(y: .value("Baseline", base))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(.secondary)
                .annotation(position: .topTrailing) {
                    Text("Baseline \(String(format: "%.1f", base)) kWh")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
        }
        .frame(height: 260)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month().year(), centered: false)
            }
        }
        .chartYAxisLabel("Estimated Capacity (kWh)")
        .kwhInteractiveDataViz()
        #else
        VStack(alignment: .leading, spacing: 6) {
            Text("Trend").font(.headline)
            Text("Charts require iOS 16.0+. Showing last 5 points:")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(points.sorted { $0.date > $1.date }.prefix(5)) { p in
                HStack {
                    Text(p.date, style: .date)
                    Spacer()
                    Text("\(String(format: "%.2f", p.capacityKWh)) kWh")
                        .monospacedDigit()
                }
                .font(.subheadline)
            }
        }
        #endif
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes & Tips").font(.headline)
            Text("• Best accuracy comes from charges with larger SOC deltas (≥ 10–15%).")
            Text("• Baseline is computed as the average of the upper quartile of capacity estimates.")
            Text("• If you know your pack’s nominal size, you can compare directly to the baseline shown here.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not enough data")
                .font(.headline)
            Text("We need at least two charge logs with energy added (kWh) and a measurable SOC change.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }
}

// MARK: - Tile

private struct Tile: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.footnote).foregroundStyle(.secondary)
            Text(value)
                .font(.title2).bold()
                .monospacedDigit()
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Model used by the view

struct CapPoint: Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var capacityKWh: Double
}

// MARK: - Estimation logic

extension BatteryHealthView {
    /// Build capacity points from entries. Capacity ≈ energyAdded / (ΔSOC/100).
    static func estimateCapacityPoints(
        from entries: [ExpenseEntry],
        minDeltaSOC: Double,
        maxDeltaSOC: Double
    ) -> [CapPoint] {

        // We need entries that represent a charge with a before/after SOC and energy
        // Many logs store only one SOC value; we’ll try to infer ΔSOC from pairs on the same day if needed.
        // But first: direct entries that *already* encode a delta via two fields is uncommon; so primary path:
        // Group entries by (calendar day) and add them up.

        let cal = Calendar.current
        let grouped = Dictionary(grouping: entries.filter { ($0.energyAddedKWh ?? 0) > 0 }) {
            cal.startOfDay(for: $0.date)
        }

        var out: [CapPoint] = []
        out.reserveCapacity(grouped.count)

        for (day, items) in grouped {
            // Prefer the widest SOC span within that day
            let socs = items.compactMap { $0.stateOfCharge }
            let energySum = items.compactMap { $0.energyAddedKWh }.reduce(0, +)

            var deltaSOC: Double?
            if socs.count >= 2 {
                if let minSOC = socs.min(), let maxSOC = socs.max() {
                    deltaSOC = maxSOC - minSOC
                }
            }

            // If we only have one SOC value, fall back to notes/chargeType hints (skip—unknown delta)
            guard let dSOC = deltaSOC, dSOC > 0 else { continue }
            if dSOC < minDeltaSOC || dSOC > maxDeltaSOC { continue }
            guard energySum > 0 else { continue }

            let capacity = energySum / (dSOC / 100.0)
            if capacity.isFinite && capacity > 0 {
                out.append(CapPoint(date: day, capacityKWh: capacity))
            }
        }

        return out.sorted { $0.date < $1.date }
    }

    /// Estimate baseline as the average of the upper quartile (to reduce noise from partials/cold packs).
    static func estimateBaseline(from points: [CapPoint]) -> Double? {
        guard !points.isEmpty else { return nil }
        let sorted = points.map(\.capacityKWh).sorted()
        guard let qIdx = quantileIndex(sorted.count, q: 0.75) else {
            // Fallback: mean of top 3 or max if fewer
            let top = Array(sorted.suffix(3))
            if top.isEmpty { return sorted.max() }
            let avg = top.reduce(0, +) / Double(top.count)
            return avg.isFinite ? avg : sorted.max()
        }
        let upper = Array(sorted[qIdx...])
        guard !upper.isEmpty else { return sorted.max() }
        let avg = upper.reduce(0, +) / Double(upper.count)
        return avg.isFinite ? avg : sorted.max()
    }

    private static func quantileIndex(_ n: Int, q: Double) -> Int? {
        guard n > 0 else { return nil }
        let clampedQ = min(max(q, 0.0), 1.0)
        let idx = Int(Double(n - 1) * clampedQ)
        return min(max(idx, 0), n - 1)
    }
}

// MARK: - Preview

#if DEBUG
struct BatteryHealthView_Previews: PreviewProvider {
    static var previews: some View {
        let store = EntriesStore()
        // If your EntriesStore doesn’t preload mock data, you can inject a few:
        // store.entries = mockEntries()

        return NavigationStack {
            BatteryHealthView().environmentObject(store)
        }
    }

    static func mockEntries() -> [ExpenseEntry] {
        var out: [ExpenseEntry] = []
        let now = Date()
        for i in 0..<12 {
            let day = Calendar.current.date(byAdding: .day, value: -i * 10, to: now)!
            let kwh = 20.0 + Double.random(in: -2...2)
            let start: Double = 20
            let end: Double = 80
            out.append(ExpenseEntry(
                date: day,
                amount: kwh * 0.3,
                category: "Charging",
                energyKWh: kwh,
                odometer: 10_000 + Double(i) * 500,
                location: "Home",
                notes: nil,
                vehicleName: "Model 3",
                stateOfCharge: i % 2 == 0 ? end : start, // mock two SOCs per day in real data
                chargeType: (i % 3 == 0) ? "Supercharger" : "Home",
                isBusiness: false
            ))
        }
        return out
    }
}
#endif
