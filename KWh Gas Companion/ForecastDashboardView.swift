//
//  ForecastDashboardView.swift
//  KWh Gas Companion
//
//  Forecast dashboard for charging/energy expenses.
//  - Window selector (3/6/12/24/36 months)
//  - Stable month IDs (Date-based)
//  - Summary metrics (totals, averages, effective $/kWh)
//  - Simple forecast (next 3 months): seasonal (if >= 12 mo) else trailing-3 avg
//  - Theme-driven background + cards via AppThemeSpec (appThemeBox)
//  - Charts are guarded with canImport(Charts)
//
//  Swift 6 • iOS 17+
//

import SwiftUI
#if canImport(Charts)
import Charts
#endif

@MainActor
struct ForecastDashboardView: View {

    // MARK: - Init

    private let initialMonths: Int
    init(months: Int = 12) { self.initialMonths = months }

    // MARK: - Environment

    @Environment(\.colorScheme) private var scheme
    @Environment(\.appThemeBox) private var themeBox
    @EnvironmentObject private var entriesStore: EntriesStore

    // MARK: - UI State

    @State private var monthsWindow: Int = 12
    @State private var metric: Metric = .cost

    enum Metric: String, CaseIterable, Identifiable {
        case cost = "Cost"
        case kwh  = "kWh"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .cost: return "dollarsign.circle"
            case .kwh:  return "bolt.fill"
            }
        }
    }

    private let windowOptions: [Int] = [3, 6, 12, 24, 36]

    // MARK: - Data

    private var energyEntries: [ExpenseEntry] {
        entriesStore.entries.filter { $0.isEnergy }
    }

    private var monthlyAll: [MonthAggregate] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: energyEntries) { e in
            cal.startOfMonth(for: e.date)
        }

        return grouped.keys.sorted().map { month in
            let set = grouped[month] ?? []
            let cost = set.reduce(0.0) { $0 + $1.amount }
            let kwh  = set.reduce(0.0) { $0 + ($1.energyKWh ?? 0) }
            return MonthAggregate(month: month, cost: cost, kwh: kwh)
        }
    }

    private var windowed: [MonthAggregate] {
        let all = monthlyAll
        guard monthsWindow > 0 else { return all }
        return Array(all.suffix(monthsWindow))
    }

    private var totals: (cost: Double, kwh: Double) {
        (windowed.reduce(0) { $0 + $1.cost },
         windowed.reduce(0) { $0 + $1.kwh })
    }

    private var averages: (costPerMonth: Double, kwhPerMonth: Double, costPerKwh: Double?) {
        let n = max(Double(windowed.count), 1)
        let costPerMonth = totals.cost / n
        let kwhPerMonth  = totals.kwh / n
        let costPerKwh: Double? = totals.kwh > 0 ? (totals.cost / totals.kwh) : nil
        return (costPerMonth, kwhPerMonth, costPerKwh)
    }

    // MARK: - Forecasting

    /// Trailing-3 average (fallback)
    private var trailing3Avg: (cost: Double, kwh: Double)? {
        let tail = Array(windowed.suffix(3))
        guard !tail.isEmpty else { return nil }
        let avgCost = tail.reduce(0) { $0 + $1.cost } / Double(tail.count)
        let avgKwh  = tail.reduce(0) { $0 + $1.kwh } / Double(tail.count)
        return (avgCost, avgKwh)
    }

    /// Seasonal avg by month-of-year (only if we have >= 12 months)
    private var seasonalByMonth: [Int: (cost: Double, kwh: Double)]? {
        guard monthlyAll.count >= 12 else { return nil }
        let cal = Calendar.current
        let grouped = Dictionary(grouping: monthlyAll) { agg in
            cal.component(.month, from: agg.month) // 1...12
        }

        var out: [Int: (cost: Double, kwh: Double)] = [:]
        for (monthIndex, series) in grouped {
            guard !series.isEmpty else { continue }
            let avgCost = series.reduce(0) { $0 + $1.cost } / Double(series.count)
            let avgKwh  = series.reduce(0) { $0 + $1.kwh } / Double(series.count)
            out[monthIndex] = (avgCost, avgKwh)
        }
        return out.isEmpty ? nil : out
    }

    /// Next 3 months forecast points (seasonal if available, else trailing-3)
    private var forecast: [MonthAggregate] {
        guard let last = windowed.last else { return [] }
        let cal = Calendar.current

        let baseTrailing = trailing3Avg
        let seasonal = seasonalByMonth

        var points: [MonthAggregate] = []
        for step in 1...3 {
            guard let next = cal.date(byAdding: .month, value: step, to: last.month) else { continue }
            let key = cal.component(.month, from: next)

            let fc: (cost: Double, kwh: Double)?
            if let seasonal, let s = seasonal[key] {
                fc = s
            } else {
                fc = baseTrailing
            }

            guard let fc else { continue }
            points.append(
                MonthAggregate(
                    month: cal.startOfMonth(for: next),
                    cost: fc.cost,
                    kwh: fc.kwh,
                    isForecast: true
                )
            )
        }
        return points
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header

                    if windowed.isEmpty {
                        EmptyStateCard(
                            title: "No energy data yet",
                            message: "Add charging entries with kWh (and ideally cost) to unlock charts and forecasts."
                        )
                    } else {
                        controls
                        summary

                        #if canImport(Charts)
                        chartCard
                        #else
                        Card(title: "Charts Unavailable", subtitle: "Charts framework not available") {
                            Text("This build target doesn’t include Charts. You can still view totals and projections above.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        #endif

                        projectionCard
                    }

                    footnote
                }
                .padding(16)
            }
            .background(themedBackground.ignoresSafeArea())
            .navigationTitle("Forecast Dashboard")
            .toolbarTitleDisplayMode(.inline)
        }
        .onAppear {
            monthsWindow = windowOptions.contains(initialMonths) ? initialMonths : 12
        }
    }

    // MARK: - Background

    private var themedBackground: some View {
        let t = themeBox.base
        return Rectangle()
            .fill(t.screenBackground)
            .overlay {
                RadialGradient(
                    colors: [
                        t.accent.opacity(scheme == .dark ? 0.20 : 0.12),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 560
                )
                .blur(radius: scheme == .dark ? 28 : 22)
            }
    }

    // MARK: - UI Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Forecast Dashboard")
                .font(.title.bold())

            Text("\(monthsWindow)-month window • \(windowed.count) month\(windowed.count == 1 ? "" : "s") tracked")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controls: some View {
        Card(title: "Controls", subtitle: nil) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Label("Window", systemImage: "calendar")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Picker("Window", selection: $monthsWindow) {
                        ForEach(windowOptions, id: \.self) { n in
                            Text("\(n) mo").tag(n)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }

                HStack(spacing: 10) {
                    Label("Metric", systemImage: metric.icon)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Picker("Metric", selection: $metric) {
                        ForEach(Metric.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }
            }
        }
    }

    private var summary: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                MetricPill(title: "Total Cost", value: currency(totals.cost), icon: "creditcard")
                MetricPill(title: "Total kWh", value: number(totals.kwh, 0), icon: "bolt.fill")
            }

            HStack(spacing: 12) {
                MetricPill(title: "Avg Cost/mo", value: currency(averages.costPerMonth), icon: "calendar.badge.clock")
                MetricPill(title: "Avg kWh/mo", value: number(averages.kwhPerMonth, 0), icon: "bolt.badge.a")
            }

            HStack(spacing: 12) {
                MetricPill(title: "Effective $/kWh", value: averages.costPerKwh.map { "\(currency($0))/kWh" } ?? "—", icon: "tag")
                MetricPill(title: "Forecast Mode", value: monthlyAll.count >= 12 ? "Seasonal" : "Trailing-3", icon: "wand.and.stars")
            }
        }
    }

    #if canImport(Charts)
    private var chartCard: some View {
        let t = themeBox.base

        return Card(
            title: metric == .cost ? "Monthly Cost" : "Monthly kWh",
            subtitle: forecastSubtitle
        ) {
            Chart {
                ForEach(windowed) { p in
                    BarMark(
                        x: .value("Month", p.month, unit: .month),
                        y: .value(metric == .cost ? "Cost" : "kWh", metric == .cost ? p.cost : p.kwh)
                    )
                    .foregroundStyle(t.accent.opacity(scheme == .dark ? 0.70 : 0.60))
                }

                if !forecast.isEmpty {
                    ForEach(forecast) { p in
                        LineMark(
                            x: .value("Month", p.month, unit: .month),
                            y: .value(metric == .cost ? "Forecast Cost" : "Forecast kWh", metric == .cost ? p.cost : p.kwh)
                        )
                        .foregroundStyle(t.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))

                        PointMark(
                            x: .value("Month", p.month, unit: .month),
                            y: .value("Forecast", metric == .cost ? p.cost : p.kwh)
                        )
                        .foregroundStyle(t.accent)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { v in
                    if let d = v.as(Date.self) {
                        AxisValueLabel { Text(d, format: .dateTime.month(.abbreviated)) }
                    }
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 260)
            .accessibilityLabel(metric == .cost ? "Monthly cost chart with forecast" : "Monthly kilowatt-hour chart with forecast")
        }
    }
    #endif

    private var projectionCard: some View {
        Card(title: "Next 3 Months", subtitle: projectionSubtitle) {
            if forecast.isEmpty {
                Text("Not enough data to forecast yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    let items = Array(forecast.enumerated())
                    ForEach(items, id: \.element.id) { idx, f in
                        HStack {
                            Text(f.month, format: .dateTime.month(.abbreviated).year())
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if metric == .cost {
                                Text(currency(f.cost)).monospacedDigit()
                            } else {
                                Text(number(f.kwh, 0)).monospacedDigit()
                            }
                        }
                        .padding(.vertical, 6)

                        if idx < items.count - 1 {
                            Divider().opacity(0.35)
                        }
                    }
                }
            }
        }
    }

    private var footnote: some View {
        Card(title: "How forecasts work", subtitle: nil) {
            Text(monthlyAll.count >= 12
                 ? "With at least 12 months of history, we use a simple seasonal average by month-of-year (e.g., “January tends to look like this”)."
                 : "With fewer than 12 months, we fall back to the trailing 3-month average.")
            .font(.footnote)
            .foregroundStyle(.secondary)

            Text("This is a lightweight estimate, not a full statistical model.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var forecastSubtitle: String {
        monthlyAll.count >= 12 ? "History + seasonal forecast (dashed)" : "History + trailing-3 forecast (dashed)"
    }

    private var projectionSubtitle: String {
        monthlyAll.count >= 12 ? "Seasonal by month-of-year" : "Trailing 3-month average"
    }
}

// MARK: - Models

private struct MonthAggregate: Identifiable, Hashable {
    let month: Date
    let cost: Double
    let kwh: Double
    var isForecast: Bool = false

    var id: Date { month } // stable identity
}

// MARK: - Theme-driven UI helpers (file-local)

private struct Card<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.appThemeBox) private var themeBox

    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        let t = themeBox.base

        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: t.corner, style: .continuous)
                .fill(t.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: t.corner, style: .continuous)
                        .strokeBorder(t.separator.opacity(scheme == .dark ? 0.60 : 0.80), lineWidth: 1)
                )
        )
        .shadow(
            color: Color.black.opacity(scheme == .dark ? 0.28 : 0.10),
            radius: t.elevation,
            x: 0,
            y: 4
        )
    }
}

private struct MetricPill: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.appThemeBox) private var themeBox

    let title: String
    let value: String
    let icon: String

    var body: some View {
        let t = themeBox.base

        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: t.smallCorner, style: .continuous)
                .fill(t.cardBackground.opacity(scheme == .dark ? 0.95 : 1.0))
                .overlay(
                    RoundedRectangle(cornerRadius: t.smallCorner, style: .continuous)
                        .strokeBorder(t.separator.opacity(scheme == .dark ? 0.55 : 0.75), lineWidth: 1)
                )
        )
    }
}

private struct EmptyStateCard: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.appThemeBox) private var themeBox

    let title: String
    let message: String

    var body: some View {
        let t = themeBox.base

        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .imageScale(.large)
                .foregroundStyle(.secondary)

            Text(title).font(.headline)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: t.corner, style: .continuous)
                .fill(t.cardBackground.opacity(scheme == .dark ? 0.90 : 1.0))
                .overlay(
                    RoundedRectangle(cornerRadius: t.corner, style: .continuous)
                        .strokeBorder(t.separator.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Date helpers

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}

// MARK: - Formatting

private enum Formatters {
    static func currencyFormatter() -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = Locale.current.currency?.identifier ?? "USD"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 3
        return f
    }

    static func decimalFormatter(digits: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = digits
        f.minimumFractionDigits = digits
        return f
    }
}

private func currency(_ v: Double) -> String {
    let f = Formatters.currencyFormatter()
    f.currencyCode = Locale.current.currency?.identifier ?? "USD"
    f.maximumFractionDigits = abs(v) < 1 ? 3 : 2
    return f.string(from: NSNumber(value: v)) ?? String(format: "$%.2f", v)
}

private func number(_ v: Double, _ digits: Int) -> String {
    let f = Formatters.decimalFormatter(digits: digits)
    return f.string(from: NSNumber(value: v)) ?? "\(v)"
}

#if DEBUG
#Preview {
    NavigationStack {
        ForecastDashboardView()
            .environmentObject(EntriesStore())
    }
    .appTheme(DefaultAppTheme())
}
#endif
