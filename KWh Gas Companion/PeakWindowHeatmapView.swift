// PeakWindowHeatmapView.swift
// KWh Gas Companion
//
// Heatmap of charging intensity by weekday × hour.
// Input: just [ExpenseEntry] (no AnalyticsEngine dependency).

import SwiftUI

struct PeakWindowHeatmapView: View {
    enum Metric: String, CaseIterable, Identifiable {
        case kWh = "kWh"
        case cost = "Cost"
        case costPerKWh = "Cost/kWh"
        case sessions = "Sessions"
        var id: String { rawValue }
    }

    // Input data
    let entries: [ExpenseEntry]
    /// Optional filter range for entry.date (inclusive).
    var dateRange: ClosedRange<Date>? = nil

    // UI state
    @State private var metric: Metric = .kWh

    // Layout
    private let dayLabelWidth: CGFloat = 56
    private let cellCorner: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            heatmap
            legend
        }
        .padding()
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Peak Window Heatmap")
                    .font(.headline)
                Text("Aggregated by weekday × hour")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Metric", selection: $metric) {
                ForEach(Metric.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
        }
    }

    // MARK: - Heatmap

    private var heatmap: some View {
        let grid = HeatGrid(entries: filteredEntries)
        return GeometryReader { geo in
            let availableWidth = geo.size.width - dayLabelWidth
            let cellWidth = max(8, floor(availableWidth / 24.0) - 2) // small gap
            VStack(alignment: .leading, spacing: 6) {
                hourHeader(cellWidth: cellWidth)
                ForEach(Weekday.allCases, id: \.self) { wd in
                    HStack(spacing: 2) {
                        Text(wd.short)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: dayLabelWidth, alignment: .trailing)
                        ForEach(0..<24, id: \.self) { hour in
                            let value = grid.value(for: wd, hour: hour, metric: metric)
                            let color = grid.color(for: value, metric: metric)
                            RoundedRectangle(cornerRadius: cellCorner)
                                .fill(color)
                                .frame(width: cellWidth, height: cellWidth)
                                .overlay {
                                    RoundedRectangle(cornerRadius: cellCorner)
                                        .strokeBorder(Color.black.opacity(0.06))
                                }
                                .accessibilityLabel("\(wd.accessibility), \(hourLabel(hour))")
                                .accessibilityValue(grid.accessibilityValue(for: value, metric: metric))
                        }
                    }
                }
            }
        }
        .frame(minHeight: 24 + 7 * 18)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func hourHeader(cellWidth: CGFloat) -> some View {
        HStack(spacing: 2) {
            Spacer().frame(width: dayLabelWidth)
            ForEach([0,3,6,9,12,15,18,21], id: \.self) { h in
                Text(hourLabel(h))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: cellWidth * 3 + 4, alignment: .leading)
            }
            Spacer()
        }.padding(.top, 8)
    }

    // MARK: - Legend

    private var legend: some View {
        let grid = HeatGrid(entries: filteredEntries)
        let (minVal, maxVal) = grid.range(for: metric)
        return HStack(spacing: 8) {
            Text("Low").font(.caption).foregroundStyle(.secondary)
            LinearGradient(
                colors: (0...12).map { step in
                    let t = Double(step) / 12.0
                    return HeatGrid.heatColor(t)
                },
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 8)
            .clipShape(Capsule())
            Text("High").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(grid.format(value: minVal, metric: metric))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("→")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(grid.format(value: maxVal, metric: metric))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private var filteredEntries: [ExpenseEntry] {
        guard let r = dateRange else { return entries }
        return entries.filter { r.contains($0.date) }
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }
}

// MARK: - Data Aggregation

private struct HeatCell {
    var sessions: Int = 0
    var kWhSum: Double = 0
    var costSum: Double = 0

    mutating func add(entry: ExpenseEntry) {
        sessions += 1
        if let k = entry.energyKWh { kWhSum += max(0, k) }
        costSum += max(0, entry.amount)
    }

    func value(for metric: PeakWindowHeatmapView.Metric) -> Double {
        switch metric {
        case .kWh: return kWhSum
        case .cost: return costSum
        case .costPerKWh:
            guard kWhSum > 0 else { return 0 }
            return costSum / kWhSum
        case .sessions: return Double(sessions)
        }
    }
}

private enum Weekday: Int, CaseIterable {
    // Calendar.weekday: 1=Sun ... 7=Sat
    case sun = 1, mon, tue, wed, thu, fri, sat

    var short: String {
        switch self {
        case .sun: return "Sun"
        case .mon: return "Mon"
        case .tue: return "Tue"
        case .wed: return "Wed"
        case .thu: return "Thu"
        case .fri: return "Fri"
        case .sat: return "Sat"
        }
    }
    var accessibility: String {
        switch self {
        case .sun: return "Sunday"
        case .mon: return "Monday"
        case .tue: return "Tuesday"
        case .wed: return "Wednesday"
        case .thu: return "Thursday"
        case .fri: return "Friday"
        case .sat: return "Saturday"
        }
    }
}

private struct HeatGrid {
    private var cells: [[HeatCell]] // [weekday 1...7][hour 0...23]
    private let calendar = Calendar(identifier: .gregorian)

    init(entries: [ExpenseEntry]) {
        var grid = Array(
            repeating: Array(repeating: HeatCell(), count: 24),
            count: 7
        )
        for e in entries {
            let w = calendar.component(.weekday, from: e.date) // 1..7
            let h = calendar.component(.hour, from: e.date)    // 0..23
            guard (1...7).contains(w), (0...23).contains(h) else { continue }
            grid[w - 1][h].add(entry: e)
        }
        self.cells = grid
    }

    func value(for day: Weekday, hour: Int, metric: PeakWindowHeatmapView.Metric) -> Double {
        guard (0...23).contains(hour) else { return 0 }
        return cells[day.rawValue - 1][hour].value(for: metric)
    }

    func range(for metric: PeakWindowHeatmapView.Metric) -> (Double, Double) {
        var minV = Double.greatestFiniteMagnitude
        var maxV = 0.0
        for d in 0..<7 {
            for h in 0..<24 {
                let v = cells[d][h].value(for: metric)
                if v > maxV { maxV = v }
                if v < minV { minV = v }
            }
        }
        if minV == Double.greatestFiniteMagnitude { minV = 0 }
        if maxV == minV { maxV = minV * 1.0001 + (minV == 0 ? 1 : 0) }
        return (minV, maxV)
    }

    func color(for value: Double, metric: PeakWindowHeatmapView.Metric) -> Color {
        let (minV, maxV) = range(for: metric)
        let t = normalized(value, minV, maxV)
        return Self.heatColor(t)
    }

    func accessibilityValue(for value: Double, metric: PeakWindowHeatmapView.Metric) -> Text {
        Text(format(value: value, metric: metric))
    }

    func format(value: Double, metric: PeakWindowHeatmapView.Metric) -> String {
        switch metric {
        case .kWh:
            return String(format: "%.1f kWh", value)
        case .cost:
            return value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
        case .costPerKWh:
            let s = value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
            return "\(s)/kWh"
        case .sessions:
            return String(format: "%.0f", value)
        }
    }

    // MARK: helpers

    private func normalized(_ x: Double, _ a: Double, _ b: Double) -> Double {
        guard b > a else { return 0 }
        let t = (x - a) / (b - a)
        return min(1, max(0, t))
    }

    /// Blue → Indigo/Purple ramp without needing to blend `Color`s as views.
    static func heatColor(_ tIn: Double) -> Color {
        let t = min(1, max(0, tIn))
        // Hue from ~0.60 (blue) to ~0.75 (purple), increase saturation, reduce brightness a bit
        let hue = 0.60 + 0.15 * t
        let sat = 0.20 + 0.65 * t
        let bri = 0.96 - 0.30 * t
        return Color(hue: hue, saturation: sat, brightness: bri)
    }
}

// MARK: - Preview

#if DEBUG
struct PeakWindowHeatmapView_Previews: PreviewProvider {
    static var previews: some View {
        let cal = Calendar.current
        func make(_ y: Int, _ m: Int, _ d: Int, _ h: Int, kWh: Double, cost: Double) -> ExpenseEntry {
            let comps = DateComponents(year: y, month: m, day: d, hour: h)
            let date = cal.date(from: comps) ?? Date()
            // Avoid argument order issues by setting fields after init.
            var e = ExpenseEntry(date: date, amount: cost)
            e.energyKWh = kWh
            e.location = "Home"
            e.vehicleName = "Model 3"
            e.chargeType = "Home"
            e.vin = "5YJ3E11111111111"
            e.isEnergy = true
            return e
        }

        var demo: [ExpenseEntry] = []
        // Sprinkle some synthetic usage around weekday evenings/mornings
        for day in 1...28 {
            demo.append(make(2025, 7, day, 18, kWh: Double.random(in: 8...18), cost: Double.random(in: 2...6)))
            demo.append(make(2025, 7, day, 19, kWh: Double.random(in: 10...22), cost: Double.random(in: 3...8)))
            demo.append(make(2025, 7, day, 7,  kWh: Double.random(in: 2...6),   cost: Double.random(in: 1...3)))
        }

        return Group {
            PeakWindowHeatmapView(entries: demo)
                .previewDisplayName("kWh")
            PeakWindowHeatmapView(
                entries: demo,
                dateRange: (Calendar.current.date(byAdding: .day, value: -21, to: Date()) ?? Date())...Date()
            )
            .previewDisplayName("Filtered")
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif
