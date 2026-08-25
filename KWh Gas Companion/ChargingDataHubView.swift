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

    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var appearance: AppAppearance
    @StateObject private var adsStore = AdsEntitlementStore.shared
    @Environment(\.colorScheme) private var scheme

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
        }
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        card(tint: appearance.accentColor) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Summary", systemImage: "tray.full.fill")
                    .font(.headline)

                let energyCount = entriesStore.energyEntries().count
                let totalCount = entriesStore.entries.count

                HStack(spacing: 12) {
                    summaryStatChip(
                        value: "\(energyCount)",
                        label: "Energy entries",
                        icon: "bolt.fill",
                        color: appearance.accentColor
                    )
                    summaryStatChip(
                        value: "\(totalCount)",
                        label: "All entries",
                        icon: "list.bullet",
                        color: .secondary
                    )
                }

                Divider()
                    .opacity(0.4)

                Text("Use Import, Reconcile, and Export to keep your charging history clean and portable.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Import Card

    private var importStatusCard: some View {
        card(tint: appearance.accentColor) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Import Charging History", systemImage: "tray.and.arrow.down.fill")
                    .font(.headline)

                Text("Bring in your official Tesla charging history and save each session to your charging log.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                NavigationLink {
                    CSVChargingWizardView()
                } label: {
                    actionRow(
                        title: "Import Official Tesla CSV",
                        subtitle: "Match columns and save your sessions",
                        systemImage: "tray.and.arrow.down",
                        tint: appearance.accentColor
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        card(tint: .secondary) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Tools", systemImage: "wrench.and.screwdriver.fill")
                    .font(.headline)
                    .padding(.bottom, 8)

                NavigationLink {
                    ChargingReconciliationView()
                } label: {
                    actionRow(
                        title: "Reconcile Sources",
                        subtitle: "Compare imported sessions vs your entries",
                        systemImage: "arrow.triangle.2.circlepath",
                        tint: .purple
                    )
                }
                .buttonStyle(.plain)

                rowDivider

                NavigationLink {
                    ChargingDataStudioView()
                } label: {
                    actionRow(
                        title: "Charging Data Studio",
                        subtitle: "Inspect and analyze charging records",
                        systemImage: "tablecells",
                        tint: .blue
                    )
                }
                .buttonStyle(.plain)

                rowDivider

                NavigationLink {
                    CSVExportView()
                } label: {
                    actionRow(
                        title: "Export CSV",
                        subtitle: "Share or back up your data",
                        systemImage: "square.and.arrow.up",
                        tint: .green
                    )
                }
                .buttonStyle(.plain)

                rowDivider

                NavigationLink {
                    DirectConnectionClientView()
                } label: {
                    actionRow(
                        title: "Direct Connection",
                        subtitle: "Connect a compatible dashboard API",
                        systemImage: "server.rack",
                        tint: .orange
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 40)
            .opacity(0.4)
    }

    private func summaryStatChip(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.bold).monospacedDigit())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemBackground))
        )
    }

    private func actionRow(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(scheme == .dark ? 0.22 : 0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(title)")
    }

    private func card<Content: View>(tint: Color, @ViewBuilder _ content: () -> Content) -> some View {
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
            colors: [
                accent.opacity(scheme == .dark ? 0.16 : 0.10),
                Color(uiColor: .systemBackground),
                Color(uiColor: .secondarySystemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Import report formatting

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

        return parts.isEmpty ? String(describing: type(of: report)) : parts.joined(separator: " · ")
    }
}
