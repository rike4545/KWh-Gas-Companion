//
//  CostPerKWhTrendView 2.swift
//  KWh Gas Companion
//
//  Created by Bryan on 8/14/25.
//


//  CostPerKWhTrendView.swift
//  KWh Gas Companion
//
//  Trend view for **$/kWh** over time. Works out‑of‑the‑box with EntriesStore.
//  • Uses entries where `isEnergy == true` and finds a kWh field via reflection
//    (tries: energyKWh, kWh, kwh, chargedKWh, kWhAdded, energy).
//  • Computes per‑entry cost/kWh = amount / kWh.
//  • Lets you filter by time window (3M/6M/12M/All), trim outliers, and set a
//    moving‑average window (days).
//  • Charts raw points + moving average line (Swift Charts).

import SwiftUI
import Charts

struct CostPerKWhTrendView: View {
    // Optional injection for call sites that want a specific list
    private let injectedEntries: [ExpenseEntry]?
    init(entries: [ExpenseEntry]? = nil) { self.injectedEntries = entries }

    @EnvironmentObject private var entriesStore: EntriesStore

    // Controls
    enum RangePick: String, CaseIterable, Identifiable { case m3 = "3M", m6 = "6M", m12 = "12M", all = "All"; var id: String { rawValue } }
    @State private var rangePick: RangePick = .m6
    @State private var trimOutliers: Bool = false
    @State private var maWindowDays: Int = 30

    // Appearance
    private let bg = Color(uiColor: .systemGroupedBackground)
    private let cardBG = Color(uiColor: .secondarySystemBackground)

    // Data
    private var entries: [ExpenseEntry] { injectedEntries ?? entriesStore.entries }
    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    // Extract energy entries with kWh available
    private var energyPoints: [CPKPoint] {
        entries
            .filter { $0.isEnergy }
            .compactMap { e -> CPKPoint? in
                guard let kwh = extractKWh(e), kwh > 0 else { return nil }
                let cpk = e.amount / kwh
                return CPKPoint(date: e.date, value: cpk)
            }
            .sorted { $0.date < $1.date }
    }

    private var filteredPoints: [CPKPoint] {
        let pts = energyPoints
        guard !pts.isEmpty else { return [] }
        let start = startDate(for: rangePick)
        var windowed = pts.filter { $0.date >= start }
        if trimOutliers, windowed.count >= 8 {
            let (lo, hi) = percentileBounds(values: windowed.map { $0.value }, low: 0.05, high: 0.95)
            windowed = windowed.filter { $0.value >= lo && $0.value <= hi }
        }
        return windowed
    }

    private var movingAvg: [CPKPoint] {
        let pts = filteredPoints
        guard !pts.isEmpty else { return [] }
        let days = max(maWindowDays, 1)
        var result: [CPKPoint] = []
        var j = 0
        var sum: Double = 0
        var buffer: [(Date, Double)] = []
        for i in 0..<pts.count {
            let di = pts[i]
            buffer.append((di.date, di.value))
            sum += di.value
            // Drop old points beyond window
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: di.date) ?? di.date
            while j < buffer.count, buffer[j].0 < cutoff {
                sum -= buffer[j].1
                j += 1
            }
            let count = Double(buffer.count - j)
            if count > 0 { result.append(CPKPoint(date: di.date, value: sum / count)) }
        }
        return result
    }

    // Summary
    private var stats: (min: Double, max: Double, last: Double, avg: Double)? {
        let pts = filteredPoints
        guard !pts.isEmpty else { return nil }
        let vals = pts.map { $0.value }
        let minV = vals.min() ?? 0
        let maxV = vals.max() ?? 0
        let last = pts.last!.value
        let avg = vals.reduce(0, +) / Double(vals.count)
        return (minV, maxV, last, avg)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if filteredPoints.isEmpty {
                    EmptyStateCard(title: "No kWh data found",
                                   message: "Add charging entries with a kWh field to plot $/kWh. Supported property names: energyKWh, kWh, kwh, chargedKWh, kWhAdded, energy.")
                } else {
                    metricsRow
                    controls
                    trendChart
                }
            }
            .padding(16)
        }
        .background(bg.ignoresSafeArea())
        .navigationTitle("Cost per kWh Trend")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cost per kWh Trend").font(.title.bold())
            Text("Track your paid $/kWh over time.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricsRow: some View {
        let s = stats
        return HStack(spacing: 12) {
            MetricPill(title: "Latest", value: s.map { currencyShort($0.last) } ?? "—", icon: "bolt.fill")
            MetricPill(title: "Average", value: s.map { currencyShort($0.avg) } ?? "—", icon: "line.3.horizontal.decrease.circle")
            MetricPill(title: "Range", value: s.map { "\(currencyShort($0.min))–\(currencyShort($0.max))" } ?? "—", icon: "arrow.left.and.right.circle")
        }
    }

    private var controls: some View {
        Card(title: "Filters", subtitle: "Time window, smoothing, outliers") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Range").foregroundStyle(.secondary)
                    Picker("Range", selection: $rangePick) {
                        ForEach(RangePick.allCases) { rp in Text(rp.rawValue).tag(rp) }
                    }
                    .pickerStyle(.segmented)
                }
                GridRow {
                    Text("MA Window").foregroundStyle(.secondary)
                    Stepper(value: $maWindowDays, in: 3...90, step: 1) { Text("\(maWindowDays) days") }
                }
                GridRow {
                    Toggle(isOn: $trimOutliers) { Text("Trim outliers (5–95th %)") }
                }
            }
            .font(.footnote)
        }
    }

    private var trendChart: some View {
        Card(title: "$/kWh over time", subtitle: "Points + moving average") {
            Chart {
                ForEach(filteredPoints) { p in
                    PointMark(
                        x: .value("Date", p.date),
                        y: .value("$/kWh", p.value)
                    )
                }
                ForEach(movingAvg) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("MA", p.value)
                    )
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    if let d = v.as(Double.self) { AxisValueLabel(currencyShort(d)) }
                }
            }
            .frame(height: 260)
        }
    }

    // MARK: - Helpers
    private func currencyShort(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = currencyCode
        f.maximumFractionDigits = v < 1 ? 3 : 2
        return f.string(from: NSNumber(value: v)) ?? "$0.00"
    }

    private func startDate(for pick: RangePick) -> Date {
        let cal = Calendar.current
        switch pick {
        case .m3:  return cal.date(byAdding: .month, value: -3, to: Date()) ?? Date.distantPast
        case .m6:  return cal.date(byAdding: .month, value: -6, to: Date()) ?? Date.distantPast
        case .m12: return cal.date(byAdding: .year, value: -1, to: Date()) ?? Date.distantPast
        case .all: return Date.distantPast
        }
    }

    private func extractKWh(_ entry: ExpenseEntry) -> Double? {
        let keys = ["energyKWh", "kWh", "kwh", "chargedKWh", "kWhAdded", "energy"]
        let m = Mirror(reflecting: entry)
        for child in m.children {
            if let label = child.label, keys.contains(label) {
                if let v = child.value as? Double { return v }
                if let opt = child.value as? Optional<Double> { return opt }
            }
        }
        return nil
    }

    private func percentileBounds(values: [Double], low: Double, high: Double) -> (Double, Double) {
        let xs = values.sorted()
        func q(_ p: Double) -> Double {
            if xs.isEmpty { return 0 }
            let idx = min(max(Int(Double(xs.count - 1) * p), 0), xs.count - 1)
            return xs[idx]
            }
        return (q(low), q(high))
    }
}

// MARK: - Types & UI helpers
struct CPKPoint: Identifiable { let id = UUID(); let date: Date; let value: Double }

private struct Card<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.secondary) }
            }
            content
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(uiColor: .separator).opacity(0.25), lineWidth: 1))
    }
}

private struct MetricPill: View {
    let title: String, value: String, icon: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(uiColor: .secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(uiColor: .separator).opacity(0.25), lineWidth: 1))
    }
}

private struct EmptyStateCard: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle").imageScale(.large).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .tertiarySystemBackground)))
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CostPerKWhTrendView()
            .environmentObject(EntriesStore())
    }
}
#endif
