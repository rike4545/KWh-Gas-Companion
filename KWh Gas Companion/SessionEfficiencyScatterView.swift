//  SessionEfficiencyScatterView.swift
//  KWh Gas Companion
//
//  Retooled to remove TeslaFiSessionManager dependency.
//  • Works standalone (optional injection) or derives best-effort points from EntriesStore
//  • Scatter charts using Swift Charts (iOS 16+)
//  • If temperature or kWh/distance are missing, shows helpful empty states

import SwiftUI
import Charts

struct SessionEfficiencyScatterView: View {
    // Optional injection so you can pass prebuilt points from TeslaFi import, etc.
    private let injected: [EfficiencyPoint]?
    init(points: [EfficiencyPoint]? = nil) {
        self.injected = points
    }

    // Default pathway reads from EntriesStore and tries to derive points
    @EnvironmentObject private var entriesStore: EntriesStore

    enum RangePick: String, CaseIterable, Identifiable { case last3 = "3M", last6 = "6M", last12 = "12M", all = "All"; var id: String { rawValue } }
    @State private var range: RangePick = .last6
    @State private var showTrend = true

    private var useFahrenheit: Bool { Locale.current.usesFahrenheit }

    // MARK: - Derived points
    private var points: [EfficiencyPoint] {
        if let injected { return injected }
        return derivePointsFromEntries(entriesStore.entries)
    }

    private var filtered: [EfficiencyPoint] {
        switch range {
        case .all: return points
        case .last3: return points.filter { $0.date >= monthOffset(-3) }
        case .last6: return points.filter { $0.date >= monthOffset(-6) }
        case .last12: return points.filter { $0.date >= monthOffset(-12) }
        }
    }

    private var withTemp: [EfficiencyPoint] { filtered.filter { $0.tempC != nil } }
    private var withEnergy: [EfficiencyPoint] { filtered.filter { ($0.kWh ?? 0) > 0 } }
    private var withEfficiency: [EfficiencyPoint] { filtered.filter { ($0.kWh ?? 0) > 0 && ($0.distanceMi ?? 0) > 0 } }

    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                rangePicker

                if points.isEmpty {
                    EmptyStateCard(
                        title: "No session data",
                        message: "Import TeslaFi CSV or add charging entries with odometer/energy to analyze efficiency.")
                } else if withTemp.isEmpty {
                    EmptyStateCard(
                        title: "No temperature in data",
                        message: "This scatter needs ambient temperature. Import TeslaFi CSV that includes temp.")
                } else {
                    metricsRow
                    energyVsTemp
                    if !withEfficiency.isEmpty { efficiencyVsTemp }
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Efficiency Scatter")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: UI sections
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Session Efficiency Scatter").font(.title.bold())
            Text("Energy and efficiency vs ambient temperature").font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rangePicker: some View {
        HStack {
            Text("Range").font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Picker("Range", selection: $range) {
                ForEach(RangePick.allCases) { r in Text(r.rawValue).tag(r) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
        }
    }

    private var metricsRow: some View {
        let avgTempC = withTemp.compactMap { $0.tempC }.average
        let avgTempDisp = avgTempC.map { useFahrenheit ? Self.fToDisplay(Self.cToF($0)) : Self.cToDisplay($0) } ?? "—"
        let avgWhPerMi = withEfficiency.map { ($0.kWh ?? 0) / max($0.distanceMi ?? 0, 0.0001) * 1000 }.average
        let avgWhDisp = avgWhPerMi.map { String(format: "%.0f Wh/mi", $0) } ?? "—"

        return HStack(spacing: 12) {
            MetricPill(title: "Points", value: "\(filtered.count)", icon: "dot.scope")
            MetricPill(title: "Avg Temp", value: avgTempDisp, icon: "thermometer")
            MetricPill(title: "Avg Eff.", value: avgWhDisp, icon: "gauge")
        }
    }

    private var energyVsTemp: some View {
        Card(title: "Energy vs Temperature", subtitle: filtered.isEmpty ? nil : subtitleRangeText) {
            Chart(withEnergy) { p in
                PointMark(
                    x: .value("Temp", useFahrenheit ? Self.cToF(p.tempC ?? 0) : (p.tempC ?? 0)),
                    y: .value("kWh", p.kWh ?? 0)
                )
                .opacity(0.8)
            }
            .chartXAxis {
                AxisMarks(position: .bottom) { v in
                    if let t = v.as(Double.self) {
                        AxisValueLabel(useFahrenheit ? Self.fToDisplay(t) : Self.cToDisplay(t))
                    }
                }
            }
            .frame(height: 260)
        }
    }

    private var efficiencyVsTemp: some View {
        Card(title: "Wh/mi vs Temperature", subtitle: "Computed when distance is available") {
            let pts = withEfficiency.map { ScatterPoint(
                x: useFahrenheit ? Self.cToF($0.tempC ?? 0) : ($0.tempC ?? 0),
                y: (($0.kWh ?? 0) / max($0.distanceMi ?? 0, 0.0001)) * 1000
            ) }

            let line = regression(pts)

            Chart {
                ForEach(pts) { p in
                    PointMark(
                        x: .value("Temp", p.x),
                        y: .value("Wh/mi", p.y)
                    )
                    .opacity(0.8)
                }
                if showTrend, let line {
                    LineMark(
                        x: .value("Temp", line.x1), y: .value("Wh/mi", line.y1)
                    )
                    LineMark(
                        x: .value("Temp", line.x2), y: .value("Wh/mi", line.y2)
                    )
                    .foregroundStyle(.secondary)
                }
            }
            .chartXAxis {
                AxisMarks(position: .bottom) { v in
                    if let t = v.as(Double.self) {
                        AxisValueLabel(useFahrenheit ? Self.fToDisplay(t) : Self.cToDisplay(t))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    if let val = v.as(Double.self) {
                        AxisValueLabel(String(format: "%.0f Wh/mi", val))
                    }
                }
            }
            .frame(height: 260)
        }
    }

    private var subtitleRangeText: String {
        guard let first = filtered.min(by: { $0.date < $1.date })?.date,
              let last  = filtered.max(by: { $0.date < $1.date })?.date else { return "" }
        return "\(monthYear(first)) – \(monthYear(last))"
    }

    // MARK: - Derivation from entries
    private func derivePointsFromEntries(_ entries: [ExpenseEntry]) -> [EfficiencyPoint] {
        // Sort by date ascending
        let energy = entries.filter { $0.isEnergy }.sorted(by: { $0.date < $1.date })
        guard !energy.isEmpty else { return [] }

        // attempt to compute distance deltas between consecutive energy entries using odometer
        var points: [EfficiencyPoint] = []
        var prevOdo: Double? = nil
        for e in energy {
            let tempC = extractDouble(from: e, key: "ambientTempC") ?? {
                if let f = extractDouble(from: e, key: "ambientTempF") { return (f - 32.0) * 5.0/9.0 }
                if let t = extractDouble(from: e, key: "temperatureC") { return t }
                if let f2 = extractDouble(from: e, key: "temperatureF") { return (f2 - 32.0) * 5.0/9.0 }
                return nil
            }()
            let kWh = extractDouble(from: e, key: "energyKWh") ?? extractDouble(from: e, key: "kWh")

            var distance: Double? = nil
            if let odo = e.odometer {
                if let prev = prevOdo, odo > prev { distance = odo - prev }
                prevOdo = odo
            }

            points.append(EfficiencyPoint(date: e.date, tempC: tempC, kWh: kWh, distanceMi: distance))
        }
        return points
    }

    private func extractDouble(from entry: ExpenseEntry, key: String) -> Double? {
        let mirror = Mirror(reflecting: entry)
        for child in mirror.children {
            if child.label == key {
                return child.value as? Double
            }
        }
        return nil
    }

    // MARK: - Date helpers
    private func monthOffset(_ months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: Date()) ?? Date()
    }
    private func monthYear(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"; return f.string(from: d)
    }

    // MARK: - Regression & math
    private func regression(_ pts: [ScatterPoint]) -> (x1: Double, y1: Double, x2: Double, y2: Double)? {
        guard pts.count >= 2 else { return nil }
        let xs = pts.map { $0.x }, ys = pts.map { $0.y }
        let n = Double(pts.count)
        let sumX = xs.reduce(0,+), sumY = ys.reduce(0,+)
        let sumXY = zip(xs,ys).reduce(0) { $0 + $1.0*$1.1 }
        let sumXX = xs.reduce(0) { $0 + $1*$1 }
        let denom = (n*sumXX - sumX*sumX)
        guard abs(denom) > 1e-9 else { return nil }
        let b = (n*sumXY - sumX*sumY) / denom
        let a = (sumY - b*sumX) / n
        guard let minX = xs.min(), let maxX = xs.max() else { return nil }
        return (minX, a + b*minX, maxX, a + b*maxX)
    }
}

// MARK: - Models

struct EfficiencyPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let tempC: Double?    // ambient temp in °C
    let kWh: Double?      // energy in kWh
    let distanceMi: Double? // distance in miles between charges
}

struct ScatterPoint: Identifiable, Hashable {
    let id = UUID()
    let x: Double
    let y: Double
}

// MARK: - Reusable UI (shared styles)

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

// MARK: - Locale helpers

private extension Locale {
    var usesFahrenheit: Bool {
        let id = (self as NSLocale).object(forKey: .countryCode) as? String ?? "US"
        return ["BS","US","BZ","KY","PW","GU","MH","FM","LR"].contains(id)
    }
}

// MARK: - Math helpers
private extension Array where Element == Double {
    var average: Double? { isEmpty ? nil : reduce(0,+) / Double(count) }
}

private extension SessionEfficiencyScatterView {
    static func cToF(_ c: Double) -> Double { c * 9/5 + 32 }
    static func cToDisplay(_ c: Double) -> String { String(format: "%.0f℃", c) }
    static func fToDisplay(_ f: Double) -> String { String(format: "%.0f℉", f) }
}

#if DEBUG
#Preview {
    NavigationStack {
        SessionEfficiencyScatterView(points: [
            EfficiencyPoint(date: .now.addingTimeInterval(-86400*10), tempC: 10, kWh: 28, distanceMi: 90),
            EfficiencyPoint(date: .now.addingTimeInterval(-86400*8), tempC: 20, kWh: 26, distanceMi: 100),
            EfficiencyPoint(date: .now.addingTimeInterval(-86400*6), tempC: -5, kWh: 35, distanceMi: 80)
        ])
        .environmentObject(EntriesStore())
    }
}
#endif
