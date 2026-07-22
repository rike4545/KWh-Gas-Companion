//
//  AIEvidence.swift
//  My KWh Companion
//
//  Omni-Mode: private, evidence-first AI grounded strictly in local data.
//  Safe to drop in; no 3rd-party deps. iOS 17+.
//
//  © 2025
//

import SwiftUI
import Foundation

// MARK: - Types

public struct AIEvidence: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let source: String      // e.g., "EntriesStore", "TeslaFiSessionStore"
    public let reference: String   // e.g., entry id / site name / date
    public let summary: String     // short human-readable line
}

public struct AIAnswer: Identifiable, Hashable {
    public let id = UUID()
    public let text: String
    public let confidence: Double  // 0.0 - 1.0
    public let evidence: [AIEvidence]
    public let usedTools: [String]
}

public enum AIScope: String, CaseIterable, Identifiable {
    case off = "Off"
    case localOnly = "Local Only"
    case cloudAugmented = "Cloud Augmented (Opt-in)"
    public var id: String { rawValue }
}

// MARK: - Settings (bindable & persisted)

@MainActor
public final class AISettings: ObservableObject {
    @Published public var scopeRaw: String {
        didSet { UserDefaults.standard.set(scopeRaw, forKey: "ai.scope") }
    }
    @Published public var requireEvidence: Bool {
        didSet { UserDefaults.standard.set(requireEvidence, forKey: "ai.requireEvidence") }
    }
    @Published public var showConfidence: Bool {
        didSet { UserDefaults.standard.set(showConfidence, forKey: "ai.showConfidence") }
    }
    @Published public var isBusy: Bool = false

    public var scope: AIScope {
        get { AIScope(rawValue: scopeRaw) ?? .localOnly }
        set { scopeRaw = newValue.rawValue }
    }

    public init() {
        let d = UserDefaults.standard
        self.scopeRaw = d.string(forKey: "ai.scope") ?? AIScope.localOnly.rawValue
        self.requireEvidence = (d.object(forKey: "ai.requireEvidence") as? Bool) ?? true
        self.showConfidence  = (d.object(forKey: "ai.showConfidence")  as? Bool) ?? true
    }
}

// MARK: - Data adapters (closures)

public struct AIContext {
    public var loadEntries:  () -> [Any] = { [] }   // Expect ExpenseEntry
    public var loadSessions: () -> [Any] = { [] }   // Expect TeslaFiSession
    public var loadVehicles: () -> [Any] = { [] }   // Expect VehicleProfile

    public init() {}
}

// MARK: - Lightweight reflection helpers (model-agnostic)

fileprivate struct AIEntryLite: Hashable {
    var id: String
    var date: Date
    var energyKWh: Double?
    var cost: Double?
    var miles: Double?
    var site: String?
}

fileprivate struct AISessionLite: Hashable {
    var id: String
    var startDate: Date
    var endDate: Date?
    var energyKWh: Double
    var cost: Double?
    var location: String?
}

fileprivate func extractEntries(_ anyEntries: [Any]) -> [AIEntryLite] {
    anyEntries.compactMap { e in
        let m = Mirror(reflecting: e)
        var out = AIEntryLite(id: UUID().uuidString, date: .distantPast, energyKWh: nil, cost: nil, miles: nil, site: nil)

        func val<T>(_ name: String, _ type: T.Type) -> T? {
            for ch in m.children {
                if ch.label?.lowercased() == name.lowercased() { return ch.value as? T }
            }
            return nil
        }

        // date: accept date/startDate/timestamp
        guard let d = val("date", Date.self) ?? val("startDate", Date.self) ?? val("timestamp", Date.self) else { return nil }
        out.date = d
        out.id   = val("id", UUID.self)?.uuidString
                ?? val("id", String.self)
                ?? ISO8601DateFormatter().string(from: d)
        out.energyKWh = val("energyKWh", Double.self) ?? val("kwh", Double.self) ?? val("energyAdded", Double.self)
        out.cost      = val("cost", Double.self)      ?? val("amount", Double.self) ?? val("price", Double.self)
        out.miles     = val("miles", Double.self)     ?? val("distance", Double.self)
        out.site      = val("siteName", String.self)  ?? val("location", String.self) ?? val("vendor", String.self)
        return out
    }
    .sorted { $0.date < $1.date }
}

fileprivate func extractSessions(_ anySessions: [Any]) -> [AISessionLite] {
    anySessions.compactMap { s in
        let m = Mirror(reflecting: s)

        func val<T>(_ name: String, _ type: T.Type) -> T? {
            for ch in m.children {
                if ch.label?.lowercased() == name.lowercased() { return ch.value as? T }
            }
            return nil
        }

        guard let start = val("startDate", Date.self) ?? val("date", Date.self),
              let energy = val("energyAddedKWh", Double.self) ?? val("kwh", Double.self) ?? val("energyKWh", Double.self)
        else {
            return nil
        }

        let id = val("id", UUID.self)?.uuidString
            ?? val("id", String.self)
            ?? ISO8601DateFormatter().string(from: start)

        return AISessionLite(
            id: id,
            startDate: start,
            endDate: val("endDate", Date.self),
            energyKWh: energy,
            cost: val("cost", Double.self) ?? val("amount", Double.self),
            location: val("location", String.self) ?? val("siteName", String.self)
        )
    }
    .sorted { $0.startDate < $1.startDate }
}

// MARK: - Tools

public protocol AITool {
    var name: String { get }
    func score(query: String) -> Double   // rough intent match 0-1
    func answer(query: String, ctx: AIContext) throws -> AIAnswer?
}

fileprivate extension String {
    func containsAny(_ needles: [String]) -> Bool {
        let hay = self.lowercased()
        return needles.contains { hay.contains($0.lowercased()) }
    }
}

// Forecast tool — projects next month(s) cost from recent trend
public struct ForecastTool: AITool {
    public let name = "Forecast"
    public init() {}

    public func score(query: String) -> Double {
        query.lowercased().containsAny(["forecast","predict","projection","next month","future"]) ? 0.9 : 0.0
    }

    public func answer(query: String, ctx: AIContext) throws -> AIAnswer? {
        let entries = extractEntries(ctx.loadEntries())
        guard entries.count >= 3 else {
            return AIAnswer(text: "Not enough history to forecast yet.", confidence: 0.3, evidence: [], usedTools: [name])
        }

        let cal = Calendar.current
        let byMonth = Dictionary(grouping: entries) { cal.date(from: cal.dateComponents([.year, .month], from: $0.date)) ?? $0.date }
        let ordered = byMonth.keys.sorted()
        var series: [(Date, Double)] = []
        for k in ordered {
            let total = byMonth[k]?.compactMap { $0.cost }.reduce(0, +) ?? 0
            series.append((k, total))
        }
        guard series.count >= 3 else {
            return AIAnswer(text: "Need a few months of data for a useful forecast.", confidence: 0.35, evidence: [], usedTools: [name])
        }

        // simple linear trend y = a + b * t
        let n = Double(series.count)
        let x: [Double] = (0..<series.count).map { Double($0) }
        let y: [Double] = series.map { $0.1 }
        let sumX  = x.reduce(0,+)
        let sumY  = y.reduce(0,+)
        let sumXX = x.map { $0 * $0 }.reduce(0,+)
        let sumXY = zip(x, y).map { $0.0 * $0.1 }.reduce(0,+)  // tuple-safe multiply

        let denom = (n * sumXX - sumX * sumX)
        let b = denom == 0 ? 0 : (n * sumXY - sumX * sumY) / denom
        let a = (sumY - b * sumX) / n

        let nextX = Double(series.count)
        let nextVal = max(0, a + b * nextX)
        let last3Avg = y.suffix(3).reduce(0,+) / Double(min(3, y.count))
        let blended = max(0, 0.6 * nextVal + 0.4 * last3Avg)

        // evidence: last 3 months
        let fmt = DateFormatter(); fmt.dateFormat = "MMM yyyy"
        let ev: [AIEvidence] = series.suffix(3).map { (d, v) in
            AIEvidence(source: "EntriesStore", reference: fmt.string(from: d), summary: String(format: "%@ total $%.2f", fmt.string(from: d), v))
        }
        let txt = String(format: "Projected next month spend: $%.2f (trend-adjusted)", blended)
        return AIAnswer(text: txt, confidence: 0.65, evidence: ev, usedTools: [name])
    }
}

// Trends tool — best/worst months, totals, average $/kWh
public struct TrendsTool: AITool {
    public let name = "Trends"
    public init() {}

    public func score(query: String) -> Double {
        query.lowercased().containsAny(["most expensive","cheapest","average","trend","biggest","total","per kwh","per mile"]) ? 0.8 : 0.0
    }

    public func answer(query: String, ctx: AIContext) throws -> AIAnswer? {
        let entries = extractEntries(ctx.loadEntries())
        guard !entries.isEmpty else { return AIAnswer(text: "No entries yet.", confidence: 0.2, evidence: [], usedTools: [name]) }

        let cal = Calendar.current
        let byMonth = Dictionary(grouping: entries) { cal.date(from: cal.dateComponents([.year, .month], from: $0.date)) ?? $0.date }

        var monthTotals: [(Date, Double)] = []
        var allKWh: Double = 0
        var allCost: Double = 0

        for (k, arr) in byMonth {
            let total = arr.compactMap { $0.cost }.reduce(0, +)
            monthTotals.append((k, total))
            allKWh += arr.compactMap { $0.energyKWh }.reduce(0, +)
            allCost += total
        }

        let mostExpensive = monthTotals.max(by: { $0.1 < $1.1 })
        let cheapest      = monthTotals.min(by: { $0.1 < $1.1 })
        let fmt = DateFormatter(); fmt.dateFormat = "MMM yyyy"
        let avgPKWh = allKWh > 0 ? allCost / allKWh : 0

        let msg = """
        Total spend $\(String(format: "%.2f", allCost)); avg $/kWh \(String(format: "%.3f", avgPKWh)).
        Most expensive: \(mostExpensive.map { "\(fmt.string(from: $0.0)) $\(String(format: "%.2f", $0.1))" } ?? "n/a").
        Cheapest: \(cheapest.map { "\(fmt.string(from: $0.0)) $\(String(format: "%.2f", $0.1))" } ?? "n/a").
        """

        let ev: [AIEvidence] = [mostExpensive, cheapest].compactMap { $0 }.map { (d, v) in
            AIEvidence(source: "EntriesStore", reference: fmt.string(from: d), summary: String(format: "%@ $%.2f", fmt.string(from: d), v))
        }
        return AIAnswer(text: msg, confidence: 0.8, evidence: ev, usedTools: [name])
    }
}

// Anomalies tool — MAD-based outlier check on $/kWh, cost/mi
public struct AnomaliesTool: AITool {
    public let name = "Anomalies"
    public init() {}

    public func score(query: String) -> Double {
        query.lowercased().containsAny(["anomaly","outlier","weird","spike","suspicious"]) ? 0.85 : 0.0
    }

    public func answer(query: String, ctx: AIContext) throws -> AIAnswer? {
        let entries = extractEntries(ctx.loadEntries())
        guard !entries.isEmpty else { return AIAnswer(text: "No entries to analyze.", confidence: 0.2, evidence: [], usedTools: [name]) }

        // series for $/kWh and cost/mi when possible
        let pkwhSeries = entries.compactMap { e -> (AIEntryLite, Double)? in
            if let c = e.cost, let k = e.energyKWh, k > 0 { return (e, c/k) }
            return nil
        }
        let costMiSeries = entries.compactMap { e -> (AIEntryLite, Double)? in
            if let c = e.cost, let m = e.miles, m > 0 { return (e, c/m) }
            return nil
        }

        func median(_ xs: [Double]) -> Double {
            guard !xs.isEmpty else { return 0 }
            let s = xs.sorted()
            let mid = s.count / 2
            if s.count % 2 == 0 { return (s[mid-1] + s[mid]) / 2 } else { return s[mid] }
        }
        func madZ(_ xs: [Double]) -> [Double] {
            guard !xs.isEmpty else { return [] }
            let med = median(xs)
            let devs = xs.map { abs($0 - med) }
            let mad = median(devs)
            let denom = mad == 0 ? 1e-9 : mad * 1.4826
            return xs.map { ($0 - med) / denom }
        }

        var evidence: [AIEvidence] = []
        var lines: [String] = []

        if pkwhSeries.count >= 6 {
            let vals = pkwhSeries.map { $0.1 }
            let z = madZ(vals)
            for (i, pair) in pkwhSeries.enumerated() where abs(z[i]) >= 3.5 {
                let e = pair.0
                let line = String(format: "%@ $/kWh spike: %.3f (z=%.1f)", shortDate(e.date), pair.1, z[i])
                lines.append("• " + line)
                evidence.append(AIEvidence(source: "EntriesStore", reference: e.id, summary: line))
            }
        }
        if costMiSeries.count >= 6 {
            let vals = costMiSeries.map { $0.1 }
            let z = madZ(vals)
            for (i, pair) in costMiSeries.enumerated() where abs(z[i]) >= 3.5 {
                let e = pair.0
                let line = String(format: "%@ cost/mi outlier: %.3f (z=%.1f)", shortDate(e.date), pair.1, z[i])
                lines.append("• " + line)
                evidence.append(AIEvidence(source: "EntriesStore", reference: e.id, summary: line))
            }
        }
        if lines.isEmpty { lines = ["No strong anomalies detected based on your saved data."] }
        return AIAnswer(text: lines.joined(separator: "\n"), confidence: 0.7, evidence: evidence, usedTools: [name])
    }
}

// Sites tool — top/cheapest/most visited sites
public struct SitesTool: AITool {
    public let name = "Sites"
    public init() {}

    public func score(query: String) -> Double {
        query.lowercased().containsAny(["site","supercharger","location","where","station"]) ? 0.75 : 0.0
    }

    public func answer(query: String, ctx: AIContext) throws -> AIAnswer? {
        let entries = extractEntries(ctx.loadEntries())
        let groups = Dictionary(grouping: entries, by: { $0.site ?? "(Unknown)" })

        var stats: [(String, Int, Double, Double)] = [] // site, visits, totalCost, avgPKWh
        for (site, arr) in groups {
            let visits = arr.count
            let cost = arr.compactMap { $0.cost }.reduce(0, +)
            let kwh  = arr.compactMap { $0.energyKWh }.reduce(0, +)
            let pkwh = kwh > 0 ? cost / kwh : 0
            stats.append((site, visits, cost, pkwh))
        }
        guard !stats.isEmpty else {
            return AIAnswer(text: "No site data available yet.", confidence: 0.3, evidence: [], usedTools: [name])
        }

        let top   = stats.sorted { $0.2 > $1.2 }.prefix(3)
        // Exclude sites with no kWh data (pkwh==0 is a sentinel, not a real rate).
        let cheap = stats.filter { $0.3 > 0 }.sorted { $0.3 < $1.3 }.prefix(3)

        var lines: [String] = []
        lines.append("Top spend sites:")
        for t in top   { lines.append(String(format: "• %@ — $%.2f over %d visits", t.0, t.2, t.1)) }
        lines.append("\nLowest $/kWh:")
        for c in cheap { lines.append(String(format: "• %@ — $/kWh %.3f", c.0, c.3)) }

        let ev = (top + cheap).map {
            AIEvidence(source: "EntriesStore",
                       reference: $0.0,
                       summary: String(format: "%@ (visits %d, $%.2f, $/kWh %.3f)", $0.0, $0.1, $0.2, $0.3))
        }
        return AIAnswer(text: lines.joined(separator: "\n"), confidence: 0.75, evidence: ev, usedTools: [name])
    }
}

public struct ChargingHabitsTool: AITool {
    public let name = "ChargingHabits"
    public init() {}

    public func score(query: String) -> Double {
        let q = query.lowercased()
        if q.containsAny(["where does this owner charge", "charge most often", "charging habits", "where do i charge", "how do i charge"]) {
            return 0.95
        }
        if q.contains("where") && q.contains("charg") { return 0.85 }
        return 0.0
    }

    public func answer(query: String, ctx: AIContext) throws -> AIAnswer? {
        let entries = extractEntries(ctx.loadEntries()).map { lite in
            ExpenseEntry(
                id: UUID(uuidString: lite.id) ?? UUID(),
                date: lite.date,
                amount: lite.cost ?? 0,
                currencyCode: nil,
                category: "Charging",
                energyKWh: lite.energyKWh,
                odometer: nil,
                location: lite.site,
                notes: nil,
                vehicleName: nil,
                stateOfCharge: nil,
                chargeType: nil,
                vehicleID: nil,
                isBusiness: false,
                vin: nil,
                isEnergy: true,
                charging: nil,
                vatAmount: nil,
                invoiceNumber: nil,
                repeatRule: nil
            )
        }
        let sessions = extractSessions(ctx.loadSessions()).map {
            TeslaFiSession(
                id: UUID(uuidString: $0.id) ?? UUID(),
                startDate: $0.startDate,
                endDate: $0.endDate ?? $0.startDate,
                energyAddedKWh: $0.energyKWh,
                cost: $0.cost,
                location: $0.location
            )
        }

        let insights = ChargingBehaviorInsights.build(entries: entries, teslaFiSessions: sessions)
        guard insights.totalSessions > 0 else {
            return AIAnswer(text: "I do not have enough charging history yet to tell where this owner charges most often.", confidence: 0.25, evidence: [], usedTools: [name])
        }

        return AIAnswer(
            text: insights.whereAndHowSummary,
            confidence: min(0.95, 0.45 + (Double(insights.totalSessions) / 40.0)),
            evidence: insights.evidence,
            usedTools: [name]
        )
    }
}

public struct BatteryCareTool: AITool {
    public let name = "BatteryCare"
    public init() {}

    public func score(query: String) -> Double {
        let q = query.lowercased()
        if q.containsAny(["battery health", "long-term battery", "battery degradation", "affecting battery", "battery suggestions", "battery tips", "recommend"]) {
            return 0.92
        }
        return 0.0
    }

    public func answer(query: String, ctx: AIContext) throws -> AIAnswer? {
        let entries = ctx.loadEntries().compactMap { $0 as? ExpenseEntry }
        let sessions = ctx.loadSessions().compactMap { $0 as? TeslaFiSession }
        let insights = ChargingBehaviorInsights.build(entries: entries, teslaFiSessions: sessions)

        guard insights.totalSessions > 0 else {
            return AIAnswer(text: "I do not have enough charging history yet to estimate battery-health factors or suggestions.", confidence: 0.25, evidence: [], usedTools: [name])
        }

        let q = query.lowercased()
        let text: String
        if q.contains("suggest") || q.contains("recommend") || q.contains("what should i do") || q.contains("tips") {
            text = insights.suggestionsSummary
        } else {
            text = insights.batteryHealthSummary + "\n\nConcrete suggestions:\n" + insights.suggestionsSummary
        }

        return AIAnswer(
            text: text,
            confidence: min(0.95, 0.45 + (Double(insights.totalSessions) / 40.0)),
            evidence: insights.evidence,
            usedTools: [name]
        )
    }
}

// Fallback tool — describes what the AI can/can't do locally
public struct CapabilityTool: AITool {
    public let name = "Capabilities"
    public init() {}

    public func score(query: String) -> Double { 0.2 } // low so others win first

    public func answer(query: String, ctx: AIContext) throws -> AIAnswer? {
        let text = "I answer strictly from what the app has saved: entries, sessions, vehicles. Try: ‘where do I charge most often’, ‘what is affecting long-term battery health’, ‘forecast next month’, or ‘find anomalies’."
        return AIAnswer(text: text, confidence: 0.9, evidence: [], usedTools: [name])
    }
}

// MARK: - Engine

@MainActor
public final class SparkAIEngine: ObservableObject {
    @Published public var lastAnswer: AIAnswer? = nil
    private let settings: AISettings
    private let ctx: AIContext
    private let tools: [AITool]

    public init(settings: AISettings, context: AIContext, extraTools: [AITool] = []) {
        self.settings = settings
        self.ctx = context
        var base: [AITool] = [ChargingHabitsTool(), BatteryCareTool(), ForecastTool(), TrendsTool(), AnomaliesTool(), SitesTool(), CapabilityTool()]
        base.append(contentsOf: extraTools)
        self.tools = base
    }

    public func ask(_ query: String) {
        guard settings.scope != .off else {
            lastAnswer = AIAnswer(text: "AI is turned off in Settings.", confidence: 1.0, evidence: [], usedTools: [])
            return
        }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        settings.isBusy = true
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            // Intent routing by best-scoring tool
            let ranked = self.tools
                .map { ($0, $0.score(query: q)) }
                .sorted { $0.1 > $1.1 }

            for (tool, score) in ranked where score > 0 {
                if let ans = try? tool.answer(query: q, ctx: self.ctx) {
                    let final: AIAnswer
                    if self.settings.requireEvidence && ans.evidence.isEmpty {
                        final = AIAnswer(
                            text: ans.text + "\n\n(Answer grounded in app data only; no explicit evidence rows matched.)",
                            confidence: max(0, min(1, ans.confidence * 0.8)),
                            evidence: ans.evidence,
                            usedTools: ans.usedTools
                        )
                    } else {
                        final = ans
                    }
                    await MainActor.run {
                        self.lastAnswer = final
                        self.settings.isBusy = false
                    }
                    return
                }
            }

            await MainActor.run {
                self.lastAnswer = AIAnswer(
                    text: "I couldn’t map that request to your saved data.",
                    confidence: 0.2,
                    evidence: [],
                    usedTools: []
                )
                self.settings.isBusy = false
            }
        }
    }
}

// MARK: - UI

public struct AIChatView: View {
    @EnvironmentObject private var ai: SparkAIEngine
    @EnvironmentObject private var aiSettings: AISettings

    @State private var prompt: String = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            header
            ScrollView {
                if let ans = ai.lastAnswer {
                    AnswerCard(answer: ans, showConfidence: aiSettings.showConfidence)
                        .padding(.horizontal)
                } else {
                    Text("Ask something like: ‘where do I charge most often’, ‘what is affecting long-term battery health’, ‘forecast next month’, or ‘find anomalies’.")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            inputBar
        }
        .navigationTitle("AI")
    }

    private var header: some View {
        HStack {
            Label("Omni-Mode (Local)", systemImage: "bolt.circle")
                .font(.headline)
            Spacer()
            NavigationLink(destination: AISettingsView()) {
                Image(systemName: "gearshape")
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about your data…", text: $prompt)
                .textFieldStyle(.roundedBorder)
                .disabled(aiSettings.isBusy || aiSettings.scope == .off)
                .onSubmit(send)
            if aiSettings.isBusy {
                ProgressView().padding(.horizontal, 4)
            }
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 24))
            }
            .disabled(aiSettings.scope == .off || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func send() {
        let q = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        ai.ask(q)
        prompt = ""
    }
}

fileprivate struct AnswerCard: View {
    let answer: AIAnswer
    let showConfidence: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(answer.text)
                .font(.body)
            if showConfidence {
                HStack(spacing: 8) {
                    ProgressView(value: min(max(answer.confidence,0),1))
                        .progressViewStyle(.linear)
                        .frame(width: 120)
                    Text(String(format: "Confidence %.0f%%", answer.confidence * 100))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !answer.evidence.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Evidence")
                    .font(.subheadline.weight(.semibold))
                ForEach(answer.evidence) { ev in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                        VStack(alignment: .leading) {
                            Text(ev.summary)
                            Text("\(ev.source) — \(ev.reference)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if !answer.usedTools.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Tools: " + answer.usedTools.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

public struct AISettingsView: View {
    @EnvironmentObject private var settings: AISettings

    public init() {}

    public var body: some View {
        Form {
            Section("Mode & Privacy") {
                Picker("Scope", selection: $settings.scopeRaw) {
                    ForEach(AIScope.allCases) { s in
                        Text(s.rawValue).tag(s.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Require evidence for answers", isOn: $settings.requireEvidence)
                Toggle("Show confidence meter", isOn: $settings.showConfidence)
                Text("Local Only means the AI uses only what your app has saved — no internet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("About") {
                Text("Omni-Mode answers what it can from your saved entries, sessions, sites, and vehicles. For anything outside your data, it will say it can’t know.")
                    .font(.callout)
            }
        }
        .navigationTitle("AI Settings")
    }
}

// MARK: - Utilities

fileprivate func shortDate(_ d: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
    return f.string(from: d)
}
