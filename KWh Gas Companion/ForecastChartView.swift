//  ForecastChartView.swift
//  KWh Gas Companion
//
//  Retooled forecasting view that works out-of-the-box:
//  • Uses EntriesStore to aggregate historical monthly data
//  • Measures: Spend, Sessions, kWh (best-effort via reflection)
//  • Methods: Linear trend or Moving Average (windowed)
//  • Configurable range and forecast horizon
//  • Clean Dashboard-style UI with Cards/Pills (local helpers)
//
//  Requires: Swift Charts (iOS 16+)

import SwiftUI
import Charts

struct ForecastChartView: View {
    @EnvironmentObject private var entriesStore: EntriesStore

    // MARK: Controls
    enum Measure: String, CaseIterable, Identifiable { case spend = "Spend", sessions = "Sessions", kwh = "kWh"; var id: String { rawValue } }
    enum RangePick: String, CaseIterable, Identifiable { case m6 = "6M", m12 = "12M", m24 = "24M", all = "All"; var id: String { rawValue } }
    enum Method: String, CaseIterable, Identifiable { case trend = "Trend", ma = "Moving Avg"; var id: String { rawValue } }

    @State private var measure: Measure = .spend
    @State private var rangePick: RangePick = .m12
    @State private var method: Method = .trend
    @State private var horizonMonths: Int = 6
    @State private var maWindow: Int = 3
    @State private var energyOnly: Bool = true
    @State private var scenarioUpliftPct: Double = 0 // percent lift applied to forecast

    private let bg = Color(uiColor: .systemGroupedBackground)

    // MARK: Derived data
    private var entries: [ExpenseEntry] { entriesStore.entries }

    private var monthRows: [MonthRow] {
        guard !entries.isEmpty else { return [] }
        // Group by month start
        let filtered: [ExpenseEntry] = energyOnly ? entries.filter { $0.isEnergy } : entries
        let grouped = Dictionary(grouping: filtered, by: { monthStart($0.date) })
        var rows: [MonthRow] = []
        for (m, list) in grouped {
            switch measure {
            case .spend:
                let total = list.reduce(0) { $0 + $1.amount }
                rows.append(.init(month: m, value: total))
            case .sessions:
                rows.append(.init(month: m, value: Double(list.count)))
            case .kwh:
                let sumKWh = list.compactMap(extractKWh).reduce(0, +)
                if sumKWh > 0 { rows.append(.init(month: m, value: sumKWh)) }
            }
        }
        return rows.sorted { $0.month < $1.month }
    }

    private var windowedHistory: [MonthRow] {
        guard !monthRows.isEmpty else { return [] }
        let start = startDate(for: rangePick)
        return monthRows.filter { $0.month >= start }
    }

    private var forecast: [MonthRow] {
        guard !windowedHistory.isEmpty else { return [] }
        switch method {
        case .trend:
            return linearForecast(windowedHistory, horizon: horizonMonths)
        case .ma:
            return movingAverageForecast(windowedHistory, horizon: horizonMonths, window: max(maWindow, 1))
        }
    }

    private var combinedSeries: [ChartPoint] {
        // mark history vs forecast distinctly
        let hist = windowedHistory.map { ChartPoint(date: $0.month, value: $0.value, kind: .history) }
        let uplift = 1 + scenarioUpliftPct/100.0
        let f = forecast.map { ChartPoint(date: $0.month, value: $0.value * uplift, kind: .forecast) }
        return hist + f
    }

    // MARK: Body
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                if windowedHistory.count < 2 {
                    EmptyStateCard(title: "Not enough data",
                                   message: "Add more entries to compute a forecast. Try importing CSVs or logging charges.")
                } else {
                    metricsRow
                    controls
                    chartCard
                }
            }
            .padding(16)
        }
        .background(bg.ignoresSafeArea())
        .navigationTitle("Forecast")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Forecast").font(.title.bold())
            Text("Monthly \(measure.rawValue.lowercased()) with \(method.rawValue.lowercased()) model")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricsRow: some View {
        let hist = windowedHistory
        let last = hist.last?.value ?? 0
        let next = (forecast.first?.value ?? 0) * (1 + scenarioUpliftPct/100.0)
        let sum6 = forecast.prefix(6).reduce(0) { $0 + $1.value } * (1 + scenarioUpliftPct/100.0)

        return HStack(spacing: 12) {
            MetricPill(title: "Last Month", value: formatValue(last), icon: "clock")
            MetricPill(title: "Next Month", value: formatValue(next), icon: "chevron.forward.circle")
            MetricPill(title: "6-mo Total", value: formatValue(sum6), icon: "calendar")
        }
    }

    private var controls: some View {
        Card(title: "Controls", subtitle: "Measure, range, method, horizon") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Measure").foregroundStyle(.secondary)
                    Picker("Measure", selection: $measure) {
                        ForEach(Measure.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                GridRow {
                    Text("Energy only").foregroundStyle(.secondary)
                    Toggle("", isOn: $energyOnly).labelsHidden()
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    Text("Range").foregroundStyle(.secondary)
                    Picker("Range", selection: $rangePick) {
                        ForEach(RangePick.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                GridRow {
                    Text("Method").foregroundStyle(.secondary)
                    Picker("Method", selection: $method) {
                        ForEach(Method.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                if method == .ma {
                    GridRow {
                        Text("MA Window").foregroundStyle(.secondary)
                        Stepper(value: $maWindow, in: 2...12, step: 1) { Text("\(maWindow) months") }
                    }
                }
                GridRow {
                    Text("Horizon").foregroundStyle(.secondary)
                    Stepper(value: $horizonMonths, in: 1...24, step: 1) { Text("\(horizonMonths) months") }
                }
                GridRow {
                    Text("Scenario Uplift").foregroundStyle(.secondary)
                    Stepper(value: $scenarioUpliftPct, in: -50...200, step: 1) {
                        Text(String(format: "%+.0f%%", scenarioUpliftPct))
                    }
                }
            }
            .font(.footnote)
        }
    }

    private var chartCard: some View {
        Card(title: chartTitle, subtitle: chartSubtitle) {
            Chart(combinedSeries) { p in
                switch p.kind {
                case .history:
                    LineMark(x: .value("Month", p.date), y: .value("Value", p.value))
                    PointMark(x: .value("Month", p.date), y: .value("Value", p.value))
                case .forecast:
                    LineMark(x: .value("Month", p.date), y: .value("Value", p.value))
                        .interpolationMethod(.linear)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    PointMark(x: .value("Month", p.date), y: .value("Value", p.value))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    if let date = value.as(Date.self) { AxisValueLabel(monthShort(date)) }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    if let num = v.as(Double.self) { AxisValueLabel(axisLabel(num)) }
                }
            }
            .frame(height: 260)
            .kwhInteractiveDataViz()
        }
    }

    private var chartTitle: String { "\(measure.rawValue) Forecast" }
    private var chartSubtitle: String {
        "\(method.rawValue), horizon \(horizonMonths)m, range \(rangePick.rawValue)"
    }

    // MARK: Forecast engines
    private func linearForecast(_ rows: [MonthRow], horizon: Int) -> [MonthRow] {
        guard rows.count >= 2 else { return [] }
        // x = month index starting at 0
        let xs = rows.enumerated().map { Double($0.offset) }
        let ys = rows.map { $0.value }
        let n = Double(xs.count)
        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumXX = xs.reduce(0) { $0 + $1 * $1 }
        let denom = n * sumXX - sumX * sumX
        let slope = denom != 0 ? (n * sumXY - sumX * sumY) / denom : 0
        let intercept = (sumY - slope * sumX) / n
        // Project next months
        var out: [MonthRow] = []
        if let lastMonth = rows.last?.month {
            for h in 1...max(horizon, 1) {
                let x = Double(xs.count - 1 + h)
                let y = max(0, slope * x + intercept)
                if let d = Calendar.current.date(byAdding: .month, value: h, to: lastMonth) {
                    out.append(.init(month: monthStart(d), value: y))
                }
            }
        }
        return out
    }

    private func movingAverageForecast(_ rows: [MonthRow], horizon: Int, window: Int) -> [MonthRow] {
        guard rows.count >= window, window > 0 else { return [] }
        var out: [MonthRow] = []
        let vals = rows.map { $0.value }
        let lastWindowAvg: Double = {
            let count = min(window, vals.count)
            return vals.suffix(count).reduce(0, +) / Double(count)
        }()
        if let lastMonth = rows.last?.month {
            for h in 1...max(horizon, 1) {
                if let d = Calendar.current.date(byAdding: .month, value: h, to: lastMonth) {
                    out.append(.init(month: monthStart(d), value: max(0, lastWindowAvg)))
                }
            }
        }
        return out
    }

    // MARK: Formatting helpers
    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    private func axisLabel(_ v: Double) -> String {
        switch measure {
        case .spend: return currencyShort(v)
        case .sessions: return numberShort(v, 0)
        case .kwh: return numberShort(v, v < 10 ? 2 : 0) + " kWh"
        }
    }

    private func formatValue(_ v: Double) -> String {
        switch measure {
        case .spend: return currencyShort(v)
        case .sessions: return numberShort(v, 0)
        case .kwh: return numberShort(v, v < 10 ? 2 : 0) + " kWh"
        }
    }

    private func currencyShort(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = currencyCode
        f.maximumFractionDigits = v < 1 ? 3 : 2
        return f.string(from: NSNumber(value: v)) ?? "$0.00"
    }

    private func numberShort(_ v: Double, _ digits: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        f.maximumFractionDigits = digits; f.minimumFractionDigits = digits
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    // MARK: KWh extraction via reflection (best-effort)
    private func extractKWh(_ e: ExpenseEntry) -> Double? {
        let keys = ["energyKWh","kWh","kwh","chargedKWh","kWhAdded","energy"]
        let m = Mirror(reflecting: e)
        for child in m.children {
            if let label = child.label, keys.contains(label) {
                if let v = child.value as? Double { return v }
                if let opt = child.value as? Optional<Double> { return opt }
            }
        }
        return nil
    }

    // MARK: Date helpers
    private func monthStart(_ d: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year,.month], from: d)) ?? d
    }
    private func startDate(for pick: RangePick) -> Date {
        let cal = Calendar.current
        switch pick {
        case .m6:  return cal.date(byAdding: .month, value: -6, to: Date()) ?? .distantPast
        case .m12: return cal.date(byAdding: .month, value: -12, to: Date()) ?? .distantPast
        case .m24: return cal.date(byAdding: .month, value: -24, to: Date()) ?? .distantPast
        case .all: return .distantPast
        }
    }
    private func monthShort(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "MMM"; return f.string(from: d) }
}

// MARK: - Small data models
private struct MonthRow: Identifiable, Hashable { let id = UUID(); let month: Date; let value: Double }
private struct ChartPoint: Identifiable, Hashable {
    enum Kind { case history, forecast }
    let id = UUID()
    let date: Date
    let value: Double
    let kind: Kind
}

// MARK: - UI helpers (local copies)
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
    NavigationStack { ForecastChartView().environmentObject(EntriesStore()) }
}
#endif
