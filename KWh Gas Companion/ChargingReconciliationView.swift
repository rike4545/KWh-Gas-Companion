//
//  ChargingReconciliationView.swift
//  My KWh Companion
//
//  Reconcile TeslaFi sessions vs on-device ExpenseEntry charging rows.
//  - No dependency on legacy `ChargingLedgerMapping`
//  - No dynamicMember binding access on EnvironmentObject
//  - Uses EVChargingLedgerItem builders + simple matching heuristics
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import Foundation

@MainActor
struct ChargingReconciliationView: View {

    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore
    @EnvironmentObject private var entriesStore: EntriesStore

    @State private var showMatchesOnly: Bool = true
    @State private var maxMinutesApart: Double = 20
    @State private var maxKWhApart: Double = 0.6

    var body: some View {
        let result = reconcile()

        ScrollView {
            VStack(spacing: 14) {

                summaryCard(result: result)

                controlsCard

                if !result.matches.isEmpty {
                    matchesCard(result: result)
                }

                if !result.unmatchedTeslaFi.isEmpty {
                    unmatchedTeslaFiCard(items: result.unmatchedTeslaFi)
                }

                if !result.unmatchedEntries.isEmpty {
                    unmatchedEntriesCard(items: result.unmatchedEntries)
                }

                if result.matches.isEmpty, result.unmatchedTeslaFi.isEmpty, result.unmatchedEntries.isEmpty {
                    emptyStateCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("Reconcile Sources")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Reconciliation model

    private struct Match: Identifiable {
        let id: String
        let teslaFi: EVChargingLedgerItem
        let entry: EVChargingLedgerItem
        let minutesApart: Double
        let kWhApart: Double
        let locationHint: String
    }

    private struct ReconcileResult {
        let teslaFiCount: Int
        let entryCount: Int
        let matches: [Match]
        let unmatchedTeslaFi: [EVChargingLedgerItem]
        let unmatchedEntries: [EVChargingLedgerItem]
    }

    // MARK: - Core reconcile logic (greedy matcher)

    private func reconcile() -> ReconcileResult {
        // Source lists
        let teslaFiItems: [EVChargingLedgerItem] =
            teslaFiStore.sessions
                .map { EVChargingLedgerItem.fromTeslaFi($0) }
                .sorted(by: { $0.startDate > $1.startDate })

        let entryItemsAll: [EVChargingLedgerItem] =
            entriesStore.energyEntries()
                .map { EVChargingLedgerItem.fromEntry($0) }
                .sorted(by: { $0.startDate > $1.startDate })

        // Match using a greedy strategy:
        // for each TeslaFi item, take the best remaining entry within thresholds.
        var remainingEntries = entryItemsAll
        var matches: [Match] = []
        matches.reserveCapacity(min(teslaFiItems.count, entryItemsAll.count))

        for t in teslaFiItems {
            guard let (bestIdx, bestMatch) = bestEntryMatch(for: t, candidates: remainingEntries) else {
                continue
            }
            matches.append(bestMatch)
            remainingEntries.remove(at: bestIdx)
        }

        // Unmatched
        let matchedTeslaFiIDs = Set(matches.map { $0.teslaFi.id })
        let unmatchedTeslaFi = teslaFiItems.filter { !matchedTeslaFiIDs.contains($0.id) }
        let unmatchedEntries = remainingEntries

        // Optionally filter view down to matches only
        let filteredMatches = showMatchesOnly ? matches : matches

        return ReconcileResult(
            teslaFiCount: teslaFiItems.count,
            entryCount: entryItemsAll.count,
            matches: filteredMatches,
            unmatchedTeslaFi: showMatchesOnly ? [] : unmatchedTeslaFi,
            unmatchedEntries: showMatchesOnly ? [] : unmatchedEntries
        )
    }

    private func bestEntryMatch(
        for teslaFi: EVChargingLedgerItem,
        candidates: [EVChargingLedgerItem]
    ) -> (Int, Match)? {

        var best: (idx: Int, score: Double, match: Match)? = nil

        for (idx, e) in candidates.enumerated() {
            // Time window
            let dt = abs(e.startDate.timeIntervalSince(teslaFi.startDate))
            let minutesApart = dt / 60.0
            if minutesApart > maxMinutesApart { continue }

            // kWh difference (if both known)
            let tk = teslaFi.energyKWh
            let ek = e.energyKWh
            let kWhApart: Double = {
                guard let tk, let ek else { return 0 } // if missing, don't block
                return abs(tk - ek)
            }()
            if (tk != nil && ek != nil) && kWhApart > maxKWhApart { continue }

            // Location hint
            let hint = locationSimilarityHint(a: teslaFi.location, b: e.location)

            // Score: smaller minutes + smaller kWh + bonus if location looks similar
            var score = minutesApart * 1.0 + kWhApart * 6.0
            if hint == "Same site" { score -= 3.0 }
            if hint == "Similar" { score -= 1.2 }

            let m = Match(
                id: teslaFi.id + "→" + e.id,
                teslaFi: teslaFi,
                entry: e,
                minutesApart: minutesApart,
                kWhApart: kWhApart,
                locationHint: hint
            )

            if let current = best {
                if score < current.score {
                    best = (idx, score, m)
                }
            } else {
                best = (idx, score, m)
            }
        }

        if let best { return (best.idx, best.match) }
        return nil
    }

    private func locationSimilarityHint(a: String, b: String) -> String {
        let aa = a.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let bb = b.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if aa.isEmpty || bb.isEmpty { return "—" }
        if aa == bb { return "Same site" }

        // Very light similarity: token overlap
        let aTokens = Set(aa.split(separator: " ").map(String.init))
        let bTokens = Set(bb.split(separator: " ").map(String.init))
        let overlap = aTokens.intersection(bTokens).count
        if overlap >= 2 { return "Similar" }

        // "supercharger" / "dcfc" hint
        if (aa.contains("supercharg") && bb.contains("supercharg")) { return "Similar" }
        if (aa.contains("dcfc") && bb.contains("dcfc")) { return "Similar" }

        return "Different"
    }

    // MARK: - UI

    private func summaryCard(result: ReconcileResult) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Overview", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)

                statRow("TeslaFi rows", "\(result.teslaFiCount)")
                statRow("Entry rows", "\(result.entryCount)")
                statRow("Matches", "\(result.matches.count)")

                Text(showMatchesOnly
                     ? "Showing matches only. Turn off the filter to see unmatched rows."
                     : "Review unmatched rows to spot missing imports or duplicated sessions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var controlsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Matching Controls", systemImage: "slider.horizontal.3")
                    .font(.headline)

                Toggle("Show matches only", isOn: $showMatchesOnly)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Max minutes apart: \(Int(maxMinutesApart))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Slider(value: $maxMinutesApart, in: 5...60, step: 5)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Max kWh difference: \(String(format: "%.1f", maxKWhApart))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Slider(value: $maxKWhApart, in: 0.2...3.0, step: 0.2)
                }
            }
        }
    }

    private func matchesCard(result: ReconcileResult) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Matches", systemImage: "checkmark.seal")
                    .font(.headline)

                ForEach(result.matches.prefix(40)) { m in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(dateTime(m.teslaFi.startDate))
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(Int(m.minutesApart))m · \(String(format: "%.1f", m.kWhApart)) kWh")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("TeslaFi: \(m.teslaFi.location)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text("Entry: \(m.entry.location) · \(m.locationHint)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 8)

                    Divider().opacity(0.35)
                }

                if result.matches.count > 40 {
                    Text("Showing first 40 matches.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func unmatchedTeslaFiCard(items: [EVChargingLedgerItem]) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Unmatched TeslaFi", systemImage: "tray.and.arrow.down")
                    .font(.headline)

                ForEach(items.prefix(40)) { it in
                    row(item: it)
                    Divider().opacity(0.35)
                }

                if items.count > 40 {
                    Text("Showing first 40.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func unmatchedEntriesCard(items: [EVChargingLedgerItem]) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Unmatched Entries", systemImage: "square.and.pencil")
                    .font(.headline)

                ForEach(items.prefix(40)) { it in
                    row(item: it)
                    Divider().opacity(0.35)
                }

                if items.count > 40 {
                    Text("Showing first 40.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var emptyStateCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Label("Nothing to reconcile yet", systemImage: "info.circle")
                    .font(.headline)
                Text("Import TeslaFi and/or add charging entries to compare sources.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func row(item: EVChargingLedgerItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dateTime(item.startDate))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let k = item.energyKWh {
                    Text(String(format: "%.1f kWh", k))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(item.location)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold))
        }
        .font(.subheadline)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            )
    }

    private func dateTime(_ d: Date) -> String {
        Self.df.string(from: d)
    }

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
}
