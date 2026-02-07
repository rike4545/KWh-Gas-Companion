// TCOTimelineView.swift
// KWh Gas Companion

import SwiftUI
import Charts

struct TCOTimelineView: View {
    /// Optional explicit injection. If nil, uses entriesStore.entries.
    let entries: [ExpenseEntry]? = nil

    @EnvironmentObject private var entriesStore: EntriesStore
    @State private var monthsWindow: Int = 24
    @State private var showCumulative: Bool = true

    // MARK: - Effective data
    private var data: [ExpenseEntry] {
        let all = entries ?? entriesStore.entries
        guard monthsWindow > 0 else { return all }
        let cal = Calendar.current
        let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        let cutoff = cal.date(byAdding: .month, value: -monthsWindow + 1, to: startOfThisMonth) ?? .distantPast
        return all.filter { (reflect($0, ["date","startDate","timestamp"]) ?? .distantPast) >= cutoff }
    }

    // MARK: - Aggregations
    private var monthlyRows: [TCOMonthRow] {
        guard !data.isEmpty else { return [] }
        let cal = Calendar.current
        let groups = Dictionary(grouping: data) { e in
            cal.date(from: cal.dateComponents([.year, .month], from: reflect(e, ["date","startDate","timestamp"]) ?? Date())) ?? cal.startOfDay(for: Date())
        }

        // Build + sort
        let months = groups.keys.sorted()
        var runningTotal = 0.0

        return months.map { m in
            let items = groups[m] ?? []
            let energyCost = items.filter { isEnergyEntry($0) }.reduce(0) { $0 + $1.amount }
            let nonEnergyCost = items.filter { !isEnergyEntry($0) }.reduce(0) { $0 + $1.amount }
            let total = energyCost + nonEnergyCost
            runningTotal += total
            return TCOMonthRow(month: m, energy: energyCost, nonEnergy: nonEnergyCost, total: total, cumulative: runningTotal)
        }
    }

    private var totals: (energy: Double, non: Double, total: Double) {
        monthlyRows.reduce(into: (0,0,0)) { acc, r in
            acc.energy += r.energy; acc.non += r.nonEnergy; acc.total += r.total
        }
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                controls

                if monthlyRows.isEmpty {
                    TCOEmpty(message: "No entries in the selected window. Add charging and expense data to see your TCO over time.")
                } else {
                    metrics
                    timelineChart
                    detailList
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("TCO Timeline")
        .toolbarTitleDisplayMode(.inline)
        .tint(.accentColor)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Total Cost of Ownership")
                .font(.title.bold())
            if let first = monthlyRows.first?.month, let last = monthlyRows.last?.month {
                Text("\(monthlyRows.count) months • \(formatCurrency(totals.total)) total • \(formatMonthYear(first)) — \(formatMonthYear(last))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(monthlyRows.count) months • \(formatCurrency(totals.total)) total")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                Stepper(value: $monthsWindow, in: 1...60, step: 1) {
                    Text("Window: \(monthsWindow) mo")
                }
                Spacer()
            }
            Toggle(isOn: $showCumulative) { Text("Show cumulative total") }
                .toggleStyle(.switch)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(uiColor: .secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(uiColor: .separator).opacity(0.25), lineWidth: 1))
    }

    private var metrics: some View {
        HStack(spacing: 12) {
            TCOMetric(title: "Energy", value: formatCurrency(totals.energy), icon: "bolt.fill")
            TCOMetric(title: "Non-Energy", value: formatCurrency(totals.non), icon: "cart.fill")
            TCOMetric(title: "Total", value: formatCurrency(totals.total), icon: "dollarsign.circle.fill")
        }
    }

    private var timelineChart: some View {
        TCOCard(title: "Monthly Costs", subtitle: showCumulative ? "Stacked bars with cumulative line" : "Stacked bars per month") {
            Chart {
                ForEach(monthlyRows) { r in
                    BarMark(
                        x: .value("Month", r.month, unit: .month),
                        y: .value("Energy", r.energy),
                        stacking: .standard
                    )
                    .foregroundStyle(.blue)

                    BarMark(
                        x: .value("Month", r.month, unit: .month),
                        y: .value("Non-Energy", r.nonEnergy),
                        stacking: .standard
                    )
                    .foregroundStyle(.green)

                    if showCumulative {
                        LineMark(
                            x: .value("Month", r.month, unit: .month),
                            y: .value("Cumulative", r.cumulative)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.secondary)
                        .lineStyle(.init(lineWidth: 2))
                        PointMark(
                            x: .value("Month", r.month, unit: .month),
                            y: .value("Cumulative", r.cumulative)
                        )
                        .symbolSize(14)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { v in
                    if let d = v.as(Date.self) {
                        AxisValueLabel { Text(d, format: .dateTime.month(.abbreviated)) }
                    }
                }
            }
            .frame(height: 300)
        }
    }

    private var detailList: some View {
        TCOCard(title: "Monthly Detail", subtitle: "Sorted by date") {
            VStack(spacing: 10) {
                ForEach(monthlyRows) { r in
                    HStack {
                        Text(formatMonthYear(r.month))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Energy \(formatCurrency(r.energy))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Non \(formatCurrency(r.nonEnergy))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatCurrency(r.total))
                                .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 6)
                    Divider().opacity(0.2)
                }
            }
        }
    }

    // MARK: - Helpers

    private func isEnergyEntry(_ e: ExpenseEntry) -> Bool {
        if let flag: Bool = reflect(e, ["isEnergy","isCharging","energyFlag"]) { return flag }
        if let cat: String? = reflect(e, ["category"]) {
            let lc = (cat ?? "").lowercased()
            return lc.contains("charge") || lc.contains("electric") || lc.contains("energy")
        }
        if let cat: String = reflect(e, ["category"]) {
            let lc = cat.lowercased()
            return lc.contains("charge") || lc.contains("electric") || lc.contains("energy")
        }
        return false
    }

    private func formatCurrency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = Locale.current.currency?.identifier ?? "USD"
        f.maximumFractionDigits = v < 1000 ? 2 : 0
        return f.string(from: NSNumber(value: v)) ?? "$0"
    }

    private func formatMonthYear(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: d)
    }
}

// MARK: - Local models & UI

private struct TCOMonthRow: Identifiable {
    let id = UUID()
    let month: Date
    let energy: Double
    let nonEnergy: Double
    let total: Double
    let cumulative: Double
}

private struct TCOCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.secondary) }
            }
            content
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(uiColor: .secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(uiColor: .separator).opacity(0.25), lineWidth: 1))
    }
}

private struct TCOMetric: View {
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

private struct TCOEmpty: View {
    let message: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .imageScale(.large)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(uiColor: .tertiarySystemBackground)))
    }
}

// MARK: - Reflection helper

/// Get the first property matching any of the names, cast to T. Unwraps optionals via Mirror.
private func reflect<Source, T>(_ value: Source, _ names: [String]) -> T? {
    let mirror = Mirror(reflecting: value)
    for child in mirror.children {
        guard let label = child.label, names.contains(label) else { continue }
        if let typed = child.value as? T { return typed }
        let cm = Mirror(reflecting: child.value)
        if cm.displayStyle == .optional, let some = cm.children.first?.value as? T { return some }
    }
    return nil
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TCOTimelineView() // uses EnvironmentObject entries
            .environmentObject(EntriesStore())
    }
}
