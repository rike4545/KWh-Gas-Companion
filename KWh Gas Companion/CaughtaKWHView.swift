//
//  CaughtaKWHView.swift
//  KWh Gas Companion
//

import SwiftUI

struct CaughtaKWHView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore

    private var summary: CaughtaKWHSummary {
        CaughtaKWHEngine.summarize(
            entries: entriesStore.energyEntries(),
            sessions: teslaFiStore.sessionsForUI
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                CaughtaKWHHero(summary: summary)

                CaughtaKWHCard(title: "Caught signals", subtitle: "Rows most likely to skew charging totals") {
                    VStack(spacing: 12) {
                        CaughtaKWHSignalRow(
                            title: "Missing kWh",
                            value: "\(summary.missingEnergyEntries.count)",
                            detail: "Charging expenses with cost but no usable energy value."
                        )
                        CaughtaKWHSignalRow(
                            title: "High-rate entries",
                            value: "\(summary.highRateEntries.count)",
                            detail: "Manual rows at or above \(summary.rateThreshold.caughtaKWHCurrency)/kWh."
                        )
                        CaughtaKWHSignalRow(
                            title: "High-rate sessions",
                            value: "\(summary.highRateSessions.count)",
                            detail: "Imported sessions at or above \(summary.rateThreshold.caughtaKWHCurrency)/kWh."
                        )
                    }
                }

                CaughtaKWHCard(title: "Biggest catch", subtitle: "Start here when cleaning up charging data") {
                    Text(summary.biggestCatchText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                CaughtaKWHCard(title: "Next cleanup move", subtitle: "The fastest way to improve future catches") {
                    Text(summary.nextMoveText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !summary.issueRows.isEmpty {
                    CaughtaKWHCard(title: "Review queue", subtitle: "The first rows CaughtaKWH would inspect") {
                        VStack(spacing: 12) {
                            ForEach(summary.issueRows.prefix(8)) { row in
                                CaughtaKWHReviewRow(row: row)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("CaughtaKWH")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CaughtaKWHHero: View {
    let summary: CaughtaKWHSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("CaughtaKWH", systemImage: "bolt.badge.exclamationmark")
                .font(.title2.weight(.semibold))
            Text("Catch missing energy, suspicious rates, and cleanup targets before they distort forecasts, trends, and budgets.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                CaughtaKWHMetric(title: "Caught", value: "\(summary.caughtCount)")
                CaughtaKWHMetric(title: "Clean rows", value: "\(summary.cleanRowCount)")
                CaughtaKWHMetric(title: "Baseline", value: summary.baselineRate.map { "\($0.caughtaKWHCurrency)/kWh" } ?? "Learning")
                CaughtaKWHMetric(title: "Worst rate", value: summary.worstRate.map { "\($0.caughtaKWHCurrency)/kWh" } ?? "None")
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct CaughtaKWHCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct CaughtaKWHMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CaughtaKWHSignalRow: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(value)
                .font(.headline.monospacedDigit())
                .frame(width: 44, height: 36)
                .background(Color.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CaughtaKWHReviewRow: View {
    let row: CaughtaKWHIssueRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: row.systemImage)
                .font(.headline)
                .frame(width: 34, height: 34)
                .background(row.tint.opacity(0.16), in: Circle())
                .foregroundStyle(row.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                Text(row.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum CaughtaKWHEngine {
    static func summarize(entries: [ExpenseEntry], sessions: [TeslaFiSession]) -> CaughtaKWHSummary {
        let ratedEntries = entries.compactMap { entry -> CaughtaKWHRatedEntry? in
            guard let energy = entry.energyAddedKWh, energy > 0 else { return nil }
            return CaughtaKWHRatedEntry(entry: entry, rate: entry.amount / energy)
        }
        let ratedSessions = sessions.compactMap { session -> CaughtaKWHRatedSession? in
            guard session.energyAddedKWh > 0, let cost = session.cost else { return nil }
            return CaughtaKWHRatedSession(session: session, rate: cost / session.energyAddedKWh)
        }
        let allRates = ratedEntries.map(\.rate) + ratedSessions.map(\.rate)
        let baseline = allRates.isEmpty ? nil : allRates.reduce(0, +) / Double(allRates.count)
        let threshold = max(0.55, (baseline ?? 0.0) * 1.35)
        let missingEnergyEntries = entries.filter { entry in
            entry.amount > 0 && ((entry.energyAddedKWh ?? 0) <= 0)
        }
        let highRateEntries = ratedEntries.filter { $0.rate >= threshold }
        let highRateSessions = ratedSessions.filter { $0.rate >= threshold }
        let caughtCount = missingEnergyEntries.count + highRateEntries.count + highRateSessions.count
        let totalRows = entries.count + sessions.count
        let worstRate = (highRateEntries.map(\.rate) + highRateSessions.map(\.rate)).max()

        let issueRows = buildIssueRows(
            missingEnergyEntries: missingEnergyEntries,
            highRateEntries: highRateEntries,
            highRateSessions: highRateSessions
        )

        return CaughtaKWHSummary(
            caughtCount: caughtCount,
            cleanRowCount: max(0, totalRows - caughtCount),
            baselineRate: baseline,
            rateThreshold: threshold,
            worstRate: worstRate,
            missingEnergyEntries: missingEnergyEntries,
            highRateEntries: highRateEntries,
            highRateSessions: highRateSessions,
            issueRows: issueRows
        )
    }

    private static func buildIssueRows(
        missingEnergyEntries: [ExpenseEntry],
        highRateEntries: [CaughtaKWHRatedEntry],
        highRateSessions: [CaughtaKWHRatedSession]
    ) -> [CaughtaKWHIssueRow] {
        let missingRows = missingEnergyEntries.map { entry in
            CaughtaKWHIssueRow(
                title: entry.caughtaKWHDisplayTitle,
                detail: "Missing kWh for a \(entry.amount.caughtaKWHCurrency) charging entry.",
                systemImage: "bolt.slash",
                tint: .orange
            )
        }
        let entryRows = highRateEntries.sorted { $0.rate > $1.rate }.map { rated in
            CaughtaKWHIssueRow(
                title: rated.entry.caughtaKWHDisplayTitle,
                detail: "\(rated.rate.caughtaKWHCurrency)/kWh. Check energy, taxes, idle fees, or whether this row should be split.",
                systemImage: "exclamationmark.triangle",
                tint: .red
            )
        }
        let sessionRows = highRateSessions.sorted { $0.rate > $1.rate }.map { rated in
            CaughtaKWHIssueRow(
                title: rated.session.displayLocation,
                detail: "\(rated.rate.caughtaKWHCurrency)/kWh imported session. Check cost, energy, idle fees, and provider pricing.",
                systemImage: "tray.and.arrow.down",
                tint: .purple
            )
        }
        return entryRows + sessionRows + missingRows
    }
}

struct CaughtaKWHSummary {
    let caughtCount: Int
    let cleanRowCount: Int
    let baselineRate: Double?
    let rateThreshold: Double
    let worstRate: Double?
    let missingEnergyEntries: [ExpenseEntry]
    let highRateEntries: [CaughtaKWHRatedEntry]
    let highRateSessions: [CaughtaKWHRatedSession]
    let issueRows: [CaughtaKWHIssueRow]

    var biggestCatchText: String {
        if let entry = highRateEntries.max(by: { $0.rate < $1.rate }) {
            return "\(entry.entry.caughtaKWHDisplayTitle) is running at \(entry.rate.caughtaKWHCurrency)/kWh. Check the energy value, taxes, idle fees, and whether the row should be split."
        }
        if let session = highRateSessions.max(by: { $0.rate < $1.rate }) {
            return "\(session.session.displayLocation) is running at \(session.rate.caughtaKWHCurrency)/kWh. Check imported cost, energy, idle fees, and provider pricing."
        }
        if let missing = missingEnergyEntries.first {
            return "\(missing.caughtaKWHDisplayTitle) is missing kWh. Add energy so cost per kWh, forecasts, and budget guardrails can use it."
        }
        return "No charging rows are standing out right now. Keep importing sessions and logging energy so CaughtaKWH has more signal to inspect."
    }

    var nextMoveText: String {
        if !missingEnergyEntries.isEmpty {
            return "Start by filling missing kWh on charging expenses. That one field unlocks price-per-kWh trend checks, anomaly detection, budget pacing, and more reliable forecasts."
        }
        return "Review unusually high-rate rows first, then keep provider and site names consistent so the app can separate real pricing changes from messy labels."
    }
}

struct CaughtaKWHRatedEntry: Identifiable {
    let entry: ExpenseEntry
    let rate: Double
    var id: UUID { entry.id }
}

struct CaughtaKWHRatedSession: Identifiable {
    let session: TeslaFiSession
    let rate: Double
    var id: UUID { session.id }
}

struct CaughtaKWHIssueRow: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
}

private extension ExpenseEntry {
    var caughtaKWHDisplayTitle: String {
        let site = charging?.siteName ?? location
        let trimmed = site?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return summaryLabel
    }
}

private extension Double {
    var caughtaKWHCurrency: String {
        formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CaughtaKWHView()
            .environmentObject(EntriesStore())
            .environmentObject(TeslaFiSessionStore())
    }
}
#endif
