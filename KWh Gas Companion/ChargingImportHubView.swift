//
//  ChargingImportHubView.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/10/25.
//


//
//  ChargingImportHubView.swift
//  My KWh Companion
//
//  Swift 6 / iOS 17+
//
//  Central “Import Center” for charging data:
//  - Official Tesla Supercharging CSV  → CSVChargingWizardView (billing / ledger)
//  - TeslaFi Monthly Analytics CSV     → TeslaFiCSVImportView (analytics sessions)
//
//  This view does NOT do any importing itself. It only routes to the
//  appropriate importer and explains the difference between them.
//
//

import SwiftUI

@MainActor
struct ChargingImportHubView: View {
    @EnvironmentObject private var appearance: AppAppearance
    @Environment(\.colorScheme) private var scheme
    @StateObject private var adsStore = AdsEntitlementStore.shared
    @StateObject private var teslaFiUnlock = TeslaFiEntitlementStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                VStack(spacing: 16) {
                    NavigationLink {
                        CSVChargingWizardView()
                    } label: {
                        ImportTile(
                            icon: "bolt.car.fill",
                            title: "Official Tesla Supercharging CSV",
                            subtitle: "Import billed Supercharging sessions from the official Tesla app CSV into your main charging ledger.",
                            bulletPoints: [
                                "Writes to your ExpenseEntry / charging log",
                                "Maps Tesla billing headers (ChargeStartDateTime, QuantityBase, Total Inc. VAT, etc.)",
                                "Supports duplicate skipping & optional kWh backfill"
                            ],
                            accent: appearance.accentColor,
                            isAnalytics: false,
                            locked: false
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        TeslaFiCSVImportView()
                    } label: {
                        ImportTile(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "TeslaFi Monthly Analytics CSV",
                            subtitle: teslaFiUnlock.hasTeslaFiUnlock
                                ? "Import monthly CSV exports from TeslaFi.com to build richer analytics and reconstructed charging sessions."
                                : "Unlock for $0.99 to import monthly CSV exports from TeslaFi.com.",
                            bulletPoints: [
                                "Uses TeslaFiSessionStore.parseTeslaFiCSV",
                                "Safe to re-import the same month (duplicates are skipped)",
                                "Does not modify your official Tesla billing history"
                            ],
                            accent: appearance.accentColor,
                            isAnalytics: true,
                            locked: !teslaFiUnlock.hasTeslaFiUnlock
                        )
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 640)

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                        .frame(maxWidth: 640)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Charging Imports")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await adsStore.load()
            await teslaFiUnlock.load()
        }
    }

    // MARK: - Header

    private var header: some View {
        let accent = appearance.accentColor

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(scheme == .dark ? 0.25 : 0.18))
                    Image(systemName: "bolt.fill")
                        .font(.title2.weight(.semibold))
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Charging Import Center")
                        .font(.title2.weight(.semibold))
                    Text("Choose how you want to bring charging data into My KWh Companion.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text("Use the **Official Tesla Supercharging CSV** importer for real billing history from Tesla. Use the **TeslaFi Monthly Analytics CSV** importer for rich, time-series logs from TeslaFi.com. They are fully independent pipelines.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Tile

fileprivate struct ImportTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let bulletPoints: [String]
    let accent: Color
    let isAnalytics: Bool
    let locked: Bool

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent.opacity(scheme == .dark ? 0.26 : 0.18))
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if locked {
                    Text("Locked")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(accent.opacity(0.18)))
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(bulletPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: isAnalytics ? "sparkles" : "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(isAnalytics ? accent : .secondary)
                        Text(point)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(
                    color: Color.black.opacity(scheme == .dark ? 0.35 : 0.10),
                    radius: 10,
                    x: 0,
                    y: 4
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let appearance = AppAppearance()
    let entries = EntriesStore()
    let teslaFi = TeslaFiSessionStore()
    let profile = ProfileStore()
    let appModel = KWhGasCompanionAppModel(
        teslaFiStore: teslaFi,
        profileStore: profile,
        entriesStore: entries
    )

    return NavigationStack {
        ChargingImportHubView()
            .environmentObject(appearance)
            .environmentObject(entries)
            .environmentObject(teslaFi)
            .environmentObject(profile)
            .environmentObject(appModel)
    }
}
#endif
