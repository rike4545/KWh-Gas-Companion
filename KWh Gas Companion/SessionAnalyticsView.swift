//
//  SessionAnalyticsView.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/14/25.
//


//
//  SessionAnalyticsView.swift
//  KWh Gas Companion
//
//  Charging Session Analytics (TeslaFi sessions)
//  - Range + search + missing-cost filter
//  - Totals, rates, top locations
//  - Data-quality checks (duplicates / overlaps)
//  - Lightweight bar chart (no Charts dependency)
//
//  Assumes TeslaFiSession includes at least:
//    id: UUID
//    startDate: Date
//    endDate: Date
//    energyAddedKWh: Double
//    cost: Double?
//    location: String?
//    fingerprint: String
//

import SwiftUI
import Foundation

@MainActor
public struct SessionAnalyticsView: View {

    // If your app injects a TeslaFiSessionStore via EnvironmentObject, keep this.
    // If you don’t have it, remove these 2 lines and use init(sessions:) instead.
    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore

    private let overrideSessions: [TeslaFiSession]?

    @State private var range: RangePreset = .last31Days
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -31, to: Date()) ?? Date()
    @State private var customEnd: Date = Date()

    @State private var query: String = ""
    @State private var showMissingCostOnly: Bool = false

    @State private var sort: SortMode = .newestFirst

    public init() {
        self.overrideSessions = nil
    }

    public init(sessions: [TeslaFiSession]) {
        self.overrideSessions = sessions
    }

    public var body: some View {
        let base = overrideSessions ?? teslaFiStore.sessions
        let filtered = filteredSessions(base)
        let summary = Summary(from: filtered)
        let quality = QualityReport(from: filtered)
        let daily = DailyAgg.series(from: filtered, calendar: Calendar.current)

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                header

                controlsCard(baseCount: base.count, filteredCount: filtered.count)

                summarySection(summary)

                insightsSection(summary: summary, quality: quality)

                trendSection(daily: daily, summary: summary)

                topLocationsSection(rows: TopLocation.rows(from: filtered))

                qualitySection(quality)

                sessionListSection(sessions: sorted(filtered))
            }
            .padding()
        }
        .navigationTitle("Session Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Session Analytics")
                .font(.title2.weight(.semibold))
            Text("Totals, trends, and data quality checks for your charging sessions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Controls

    private func controlsCard(baseCount: Int, filteredCount: Int) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Range", selection: $range) {
                    ForEach(RangePreset.allCases, id: \.self) { p in
                        Text(p.title).tag(p)
                    }
                }
                .pickerStyle(.segmented)

                if range == .custom {
                    DatePicker("Start", selection: $customStart, displayedComponents: [.date])
                    DatePicker("End", selection: $customEnd, displayedComponents: [.date])
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search location…", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(10)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Toggle(isOn: $showMissingCostOnly) {
                    Text("Show missing-cost sessions only")
                }

                Picker("Sort", selection: $sort) {
                    Text("Newest").tag(SortMode.newestFirst)
                    Text("Oldest").tag(SortMode.oldestFirst)
                    Text("Highest kWh").tag(SortMode.highestEnergy)
                    Text("Highest Cost").tag(SortMode.highestCost)
                }
                .pickerStyle(.menu)

                HStack {
                    Text("\(filteredCount) shown")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(baseCount) total")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Summary

    private func summarySection(_ s: Summary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Summary")
                .font(.headline)

            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
                metricCard("Sessions", "\(s.count)", "list.number")
                metricCard("Energy", "\(fmtNumber(s.totalEnergyKWh, digits: 1)) kWh", "bolt.fill")
                metricCard("Cost", fmtCurrency(s.totalCost), "dollarsign.circle.fill")
                metricCard("$ / kWh", fmtCurrency(s.costPerKWh), "chart.line.uptrend.xyaxis")
                metricCard("Avg kWh", fmtNumber(s.avgKWhPerSession, digits: 1), "gauge.with.dots.needle.67percent")
                metricCard("Avg mins", fmtNumber(s.avgDurationMinutes, digits: 0), "clock.fill")
            }
        }
    }

    // MARK: - Insights (sentience)

    private func insightsSection(summary: Summary, quality: QualityReport) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Next Up")
                        .font(.headline)
                    Spacer()
                    Text("Actionable")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                let actions = suggestedActions(summary: summary, quality: quality)

                if actions.isEmpty {
                    Label("Nothing urgent detected in this window.", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(actions, id: \.self) { item in
                        Label(item, systemImage: "sparkles")
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    // MARK: - Trend

    private func trendSection(daily: [DailyAgg], summary: Summary) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Trend")
                    .font(.headline)

                if daily.isEmpty {
                    Text("No sessions in this range.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    MiniBarChart(
                        titleLeft: "kWh / day",
                        titleRight: "\(fmtNumber(summary.totalEnergyKWh, digits: 1)) kWh",
                        points: daily.map { .init(label: $0.shortLabel, value: $0.energyKWh) }
                    )
                    .frame(height: 120)

                    MiniBarChart(
                        titleLeft: "Cost / day",
                        titleRight: fmtCurrency(summary.totalCost),
                        points: daily.map { .init(label: $0.shortLabel, value: $0.cost) }
                    )
                    .frame(height: 120)
                }
            }
        }
    }

    // MARK: - Top locations

    private func topLocationsSection(rows: [TopLocation]) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Top Locations")
                        .font(.headline)
                    Spacer()
                    Text("by kWh")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if rows.isEmpty {
                    Text("No location data available.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(rows.prefix(8)) { row in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.name.isEmpty ? "Unknown" : row.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Text("\(row.count) session(s)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(fmtNumber(row.energyKWh, digits: 1)) kWh")
                                        .font(.subheadline.weight(.semibold))
                                    if row.cost > 0 {
                                        Text(fmtCurrency(row.cost))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Divider().opacity(0.25)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Quality

    private func qualitySection(_ q: QualityReport) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Data Quality")
                        .font(.headline)
                    Spacer()
                    Text("\(q.issues.count) issue(s)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if q.issues.isEmpty {
                    Label("No issues detected.", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(q.issues, id: \.self) { issue in
                        Label(issue, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    // MARK: - Sessions list

    private func sessionListSection(sessions: [TeslaFiSession]) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Sessions")
                        .font(.headline)
                    Spacer()
                    Text("\(sessions.count)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if sessions.isEmpty {
                    Text("Nothing to show.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(sessions, id: \.id) { s in
                            sessionRow(s)
                            Divider().opacity(0.25)
                        }
                    }
                }
            }
        }
    }

    private func sessionRow(_ s: TeslaFiSession) -> some View {
        let durationMins = max(0, s.endDate.timeIntervalSince(s.startDate) / 60.0)
        let cost = s.cost ?? 0
        let kwh = max(0, s.energyAddedKWh)
        let costPer = (cost > 0 && kwh > 0) ? (cost / kwh) : nil

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(s.startDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.subheadline.weight(.semibold))
                Text("→")
                    .foregroundStyle(.secondary)
                Text(s.endDate, format: .dateTime.hour().minute())
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if let loc = s.location, !loc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(loc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Unknown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Label("\(fmtNumber(kwh, digits: 1)) kWh", systemImage: "bolt")
                Label("\(fmtNumber(durationMins, digits: 0)) min", systemImage: "clock")
                if cost > 0 {
                    Label(fmtCurrency(cost), systemImage: "dollarsign.circle")
                } else {
                    Label("Cost missing", systemImage: "questionmark.circle")
                        .foregroundStyle(.secondary)
                }
                if let cpk = costPer {
                    Label("$\(fmtNumber(cpk, digits: 2))/kWh", systemImage: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Filtering / Sorting

    private func filteredSessions(_ sessions: [TeslaFiSession]) -> [TeslaFiSession] {
        let (start, end) = window()

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return sessions.filter { s in
            // range
            guard s.startDate >= start && s.startDate <= end else { return false }

            // missing cost filter
            if showMissingCostOnly {
                if (s.cost ?? 0) > 0 { return false }
            }

            // query
            if !q.isEmpty {
                let loc = (s.location ?? "").lowercased()
                if !loc.contains(q) { return false }
            }

            return true
        }
    }

    private func sorted(_ sessions: [TeslaFiSession]) -> [TeslaFiSession] {
        switch sort {
        case .newestFirst:
            return sessions.sorted { $0.startDate > $1.startDate }
        case .oldestFirst:
            return sessions.sorted { $0.startDate < $1.startDate }
        case .highestEnergy:
            return sessions.sorted { $0.energyAddedKWh > $1.energyAddedKWh }
        case .highestCost:
            return sessions.sorted { ($0.cost ?? 0) > ($1.cost ?? 0) }
        }
    }

    private func window() -> (Date, Date) {
        let cal = Calendar.current
        let now = Date()

        switch range {
        case .last7Days:
            let start = cal.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)
        case .last31Days:
            let start = cal.date(byAdding: .day, value: -31, to: now) ?? now
            return (start, now)
        case .last90Days:
            let start = cal.date(byAdding: .day, value: -90, to: now) ?? now
            return (start, now)
        case .ytd:
            let year = cal.component(.year, from: now)
            let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
            return (start, now)
        case .all:
            return (.distantPast, .distantFuture)
        case .custom:
            let s = min(customStart, customEnd)
            let e = max(customStart, customEnd)
            // Expand to end-of-day for nicer inclusion
            let end = cal.date(bySettingHour: 23, minute: 59, second: 59, of: e) ?? e
            return (s, end)
        }
    }

    // MARK: - Suggestions

    private func suggestedActions(summary: Summary, quality: QualityReport) -> [String] {
        var out: [String] = []

        if summary.count == 0 {
            out.append("Import TeslaFi sessions or add charging entries to unlock insights.")
            return out
        }

        if summary.missingCostCount > 0 {
            out.append("Add missing costs to \(summary.missingCostCount) session(s) to improve accuracy.")
        }

        if summary.totalEnergyKWh > 0, summary.costPerKWh == 0 {
            out.append("You have energy but no recorded cost—set a default rate or fill in costs.")
        }

        if quality.duplicateCount > 0 {
            out.append("Duplicates detected (\(quality.duplicateCount)). Consider dedupe/merge settings.")
        }

        if quality.overlapCount > 0 {
            out.append("Overlapping sessions detected (\(quality.overlapCount)). This can inflate totals.")
        }

        if summary.costPerKWh > 0.70 {
            out.append("Your $/kWh is high in this window—check if these were peak Supercharger hours.")
        }

        return out
    }

    // MARK: - UI helpers

    private func metricCard(_ title: String, _ value: String, _ systemImage: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fmtNumber(_ v: Double, digits: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = digits
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    private func fmtCurrency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "$\(v)"
    }

    // MARK: - Types

    private enum RangePreset: CaseIterable, Hashable {
        case last7Days, last31Days, last90Days, ytd, all, custom

        var title: String {
            switch self {
            case .last7Days: return "7D"
            case .last31Days: return "31D"
            case .last90Days: return "90D"
            case .ytd: return "YTD"
            case .all: return "All"
            case .custom: return "Custom"
            }
        }
    }

    private enum SortMode: Hashable {
        case newestFirst
        case oldestFirst
        case highestEnergy
        case highestCost
    }

    private struct Summary {
        var count: Int
        var totalEnergyKWh: Double
        var totalCost: Double
        var missingCostCount: Int
        var avgKWhPerSession: Double
        var avgDurationMinutes: Double

        var costPerKWh: Double {
            guard totalEnergyKWh > 0 else { return 0 }
            return totalCost / totalEnergyKWh
        }

        init(from sessions: [TeslaFiSession]) {
            count = sessions.count
            totalEnergyKWh = sessions.reduce(into: 0.0) { $0 += max(0, $1.energyAddedKWh) }
            totalCost = sessions.reduce(into: 0.0) { $0 += max(0, $1.cost ?? 0) }
            missingCostCount = sessions.filter { ($0.cost ?? 0) <= 0 }.count

            let totalMinutes = sessions.reduce(into: 0.0) { sum, s in
                let mins = max(0, s.endDate.timeIntervalSince(s.startDate) / 60.0)
                sum += mins
            }

            avgKWhPerSession = count > 0 ? (totalEnergyKWh / Double(count)) : 0
            avgDurationMinutes = count > 0 ? (totalMinutes / Double(count)) : 0
        }
    }

    private struct QualityReport {
        var issues: [String] = []
        var duplicateCount: Int = 0
        var overlapCount: Int = 0

        init(from sessions: [TeslaFiSession]) {
            guard !sessions.isEmpty else { return }

            // duplicates by fingerprint
            var seen = Set<String>()
            var dups = 0
            for s in sessions {
                if !seen.insert(s.fingerprint).inserted { dups += 1 }
            }
            duplicateCount = dups
            if dups > 0 {
                issues.append("Duplicate fingerprints: \(dups) (possible repeated imports).")
            }

            // overlaps by time
            let sorted = sessions.sorted { $0.startDate < $1.startDate }
            var overlaps = 0
            for i in 1..<sorted.count {
                if sorted[i].startDate < sorted[i - 1].endDate {
                    overlaps += 1
                }
            }
            overlapCount = overlaps
            if overlaps > 0 {
                issues.append("Overlapping sessions: \(overlaps) (totals may be inflated).")
            }

            // missing cost
            let missing = sessions.filter { ($0.cost ?? 0) <= 0 }.count
            if missing > 0 {
                issues.append("Missing cost: \(missing) session(s).")
            }

            // zero energy
            let zeroEnergy = sessions.filter { $0.energyAddedKWh <= 0 }.count
            if zeroEnergy > 0 {
                issues.append("Zero kWh: \(zeroEnergy) session(s) (logging gaps).")
            }
        }
    }

    private struct TopLocation: Identifiable {
        var id: String { name }
        var name: String
        var count: Int
        var energyKWh: Double
        var cost: Double

        static func rows(from sessions: [TeslaFiSession]) -> [TopLocation] {
            struct Acc { var count = 0; var kwh = 0.0; var cost = 0.0 }

            var map: [String: Acc] = [:]
            for s in sessions {
                let raw = s.location ?? ""
                let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalized = key.isEmpty ? "" : key
                var acc = map[normalized, default: Acc()]
                acc.count += 1
                acc.kwh += max(0, s.energyAddedKWh)
                acc.cost += max(0, s.cost ?? 0)
                map[normalized] = acc
            }

            return map.map { (k, v) in
                TopLocation(name: k, count: v.count, energyKWh: v.kwh, cost: v.cost)
            }
            .sorted { $0.energyKWh > $1.energyKWh }
        }
    }

    private struct DailyAgg: Hashable {
        var day: Date
        var energyKWh: Double
        var cost: Double

        var shortLabel: String {
            day.formatted(.dateTime.month(.abbreviated).day())
        }

        static func series(from sessions: [TeslaFiSession], calendar: Calendar) -> [DailyAgg] {
            guard !sessions.isEmpty else { return [] }

            struct Acc { var kwh = 0.0; var cost = 0.0 }
            var map: [Date: Acc] = [:]

            for s in sessions {
                let day = calendar.startOfDay(for: s.startDate)
                var acc = map[day, default: Acc()]
                acc.kwh += max(0, s.energyAddedKWh)
                acc.cost += max(0, s.cost ?? 0)
                map[day] = acc
            }

            return map
                .map { DailyAgg(day: $0.key, energyKWh: $0.value.kwh, cost: $0.value.cost) }
                .sorted { $0.day < $1.day }
        }
    }
}

// MARK: - Mini Bar Chart (no Charts)

private struct MiniBarChart: View {

    struct Point: Hashable {
        var label: String
        var value: Double
    }

    var titleLeft: String
    var titleRight: String
    var points: [Point]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(titleLeft).font(.subheadline.weight(.semibold))
                Spacer()
                Text(titleRight).font(.footnote).foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                let h = proxy.size.height
                let w = proxy.size.width
                let maxV = max(points.map(\.value).max() ?? 0, 0.0001)
                let barCount = max(points.count, 1)
                let gap: CGFloat = 4
                let barW = max(2, (w - gap * CGFloat(barCount - 1)) / CGFloat(barCount))

                HStack(alignment: .bottom, spacing: gap) {
                    ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                        let t = CGFloat(p.value / maxV)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .frame(width: barW, height: max(2, h * t))
                            .foregroundStyle(.primary.opacity(0.25))
                    }
                }
            }
        }
    }
}
