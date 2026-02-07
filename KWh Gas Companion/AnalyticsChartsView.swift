//
//  AnalyticsChartsView.swift
//  KWh Gas Companion
//
//  Self-contained: no TeslaFiSessionStore required.
//  Uses EntriesStore energy-like entries (amount/energyKWh/kWh/energy) to chart
//  monthly kWh & cost, with optional SMA line.
//  iOS 16+: Swift Charts. Compile-safe across model variants.
//

import SwiftUI
import Charts
import Foundation

@MainActor
struct AnalyticsChartsView: View {
    // Pull from your app’s EntriesStore (already injected at the root)
    @EnvironmentObject private var entriesStore: EntriesStore

    enum Metric: String, CaseIterable, Identifiable {
        case energy, cost
        var id: String { rawValue }
        var title: String { self == .energy ? "kWh" : "Cost" }
    }

    @State private var metric: Metric = .energy
    @State private var monthsBack: Int = 12
    @State private var showSMA = true
    @State private var smaWindow = 3

    @AppStorage("analytics.target.kwh") private var monthlyTargetKWh: Double = 0

    @State private var series: [MonthlySeries.Point] = []

    private var currencyCode: String {
        if #available(iOS 16.0, *) { return Locale.current.currency?.identifier ?? "USD" }
        return (Locale.current as NSLocale).currencyCode ?? "USD"
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Text("Charging Analytics").font(.title2).bold()
                Spacer()
                Picker("Metric", selection: $metric) {
                    Text("kWh").tag(Metric.energy)
                    Text("Cost").tag(Metric.cost)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            // Chart
            if series.isEmpty {
                VStack(spacing: 6) {
                    Text("No charging data yet").font(.headline)
                    Text("Add charging entries (or import CSV) to see monthly \(metric.title.lowercased()) trends.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 240)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                Chart {
                    // Bars
                    ForEach(series) { p in
                        BarMark(
                            x: .value("Month", p.month, unit: .month),
                            y: .value(metric.title, metric == .energy ? p.kWh : p.cost)
                        )
                    }
                    // SMA (optional)
                    if showSMA {
                        ForEach(smaPoints(), id: \.month) { s in
                            LineMark(
                                x: .value("Month", s.month, unit: .month),
                                y: .value("SMA", s.value)
                            )
                            .interpolationMethod(.monotone)
                        }
                    }
                    // Target (energy only)
                    if metric == .energy, monthlyTargetKWh > 0 {
                        RuleMark(y: .value("Target", monthlyTargetKWh))
                    }
                }
                .frame(minHeight: 280)
                .chartYAxisLabel(metric == .energy ? "kWh" : currencyCode)

                // Totals footer
                HStack {
                    Text("Months shown: \(monthsBack)")
                    Spacer()
                    Text("Total \(metric.title): \(formattedTotal())")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            // Controls
            VStack(spacing: 8) {
                HStack {
                    Stepper("\(monthsBack) months", value: $monthsBack, in: 3...36)
                    Spacer()
                    #if swift(>=5.9)
                    Toggle("Show \(smaWindow)-mo moving average", isOn: $showSMA).toggleStyle(.switch)
                    #else
                    Toggle("Show \(smaWindow)-mo moving average", isOn: $showSMA).toggleStyle(SwitchToggleStyle())
                    #endif
                }
                HStack {
                    Text("SMA window")
                    Spacer()
                    Stepper("SMA: \(smaWindow)", value: $smaWindow, in: 2...12)
                        .labelsHidden()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle("Analytics")
        .onAppear { rebuildSeries() }
        .onChange(of: monthsBack) { _, _ in rebuildSeries() }
        .onChange(of: entriesStore.entries) { _, _ in rebuildSeries() }
        .onChange(of: metric) { _, _ in /* only affects footer text */ }
        .onChange(of: showSMA) { _, _ in /* toggles overlay */ }
        .onChange(of: smaWindow) { _, _ in /* recompute overlay line */ }
    }

    // MARK: - Helpers

    private func rebuildSeries() {
        series = MonthlySeries.build(from: entriesStore.entries, monthsBack: monthsBack)
        smaWindow = min(max(smaWindow, 2), max(2, monthsBack))
    }

    private func formattedTotal() -> String {
        switch metric {
        case .energy:
            let sum = entriesStore.entries
                .filter { $0._isEnergyLike }
                .reduce(0.0) { $0 + $1._energyKWhIfAny }
            return String(format: "%.1f", sum)
        case .cost:
            let sum = entriesStore.entries
                .filter { $0._isEnergyLike }
                .reduce(0.0) { $0 + $1._amount }
            return currencyString(sum)
        }
    }

    private func smaPoints() -> [(month: Date, value: Double)] {
        guard showSMA else { return [] }
        let transform: (MonthlySeries.Point) -> Double = (metric == .energy) ? { $0.kWh } : { $0.cost }
        return MonthlySeries.sma(series, window: smaWindow, transform: transform)
    }
}

// MARK: - Monthly aggregation from EntriesStore

struct MonthlySeries {
    struct Point: Identifiable, Hashable {
        let month: Date   // normalized to start of month
        let kWh: Double
        let cost: Double
        var id: Date { month }
    }

    static func build(from entries: [ExpenseEntry], monthsBack: Int) -> [Point] {
        guard monthsBack > 0 else { return [] }
        let cal = Calendar(identifier: .gregorian)

        // Seed last N months so the x-axis is continuous
        var months: [Date] = []
        if let end = cal.dateInterval(of: .month, for: Date())?.start {
            for i in (0..<monthsBack).reversed() {
                if let m = cal.date(byAdding: .month, value: -i, to: end) { months.append(m) }
            }
        }

        // Sum energy-like entries by month
        var bucket: [Date: (kWh: Double, cost: Double)] = [:]
        for e in entries where e._isEnergyLike {
            guard let m = cal.dateInterval(of: .month, for: e._date)?.start else { continue }
            let added = e._energyKWhIfAny
            let cost  = e._amount
            let prev  = bucket[m] ?? (0.0, 0.0)
            bucket[m] = (prev.kWh + added, prev.cost + cost)
        }

        // Emit in seeded order (missing months -> zeros)
        return months.map { m in
            let totals = bucket[m] ?? (0.0, 0.0)
            return Point(month: m, kWh: totals.kWh, cost: totals.cost)
        }
    }

    static func sma(_ points: [Point], window: Int, transform: (Point) -> Double) -> [(month: Date, value: Double)] {
        guard window > 1, !points.isEmpty else { return [] }
        var result: [(Date, Double)] = []
        var running: Double = 0
        var q: [Double] = []
        for p in points {
            let v = transform(p)
            q.append(v)
            running += v
            if q.count > window { running -= q.removeFirst() }
            result.append((p.month, running / Double(q.count)))
        }
        return result
    }
}

// MARK: - Entries bridging (date/amount/energy tolerant)

fileprivate extension ExpenseEntry {
    var _date: Date {
        if let d: Date = Mirror._get(self, "date") { return d }
        if let s: String = Mirror._get(self, "dateString") {
            let f = ISO8601DateFormatter(); if let d = f.date(from: s) { return d }
        }
        return Date.distantPast
    }
    var _amount: Double {
        if let v: Double = Mirror._get(self, "amount") { return v }
        if let v: Double = Mirror._get(self, "cost") { return v }
        return 0
    }
    var _categoryString: String {
        if let s: String = Mirror._get(self, "category") { return s.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let rep = Mirror._get(self, "category") as (any RawRepresentable)? {
            return String(describing: rep.rawValue)
        }
        return ""
    }
    var _energyKWhIfAny: Double {
        if let k: Double = Mirror._get(self, "energyKWh") { return max(0, k) }
        if let k: Double = Mirror._get(self, "kWh") { return max(0, k) }
        if let k: Double = Mirror._get(self, "energy") { return max(0, k) }
        return 0
    }
    var _isEnergyLike: Bool {
        if let b: Bool = Mirror._get(self, "isEnergy") { return b }
        let c = _categoryString.lowercased()
        if ["energy", "charging", "charge", "supercharger", "dcfc"].contains(where: { c.contains($0) }) { return true }
        if _energyKWhIfAny > 0 { return true }
        return false
    }
}

fileprivate extension Mirror {
    static func _get<T>(_ value: Any, _ label: String) -> T? {
        for child in Mirror(reflecting: value).children {
            if child.label?.lowercased() == label.lowercased() {
                return child.value as? T
            }
        }
        return nil
    }
}

// MARK: - Formatting

private func currencyString(_ amount: Double, code: String? = nil) -> String {
    let nf = NumberFormatter()
    nf.locale = .current
    nf.numberStyle = .currency
    nf.currencyCode = code ?? (Locale.current as NSLocale).currencyCode ?? "USD"
    return nf.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        AnalyticsChartsView()
            .environmentObject(EntriesStore())
    }
}
#endif
