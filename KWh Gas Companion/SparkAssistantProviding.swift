//
//  SparkAssistantProviding.swift
//  KWh Gas Companion
//
//  Created by Bryan on 1/13/26.
//


//
//  SparkAssistantProviding.swift
//  My EV Companion — Spark
//
//  Plug-in assistant interface:
//  - local heuristic coaching (default)
//  - on-device LLM
//  - remote LLM service
//
//  Swift 6 • iOS 17+
//

import Foundation

public protocol SparkAssistantProviding: Sendable {
    func respond(to report: SparkReport, userQuery: String?) async throws -> SparkAssistantResponse
}

public struct SparkAssistantResponse: Codable, Hashable, Sendable {
    public var title: String
    public var headline: String
    public var bullets: [String]
    public var warnings: [String]
    public var actions: [SparkAssistantAction]
    public var dataUsed: String?

    public init(
        title: String,
        headline: String,
        bullets: [String] = [],
        warnings: [String] = [],
        actions: [SparkAssistantAction] = [],
        dataUsed: String? = nil
    ) {
        self.title = title
        self.headline = headline
        self.bullets = bullets
        self.warnings = warnings
        self.actions = actions
        self.dataUsed = dataUsed
    }

    public func renderAsText() -> String {
        var lines: [String] = []
        lines.append(title)
        lines.append(headline)

        if !bullets.isEmpty {
            lines.append("")
            for b in bullets { lines.append("• " + b) }
        }

        if !warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            for w in warnings { lines.append("• " + w) }
        }

        if !actions.isEmpty {
            lines.append("")
            lines.append("Actions:")
            for a in actions { lines.append("• " + a.title) }
        }

        return lines.joined(separator: "\n")
    }
}

public struct SparkAssistantAction: Codable, Hashable, Sendable, Identifiable {
    public enum Role: String, Codable, Hashable, Sendable {
        case primary
        case secondary
    }

    public var id: String { key }

    public var key: String
    public var title: String
    public var deeplink: String?
    public var role: Role

    public init(key: String, title: String, deeplink: String? = nil, role: Role = .secondary) {
        self.key = key
        self.title = title
        self.deeplink = deeplink
        self.role = role
    }
}

// MARK: - Default local engine (no network)

public struct LocalSparkAssistantEngine: SparkAssistantProviding {

    public init() {}

    public func respond(to report: SparkReport, userQuery: String?) async throws -> SparkAssistantResponse {
        let w7 = report.window7
        let w31 = report.window31

        var headline = ""
        var bullets: [String] = []
        var warnings: [String] = []
        var actions: [SparkAssistantAction] = []

        if let w31 {
            let costStr = w31.totalCost.map { currency($0) } ?? "—"
            let kwhStr  = w31.totalKWh.map { number($0, 1) + " kWh" } ?? "—"
            let whmiStr = w31.avgWhPerMile.map { number($0, 0) + " Wh/mi" } ?? "—"
            headline = "Last 31 days: \(w31.entryCount) entries • \(costStr) • \(kwhStr) • \(whmiStr)"
        } else if let w7 {
            let costStr = w7.totalCost.map { currency($0) } ?? "—"
            headline = "Last 7 days: \(w7.entryCount) entries • \(costStr)"
        } else {
            headline = "I didn’t find enough recent data to summarize — add a few trips/charges and run again."
        }

        if let w31 {
            if w31.coverage.costKnownCount < w31.entryCount {
                warnings.append("Cost missing for \(w31.entryCount - w31.coverage.costKnownCount) entries (makes pricing less accurate).")
            }
            if w31.coverage.kWhKnownCount < w31.entryCount {
                warnings.append("Energy (kWh) missing for \(w31.entryCount - w31.coverage.kWhKnownCount) entries (limits efficiency + $/kWh).")
            }
            if w31.coverage.siteKnownCount < w31.entryCount {
                warnings.append("Location/site missing for \(w31.entryCount - w31.coverage.siteKnownCount) entries (limits site insights).")
            }
        }

        if let w31, let avg = w31.avgWhPerMile, avg.isFinite {
            if avg > 360 { bullets.append("Efficiency looks high (\(number(avg, 0)) Wh/mi). Check tire pressure, speed, and heater usage.") }
            else if avg < 250 { bullets.append("Nice efficiency (\(number(avg, 0)) Wh/mi). Your driving/conditions look favorable.") }
        }

        if let top = report.topSitesBySpend.first, top.totalCost > 0 {
            var s = "Top spend site: \(top.name) — \(currency(top.totalCost)) across \(top.visits) visit(s)."
            if let p = top.avgCostPerKWh, p.isFinite, p > 0 { s += " (~\(currency(p))/kWh avg)" }
            bullets.append(s)
        }

        if !report.anomalies.isEmpty {
            bullets.append("\(report.anomalies.count) outlier(s) detected — check for idle fees, refunds, or unusual pricing.")
        }

        if let w7, let w31, let c7 = w7.totalCost, let c31 = w31.totalCost, c31 > 0 {
            let weekly = c31 / 31.0 * 7.0
            if weekly.isFinite, weekly > 0 { bullets.append("Estimated weekly spend from the last 31 days: \(currency(weekly)).") }
            if c7 > (weekly * 1.35) {
                bullets.append("This week is running hotter than your 31-day pace — road trips or peak pricing may be involved.")
            }
        }

        actions.append(.init(key: "open_sites", title: "Open Sites", deeplink: "myev://spark/panel?mode=sites", role: .primary))
        actions.append(.init(key: "open_anomalies", title: "Open Anomalies", deeplink: "myev://spark/panel?mode=anomalies"))
        actions.append(.init(key: "open_summary", title: "Open Summary", deeplink: "myev://spark/panel?mode=summary"))

        // ✅ FIX: do NOT escape quotes inside \(...). Just build strings normally.
        let used = "Data used: \(report.sourceCounts.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", "))."

        return SparkAssistantResponse(
            title: "Spark Coach",
            headline: headline,
            bullets: bullets,
            warnings: warnings,
            actions: actions,
            dataUsed: used
        )
    }

    private func number(_ v: Double, _ digits: Int) -> String {
        if #available(iOS 15.0, macOS 12.0, *) {
            return v.formatted(.number.precision(.fractionLength(digits)))
        } else {
            return String(format: "%.\(digits)f", v)
        }
    }

    private func currency(_ v: Double) -> String {
        if #available(iOS 15.0, macOS 12.0, *) {
            return v.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
        } else {
            let nf = NumberFormatter()
            nf.locale = .current
            nf.numberStyle = .currency
            return nf.string(from: v as NSNumber) ?? String(format: "$%.2f", v)
        }
    }
}
