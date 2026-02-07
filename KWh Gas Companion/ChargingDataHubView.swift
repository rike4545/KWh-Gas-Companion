//
//  ChargingDataHubView.swift
//  My KWh Companion
//
//  Charging data hub: import, reconciliation, export, and quick health signals.
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import Foundation

@MainActor
struct ChargingDataHubView: View {

    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var appearance: AppAppearance
    @StateObject private var adsStore = AdsEntitlementStore.shared
    @StateObject private var teslaFiUnlock = TeslaFiEntitlementStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                summaryCard
                importStatusCard
                actionsCard

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("Charging Data")
        .navigationBarTitleDisplayMode(.inline)
        .background(backgroundView.ignoresSafeArea())
        .task {
            await adsStore.load()
            await teslaFiUnlock.load()
        }
    }

    // MARK: - Cards

    private var summaryCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Summary", systemImage: "tray.full")
                    .font(.headline)

                let teslaFiCount: Int = {
                    guard teslaFiUnlock.hasTeslaFiUnlock else { return 0 }
                    if !teslaFiStore.canonicalSessions.isEmpty { return teslaFiStore.canonicalSessions.count }
                    return teslaFiStore.sessions.count
                }()

                let energyEntryCount = entriesStore.energyEntries().count

                statRow("TeslaFi sessions", "\(teslaFiCount)")
                statRow("Energy entries", "\(energyEntryCount)")
                statRow("All entries", "\(entriesStore.entries.count)")

                Divider().padding(.vertical, 2)

                if teslaFiUnlock.hasTeslaFiUnlock {
                    Text("Use Import, Reconcile, and Export to keep your charging history clean and portable.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Unlock TeslaFi import to enable richer analytics and reconciliation.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var importStatusCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("TeslaFi Import", systemImage: "tray.and.arrow.down")
                        .font(.headline)
                    Spacer()
                    if teslaFiStore.isImporting && teslaFiUnlock.hasTeslaFiUnlock {
                        Text("Working…")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    }
                }

                if !teslaFiUnlock.hasTeslaFiUnlock {
                    TeslaFiUnlockCard(
                        title: "TeslaFi Import Locked",
                        subtitle: "Unlock TeslaFi CSV import and analytics for $0.99."
                    )
                } else if teslaFiStore.isImporting {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Importing and parsing your CSV…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if let err = teslaFiStore.lastError, !err.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let report = teslaFiStore.lastImportReport {
                    Text("Last import: \(describeImportReport(report))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No import yet. Importing TeslaFi unlocks richer session analytics and reconciliation.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if teslaFiUnlock.hasTeslaFiUnlock {
                    NavigationLink {
                        TeslaFiCSVImportView()
                    } label: {
                        actionRow(
                            title: "Import TeslaFi CSV",
                            subtitle: "Bring in charging sessions from TeslaFi",
                            systemImage: "tray.and.arrow.down"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var actionsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Tools", systemImage: "wrench.and.screwdriver")
                    .font(.headline)

                NavigationLink {
                    ChargingReconciliationView()
                } label: {
                    actionRow(
                        title: "Reconcile Sources",
                        subtitle: "Compare TeslaFi vs your entries",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ChargingDataStudioView() // ✅ no-arg
                } label: {
                    actionRow(
                        title: "Charging Data Studio",
                        subtitle: "Inspect and analyze charging records",
                        systemImage: "tablecells"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    CSVExportView()
                } label: {
                    actionRow(
                        title: "Export CSV",
                        subtitle: "Share or back up your data",
                        systemImage: "square.and.arrow.up"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    TeslaMateProClientView()
                } label: {
                    actionRow(
                        title: "TeslaMate Client (Pro)",
                        subtitle: "Direct TeslaMate dashboards + charging costs",
                        systemImage: "server.rack"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - UI Helpers

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold))
        }
        .font(.subheadline)
    }

    private func actionRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(title)")
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

    private var backgroundView: some View {
        let accent = appearance.accentColor
        return LinearGradient(
            colors: [accent.opacity(0.18), Color(.systemBackground), Color(.secondarySystemBackground)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Import report formatting (no assumptions about fields)

    private func describeImportReport(_ report: TFIImportReport) -> String {
        let m = Mirror(reflecting: report)

        func int(_ name: String) -> Int? { m.children.first { $0.label == name }?.value as? Int }
        func dbl(_ name: String) -> Double? { m.children.first { $0.label == name }?.value as? Double }
        func str(_ name: String) -> String? { m.children.first { $0.label == name }?.value as? String }

        let imported  = int("imported") ?? int("added") ?? int("newCount") ?? int("newSessions")
        let deduped   = int("deduped") ?? int("duplicates") ?? int("duplicateCount")
        let rows      = int("rows") ?? int("rowCount") ?? int("totalRows")
        let errors    = int("errors") ?? int("errorCount")
        let filename  = str("filename") ?? str("fileName") ?? str("sourceName")
        let seconds   = dbl("durationSeconds") ?? dbl("seconds")

        var parts: [String] = []
        if let filename, !filename.isEmpty { parts.append(filename) }
        if let imported { parts.append("\(imported) added") }
        if let deduped { parts.append("\(deduped) dupes") }
        if let rows { parts.append("\(rows) rows") }
        if let errors, errors > 0 { parts.append("\(errors) errors") }
        if let seconds { parts.append(String(format: "%.1fs", seconds)) }

        if !parts.isEmpty { return parts.joined(separator: " · ") }
        if let desc = report as? CustomStringConvertible { return desc.description }
        return String(describing: type(of: report))
    }
}
