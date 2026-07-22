//
//  DeepDepthShiftView.swift
//  KWh Gas Companion
//
//  Deep Analytics (DeepDepth Shift)
//
//  FIXES / GUARANTEES:
//  ✅ No invalid Swift Range construction in this file (no “1..<0” traps)
//  ✅ Provider is ALWAYS called with endExclusive > start
//  ✅ Custom dates clamped so Start never exceeds End
//  ✅ Unique local enum/type names to avoid “ambiguous / redeclaration” collisions
//  ✅ Polished UI + AppThemeSpec-driven background/cards + AppAppearance tint
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import Charts
import Foundation

@MainActor
public struct DeepDepthShiftView: View {

    @Environment(\.deepDepthProvider) private var provider
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var appearance: AppAppearance

    private var T: any AppThemeSpec { themeBox.base }
    private var accent: Color { appearance.accentColor }

    // Mirrors SettingsView key
    @AppStorage("uiStyle") private var uiStyleRaw: String = "teslaGlass"

    // MARK: - State

    @State private var rangePreset: DDShift_RangePreset = .last31Days
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -31, to: Date()) ?? Date()
    @State private var customEnd: Date = Date()

    @State private var filter: DDShift_Filter = .all
    @State private var showOnlyMissingCost: Bool = false
    @State private var searchQuery: String = ""

    @State private var trendMode: DDShift_TrendMode = .energy

    @State private var isLoading: Bool = false
    @State private var sessions: [DeepDepthSession] = []
    @State private var lastError: String?
    @State private var lastUpdated: Date?

    public init() {}

    // MARK: - Body

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: T.spacing) {

                headerCard

                if provider == nil {
                    noProviderCard
                } else {
                    controlsCard

                    if isLoading {
                        loadingCard
                    } else if let lastError {
                        errorCard(lastError)
                    } else {
                        summarySection
                        trendCard
                        qualityCard
                        sessionsCard
                        footerCard
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .contentMargins(.top, 6, for: .scrollContent)      // reduce empty space on top
        .contentMargins(.bottom, 24, for: .scrollContent)
        .scrollIndicators(.hidden)
        .background(backgroundView)
        .navigationTitle("Deep Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accent)

        .searchable(
            text: $searchQuery,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search sessions (supercharger, missing cost, other)…"
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)

        .refreshable { await reload() }

        .task { await reload() }
        .onChange(of: rangePreset) { _, _ in Task { await reload() } }

        // ✅ Clamp custom dates: Start never > End
        .onChange(of: customStart) { _, newValue in
            if customEnd < newValue { customEnd = newValue }
            if rangePreset == .custom { Task { await reload() } }
        }
        .onChange(of: customEnd) { _, newValue in
            if newValue < customStart { customStart = newValue }
            if rangePreset == .custom { Task { await reload() } }
        }
    }

    // MARK: - Theme / Surfaces

    private var isGlass: Bool {
        let v = uiStyleRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return v == "glass" || v == "teslaglass"
    }

    private var backgroundView: some View {
        ZStack {
            Rectangle().fill(T.screenBackground).ignoresSafeArea()

            RadialGradient(
                colors: [accent.opacity(scheme == .dark ? 0.18 : 0.10), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 560
            )
            .blur(radius: 28)
            .ignoresSafeArea()

            RadialGradient(
                colors: [accent.opacity(scheme == .dark ? 0.12 : 0.07), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 680
            )
            .blur(radius: 34)
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        DDShiftCard(isGlass: isGlass, theme: T) {
            VStack(alignment: .leading, spacing: 6) {
                Text("DeepDepth Shift")
                    .font(.title3.weight(.semibold))

                Text("Energy, cost, miles, and data quality for a selected time window.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Label(windowLabel, systemImage: "calendar")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let lastUpdated {
                        Text("Updated \(lastUpdated, format: .dateTime.hour().minute())")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private var noProviderCard: some View {
        DDShiftCard(isGlass: isGlass, theme: T) {
            VStack(alignment: .leading, spacing: 10) {
                Label("No data provider connected", systemImage: "bolt.slash")
                    .font(.headline)

                Text("Deep analytics requires a DeepDepthDataProvider.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Controls

    private var controlsCard: some View {
        DDShiftCard(isGlass: isGlass, theme: T) {
            VStack(alignment: .leading, spacing: 12) {

                Picker("Range", selection: $rangePreset) {
                    ForEach(DDShift_RangePreset.allCases) { p in
                        Text(p.title).tag(p)
                    }
                }
                .pickerStyle(.segmented)

                if rangePreset == .custom {
                    DatePicker("Start", selection: $customStart, displayedComponents: [.date])
                    DatePicker("End", selection: $customEnd, displayedComponents: [.date])
                }

                Picker("Filter", selection: $filter) {
                    ForEach(DDShift_Filter.allCases) { f in
                        Text(f.title).tag(f)
                    }
                }
                .pickerStyle(.segmented)

                Toggle(isOn: $showOnlyMissingCost) {
                    Label("Only missing cost", systemImage: "questionmark.diamond")
                }

                HStack {
                    Button {
                        Task { await reload() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(T.pillTint.opacity(0.30), in: Capsule(style: .continuous))

                    Spacer()

                    Text("\(visibleSessionsSorted.count) shown")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Loading / Error

    private var loadingCard: some View {
        DDShiftCard(isGlass: isGlass, theme: T) {
            HStack(spacing: 10) {
                ProgressView()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Loading sessions…")
                        .font(.headline)
                    Text("Fetching and computing summary.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func errorCard(_ text: String) -> some View {
        DDShiftCard(isGlass: isGlass, theme: T) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Couldn’t load data", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)

                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await reload() }
                } label: {
                    Label("Try again", systemImage: "arrow.clockwise")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(T.pillTint.opacity(0.30), in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        let s = DDShift_Summary(from: visibleSessionsSorted)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Summary").font(.headline)

            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
                metricCard("Energy", value: fmtNumber(s.totalEnergyKWh, digits: 1) + " kWh", systemImage: "bolt.fill")
                metricCard("Cost", value: s.totalCost > 0 ? fmtCurrency(s.totalCost) : "—", systemImage: "dollarsign.circle.fill")
                metricCard("Miles", value: fmtNumber(s.totalMiles, digits: 1) + " mi", systemImage: "car.fill")
                metricCard("$ / kWh", value: s.costPerKWh.map(fmtCurrency) ?? "—", systemImage: "tag.fill")
                metricCard("mi / kWh", value: s.milesPerKWh.map { fmtNumber($0, digits: 2) } ?? "—", systemImage: "gauge.with.dots.needle.67percent")
                metricCard("Missing Cost", value: "\(s.missingCostCount)", systemImage: "questionmark.diamond.fill")
            }
        }
    }

    private func metricCard(_ title: String, value: String, systemImage: String) -> some View {
        DDShiftCard(isGlass: isGlass, theme: T, padding: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Trend

    private var trendCard: some View {
        let points = dailyPoints(from: visibleSessionsSorted)
        let hasAnyCost = points.contains { $0.cost > 0 }

        return DDShiftCard(isGlass: isGlass, theme: T) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Trend").font(.headline)
                    Spacer()
                    Text(points.isEmpty ? "—" : "\(points.count) day(s)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if hasAnyCost {
                    Picker("Trend", selection: $trendMode) {
                        ForEach(DDShift_TrendMode.allCases) { m in
                            Text(m.title).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if points.isEmpty {
                    Text("Not enough data to plot a trend in this window.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Chart(points) { p in
                        // ✅ No explicit domain ranges
                        if trendMode == .cost && hasAnyCost {
                            LineMark(
                                x: .value("Day", p.day),
                                y: .value("Cost", p.cost)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(accent)
                        } else {
                            BarMark(
                                x: .value("Day", p.day),
                                y: .value("kWh", p.energyKWh)
                            )
                            .foregroundStyle(accent)
                            .opacity(0.90)
                        }
                    }
                    .frame(height: 190)
                    .kwhInteractiveDataViz()

                    Text(trendMode == .cost && hasAnyCost
                         ? "Line = cost per day (only days with known cost)."
                         : "Bars = kWh per day.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private struct DDShift_DailyPoint: Identifiable, Hashable {
        let id: Date
        let day: Date
        let energyKWh: Double
        let cost: Double
    }

    private func dailyPoints(from sessions: [DeepDepthSession]) -> [DDShift_DailyPoint] {
        guard !sessions.isEmpty else { return [] }
        let cal = Calendar.current

        var map: [Date: (kwh: Double, cost: Double)] = [:]
        for s in sessions {
            let day = cal.startOfDay(for: s.start)
            var cur = map[day] ?? (0, 0)
            let kwh = (s.energyKWh.isFinite ? max(0, s.energyKWh) : 0)
            let cost = ((s.cost ?? 0).isFinite ? max(0, s.cost ?? 0) : 0)
            cur.kwh += kwh
            cur.cost += cost
            map[day] = cur
        }

        return map.keys.sorted().map { day in
            let v = map[day] ?? (0, 0)
            return DDShift_DailyPoint(id: day, day: day, energyKWh: v.kwh, cost: v.cost)
        }
    }

    // MARK: - Quality (NO invalid ranges)

    private var qualityCard: some View {
        let qc = Self.qualityChecks(for: visibleSessionsSorted)

        return DDShiftCard(isGlass: isGlass, theme: T) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Data Quality").font(.headline)
                    Spacer()
                    Text("\(qc.issues.count) issue(s)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if qc.issues.isEmpty {
                    Label("No issues detected in this window.", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(qc.issues, id: \.self) { issue in
                        Label(issue, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private struct DDShift_QualityReport: Hashable {
        var issues: [String] = []
    }

    private static func qualityChecks(for sessions: [DeepDepthSession]) -> DDShift_QualityReport {
        var issues: [String] = []

        let missingCost = sessions.filter { $0.cost == nil }.count
        if missingCost > 0 { issues.append("\(missingCost) session(s) have missing cost.") }

        let zeroEnergy = sessions.filter { $0.energyKWh == 0 }.count
        if zeroEnergy > 0 { issues.append("\(zeroEnergy) session(s) have 0 kWh (possible logging gap).") }

        let negativeMiles = sessions.filter { $0.miles < 0 }.count
        if negativeMiles > 0 { issues.append("\(negativeMiles) session(s) have negative miles (bad source data).") }

        // ✅ FIX: NEVER do `for i in 1..<sorted.count` (can trap when count == 0).
        let sorted = sessions.sorted(by: { $0.start < $1.start })
        var overlaps = 0
        if sorted.count >= 2 {
            for i in sorted.indices.dropFirst() {
                if sorted[i].start < sorted[sorted.index(before: i)].end { overlaps += 1 }
            }
        }
        if overlaps > 0 { issues.append("\(overlaps) overlapping session(s) detected (dedupe/merge recommended).") }

        return DDShift_QualityReport(issues: issues)
    }

    // MARK: - Sessions list

    private var sessionsCard: some View {
        DDShiftCard(isGlass: isGlass, theme: T) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Sessions").font(.headline)
                    Spacer()
                    Text("\(visibleSessionsSorted.count)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if visibleSessionsSorted.isEmpty {
                    Text("No sessions in this window.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(visibleSessionsSorted, id: \.self) { s in
                            sessionRow(s)
                            Divider().opacity(0.20)
                        }
                    }
                }
            }
        }
    }

    private func sessionRow(_ s: DeepDepthSession) -> some View {
        let minutes = max(0, s.end.timeIntervalSince(s.start) / 60.0)
        let costPer = (s.cost != nil && s.energyKWh > 0) ? ((s.cost ?? 0) / s.energyKWh) : nil

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(s.start, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.subheadline.weight(.semibold))
                Text("→").foregroundStyle(.secondary)
                Text(s.end, format: .dateTime.hour().minute())
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(s.isSupercharging ? "Supercharger" : "Other")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(T.pillTint.opacity(0.30), in: Capsule(style: .continuous))
            }

            HStack(spacing: 12) {
                Label(fmtNumber(s.energyKWh, digits: 1) + " kWh", systemImage: "bolt")
                if let cost = s.cost {
                    Label(fmtCurrency(cost), systemImage: "dollarsign.circle")
                } else {
                    Label("Cost unknown", systemImage: "questionmark.circle")
                        .foregroundStyle(.secondary)
                }
                Label(fmtNumber(s.miles, digits: 1) + " mi", systemImage: "car")
                Label(fmtNumber(minutes, digits: 0) + " min", systemImage: "clock")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let costPer {
                Text("$ / kWh: " + fmtCurrency(costPer))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var footerCard: some View {
        DDShiftCard(isGlass: isGlass, theme: T) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tip").font(.headline)
                Text("If you see overlaps or missing cost, your upstream source may need deduping or better cost attribution.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Visible sessions (filter/search/sort)

    private var visibleSessionsSorted: [DeepDepthSession] {
        var list: [DeepDepthSession]
        switch filter {
        case .all: list = sessions
        case .superchargingOnly: list = sessions.filter { $0.isSupercharging }
        case .nonSuperchargingOnly: list = sessions.filter { !$0.isSupercharging }
        }

        if showOnlyMissingCost { list = list.filter { $0.cost == nil } }

        let tokens = searchQuery.ddshift_tokens()
        if !tokens.isEmpty {
            list = list.filter { s in
                let hay = sessionSearchBlob(s).ddshift_normalized()
                return tokens.allSatisfy { hay.contains($0) }
            }
        }

        return list.sorted {
            if $0.start != $1.start { return $0.start > $1.start }
            if $0.end != $1.end { return $0.end > $1.end }
            if $0.energyKWh != $1.energyKWh { return $0.energyKWh > $1.energyKWh }
            return $0.miles > $1.miles
        }
    }

    private func sessionSearchBlob(_ s: DeepDepthSession) -> String {
        let type = s.isSupercharging ? "supercharger supercharg sc dcfc fast" : "other home level2 l2"
        let cost = (s.cost == nil) ? "missing cost unknown" : "has cost"
        return "\(type) \(cost) \(fmtNumber(s.energyKWh, digits: 2)) kwh \(fmtNumber(s.miles, digits: 2)) mi"
    }

    // MARK: - Window (no ClosedRange creation)

    private var window: (Date, Date) {
        let now = Date()
        switch rangePreset {
        case .last7Days:
            let start = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            return ordered(start, now)
        case .last31Days:
            let start = Calendar.current.date(byAdding: .day, value: -31, to: now) ?? now
            return ordered(start, now)
        case .custom:
            return ordered(customStart, customEnd)
        }
    }

    private func ordered(_ a: Date, _ b: Date) -> (Date, Date) {
        (min(a, b), max(a, b))
    }

    private var windowLabel: String {
        let (s, e) = window
        return "\(s.formatted(date: .abbreviated, time: .omitted)) – \(e.formatted(date: .abbreviated, time: .omitted))"
    }

    // MARK: - Reload (endExclusive > start ALWAYS)

    private func reload() async {
        guard let provider else { return }

        lastError = nil
        isLoading = true
        defer { isLoading = false }

        let cal = Calendar.current
        let (rawS, rawE) = window

        let start = cal.startOfDay(for: rawS)
        let endDay = cal.startOfDay(for: rawE)

        var endExclusive = cal.date(byAdding: .day, value: 1, to: endDay) ?? endDay.addingTimeInterval(86_400)
        if endExclusive <= start {
            endExclusive = start.addingTimeInterval(86_400)
        }

        let fetched = await provider.fetch(start, endExclusive)

        let cleaned = fetched
            .filter { $0.end >= $0.start }
            .filter { $0.energyKWh.isFinite && $0.energyKWh >= 0 }
            .filter { $0.miles.isFinite }
            .filter { ($0.cost ?? 0).isFinite }

        let unique = Array(Set(cleaned)).sorted { $0.start < $1.start }

        sessions = unique
        lastUpdated = Date()
    }

    // MARK: - Summary model

    private struct DDShift_Summary {
        var totalEnergyKWh: Double
        var totalCost: Double
        var totalMiles: Double
        var missingCostCount: Int

        var costPerKWh: Double? { totalEnergyKWh > 0 && totalCost > 0 ? (totalCost / totalEnergyKWh) : nil }
        var milesPerKWh: Double? { totalEnergyKWh > 0 ? (totalMiles / totalEnergyKWh) : nil }

        init(from sessions: [DeepDepthSession]) {
            totalEnergyKWh = sessions.reduce(0) { $0 + max(0, $1.energyKWh) }
            totalCost = sessions.reduce(0) { $0 + max(0, $1.cost ?? 0) }
            totalMiles = sessions.reduce(0) { $0 + max(0, $1.miles) }
            missingCostCount = sessions.filter { $0.cost == nil }.count
        }
    }

    // MARK: - Formatting

    private enum DDShift_Fmt {
        static func decimal(_ digits: Int) -> NumberFormatter {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.maximumFractionDigits = digits
            f.minimumFractionDigits = 0
            return f
        }

        static let currency: NumberFormatter = {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.maximumFractionDigits = 2
            return f
        }()
    }

    private func fmtNumber(_ v: Double, digits: Int) -> String {
        let f = DDShift_Fmt.decimal(digits)
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    private func fmtCurrency(_ v: Double) -> String {
        let f = DDShift_Fmt.currency
        f.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return f.string(from: NSNumber(value: v)) ?? "$\(v)"
    }

    // MARK: - Local enums (unique names)

    private enum DDShift_RangePreset: Hashable, CaseIterable, Identifiable {
        case last7Days, last31Days, custom
        var id: String { title }
        var title: String {
            switch self {
            case .last7Days: return "7D"
            case .last31Days: return "31D"
            case .custom: return "Custom"
            }
        }
    }

    private enum DDShift_Filter: Hashable, CaseIterable, Identifiable {
        case all, superchargingOnly, nonSuperchargingOnly
        var id: String { title }
        var title: String {
            switch self {
            case .all: return "All"
            case .superchargingOnly: return "SC"
            case .nonSuperchargingOnly: return "Other"
            }
        }
    }

    private enum DDShift_TrendMode: Hashable, CaseIterable, Identifiable {
        case energy, cost
        var id: String { title }
        var title: String { self == .energy ? "Energy" : "Cost" }
    }
}

// MARK: - Themed Card

fileprivate struct DDShiftCard<Content: View>: View {
    let isGlass: Bool
    let theme: any AppThemeSpec
    let padding: CGFloat
    @ViewBuilder var content: Content

    init(isGlass: Bool, theme: any AppThemeSpec, padding: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.isGlass = isGlass
        self.theme = theme
        self.padding = padding
        self.content = content()
    }

    private var surface: AnyShapeStyle {
        isGlass ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(theme.cardBackground)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(padding)
        .background(surface, in: RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                .strokeBorder(theme.separator.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: theme.elevation + 1, x: 0, y: 3)
    }
}

// MARK: - Token search normalization (unique names)

fileprivate extension String {
    func ddshift_normalized() -> String {
        let folded = self.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        let cleanedScalars = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return Character(scalar)
            } else {
                return " "
            }
        }

        let cleaned = String(cleanedScalars)
        return cleaned
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func ddshift_tokens() -> [String] {
        let norm = self.ddshift_normalized()
        guard !norm.isEmpty else { return [] }
        return norm.split(separator: " ").map { String($0) }
    }
}
