//
//  FastVsHomeImpactView.swift
//  KWh Gas Companion
//
//  Home vs DC Fast charging impact (cost + mix) from ExpenseEntry logs.
//  - Theme-driven background + cards (AppThemeSpec via appThemeBox)
//  - Window picker (3/6/12/24/36 months)
//  - More robust classification (looks at chargeType/location/notes/category)
//  - Includes “Unknown” in charts + metrics so you can see what isn’t classified
//  - Charts are guarded with canImport(Charts)
//
//  Swift 6 • iOS 17+
//

import SwiftUI
#if canImport(Charts)
import Charts
#endif

@MainActor
struct FastVsHomeImpactView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.appThemeBox) private var themeBox
    @EnvironmentObject private var entriesStore: EntriesStore

    @State private var monthsWindow: Int = 12

    private let windowOptions: [Int] = [3, 6, 12, 24, 36]

    // MARK: - Derived data

    private var energySessions: [ExpenseEntry] {
        entriesStore.entries
            .filter { $0.isEnergy && ($0.energyKWh ?? 0) > 0 }
            .sorted { $0.date < $1.date }
    }

    private var windowed: [ExpenseEntry] {
        guard monthsWindow > 0 else { return energySessions }
        let cal = Calendar.current
        let startOfThisMonth = cal.startOfMonth(for: Date())
        let cutoff = cal.date(byAdding: .month, value: -monthsWindow + 1, to: startOfThisMonth) ?? .distantPast
        return energySessions.filter { $0.date >= cutoff }
    }

    // MARK: - Classification

    enum ChargeKind: String, CaseIterable, Identifiable {
        case home = "Home"
        case fast = "Fast"
        case other = "Unknown"
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .fast: return "bolt.car"
            case .other: return "questionmark.circle"
            }
        }
    }

    private func classify(_ e: ExpenseEntry) -> ChargeKind {
        let text = [
            e.chargeType?.lowercased(),
            e.location?.lowercased(),
            e.notes?.lowercased(),
            e.category.lowercased()
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        // Home-ish (AC / Level 2)
        let homeKeys = [
            "home", "garage", "wall", "wall connector", "wallbox", "chargepoint home",
            "level 2", "lvl2", "l2", "ac", "destination", "dryer", "nema", "14-50"
        ]

        // Fast-ish (DCFC / Supercharging / public networks)
        let fastKeys = [
            "fast", "dc", "dcfc", "l3", "level 3", "ccs", "nacs",
            "super", "supercharger", "v2", "v3", "v4",
            "electrify america", "evgo", "chargepoint dc", "flo", "shell recharge", "blink dc",
            "rivian adventure", "rivian", "ran",
            "ultium", "gmc", "hummer", "cadillac",
            "tesla"
        ]

        if homeKeys.contains(where: { text.contains($0) }) { return .home }
        if fastKeys.contains(where: { text.contains($0) }) { return .fast }
        return .other
    }

    // MARK: - Aggregates

    private var sessionsByKind: [ChargeKind: [ExpenseEntry]] {
        Dictionary(grouping: windowed, by: classify)
    }

    private func totals(for kind: ChargeKind) -> (kwh: Double, cost: Double, count: Int) {
        let set = sessionsByKind[kind] ?? []
        let kwh = set.reduce(0.0) { $0 + ($1.energyKWh ?? 0) }
        let cost = set.reduce(0.0) { $0 + $1.amount }
        return (kwh, cost, set.count)
    }

    private var homeTotals: (kwh: Double, cost: Double, count: Int) { totals(for: .home) }
    private var fastTotals: (kwh: Double, cost: Double, count: Int) { totals(for: .fast) }
    private var unknownTotals: (kwh: Double, cost: Double, count: Int) { totals(for: .other) }

    private var totalKWhAll: Double { homeTotals.kwh + fastTotals.kwh + unknownTotals.kwh }
    private var totalKWhClassified: Double { homeTotals.kwh + fastTotals.kwh }

    private var homeCPK: Double? { homeTotals.kwh > 0 ? (homeTotals.cost / homeTotals.kwh) : nil }
    private var fastCPK: Double? { fastTotals.kwh > 0 ? (fastTotals.cost / fastTotals.kwh) : nil }

    /// Extra cost vs charging the same FAST kWh at the HOME $/kWh
    private var extraCostVsHome: Double? {
        guard let h = homeCPK, fastTotals.kwh > 0 else { return nil }
        let altCost = fastTotals.kwh * h
        return fastTotals.cost - altCost
    }

    private var fastSharePctAll: Double {
        guard totalKWhAll > 0 else { return 0 }
        return (fastTotals.kwh / totalKWhAll) * 100.0
    }

    private var fastSharePctClassified: Double {
        guard totalKWhClassified > 0 else { return 0 }
        return (fastTotals.kwh / totalKWhClassified) * 100.0
    }

    // MARK: - Monthly data (stacked)

    private struct MonthSegment: Identifiable, Hashable {
        let month: Date
        let kind: ChargeKind
        let kwh: Double
        var id: String { "\(month.timeIntervalSince1970)|\(kind.rawValue)" }
    }

    private var monthSegments: [MonthSegment] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: windowed) { e in cal.startOfMonth(for: e.date) }

        var out: [MonthSegment] = []
        for m in grouped.keys.sorted() {
            let set = grouped[m] ?? []
            for kind in ChargeKind.allCases {
                let kwh = set
                    .filter { classify($0) == kind }
                    .reduce(0.0) { $0 + ($1.energyKWh ?? 0) }
                out.append(MonthSegment(month: m, kind: kind, kwh: kwh))
            }
        }
        // Remove months that are all zero (rare, but safe)
        return out.filter { $0.kwh > 0 }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                controls

                if windowed.isEmpty {
                    EmptyStateCard(
                        title: "No charging data",
                        message: "Add charging entries with kWh (and cost) to compare Home vs Fast charging."
                    )
                } else {
                    metricsGrid
                    costImpactCard
                    priceComparisonCard
                    monthlyStackedCard
                    classificationHelpCard
                }
            }
            .padding(16)
        }
        .background(themedBackground.ignoresSafeArea())
        .navigationTitle("Fast vs Home Impact")
        .toolbarTitleDisplayMode(.inline)
    }

    // MARK: - UI

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

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Fast vs Home")
                .font(.title.bold())

            Text("\(monthsWindow)-month view • \(windowed.count) session\(windowed.count == 1 ? "" : "s")")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Classification uses charge type, location, notes, and category keywords.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controls: some View {
        let t = themeBox.base

        return HStack(spacing: 10) {
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

    private var metricsGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                MetricPill(title: "Home $/kWh", value: homeCPK.map(currencyShort) ?? "—", icon: ChargeKind.home.icon)
                MetricPill(title: "Fast $/kWh", value: fastCPK.map(currencyShort) ?? "—", icon: ChargeKind.fast.icon)
            }
            HStack(spacing: 12) {
                MetricPill(title: "Fast share (all)", value: percentShort(fastSharePctAll), icon: "chart.pie.fill")
                MetricPill(title: "Unknown kWh", value: numberShort(unknownTotals.kwh, 0), icon: ChargeKind.other.icon)
            }
            if totalKWhClassified > 0 {
                HStack(spacing: 12) {
                    MetricPill(title: "Fast share (classified)", value: percentShort(fastSharePctClassified), icon: "scope")
                    MetricPill(title: "Sessions", value: "\(windowed.count)", icon: "list.bullet.rectangle")
                }
            }
        }
    }

    private var costImpactCard: some View {
        Card(title: "Cost Impact", subtitle: "Fast vs Home (same kWh)") {
            let delta = extraCostVsHome

            HStack(spacing: 12) {
                MetricPill(title: "Fast kWh", value: numberShort(fastTotals.kwh, 0), icon: "bolt.fill")
                MetricPill(
                    title: "Extra vs Home",
                    value: delta.map(currencyShort) ?? "—",
                    icon: delta.map { $0 >= 0 ? "arrow.up.right" : "arrow.down.right" } ?? "arrow.right"
                )
            }

            if let d = delta {
                Text(d >= 0
                     ? "You spent \(currencyShort(d)) more than charging those kWh at your Home $/kWh."
                     : "You saved \(currencyShort(-d)) versus charging those kWh at your Home $/kWh.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else {
                Text("To estimate impact, you need some Home sessions (to compute Home $/kWh) and some Fast kWh.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var priceComparisonCard: some View {
        Card(title: "Average Price", subtitle: "$/kWh by kind") {
            #if canImport(Charts)
            let rows: [PriceRow] = [
                PriceRow(kind: .home, value: homeCPK),
                PriceRow(kind: .fast, value: fastCPK)
            ].compactMap { $0.value == nil ? nil : $0 }

            if rows.isEmpty {
                NoChartData()
            } else {
                Chart(rows) { r in
                    BarMark(
                        x: .value("Kind", r.kind.rawValue),
                        y: .value("\u{0024}/kWh", r.value ?? 0)
                    )
                    .foregroundStyle(by: .value("Kind", r.kind.rawValue))
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 220)
                .kwhInteractiveDataViz()
                .accessibilityLabel("Average price comparison chart")
            }
            #else
            Text("Charts not available in this build.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            #endif
        }
    }

    private var monthlyStackedCard: some View {
        Card(title: "Monthly kWh", subtitle: "Home + Fast + Unknown (stacked)") {
            #if canImport(Charts)
            if monthSegments.isEmpty {
                NoChartData()
            } else {
                Chart(monthSegments) { s in
                    BarMark(
                        x: .value("Month", s.month, unit: .month),
                        y: .value("kWh", s.kwh)
                    )
                    .foregroundStyle(by: .value("Kind", s.kind.rawValue))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { v in
                        if let d = v.as(Date.self) {
                            AxisValueLabel { Text(d, format: .dateTime.month(.abbreviated)) }
                        }
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 290)
                .kwhInteractiveDataViz()
                .accessibilityLabel("Monthly stacked kilowatt-hour chart")
            }
            #else
            Text("Charts not available in this build.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            #endif
        }
    }

    private var classificationHelpCard: some View {
        Card(title: "Improve classification", subtitle: nil) {
            VStack(alignment: .leading, spacing: 8) {
                if unknownTotals.count > 0 {
                    Text("You have \(unknownTotals.count) unclassified session\(unknownTotals.count == 1 ? "" : "s") in this window.")
                        .font(.subheadline.weight(.semibold))
                }

                Text("Tips:")
                    .font(.subheadline.weight(.semibold))

                VStack(alignment: .leading, spacing: 6) {
                    TipRow("Set chargeType to “Home” or “Supercharger / DCFC”.")
                    TipRow("Put network names in location/notes (e.g., “Electrify America”, “EVgo”, “Rivian Adventure Network”).")
                    TipRow("Use category labels like “Home Charging” or “Fast Charging”.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Small types

    private struct PriceRow: Identifiable {
        let kind: ChargeKind
        let value: Double?
        var id: String { kind.rawValue }
    }

    // MARK: - Formatting

    private func currencyShort(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = Locale.current.currency?.identifier ?? "USD"
        f.maximumFractionDigits = abs(v) < 1 ? 3 : 2
        return f.string(from: NSNumber(value: v)) ?? "$0.00"
    }

    private func numberShort(_ v: Double, _ digits: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = digits
        f.minimumFractionDigits = digits
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    private func percentShort(_ pct: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: pct / 100.0)) ?? "0%"
    }
}

// MARK: - Theme-driven card + pills (file-local)

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
    @Environment(\.appThemeBox) private var themeBox
    let title: String
    let message: String

    var body: some View {
        let t = themeBox.base
        VStack(spacing: 10) {
            Image(systemName: "bolt.slash")
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
                .fill(t.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: t.corner, style: .continuous)
                .strokeBorder(t.separator.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct NoChartData: View {
    @Environment(\.appThemeBox) private var themeBox

    var body: some View {
        let t = themeBox.base
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .imageScale(.large)
                .foregroundStyle(.secondary)
            Text("No chartable data")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(
            RoundedRectangle(cornerRadius: t.smallCorner, style: .continuous)
                .fill(t.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: t.smallCorner, style: .continuous)
                .strokeBorder(t.separator.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct TipRow: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "checkmark.seal")
                .foregroundStyle(.secondary)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension Calendar {
    func startOfMonth(for d: Date) -> Date {
        let comps = dateComponents([.year, .month], from: d)
        return date(from: comps) ?? d
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        FastVsHomeImpactView()
            .environmentObject(EntriesStore())
    }
    .appTheme(DefaultAppTheme())
}
#endif
