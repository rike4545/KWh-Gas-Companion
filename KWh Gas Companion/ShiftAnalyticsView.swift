//
//  ShiftAnalyticsView.swift
//  My KWh Companion
//
//  Regenerated: compile-safe, no `return` in ViewBuilders, no Material dependency,
//  namespaced helpers, and simple charts that don’t require extra frameworks.
//

import SwiftUI
import MapKit

// MARK: - Local, non-colliding types

private struct SAEntry: Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var energyKWh: Double
    var cost: Double
    var miles: Double
    var isSupercharging: Bool
}

private enum SAMode: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case cost = "Cost"
    case energy = "Energy"
    case efficiency = "Efficiency"
    case quality = "Quality"
    var id: String { rawValue }
}

private enum SARange: String, CaseIterable, Identifiable {
    case last7 = "7D", last30 = "30D", last90 = "90D"
    var id: String { rawValue }
    var days: Int { switch self { case .last7: 7; case .last30: 30; case .last90: 90 } }
}

// MARK: - View

@MainActor
struct ShiftAnalyticsView: View {

    // State
    @State private var mode: SAMode = .overview
    @State private var range: SARange = .last30
    @State private var entries: [SAEntry] = []
    @State private var loading = false
    @State private var superchargerOnly = false

    // Derived
    @State private var totalEnergy: Double = 0
    @State private var totalCost: Double = 0
    @State private var avgWhPerMile: Double = 0
    @State private var homeEnergy: Double = 0
    @State private var scEnergy: Double = 0
    @State private var notes: [String] = []

    var body: some View {
        ScrollView {
            VStack(spacing: saSpace(.lg)) {
                header
                controlBar
                if mode == .overview {
                    summaryStrip
                }
                content
            }
            .padding()
        }
        .navigationTitle("Shift Analytics")
        .task { await reload() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await reload() } } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Refresh")
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        saGlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Driving & Charging Insights")
                    .font(saFont(.title))
                Text("Cost, energy, and efficiency trends for the selected period.")
                    .font(saFont(.caption))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controlBar: some View {
        saGlassCard {
            HStack(spacing: saSpace(.md)) {
                Picker("Mode", selection: $mode) {
                    ForEach(SAMode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented)

                Divider().frame(height: 26)

                HStack(spacing: 8) {
                    ForEach(SARange.allCases) { r in
                        let active = r == range
                        Button {
                            range = r
                            Task { await reload() }
                        } label: {
                            Text(r.rawValue)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(active ? saGlassBackground() : Color.secondary.opacity(0.15))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(active ? 0.25 : 0)))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Range \(r.rawValue)")
                    }
                }

                Spacer()

                Toggle(isOn: $superchargerOnly) {
                    Text("SC only").font(saFont(.label))
                }
                .toggleStyle(.switch)
            }
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: saSpace(.md)) {
            stat("Total Cost", value: money(totalCost))
            stat("Energy", value: "\(fmt0(totalEnergy)) kWh")
            stat("Avg Wh/mi", value: fmt0(avgWhPerMile))
            stat("Home/SC", value: "\(fmt0(homeEnergy))/\(fmt0(scEnergy))")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .overview:
            VStack(spacing: saSpace(.md)) {
                saGlassCard { lineChart(title: "Daily Energy (kWh)", series: dailyEnergy()) }
                saGlassCard { lineChart(title: "Daily Cost ($)", series: dailyCost()) }
                saGlassCard { lineChart(title: "Efficiency (Wh/mi)", series: dailyEfficiency()) }
                qualityCard
            }
        case .cost:
            saGlassCard { lineChart(title: "Daily Cost ($)", series: dailyCost()) }
        case .energy:
            saGlassCard { lineChart(title: "Daily Energy (kWh)", series: dailyEnergy()) }
        case .efficiency:
            saGlassCard { lineChart(title: "Efficiency (Wh/mi)", series: dailyEfficiency()) }
        case .quality:
            qualityCard
        }
    }

    private var qualityCard: some View {
        saGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Data Quality").font(saFont(.label))
                    Spacer()
                }
                if loading {
                    Text("Checking…").font(saFont(.caption)).foregroundStyle(.secondary)
                } else if notes.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        Text("No issues detected in this range.").font(saFont(.label))
                    }
                } else {
                    ForEach(notes, id: \.self) { n in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                            Text(n).font(saFont(.caption))
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Pieces

    private func stat(_ title: String, value: String) -> some View {
        saGlassCard(corner: saRadius(.lg), pad: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(saFont(.caption)).foregroundStyle(.secondary)
                Text(value).font(saFont(.number))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }

    // Minimal, dependency-free “line chart” (polyline) per day buckets
    private func lineChart(title: String, series: [(Date, Double)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(saFont(.label))
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let ys = series.map { $0.1 }
                let maxY = max(ys.max() ?? 1, 1)
                let minY = min(ys.min() ?? 0, 0)
                let pad: CGFloat = 8
                let xStep = series.count > 1 ? (w - pad * 2) / CGFloat(series.count - 1) : 0

                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.10))
                    Path { p in
                        guard !series.isEmpty else { return }
                        for (i, point) in series.enumerated() {
                            let x = pad + CGFloat(i) * xStep
                            let yNorm = (point.1 - minY) / max(maxY - minY, 0.0001)
                            let y = h - pad - CGFloat(yNorm) * (h - pad * 2)
                            if i == 0 {
                                p.move(to: CGPoint(x: x, y: y))
                            } else {
                                p.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.primary.opacity(0.7), lineWidth: 2)
                }
            }
            .frame(height: 160)
        }
    }

    // MARK: - Data + Metrics

    private func dateWindow() -> (Date, Date) {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -range.days, to: end) ?? end.addingTimeInterval(-Double(range.days) * 86_400)
        return (start, end)
    }

    private func filtered() -> [SAEntry] {
        if superchargerOnly {
            return entries.filter { e in
                return e.isSupercharging
            }
        } else {
            return entries
        }
    }

    private func compute() {
        let data = filtered()
        totalEnergy = data.reduce(0) { $0 + max(0, $1.energyKWh) }
        totalCost   = data.reduce(0) { $0 + max(0, $1.cost) }
        let miles   = data.reduce(0) { $0 + max(0, $1.miles) }
        avgWhPerMile = miles > 0 ? (totalEnergy * 1000) / miles : 0
        homeEnergy = data.filter { e in return !e.isSupercharging }.reduce(0) { $0 + $1.energyKWh }
        scEnergy   = data.filter { e in return  e.isSupercharging }.reduce(0) { $0 + $1.energyKWh }
        notes      = quality(data)
    }

    private func quality(_ list: [SAEntry]) -> [String] {
        var out: [String] = []

        // Zero/negative energy
        let hasZero = list.contains { e in return e.energyKWh <= 0 }
        if hasZero { out.append("Some entries report zero or negative energy; verify import mapping.") }

        // Suspicious $/kWh
        let weird = list.filter { e in
            if e.energyKWh <= 0 { return false }
            let r = e.cost / e.energyKWh
            return r < 0.03 || r > 1.20
        }
        if !weird.isEmpty { out.append("Unusual $/kWh detected in \(weird.count) entries; confirm pricing tiers.") }

        // Overlaps (same-day duplicates approx.)
        let dayKey: (Date) -> Date = { d in Calendar.current.startOfDay(for: d) }
        let grouped = Dictionary(grouping: list, by: { dayKey($0.date) })
        let dupDays = grouped.values.filter { $0.count > 6 } // arbitrary threshold
        if !dupDays.isEmpty { out.append("Potential duplicate entries on \(dupDays.count) days; check CSV.") }

        return out
    }

    private func bucketByDay(_ map: (SAEntry) -> Double) -> [(Date, Double)] {
        let cal = Calendar.current
        let keyed = Dictionary(grouping: filtered(), by: { cal.startOfDay(for: $0.date) })
        let pairs = keyed.map { (day, items) -> (Date, Double) in
            let sum = items.reduce(0) { $0 + max(0, map($1)) }
            return (day, sum)
        }
        return pairs.sorted { a, b in return a.0 < b.0 }
    }

    private func dailyEnergy() -> [(Date, Double)] { bucketByDay { $0.energyKWh } }
    private func dailyCost() -> [(Date, Double)]   { bucketByDay { $0.cost } }
    private func dailyEfficiency() -> [(Date, Double)] {
        let cal = Calendar.current
        let keyed = Dictionary(grouping: filtered(), by: { cal.startOfDay(for: $0.date) })
        let pairs = keyed.map { (day, items) -> (Date, Double) in
            let kWh = items.reduce(0) { $0 + max(0, $1.energyKWh) }
            let mi  = items.reduce(0) { $0 + max(0, $1.miles) }
            let whPerMi = mi > 0 ? (kWh * 1000) / mi : 0
            return (day, whPerMi)
        }
        return pairs.sorted { a, b in return a.0 < b.0 }
    }

    // MARK: - Load (demo data stub)

    private func reload() async {
        loading = true
        let (start, _) = dateWindow()

        // Demo data; replace with your store fetch
        var tmp: [SAEntry] = []
        let days = range.days
        for i in 0..<max(10, days) {
            let d = Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let sc = i % 3 == 0
            let k = sc ? Double.random(in: 16...28) : Double.random(in: 8...14)
            let c = sc ? k * 0.43 : (k * 0.12 + 0.54)
            let m = k / 0.27 * Double.random(in: 0.85...1.05)
            if d >= start {
                tmp.append(.init(date: d, energyKWh: k, cost: c, miles: m, isSupercharging: sc))
            }
        }
        entries = tmp.sorted { a, b in return a.date < b.date }

        compute()
        loading = false
    }
}

// MARK: - Local style helpers

private enum _SAFont { case number, title, label, body, caption }
private func saFont(_ f: _SAFont) -> SwiftUI.Font {
    switch f {
    case .number: return SwiftUI.Font.title2.monospacedDigit()
    case .title:  return SwiftUI.Font.title3.weight(.semibold)
    case .label:  return SwiftUI.Font.subheadline.weight(.medium)
    case .body:   return SwiftUI.Font.body
    case .caption:return SwiftUI.Font.caption
    }
}

private enum _SASpace { case xs, sm, md, lg, xl }
private func saSpace(_ s: _SASpace) -> CGFloat {
    switch s { case .xs: 6; case .sm: 10; case .md: 14; case .lg: 18; case .xl: 24 }
}

private enum _SARadius { case sm, md, lg }
private func saRadius(_ r: _SARadius) -> CGFloat {
    switch r { case .sm: 10; case .md: 16; case .lg: 22 }
}

private func saGlassBackground() -> Color { Color.white.opacity(0.07) }

@ViewBuilder
private func saGlassCard<Content: View>(
    corner: CGFloat = saRadius(.md),
    pad: CGFloat = saSpace(.md),
    @ViewBuilder content: () -> Content
) -> some View {
    content()
        .padding(pad)
        .background(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(saGlassBackground())
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08))
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 6)
}

// MARK: - Formatters

private func money(_ v: Double) -> String {
    let f = NumberFormatter(); f.numberStyle = .currency
    return f.string(from: NSNumber(value: v)) ?? String(format: "$%.2f", v)
}
private func fmt0(_ v: Double) -> String {
    let f = NumberFormatter(); f.minimumFractionDigits = 0; f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: v)) ?? String(format: "%.0f", v)
}
private func fmt1(_ v: Double) -> String {
    let f = NumberFormatter(); f.minimumFractionDigits = 1; f.maximumFractionDigits = 1
    return f.string(from: NSNumber(value: v)) ?? String(format: "%.1f", v)
}

// MARK: - Preview

#if DEBUG
struct ShiftAnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { ShiftAnalyticsView() }
            .environment(\.colorScheme, .dark)
    }
}
#endif
