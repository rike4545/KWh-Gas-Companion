// CostBreakdownDetailView.swift
// KWh Gas Companion

import SwiftUI
import Charts

struct CostBreakdownDetailView: View {
    /// Optional explicit injection; keep nil so callers can use no-arg `init()`
    let entries: [ExpenseEntry]? = nil
    /// Fallback to the shared store
    @EnvironmentObject private var entriesStore: EntriesStore

    // MARK: - Effective data
    private var data: [ExpenseEntry] {
        (entries ?? entriesStore.entries).sorted { $0.date < $1.date }
    }

    // MARK: - Aggregates
    private var totalCost: Double {
        data.reduce(0) { $0 + $1.amount }
    }
    private var energyCost: Double {
        data.filter { $0.isEnergy }.reduce(0) { $0 + $1.amount }
    }
    private var nonEnergyCost: Double {
        totalCost - energyCost
    }

    private var categorySlices: [CBDCategorySlice] {
        let grouped = Dictionary(grouping: data, by: { $0.category.trimmingCharacters(in: .whitespacesAndNewlines) })
        return grouped
            .map { key, values in CBDCategorySlice(category: key.isEmpty ? "Uncategorized" : key,
                                                   total: values.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    private var monthlyBreakdown: [CBDMonthlyBreakdown] {
        guard !data.isEmpty else { return [] }
        let cal = Calendar.current
        let grouped = Dictionary(grouping: data) { (e: ExpenseEntry) in
            cal.date(from: cal.dateComponents([.year, .month], from: e.date)) ?? e.date
        }
        return grouped.keys.sorted().map { monthStart in
            let set = grouped[monthStart] ?? []
            let energy = set.filter { $0.isEnergy }.reduce(0) { $0 + $1.amount }
            let non    = set.filter { !$0.isEnergy }.reduce(0) { $0 + $1.amount }
            return CBDMonthlyBreakdown(month: monthStart, energy: energy, nonEnergy: non)
        }
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                if data.isEmpty {
                    CBDEmpty(message: "No entries yet. Add charging and other expenses to see your breakdown.")
                } else {
                    toplineMetrics
                    energyVsNonEnergy
                    categoryPie
                    monthlyStackedBars
                    topCategoriesList
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Cost Breakdown")
        .toolbarTitleDisplayMode(.inline)
        .tint(.accentColor)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cost Breakdown").font(.title.bold())
            Text(summaryLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryLine: String {
        let count = data.count
        if let start = data.first?.date, let end = data.last?.date {
            let df = DateFormatter(); df.dateFormat = "MMM d, yyyy"
            return "\(count) entries • \(df.string(from: start)) – \(df.string(from: end))"
        }
        return "\(count) entries"
    }

    private var toplineMetrics: some View {
        HStack(spacing: 12) {
            CBDMetric(title: "Total", value: currencyShort(totalCost), icon: "dollarsign.circle.fill")
            CBDMetric(title: "Energy", value: currencyShort(energyCost), icon: "bolt.fill")
            CBDMetric(title: "Other", value: currencyShort(nonEnergyCost), icon: "wrench.fill")
        }
    }

    private var energyVsNonEnergy: some View {
        CBDCard(title: "Energy vs Other", subtitle: "Share of spend") {
            Chart {
                BarMark(x: .value("Type", "Energy"),
                        y: .value("Cost", energyCost))
                BarMark(x: .value("Type", "Other"),
                        y: .value("Cost", nonEnergyCost))
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 220)
        }
    }

    private var categoryPie: some View {
        CBDCard(title: "By Category", subtitle: "Share of total spend") {
            if categorySlices.isEmpty {
                CBDNoChartData()
            } else {
                Chart(categorySlices) { slice in
                    SectorMark(
                        angle: .value("Cost", slice.total),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.0
                    )
                    .foregroundStyle(by: .value("Category", slice.category))
                    .annotation(position: .overlay, alignment: .center) {
                        // optional overlay per slice (kept minimal for clarity)
                        EmptyView()
                    }
                }
                .frame(height: 260)
                .chartLegend(.automatic)
            }
        }
    }

    private var monthlyStackedBars: some View {
        CBDCard(title: "Monthly Spend", subtitle: "Energy vs other") {
            if monthlyBreakdown.isEmpty {
                CBDNoChartData()
            } else {
                Chart {
                    ForEach(monthlyBreakdown) { m in
                        BarMark(
                            x: .value("Month", m.month, unit: .month),
                            y: .value("Energy", m.energy),
                            stacking: .center
                        )
                        .foregroundStyle(.blue)

                        BarMark(
                            x: .value("Month", m.month, unit: .month),
                            y: .value("Other", m.nonEnergy),
                            stacking: .center
                        )
                        .foregroundStyle(.green)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { v in
                        if let d = v.as(Date.self) {
                            AxisValueLabel {
                                Text(d, format: .dateTime.month(.abbreviated))
                            }
                        }
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 300)
            }
        }
    }

    private var topCategoriesList: some View {
        CBDCard(title: "Top Categories", subtitle: "Largest to smallest") {
            VStack(spacing: 8) {
                ForEach(categorySlices) { s in
                    HStack {
                        Text(s.category).font(.subheadline)
                        Spacer()
                        Text(currencyShort(s.total)).font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 6)
                    Divider().opacity(0.2)
                }
            }
        }
    }

    // MARK: - Formatting
    private func currencyShort(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = Locale.current.currency?.identifier ?? "USD"
        f.maximumFractionDigits = v < 1 ? 3 : 2
        return f.string(from: NSNumber(value: v)) ?? "$0.00"
    }
}

// MARK: - Small models

private struct CBDCategorySlice: Identifiable, Hashable {
    let id = UUID()
    let category: String
    let total: Double
}

private struct CBDMonthlyBreakdown: Identifiable, Hashable {
    let id = UUID()
    let month: Date
    let energy: Double
    let nonEnergy: Double
    var total: Double { energy + nonEnergy }
}

// MARK: - Reusable UI (file-scope; avoid name collisions)

private struct CBDCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(uiColor: .secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(uiColor: .separator).opacity(0.25), lineWidth: 1))
    }
}

private struct CBDMetric: View {
    let title: String
    let value: String
    let icon: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(uiColor: .secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(uiColor: .separator).opacity(0.25), lineWidth: 1))
    }
}

private struct CBDEmpty: View {
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.pie.fill").imageScale(.large).foregroundStyle(.secondary)
            Text("Nothing to show yet").font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(uiColor: .tertiarySystemBackground)))
    }
}

private struct CBDNoChartData: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line").imageScale(.large).foregroundStyle(.secondary)
            Text("No chartable data").font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(uiColor: .tertiarySystemBackground)))
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        CostBreakdownDetailView()   // no-arg; uses EnvironmentObject
            .environmentObject(EntriesStore())
    }
}
#endif
