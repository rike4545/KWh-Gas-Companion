//
//  HomeView.swift
//  KWh Gas Companion
//
//  Home hub — smooth + data-aware
//  Uses TeslaFiSessionStore via @EnvironmentObject.
//

import SwiftUI

@MainActor
struct HomeView: View {

    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore
    @EnvironmentObject private var entriesStore: EntriesStore
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme

    @State private var showSessionAnalytics = false
    @State private var showImport = false
    @State private var showTripInsights = false

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing) {
                header

                overviewStrip

                nextUpCard

                teslaFiCard

                tripInsightsCard

                entriesCard
            }
            .padding()
        }
        .background(
            Rectangle()
                .fill(theme.screenBackground)
                .ignoresSafeArea()
        )
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showImport = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            }
        }
        .sheet(isPresented: $showImport) {
            NavigationStack {
                CSVChargingWizardView()
            }
        }
        .sheet(isPresented: $showSessionAnalytics) {
            NavigationStack {
                SessionAnalyticsView()
            }
        }
        .sheet(isPresented: $showTripInsights) {
            NavigationStack {
                TripInsightsView(sessions: preferredSessions)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("My EV Companion")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text(headerSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Text(preferredSessions.isEmpty ? "Start here" : "Live")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(theme.pillTint.opacity(scheme == .dark ? 0.28 : 0.78)))
            }

            if !preferredSessions.isEmpty {
                HStack(spacing: 10) {
                    microPill("Sessions", "\(preferredSessions.count)")
                    microPill("Missing cost", "\(missingTeslaFiCostCount)")
                    if let avg = tripSnapshot.selectedWindow?.averageKnownCost {
                        microPill("Avg trip", fmtCurrency(avg))
                    }
                }
            }
        }
        .themedCard(prominent: true)
    }

    private var overviewStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("At a glance")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: overviewColumns, spacing: 12) {
                overviewTile(
                    title: "Energy",
                    value: energyHeadline,
                    symbol: "bolt.fill"
                )
                overviewTile(
                    title: "Spend",
                    value: costHeadline,
                    symbol: "dollarsign.circle.fill"
                )
                overviewTile(
                    title: "Trips",
                    value: tripHeadline,
                    symbol: "road.lanes"
                )
                overviewTile(
                    title: "Data quality",
                    value: qualityHeadline,
                    symbol: "checkmark.shield.fill"
                )
            }
        }
    }

    // MARK: - Next Up (sentience)

    private var nextUpCard: some View {
        let sessions = teslaFiStore.canonicalSessions.isEmpty
            ? teslaFiStore.sessions
            : teslaFiStore.canonicalSessions
        let sessionCount = sessions.count
        let missingCost = sessions.filter { ($0.cost ?? 0) <= 0 }.count

        let suggested: [String] = {
            var out: [String] = []

            if sessionCount == 0 {
                out.append("Import charging sessions to populate analytics and trends.")
            } else {
                out.append("You have \(sessionCount) session(s) loaded.")
            }

            if missingCost > 0 {
                out.append("Add missing costs to \(missingCost) session(s) to improve accuracy.")
            }

            // EntriesStore (optional)
            if let snapshot = entriesSnapshot, snapshot.count == 0, sessionCount > 0 {
                out.append("You have imported charging data, but no saved charging entries yet — consider converting sessions to entries.")
            }

            return out
        }()

        return sectionCard(
            title: "Next Up",
            systemImage: "sparkles",
            eyebrow: "Smart hints"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if suggested.isEmpty {
                    Label("Everything looks good.", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(suggested.enumerated()), id: \.offset) { index, suggestion in
                        tipRow(suggestion, icon: index == 0 ? "wand.and.stars" : "arrow.triangle.turn.up.right.diamond.fill")
                    }
                }
            }
        }
    }

    // MARK: - TeslaFi

    private var teslaFiCard: some View {
        let sessions = preferredSessions
        let count = sessions.count
        let totalKWh = sessions.reduce(0.0) { $0 + max(0, $1.energyAddedKWh) }
        let totalCost = sessions.reduce(0.0) { $0 + max(0, $1.cost ?? 0) }

        return sectionCard(
            title: "Charging History",
            systemImage: "bolt.car",
            eyebrow: count == 0 ? "Import ready" : "\(count) sessions"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if count == 0 {
                    Text("No sessions imported yet.")
                        .foregroundStyle(.secondary)

                    Button {
                        showImport = true
                    } label: {
                        Label("Import Charging History", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    HStack(spacing: 12) {
                        statCard("Energy", "\(fmtNumber(totalKWh, digits: 1)) kWh", symbol: "bolt.circle.fill")
                        statCard("Cost", fmtCurrency(totalCost), symbol: "banknote.fill")
                    }

                    Button {
                        showSessionAnalytics = true
                    } label: {
                        Label("View Analytics", systemImage: "chart.bar.xaxis")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var tripInsightsCard: some View {
        let snapshot = TripInsightsSnapshot.build(from: preferredSessions)

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                if let window = snapshot.selectedWindow {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(window.averageKnownCost.map(fmtCurrency) ?? "\(fmtNumber(window.averageEnergyKWh, digits: 1)) kWh")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .monospacedDigit()
                        Text(window.averageKnownCost == nil ? "Average energy per trip" : "Average trip cost")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        previewStat("Window", "\(window.size) trips")
                        previewStat("Avg energy", "\(fmtNumber(window.averageEnergyKWh, digits: 1)) kWh")
                        previewStat("Price / kWh", window.averageKnownPricePerKWh.map(fmtCurrency) ?? "Need pricing")
                    }

                    Text(snapshot.trendDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        showTripInsights = true
                    } label: {
                        Label("Open Trip Insights", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Text("Import charging sessions to compare recent trips and spot trends.")
                        .foregroundStyle(.secondary)
                    Button {
                        showImport = true
                    } label: {
                        Label("Import Charging History", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .overlay(alignment: .top) {
            EmptyView()
        }
        .modifier(HomeSectionModifier(
            title: "Trip Insights",
            systemImage: "road.lanes",
            eyebrow: snapshot.totalTrips == 0 ? "Waiting for trips" : "\(snapshot.totalTrips) total"
        ))
    }

    // MARK: - Entries (optional)

    private var entriesCard: some View {
        sectionCard(
            title: "Saved Entries",
            systemImage: "tray.full",
            eyebrow: "\(entriesSnapshot?.count ?? 0) logged"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if let snap = entriesSnapshot, snap.count > 0 {
                    HStack(spacing: 12) {
                        statCard("Energy", "\(fmtNumber(snap.energyKWh, digits: 1)) kWh", symbol: "bolt.fill")
                        statCard("Cost", fmtCurrency(snap.cost), symbol: "creditcard.fill")
                    }
                } else {
                    Text("No saved entries yet.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var entriesSnapshot: (count: Int, energyKWh: Double, cost: Double)? {
        let items = entriesStore.entries
        let charging = items.filter { $0.isEnergyEffective }
        let energy = charging.reduce(into: 0.0) { $0 += max(0, $1.energyAddedKWh ?? 0) }
        let cost = charging.reduce(into: 0.0) { $0 += max(0, $1.amount) }
        return (charging.count, energy, cost)
    }

    private var preferredSessions: [TeslaFiSession] {
        teslaFiStore.canonicalSessions.isEmpty
            ? teslaFiStore.sessions
            : teslaFiStore.canonicalSessions
    }

    private var tripSnapshot: TripInsightsSnapshot {
        TripInsightsSnapshot.build(from: preferredSessions)
    }

    private var missingTeslaFiCostCount: Int {
        preferredSessions.filter { ($0.cost ?? 0) <= 0 }.count
    }

    private var headerSubtitle: String {
        if preferredSessions.isEmpty {
            return "Your companion for turning gas-car habits into confident EV routines. Import charging history to unlock smarter guidance."
        }
        if let window = tripSnapshot.selectedWindow {
            return "Your last \(window.size) trips are summarized so the EV transition feels easier to understand."
        }
        return "Charging, fuel comparisons, and ownership costs in one transition-friendly dashboard."
    }

    private var energyHeadline: String {
        if let entries = entriesSnapshot, entries.energyKWh > 0 {
            return "\(fmtNumber(entries.energyKWh, digits: 1)) kWh"
        }
        let total = preferredSessions.reduce(0.0) { $0 + max(0, $1.energyAddedKWh) }
        return total > 0 ? "\(fmtNumber(total, digits: 1)) kWh" : "No data"
    }

    private var costHeadline: String {
        if let entries = entriesSnapshot, entries.cost > 0 {
            return fmtCurrency(entries.cost)
        }
        let total = preferredSessions.reduce(0.0) { $0 + max(0, $1.cost ?? 0) }
        return total > 0 ? fmtCurrency(total) : "Need costs"
    }

    private var tripHeadline: String {
        guard let selected = tripSnapshot.selectedWindow else { return "Import trips" }
        return "\(selected.tripCount) recent"
    }

    private var qualityHeadline: String {
        if preferredSessions.isEmpty { return "Setup needed" }
        if missingTeslaFiCostCount == 0 { return "Healthy" }
        return "\(missingTeslaFiCostCount) missing"
    }

    private var overviewColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 120), spacing: 12),
            GridItem(.flexible(minimum: 120), spacing: 12)
        ]
    }

    // MARK: - Small UI helpers

    private func sectionCard<Content: View>(
        title: String,
        systemImage: String,
        eyebrow: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Spacer()
                Text(eyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .themedCard()
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statCard(_ title: String, _ value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(theme.accent)
            stat(title, value)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.pillTint.opacity(scheme == .dark ? 0.20 : 0.60))
        )
    }

    private func previewStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.pillTint.opacity(scheme == .dark ? 0.20 : 0.60))
        )
    }

    private func overviewTile(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(theme.accent)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.pillTint.opacity(scheme == .dark ? 0.18 : 0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(theme.separator.opacity(scheme == .dark ? 0.40 : 0.18), lineWidth: 1)
                )
        )
    }

    private func microPill(_ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(theme.pillTint.opacity(scheme == .dark ? 0.22 : 0.62)))
    }

    private func tipRow(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.pillTint.opacity(scheme == .dark ? 0.22 : 0.62))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.accent)
                )

            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
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
}

private struct HomeSectionModifier: ViewModifier {
    let title: String
    let systemImage: String
    let eyebrow: String

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Spacer()
                Text(eyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            content
        }
        .themedCard(prominent: true)
    }
}
