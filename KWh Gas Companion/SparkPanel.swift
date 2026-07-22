//
//  SparkPanel.swift
//  My KWh Companion — Spark
//
//  Manual-run summary panel that merges SparkShiftStore + EntriesStore energy transactions,
//  shows BOTH 7d and 31d rolling windows (DST-safe), and provides Forecast/Trends/Anomalies/Sites.
//  - No auto-run on appear or on data changes (explicit "Run" button only)
//  - Applies logic to different expense kinds (Supercharger / Home / Public / Other)
//  - Uses lightweight EntryLite to avoid tight coupling
//
//  iOS 17+ / Swift 6
//  Regenerated: Oct 27, 2025
//

import SwiftUI
import Foundation
import Charts
#if canImport(UIKit)
import UIKit
#endif

// MARK: - DST-safe calendar (nonisolated to avoid MainActor access issues)

fileprivate var dstCalendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = .current
    return c
}

fileprivate let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - SparkPanel

@MainActor
public struct SparkPanel: View {
    // Primary source (required)
    @ObservedObject public var shiftStore: SparkShiftStore

    // Also read unified expenses (required for proper coverage)
    @EnvironmentObject private var entriesStore: EntriesStore

    // Optional extra sources (safe defaults)
    public var loadEntriesFromEntriesStore: () -> [Any] = { [] }  // legacy hook
    public var loadRates:                 () -> [Any] = { [] }
    public var loadBudgetItems:           () -> [Any] = { [] }
    public var loadTripShifts:            () -> [Any] = { [] }
    public var loadVehicleProfiles:       () -> [Any] = { [] }

    // Assistant (LLM) engine — defaults to local heuristic coach.
    public let assistantEngine: any SparkAssistantProviding

    // UI state
    @State private var mode: PanelMode = .summary
    @State private var resultText: String = "Tap Run to analyze your recent driving and charging."
    @State private var evidence: [Evidence] = []
    @State private var chartData: ChartData? = nil
    @State private var assistantResponse: SparkAssistantResponse? = nil
    @State private var assistantErrorText: String? = nil
    @State private var lastAssistantReport: SparkReport? = nil
    @State private var isRunning: Bool = false

    // Diagnostics
    @State private var lastRunCount: Int = 0
    @State private var sourceCounts: [String: Int] = [:]
    @State private var windowCounts: (d7: Int, d31: Int) = (0, 0)

    // History
    @State private var autoSaveResults: Bool = true
    @State private var history: [SavedResult] = SavedResultStore.load()

    // Toast (inline, unique to this file to avoid name collisions)
    @State private var isToastPresented = false
    @State private var toastMessage = ""

    public init(shiftStore: SparkShiftStore, assistantEngine: any SparkAssistantProviding = LocalSparkAssistantEngine()) {
        self.shiftStore = shiftStore
        self.assistantEngine = assistantEngine
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HeaderView(isRunning: isRunning,
                           lastRunCount: lastRunCount,
                           windowCounts: windowCounts)

                ModePickerView(mode: $mode)

                ResultsArea(mode: mode,
                            resultText: resultText,
                            evidence: evidence,
                            chartData: chartData,
                            assistantResponse: assistantResponse,
                            assistantErrorText: assistantErrorText,
                            lastRunCount: lastRunCount,
                            sourceCounts: sourceCounts)

                ActionRow(
                    isRunning: isRunning,
                    canCopy: !resultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    runTapped: { Task { await run() } },
                    copyTapped: {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = resultText
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        showToast("Result copied")
                    }
                )

                HistorySection(history: $history, deleteAction: { item in
                    if let idx = history.firstIndex(of: item) {
                        history.remove(at: idx)
                        SavedResultStore.save(history)
                        showToast("Deleted from history")
                    }
                })
            }
            .navigationTitle("Spark")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle(isOn: $autoSaveResults) {
                            Label("Auto-save results", systemImage: autoSaveResults ? "checkmark.circle.fill" : "circle")
                        }
                        if !history.isEmpty {
                            Button(role: .destructive) {
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                                history.removeAll()
                                SavedResultStore.save(history)
                                showToast("History cleared")
                            } label: {
                                Label("Clear History", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Options")
                }
            }
            .overlay(alignment: .bottom) {
                if isToastPresented {
                    InlineToast(text: toastMessage)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isToastPresented)
        }
    }

    // MARK: - Actions

    private func run() async {
        isRunning = true
        defer { isRunning = false }

        resultText = "Analyzing…"
        evidence.removeAll()
        chartData = nil
        assistantResponse = nil
        assistantErrorText = nil
        lastAssistantReport = nil

        // Snapshot counts for diagnostics
        let shiftCount = shiftStore.entries.count
        let expenseCount = entriesStore.entries.count

        let otherA = loadEntriesFromEntriesStore()
        let otherB = loadTripShifts()
        let otherC = loadBudgetItems()
        let otherD = loadRates()
        let otherE = loadVehicleProfiles()

        sourceCounts = [
            "Spark Shifts": shiftCount,
            "EntriesStore (all)": expenseCount,
            "Legacy hook": otherA.count,
            "TripShiftStore": otherB.count,
            "BudgetStore": otherC.count,
            "RatesStore": otherD.count,
            "VehicleProfile": otherE.count
        ]

        // Build the merged list we analyze everywhere (applies logic to expense *kinds*)
        let merged = makeMergedLite(
            shifts: shiftStore.entries,
            expenses: entriesStore.entries,  // includes CSV + manual
            extras: [otherA, otherB, otherC, otherD, otherE]
        )

        lastRunCount = merged.count
        windowCounts = windowEntryCountsLite(merged)

        guard !merged.isEmpty else {
            resultText = joinLines([
                "No entries available to analyze.",
                "",
                "Spark scanned your connected sources:",
                "• Spark Shifts: \(shiftCount)",
                "• EntriesStore (all): \(expenseCount)",
                "• Legacy hook: \(otherA.count)",
                "• TripShiftStore: \(otherB.count)",
                "• BudgetStore: \(otherC.count)",
                "• RatesStore: \(otherD.count)",
                "• VehicleProfile: \(otherE.count)",
                "",
                "To get started:",
                "1) Add a shift/drive or charging expense (CSV/manual).",
                "2) Tap **Run**."
            ])
            showToast("No entries found")
            return
        }

        // Compute
        let txt: String
        let ev: [Evidence]
        let cd: ChartData?

        switch mode {
        case .assistant:
            let report = buildSparkReport(from: merged, sourceCounts: sourceCounts)
            lastAssistantReport = report
            do {
                let resp = try await assistantEngine.respond(to: report, userQuery: nil)
                assistantResponse = resp
                assistantErrorText = nil
                (txt, ev, cd) = assistantPresentation(report: report, response: resp)
            } catch {
                assistantResponse = nil
                assistantErrorText = error.localizedDescription
                (txt, ev, cd) = assistantFailurePresentation(report: report, errorText: assistantErrorText ?? "Unknown error")
            }

        case .summary:
            (txt, ev, cd) = summarizeMergedWindows(merged)
        case .forecast:
            (txt, ev, cd) = forecast(merged)
        case .trends:
            (txt, ev, cd) = trends(merged)
        case .anomalies:
            (txt, ev, cd) = anomalies(merged)
        case .sites:
            (txt, ev, cd) = sites(merged)
        }

        resultText = txt
        evidence = ev
        chartData = cd
        showToast("Analyzed \(merged.count) entr\(merged.count == 1 ? "y" : "ies")")

        if autoSaveResults {
            let preview = txt.split(separator: "\n").prefix(2).joined(separator: " ")
            history.insert(SavedResult(timestamp: Date(), mode: mode, preview: String(preview)), at: 0)
            let cap = 25
            if history.count > cap { history.removeSubrange(cap..<history.count) }
            SavedResultStore.save(history)
        }
    }

    // MARK: - Assistant helpers

    private func assistantPresentation(report: SparkReport, response: SparkAssistantResponse) -> (String, [Evidence], ChartData?) {
        var ev: [Evidence] = []
        ev.append(Evidence(source: "Assistant", reference: "v1", summary: "Generated a structured coaching summary from SparkReport"))
        if let w31 = report.window31 {
            ev.append(Evidence(source: "SparkReport", reference: "31d",
                               summary: "Entries \(w31.entryCount); costKnown \(w31.coverage.costKnownCount)/\(w31.entryCount); kWhKnown \(w31.coverage.kWhKnownCount)/\(w31.entryCount)"))
        }
        if !report.topSitesBySpend.isEmpty {
            let top = report.topSitesBySpend[0]
            ev.append(Evidence(source: "SparkReport", reference: "topSite",
                               summary: String(format: "Top spend %@: $%.2f over %d visits", top.name, top.totalCost, top.visits)))
        }
        if !report.anomalies.isEmpty {
            ev.append(Evidence(source: "SparkReport", reference: "anomalies",
                               summary: "\(report.anomalies.count) outlier(s) detected (MAD z-score)"))
        }

        // Chart: show top spend sites (if available)
        var cd: ChartData? = nil
        let items = report.topSitesBySpend.prefix(6).map { ($0.name, $0.totalCost) }.filter { $0.1.isFinite && $0.1 > 0 }
        if !items.isEmpty {
            cd = ChartData(type: .bar, items: items)
        }

        return (response.renderAsText(), ev, cd)
    }

    private func assistantFailurePresentation(report: SparkReport, errorText: String) -> (String, [Evidence], ChartData?) {
        var ev: [Evidence] = []
        ev.append(Evidence(source: "Assistant", reference: "error", summary: errorText))
        if let w31 = report.window31 {
            ev.append(Evidence(source: "SparkReport", reference: "31d", summary: "Entries \(w31.entryCount)"))
        }
        let fallback = joinLines([
            "Assistant failed to generate a response.",
            errorText,
            "",
            "You can still use Summary/Forecast/Trends/Anomalies/Sites modes."
        ])
        return (fallback, ev, nil)
    }

    private func buildSparkReport(from entries: [EntryLite], sourceCounts: [String: Int]) -> SparkReport {
        let window7  = buildWindow(entries: entries, days: 7)
        let window31 = buildWindow(entries: entries, days: 31)

        let sites = buildTopSites(entries: entries, limit: 8)
        let anomalies = buildAnomalies(entries: entries, limit: 12)

        return SparkReport(
            generatedAt: Date(),
            sourceCounts: sourceCounts,
            window7: window7,
            window31: window31,
            topSitesBySpend: sites,
            anomalies: anomalies
        )
    }

    private func buildWindow(entries: [EntryLite], days: Int) -> SparkReport.WindowSummary? {
        guard days >= 1 else { return nil }
        let cal = dstCalendar
        let now = Date()
        guard let today = cal.dateInterval(of: .day, for: now) else { return nil }
        let end = today.end
        let start = cal.date(byAdding: .day, value: -(days - 1), to: today.start) ?? today.start

        let window = entries.filter { $0.date >= start && $0.date < end }
        guard !window.isEmpty else { return nil }

        var totalCost = 0.0
        var totalKWh = 0.0
        var totalMiles = 0.0
        var costKnown = 0
        var kWhKnown = 0
        var milesKnown = 0
        var siteKnown = 0
        var kindKnown = 0

        for e in window {
            if let c = e.cost, c.isFinite {
                totalCost += max(0, c)
                costKnown += 1
            }
            if let k = e.energyKWh, k.isFinite {
                totalKWh += max(0, k)
                kWhKnown += 1
            }
            if let m = e.miles, m.isFinite {
                totalMiles += max(0, m)
                milesKnown += 1
            }
            if let s = e.site, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                siteKnown += 1
            }
            if let k = e.kind, !k.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                kindKnown += 1
            }
        }

        let avgWhMi = (totalMiles > 0 && totalKWh.isFinite) ? (totalKWh * 1000.0) / totalMiles : nil
        let avgPerKWh = (totalKWh > 0 && totalCost.isFinite) ? totalCost / totalKWh : nil

        var notes: [String] = []
        if let avgWhMi, avgWhMi > 330 {
            notes.append("Efficiency was on the high side (\(fmt(total: avgWhMi, 0)) Wh/mi).")
        }
        if costKnown < window.count {
            notes.append("Cost is missing for \(window.count - costKnown) entr\(window.count - costKnown == 1 ? "y" : "ies").")
        }
        if kWhKnown < window.count {
            notes.append("Energy (kWh) is missing for \(window.count - kWhKnown) entr\(window.count - kWhKnown == 1 ? "y" : "ies").")
        }

        return SparkReport.WindowSummary(
            days: days,
            start: start,
            end: end,
            entryCount: window.count,
            totalCost: totalCost.isFinite ? totalCost : nil,
            totalKWh: totalKWh.isFinite ? totalKWh : nil,
            totalMiles: totalMiles.isFinite ? totalMiles : nil,
            avgWhPerMile: avgWhMi,
            avgCostPerKWh: avgPerKWh,
            coverage: .init(costKnownCount: costKnown,
                            kWhKnownCount: kWhKnown,
                            milesKnownCount: milesKnown,
                            siteKnownCount: siteKnown,
                            kindKnownCount: kindKnown),
            notes: notes
        )
    }

    private func buildTopSites(entries: [EntryLite], limit: Int) -> [SparkReport.SiteSummary] {
        guard limit > 0 else { return [] }
        var buckets: [String: (visits: Int, totalCost: Double, totalKWh: Double)] = [:]

        for e in entries {
            let raw = e.site?.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = normalizeSite(raw)
            var b = buckets[key] ?? (0, 0, 0)
            b.visits += 1
            if let c = e.cost, c.isFinite { b.totalCost += max(0, c) }
            if let k = e.energyKWh, k.isFinite { b.totalKWh += max(0, k) }
            buckets[key] = b
        }

        var stats: [SparkReport.SiteSummary] = []
        stats.reserveCapacity(buckets.count)

        for (site, b) in buckets {
            let avg = (b.totalKWh > 0 && b.totalCost.isFinite) ? (b.totalCost / b.totalKWh) : nil
            stats.append(.init(name: site, visits: b.visits, totalCost: b.totalCost, totalKWh: b.totalKWh, avgCostPerKWh: avg))
        }

        stats.sort { $0.totalCost > $1.totalCost }
        if stats.count > limit { stats = Array(stats.prefix(limit)) }
        return stats
    }

    private func buildAnomalies(entries: [EntryLite], limit: Int) -> [SparkReport.AnomalySummary] {
        guard limit > 0 else { return [] }
        guard !entries.isEmpty else { return [] }

        var pkwhSeries: [(EntryLite, Double)] = []
        var costMiSeries: [(EntryLite, Double)] = []

        for e in entries {
            if let c = e.cost, let k = e.energyKWh, k > 0, c.isFinite, k.isFinite { pkwhSeries.append((e, c / k)) }
            if let c = e.cost, let m = e.miles, m > 0, c.isFinite, m.isFinite { costMiSeries.append((e, c / m)) }
        }

        func madZ(_ xs: [Double]) -> [Double] {
            let vals = xs.filter { $0.isFinite }
            let n = vals.count
            guard n > 0 else { return [] }
            let sorted = vals.sorted()
            let median = sorted[n / 2]
            var devs: [Double] = []
            devs.reserveCapacity(n)
            for v in vals { devs.append(abs(v - median)) }
            devs.sort()
            let mad = devs[n / 2]
            let denom = (mad == 0) ? 1e-9 : mad * 1.4826
            var out: [Double] = []
            out.reserveCapacity(n)
            for v in vals { out.append((v - median) / denom) }
            return out
        }

        var out: [SparkReport.AnomalySummary] = []

        if pkwhSeries.count >= 6 {
            let vals = pkwhSeries.map { $0.1 }
            let z = madZ(vals)
            for i in 0..<min(pkwhSeries.count, z.count) where abs(z[i]) >= 3.5 {
                let e = pkwhSeries[i].0
                out.append(.init(kind: .pricePerKWhSpike,
                                 date: e.date,
                                 entryId: e.id,
                                 site: normalizeSite(e.site),
                                 metric: "$/kWh",
                                 value: pkwhSeries[i].1,
                                 zScore: z[i]))
            }
        }

        if costMiSeries.count >= 6 {
            let vals = costMiSeries.map { $0.1 }
            let z = madZ(vals)
            for i in 0..<min(costMiSeries.count, z.count) where abs(z[i]) >= 3.5 {
                let e = costMiSeries[i].0
                out.append(.init(kind: .costPerMileOutlier,
                                 date: e.date,
                                 entryId: e.id,
                                 site: normalizeSite(e.site),
                                 metric: "$/mi",
                                 value: costMiSeries[i].1,
                                 zScore: z[i]))
            }
        }

        // Sort by absolute z-score (most extreme first)
        out.sort { abs($0.zScore) > abs($1.zScore) }
        if out.count > limit { out = Array(out.prefix(limit)) }
        return out
    }

    private func normalizeSite(_ s: String?) -> String {
        let raw = (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "(Unknown)" }

        // Collapse whitespace
        let parts = raw.split(whereSeparator: { $0.isWhitespace })
        let collapsed = parts.joined(separator: " ")

        // Normalize common suffixes
        let lower = collapsed.lowercased()
        if lower.hasSuffix(" supercharger") {
            return String(collapsed.dropLast(" supercharger".count))
        }
        return collapsed
    }

    private func showToast(_ message: String) {
        toastMessage = message
        isToastPresented = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { isToastPresented = false }
        }
    }
}

// MARK: - Modes

private enum PanelMode: String, CaseIterable, Identifiable, Codable {
    case assistant, summary, forecast, trends, anomalies, sites
    var id: String { rawValue }
    var title: String {
        switch self {
        case .assistant: return "Assistant"
        case .summary:   return "Summary"
        case .forecast:  return "Forecast"
        case .trends:    return "Trends"
        case .anomalies: return "Anomalies"
        case .sites:     return "Sites"
        }
    }
}

// MARK: - Evidence & Result Card

private struct Evidence: Identifiable, Hashable {
    let id = UUID()
    let source: String
    let reference: String
    let summary: String
}

private struct ResultsArea: View {
    let mode: PanelMode
    let resultText: String
    let evidence: [Evidence]
    let chartData: ChartData?
    let assistantResponse: SparkAssistantResponse?
    let assistantErrorText: String?
    let lastRunCount: Int
    let sourceCounts: [String: Int]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if mode == .assistant {
                    AssistantCard(response: assistantResponse,
                                  errorText: assistantErrorText,
                                  fallbackText: resultText,
                                  evidence: evidence)
                        .padding(.horizontal)
                } else {
                    ResultCard(text: resultText, evidence: evidence)
                        .padding(.horizontal)
                }

                ChartView(chartData: chartData)
                    .padding(.horizontal)

                if lastRunCount == 0 {
                    EmptyState(sourceCounts: sourceCounts)
                        .padding(.horizontal)
                        .transition(.opacity)
                }
            }
        }
    }
}

private struct ResultCard: View {
    let text: String
    let evidence: [Evidence]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.body)
                .privacySensitive()

            if !evidence.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Evidence")
                    .font(.subheadline.weight(.semibold))
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(evidence) { ev in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ev.summary)
                                Text("\(ev.source) — \(ev.reference)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Spark analysis result")
    }
}

// MARK: - Chart Support

// MARK: - Assistant Result Card

private struct AssistantCard: View {
    let response: SparkAssistantResponse?
    let errorText: String?
    let fallbackText: String
    let evidence: [Evidence]

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            if let response = response {
                Text(response.title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Text(response.headline)
                    .font(.body)
                    .privacySensitive()

                if !response.bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(response.bullets.enumerated()), id: \.offset) { _, b in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•").font(.body.weight(.semibold))
                                Text(b).font(.body)
                            }
                        }
                    }
                    .padding(.top, 2)
                }

                if !response.warnings.isEmpty {
                    Divider().padding(.vertical, 2)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Warnings")
                            .font(.subheadline.weight(.semibold))
                        ForEach(Array(response.warnings.enumerated()), id: \.offset) { _, w in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(w).font(.callout)
                            }
                        }
                    }
                }

                if !response.actions.isEmpty {
                    Divider().padding(.vertical, 2)
                    FlowButtonRow(actions: response.actions) { action in
                        guard let urlString = action.deeplink, let url = URL(string: urlString) else { return }
                        openURL(url)
                    }
                }

                if let dataUsed = response.dataUsed, !dataUsed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Divider().padding(.vertical, 2)
                    Text(dataUsed)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

            } else if let errorText = errorText {
                Text("Assistant unavailable")
                    .font(.headline)
                Text(errorText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Divider().padding(.vertical, 2)
                Text(fallbackText)
                    .font(.body)
                    .privacySensitive()
            } else {
                Text("Assistant")
                    .font(.headline)
                Text(fallbackText)
                    .font(.body)
                    .privacySensitive()
            }

            if !evidence.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Evidence")
                    .font(.subheadline.weight(.semibold))
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(evidence) { e in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(e.source) • \(e.reference)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(e.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

private struct FlowButtonRow: View {
    let actions: [SparkAssistantAction]
    let tapped: (SparkAssistantAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Actions")
                .font(.subheadline.weight(.semibold))
            FlexibleWrap(spacing: 8, lineSpacing: 8) {
                ForEach(actions) { a in
                    Button {
                        tapped(a)
                    } label: {
                        HStack(spacing: 6) {
                            if a.role == .primary {
                                Image(systemName: "sparkles")
                            }
                            Text(a.title)
                        }
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(a.role == .primary ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.thinMaterial),
                                    in: Capsule())
                        .foregroundStyle(a.role == .primary ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.primary))
                    }
                    .disabled(a.deeplink == nil)
                    .opacity(a.deeplink == nil ? 0.5 : 1.0)
                }
            }
        }
    }
}

private struct FlexibleWrap<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder var content: () -> Content

    init(spacing: CGFloat, lineSpacing: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content
    }

    var body: some View {
        _FlexibleWrapLayout(spacing: spacing, lineSpacing: lineSpacing) {
            content()
        }
    }
}

private struct _FlexibleWrapLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            s.place(at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

enum ChartType: Equatable { case bar, line }

fileprivate struct ChartData: Equatable {
    let type: ChartType
    let items: [(String, Double)]
    static func == (lhs: ChartData, rhs: ChartData) -> Bool {
        guard lhs.type == rhs.type, lhs.items.count == rhs.items.count else { return false }
        for (a, b) in zip(lhs.items, rhs.items) { if a.0 != b.0 || a.1 != b.1 { return false } }
        return true
    }
}

fileprivate struct ChartView: View {
    let chartData: ChartData?

    var body: some View {
        Group {
            if let cd = chartData {
                let items = cd.items
                    .map { ($0.0, max(0, $0.1)) }
                    .filter { $0.1.isFinite && $0.1 > 0 }

                if !items.isEmpty {
                    Chart {
                        ForEach(0..<items.count, id: \.self) { i in
                            let item = items[i]
                            switch cd.type {
                            case .line:
                                LineMark(x: .value("X", item.0), y: .value("Y", item.1))
                            case .bar:
                                BarMark(x: .value("X", item.0), y: .value("Y", item.1))
                            }
                        }
                    }
                    .frame(height: 200)
                    .chartXAxis { AxisMarks() }
                    .chartYAxis { AxisMarks() }
                    .kwhInteractiveDataViz()
                    .accessibilityLabel(cd.type == .line ? "Line chart" : "Bar chart")
                    .accessibilityValue("\(items.count) data points")
                }
            }
        }
    }
}

// MARK: - Header / Picker / Actions / History

private struct HeaderView: View {
    let isRunning: Bool
    let lastRunCount: Int
    let windowCounts: (d7: Int, d31: Int)

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Label("Local Analytics", systemImage: "bolt.circle")
                .font(.headline)
            Spacer()
            if isRunning {
                ProgressView().accessibilityLabel("Analyzing")
            } else {
                let suffix = (windowCounts.d7 > 0 || windowCounts.d31 > 0)
                ? " (7d: \(windowCounts.d7), 31d: \(windowCounts.d31))"
                : ""
                Text(lastRunCount > 0 ? "Entries analyzed: \(lastRunCount)\(suffix)" : "No results yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(lastRunCount > 0 ? "Entries analyzed \(lastRunCount)" : "No results yet")
            }
        }
        .padding([.top, .horizontal])
    }
}

private struct ModePickerView: View {
    @Binding var mode: PanelMode
    var body: some View {
        ViewThatFits {
            Picker("Mode", selection: $mode) {
                ForEach(PanelMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Mode", selection: $mode) {
                ForEach(PanelMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
        }
        .padding(.horizontal)
        .accessibilityHint("Select an analysis mode")
    }
}

private struct ActionRow: View {
    let isRunning: Bool
    let canCopy: Bool
    let runTapped: () -> Void
    let copyTapped: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: runTapped) {
                Label(isRunning ? "Running…" : "Run", systemImage: isRunning ? "hourglass" : "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)
            .accessibilityLabel(isRunning ? "Analysis running" : "Run analysis")

            Button(action: copyTapped) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .disabled(!canCopy)
            .accessibilityLabel("Copy result text")
            .accessibilityHint("Copies the analysis text")

            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

private struct HistorySection: View {
    @Binding var history: [SavedResult]
    var deleteAction: (SavedResult) -> Void

    var body: some View {
        Group {
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Results History").font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .padding(.horizontal)

                    ForEach(history) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.modeTitle) – \(shortDateTime(item.timestamp))")
                                    .font(.footnote.weight(.semibold))
                                Text(item.preview)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            Spacer()
                            Button(role: .destructive) { deleteAction(item) } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("Delete history item")
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Empty State

fileprivate struct EmptyState: View {
    let sourceCounts: [String: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No entries found to analyze.")
                .font(.headline)
            Text("Here’s what I could see from your data sources:")
                .font(.footnote)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(sourceCounts.keys.sorted(), id: \.self) { key in
                    Text("• \(key): \(sourceCounts[key] ?? 0)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)
            Divider().padding(.vertical, 6)
            Text("Try adding a shift/drive, importing sessions, or linking more data. Then tap **Run**.")
                .font(.footnote)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - History

fileprivate struct SavedResult: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let mode: PanelMode
    let preview: String

    init(id: UUID = UUID(), timestamp: Date, mode: PanelMode, preview: String) {
        self.id = id
        self.timestamp = timestamp
        self.mode = mode
        self.preview = preview
    }

    var modeTitle: String { mode.title }
}

fileprivate enum SavedResultStore {
    private static let key = "SparkPanelSavedResults.v2"

    static func load() -> [SavedResult] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SavedResult].self, from: data)) ?? []
    }
    static func save(_ items: [SavedResult]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Entry reflection / merging

private struct EntryLite: Hashable {
    var id: String
    var date: Date
    var energyKWh: Double?
    var cost: Double?
    var miles: Double?
    var site: String?
    var kind: String?     // "Supercharger" / "Home" / "Public" / Other (from category/chargeType)
    var duration: Double?

    init() {
        self.id = UUID().uuidString
        self.date = Date.distantPast
    }

    init(from s: SparkShiftEntry) {
        self.id = s.id.uuidString
        self.date = s.date
        self.energyKWh = s.energyKWh
        self.cost = s.cost
        self.miles = s.miles
        self.site = s.site ?? s.note
        self.kind = s.kind.map { String(describing: $0) }
        self.duration = s.durationSeconds
    }

    init(from x: ExpenseEntry) {
        self.id = x.id.uuidString
        self.date = x.date
        self.energyKWh = x.energyAddedKWh ?? x.energyKWh
        self.cost = x.amount
        self.miles = nil
        self.site = x.charging?.siteName ?? x.location ?? x.notes

        // Normalize “kind” buckets based on known fields
        // Priority: explicit chargeType → supercharger flag → category heuristic
        let explicit = x.chargeType?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let t = explicit, !t.isEmpty {
            self.kind = normalizeKind(from: t)
        } else if x.charging?.isSupercharger == true {
            self.kind = "Supercharger"
        } else {
            self.kind = normalizeKind(from: x.category.orEmpty)
        }

        if let mins = x.chargeDurationMinutes { self.duration = Double(mins) * 60.0 }
    }
}

private func normalizeKind(from raw: String) -> String {
    let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if s.contains("super") || s.contains("v3") || s.contains("sc") { return "Supercharger" }
    if s.contains("home") || s.contains("residential") { return "Home" }
    if s.contains("public") || s.contains("evgo") || s.contains("electrify") || s.contains("chargepoint") { return "Public" }
    if s.contains("work") || s.contains("office") { return "Work" }
    return raw.isEmpty ? "Other" : raw.capitalized
}

// Build a merged, deduped list
private func makeMergedLite(
    shifts: [SparkShiftEntry],
    expenses: [ExpenseEntry],
    extras: [[Any]]
) -> [EntryLite] {
    var out: [EntryLite] = []
    out.reserveCapacity(shifts.count + expenses.count)

    // 1) direct mappings
    for s in shifts { out.append(EntryLite(from: s)) }
    for e in expenses where e.isEnergyEffective { out.append(EntryLite(from: e)) }

    // 2) legacy/extras (best-effort reflection)
    for group in extras {
        let extracted = extractEntries(group)
        if !extracted.isEmpty { out.append(contentsOf: extracted) }
    }

    // 3) dedupe across sources: minute granularity + kWh (3dp) + site
    var seen: Set<String> = []
    var unique: [EntryLite] = []
    unique.reserveCapacity(out.count)

    for e in out {
        let minuteKey = Int((e.date.timeIntervalSinceReferenceDate / 60.0).rounded(.down))
        let kwhKey = e.energyKWh.map { String(format: "%.3f", $0) } ?? "nil"
        let siteKey = (e.site ?? "").lowercased()
        let key = "\(minuteKey)|\(kwhKey)|\(siteKey)"
        if !seen.contains(key) {
            seen.insert(key)
            unique.append(e)
        }
    }

    unique.sort { $0.date < $1.date }
    return unique
}

private func extractEntries(_ anyEntries: [Any]) -> [EntryLite] {
    var out: [EntryLite] = []
    out.reserveCapacity(anyEntries.count)

    for e in anyEntries {
        if let s = e as? SparkShiftEntry { out.append(EntryLite(from: s)); continue }
        if let x = e as? ExpenseEntry, x.isEnergyEffective { out.append(EntryLite(from: x)); continue }

        // Shallow reflection fallback
        let m = Mirror(reflecting: e)
        var mapped = EntryLite()

        func val<T>(_ name: String, as: T.Type) -> T? {
            for ch in m.children {
                if ch.label?.lowercased() == name.lowercased() { return ch.value as? T }
            }
            return nil
        }

        // Required: date-ish
        let date: Date? = val("date", as: Date.self)
            ?? val("startDate", as: Date.self)
            ?? val("timestamp", as: Date.self)
        guard let d = date else { continue }
        mapped.date = d

        // Keys
        mapped.id = (val("id", as: UUID.self)?.uuidString)
            ?? val("id", as: String.self)
            ?? isoFormatter.string(from: d)

        mapped.energyKWh = val("energyKWh", as: Double.self)
            ?? val("kwh", as: Double.self)
            ?? val("energyAdded", as: Double.self)

        mapped.cost = val("cost", as: Double.self)
            ?? val("amount", as: Double.self)
            ?? val("price", as: Double.self)

        mapped.miles = val("miles", as: Double.self)
            ?? val("distance", as: Double.self)
            ?? val("distanceMiles", as: Double.self)

        mapped.site = val("siteName", as: String.self)
            ?? val("location", as: String.self)
            ?? val("vendor", as: String.self)
            ?? val("note", as: String.self)

        let rawKind = val("kind", as: String.self)
            ?? val("tripKind", as: String.self)
            ?? val("category", as: String.self)
            ?? ""
        mapped.kind = normalizeKind(from: rawKind)

        mapped.duration = val("durationSeconds", as: Double.self)
            ?? val("duration", as: Double.self)

        out.append(mapped)
    }

    out.sort { $0.date < $1.date }
    return out
}

// MARK: - Analytics tools

private func summarizeMergedWindows(_ entries: [EntryLite]) -> (String, [Evidence], ChartData?) {
    let r7  = computeLiteWindow(entries, days: 7)
    let r31 = computeLiteWindow(entries, days: 31)

    var lines: [String] = []
    var ev: [Evidence] = []

    // 7d
    lines.append("Last 7 Days")
    if let r = r7 {
        lines.append(r.message)
        ev.append(Evidence(source: "Spark", reference: "7d",
                           summary: String(format: "kWh %.2f, miles %.1f, Wh/mi %.0f",
                                           r.totalEnergyKWh, r.totalDistance, r.avgWhPerMile)))
    } else {
        lines.append("No entries in the last 7 days.")
    }

    lines.append("")

    // 31d
    lines.append("Last 31 Days")
    if let r = r31 {
        lines.append(r.message)
        ev.append(Evidence(source: "Spark", reference: "31d",
                           summary: String(format: "kWh %.2f, miles %.1f, Wh/mi %.0f",
                                           r.totalEnergyKWh, r.totalDistance, r.avgWhPerMile)))
    } else {
        lines.append("No entries in the last 31 days.")
    }

    // Simple bar chart of kWh
    var items: [(String, Double)] = []
    if let a = r7  { items.append(("7d kWh", max(0, a.totalEnergyKWh))) }
    if let b = r31 { items.append(("31d kWh", max(0, b.totalEnergyKWh))) }
    items = items.filter { $0.1.isFinite && $0.1 > 0 }
    let chart: ChartData? = items.isEmpty ? nil : ChartData(type: .bar, items: items)

    return (joinLines(lines), ev, chart)
}

// Compute a window over EntryLite
private func computeLiteWindow(_ entries: [EntryLite], days: Int) -> LiteSummary? {
    guard days >= 1 else { return nil }
    let cal = dstCalendar
    let now = Date()
    guard let today = cal.dateInterval(of: .day, for: now) else { return nil }
    let end = today.end
    let start = cal.date(byAdding: .day, value: -(days - 1), to: today.start) ?? today.start

    let window = entries.filter { $0.date >= start && $0.date < end }
    guard !window.isEmpty else { return nil }

    var totalDistance = 0.0
    var totalEnergy   = 0.0
    for e in window {
        if let m = e.miles, m > 0, m.isFinite { totalDistance += m }
        if let k = e.energyKWh, k > 0, k.isFinite { totalEnergy += k }
    }
    let count = window.count
    let avgWhMi = (totalDistance > 0 && totalEnergy.isFinite) ? (totalEnergy * 1000.0) / totalDistance : 0

    var insights: [String] = []
    if avgWhMi > 320 {
        insights.append("Consumption ran a bit high (\(fmt(total: avgWhMi, 0)) Wh/mi). Consider gentler acceleration and lower cruising speeds.")
    } else if avgWhMi > 280 {
        insights.append("Efficiency was average at \(fmt(total: avgWhMi, 0)) Wh/mi. Tire pressure and climate control can shift this.")
    } else if avgWhMi > 0 {
        insights.append("Great efficiency at \(fmt(total: avgWhMi, 0)) Wh/mi. Nice driving!")
    }

    let line = "Distance \(fmt(total: totalDistance, 1)) mi • Energy \(fmt(total: totalEnergy, 2)) kWh • Avg \(fmt(total: avgWhMi, 0)) Wh/mi • \(count) entr\(count == 1 ? "y" : "ies")"
    let msg = insights.isEmpty ? line : (line + "\n" + insights.joined(separator: " "))

    return LiteSummary(totalDistance: totalDistance,
                       totalEnergyKWh: totalEnergy,
                       avgWhPerMile: avgWhMi,
                       entryCount: count,
                       message: msg)
}

private struct LiteSummary {
    let totalDistance: Double
    let totalEnergyKWh: Double
    let avgWhPerMile: Double
    let entryCount: Int
    let message: String
}

private func windowEntryCountsLite(_ entries: [EntryLite]) -> (d7: Int, d31: Int) {
    let cal = dstCalendar
    let now = Date()
    guard let today = cal.dateInterval(of: .day, for: now) else { return (0, 0) }
    let end = today.end
    let start7 = cal.date(byAdding: .day, value: -6, to: today.start) ?? today.start
    let start31 = cal.date(byAdding: .day, value: -30, to: today.start) ?? today.start

    var d7 = 0, d31 = 0
    for e in entries {
        if e.date >= start7 && e.date < end { d7 += 1 }
        if e.date >= start31 && e.date < end { d31 += 1 }
    }
    return (d7, d31)
}

// MARK: - Additional analyses

private func forecast(_ entries: [EntryLite]) -> (String, [Evidence], ChartData?) {
    guard entries.count >= 6 else { return ("Need at least 6 entries to forecast.", [], nil) }
    let cal = dstCalendar
    var byMonth: [Date: Double] = [:]
    for e in entries {
        let key = cal.date(from: cal.dateComponents([.year, .month], from: e.date)) ?? e.date
        let c = (e.cost ?? 0)
        if c.isFinite { byMonth[key, default: 0] += max(0, c) }
    }
    let ordered = byMonth.keys.sorted()
    var series: [(Date, Double)] = []
    for k in ordered { series.append((k, byMonth[k] ?? 0)) }
    guard series.count >= 3 else { return ("Need a few months of data for a useful forecast.", [], nil) }

    // Simple linear trend + blend with last-3 average
    let n = Double(series.count)
    var sumX = 0.0, sumY = 0.0, sumXX = 0.0, sumXY = 0.0
    for i in 0..<series.count {
        let xi = Double(i), yi = series[i].1
        sumX += xi; sumY += yi; sumXX += xi*xi; sumXY += xi*yi
    }
    let denom = (n * sumXX - sumX * sumX)
    let b = denom == 0 ? 0 : (n * sumXY - sumX * sumY) / denom
    let a = (sumY - b * sumX) / n

    let nextVal = max(0, a + b * Double(series.count))
    var last3 = 0.0
    let tail = max(series.count - 3, 0)
    for i in tail..<series.count { last3 += series[i].1 }
    last3 /= Double(min(3, series.count))
    let blended = max(0, 0.6 * nextVal + 0.4 * last3)

    let fmt = DateFormatter(); fmt.dateFormat = "MMM yyyy"
    var ev: [Evidence] = []
    for i in max(series.count - 3, 0)..<series.count {
        let (d, v) = series[i]
        ev.append(Evidence(source: "Entries", reference: fmt.string(from: d), summary: String(format: "%@ total $%.2f", fmt.string(from: d), v)))
    }
    let txt = String(format: "Projected next month spend: $%.2f (trend-adjusted)", blended)

    var chartItems: [(String, Double)] = []
    for i in max(series.count - 3, 0)..<series.count {
        chartItems.append((fmt.string(from: series[i].0), series[i].1))
    }
    chartItems.append(("Next", blended))
    let cd = ChartData(type: .line, items: chartItems)
    return (txt, ev, cd)
}

private func trends(_ entries: [EntryLite]) -> (String, [Evidence], ChartData?) {
    guard !entries.isEmpty else { return ("No entries yet.", [], nil) }
    let cal = dstCalendar
    var byMonthCost: [Date: Double] = [:]
    var byMonthKWh: [Date: Double] = [:]
    for e in entries {
        let key = cal.date(from: cal.dateComponents([.year, .month], from: e.date)) ?? e.date
        let c = e.cost ?? 0
        let k = e.energyKWh ?? 0
        if c.isFinite { byMonthCost[key, default: 0] += max(0, c) }
        if k.isFinite { byMonthKWh[key, default: 0] += max(0, k) }
    }

    let months = byMonthCost.keys.sorted()
    var monthTotals: [(Date, Double)] = []
    var allKWh = 0.0, allCost = 0.0
    for m in months {
        let c = byMonthCost[m] ?? 0
        let k = byMonthKWh[m] ?? 0
        monthTotals.append((m, c))
        allKWh += k
        allCost += c
    }

    let best = monthTotals.max(by: { $0.1 < $1.1 })
    let worst = monthTotals.min(by: { $0.1 < $1.1 })
    let avgPKWh = (allKWh > 0 && allKWh.isFinite) ? allCost / allKWh : 0
    let fmt = DateFormatter(); fmt.dateFormat = "MMM yyyy"

    var lines: [String] = []
    lines.append(String(format: "Total $%.2f; avg $/kWh %.3f", allCost, avgPKWh))
    if let b = best { lines.append(String(format: "Most expensive: %@ $%.2f", fmt.string(from: b.0), b.1)) }
    if let w = worst { lines.append(String(format: "Cheapest: %@ $%.2f", fmt.string(from: w.0), w.1)) }

    var ev: [Evidence] = []
    if let b = best { ev.append(Evidence(source: "Entries", reference: fmt.string(from: b.0), summary: String(format: "%@ $%.2f", fmt.string(from: b.0), b.1))) }
    if let w = worst { ev.append(Evidence(source: "Entries", reference: fmt.string(from: w.0), summary: String(format: "%@ $%.2f", fmt.string(from: w.0), w.1))) }

    let cd = ChartData(type: .line,
                       items: monthTotals.sorted { $0.0 < $1.0 }
                                         .map { (fmt.string(from: $0.0), max(0, $0.1)) })
    return (joinLines(lines), ev, cd)
}

private func anomalies(_ entries: [EntryLite]) -> (String, [Evidence], ChartData?) {
    guard !entries.isEmpty else { return ("No entries to analyze.", [], nil) }

    var pkwhSeries: [(EntryLite, Double)] = []
    var costMiSeries: [(EntryLite, Double)] = []

    for e in entries {
        if let c = e.cost, let k = e.energyKWh, k > 0, c.isFinite, k.isFinite { pkwhSeries.append((e, c / k)) }
        if let c = e.cost, let m = e.miles, m > 0, c.isFinite, m.isFinite { costMiSeries.append((e, c / m)) }
    }

    func madZ(_ xs: [Double]) -> [Double] {
        let vals = xs.filter { $0.isFinite }
        let n = vals.count
        guard n > 0 else { return [] }
        let sorted = vals.sorted()
        let median = sorted[n / 2]
        var devs: [Double] = []
        for v in vals { devs.append(abs(v - median)) }
        devs.sort()
        let mad = devs[n / 2]
        let denom = (mad == 0) ? 1e-9 : mad * 1.4826
        var out: [Double] = []
        for v in vals { out.append((v - median) / denom) }
        return out
    }

    var lines: [String] = []
    var ev: [Evidence] = []

    if pkwhSeries.count >= 6 {
        let vals = pkwhSeries.map { $0.1 }
        let z = madZ(vals)
        for i in 0..<min(pkwhSeries.count, z.count) where abs(z[i]) >= 3.5 {
            let e = pkwhSeries[i].0
            let line = String(format: "%@ $/kWh spike: %.3f (z=%.1f)", shortDate(e.date), pkwhSeries[i].1, z[i])
            lines.append("• " + line)
            ev.append(Evidence(source: "Entries", reference: e.id, summary: line))
        }
    }
    if costMiSeries.count >= 6 {
        let vals = costMiSeries.map { $0.1 }
        let z = madZ(vals)
        for i in 0..<min(costMiSeries.count, z.count) where abs(z[i]) >= 3.5 {
            let e = costMiSeries[i].0
            let line = String(format: "%@ cost/mi outlier: %.3f (z=%.1f)", shortDate(e.date), costMiSeries[i].1, z[i])
            lines.append("• " + line)
            ev.append(Evidence(source: "Entries", reference: e.id, summary: line))
        }
    }

    if lines.isEmpty { lines = ["No strong anomalies detected based on your saved data."] }
    return (joinLines(lines), ev, nil)
}

private func sites(_ entries: [EntryLite]) -> (String, [Evidence], ChartData?) {
    guard !entries.isEmpty else { return ("No site data available yet.", [], nil) }

    var buckets: [String: (visits: Int, totalCost: Double, totalKWh: Double)] = [:]
    for e in entries {
        let key = (e.site ?? "").isEmpty ? "(Unknown)" : (e.site ?? "")
        var b = buckets[key] ?? (0, 0, 0)
        b.visits += 1
        if let c = e.cost, c.isFinite { b.totalCost += max(0, c) }
        if let k = e.energyKWh, k.isFinite { b.totalKWh += max(0, k) }
        buckets[key] = b
    }
    guard !buckets.isEmpty else { return ("No site data available yet.", [], nil) }

    var stats: [(site: String, visits: Int, totalCost: Double, avgPKWh: Double)] = []
    for (site, b) in buckets {
        let avg = b.totalKWh > 0 ? b.totalCost / b.totalKWh : 0
        stats.append((site, b.visits, b.totalCost, avg))
    }

    let topSpend = stats.sorted { $0.totalCost > $1.totalCost }.prefix(3)
    let cheapest = stats.sorted { $0.avgPKWh < $1.avgPKWh }.prefix(3)

    var lines: [String] = []
    lines.append("Top spend sites:")
    lines += topSpend.isEmpty ? ["• None"] : topSpend.map { String(format: "• %@ — $%.2f over %d visits", $0.site, $0.totalCost, $0.visits) }
    lines.append("")
    lines.append("Lowest $/kWh:")
    lines += cheapest.isEmpty ? ["• None"] : cheapest.map { String(format: "• %@ — $/kWh %.3f", $0.site, $0.avgPKWh) }

    var ev: [Evidence] = []
    for t in topSpend {
        ev.append(Evidence(source: "Entries", reference: t.site,
                           summary: String(format: "%@ (visits %d, $%.2f, $/kWh %.3f)", t.site, t.visits, t.totalCost, t.avgPKWh)))
    }
    for c in cheapest {
        ev.append(Evidence(source: "Entries", reference: c.site,
                           summary: String(format: "%@ (visits %d, $%.2f, $/kWh %.3f)", c.site, c.visits, c.totalCost, c.avgPKWh)))
    }

    let items = topSpend.map { ($0.site, max(0, $0.totalCost)) }
    let chart: ChartData? = items.isEmpty ? nil : ChartData(type: .bar, items: items)
    return (joinLines(lines), ev, chart)
}

// MARK: - Utilities

private func fmt(total value: Double, _ fractionDigits: Int) -> String {
    if #available(iOS 15.0, macOS 12.0, *) {
        return value.formatted(.number.precision(.fractionLength(fractionDigits)))
    } else {
        let nf = NumberFormatter()
        nf.minimumFractionDigits = fractionDigits
        nf.maximumFractionDigits = fractionDigits
        return nf.string(from: value as NSNumber) ?? String(format: "%.\(fractionDigits)f", value)
    }
}

private func shortDate(_ d: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "MMM d, yyyy"
    return f.string(from: d)
}

private func shortDateTime(_ d: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "MMM d, yyyy h:mm a"
    return f.string(from: d)
}

private func joinLines(_ lines: [String]) -> String {
    lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
         .joined(separator: "\n")
}

// MARK: - String helpers (fixes: `.orEmpty` for optional and non-optional)

fileprivate extension Optional where Wrapped == String {
    var orEmpty: String { self ?? "" }
}

fileprivate extension String {
    var orEmpty: String { self }
}

// MARK: - Inline Toast (unique name to avoid collisions)

fileprivate struct InlineToast: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(radius: 4)
            .accessibilityLabel("Notification: \(text)")
            .allowsHitTesting(false)
    }
}
