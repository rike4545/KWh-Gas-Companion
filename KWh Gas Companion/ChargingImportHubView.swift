//  ChargingImportHubView.swift
//  My KWh Companion
//
//  Swift 6 / iOS 17+
//
//  Central "Import Center" for charging data.
//  ✅ Wired: ImportHubOnboardingSheet (shows once on first launch)
//  🔧 FIX: TeslaFiTripCSVImportView → TeslaFiCSVImportView (was undefined, caused crash)
//

import SwiftUI

@MainActor
struct ChargingImportHubView: View {
    @EnvironmentObject private var appearance: AppAppearance
    @Environment(\.colorScheme) private var scheme
    @StateObject private var adsStore = AdsEntitlementStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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
                            badge: "Official",
                            isAnalytics: false
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        DirectConnectionClientView()
                    } label: {
                        ImportTile(
                            icon: "server.rack",
                            title: "TeslaMate",
                            subtitle: "Connect your self-hosted TeslaMate API or compatible proxy, review live data, and import fetched charging sessions.",
                            bulletPoints: [
                                "Supports cars, status, drives, charges, geofences, costs, and charging widgets",
                                "Imports TeslaMate charges into existing analytics with duplicate skipping",
                                "Works with read-only API tokens over HTTPS, LAN, or VPN"
                            ],
                            accent: appearance.accentColor,
                            badge: "Self-hosted",
                            isAnalytics: true
                        )
                    }
                    .buttonStyle(.plain)

                    // 🔧 FIX: was TeslaFiTripCSVImportView() — undefined, crash at runtime.
                    // Correct type is TeslaFiCSVImportView.
                    NavigationLink {
                        TeslaFiCSVImportView()
                    } label: {
                        ImportTile(
                            icon: "road.lanes",
                            title: "TeslaFi Raw Trip CSV",
                            subtitle: "Import raw TeslaFi polling logs and derive trip segments for trip summaries and route history.",
                            bulletPoints: [
                                "Derives trips from speed, shift state, and odometer changes",
                                "Stores trips locally on-device",
                                "Keeps this separate from charging-session CSV import"
                            ],
                            accent: appearance.accentColor,
                            badge: "Analytics",
                            isAnalytics: true
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
        .contentMargins(.top, 72, for: .scrollContent)
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle("Imports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await adsStore.load()
        }
        .toolbar(.hidden, for: .tabBar)
        // ✅ Shows the welcome onboarding sheet on first launch, never again after.
        .importHubOnboarding()
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            LinearGradient(
                colors: [
                    appearance.accentColor.opacity(scheme == .dark ? 0.10 : 0.06),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        let accent = appearance.accentColor

        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(accent.opacity(scheme == .dark ? 0.22 : 0.14))
                    .frame(width: 52, height: 52)
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Import Center")
                    .font(.title2.weight(.bold))
                Text("Choose a data pipeline to bring charging history into My KWh Companion.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07))
                )
        )
        .frame(maxWidth: 640)
    }
}

// MARK: - Tile

fileprivate struct ImportTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let bulletPoints: [String]
    let accent: Color
    let badge: String
    let isAnalytics: Bool

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent.opacity(scheme == .dark ? 0.24 : 0.16))
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        // Badge chip
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(accent.opacity(scheme == .dark ? 0.28 : 0.18))
                            )
                            .foregroundStyle(accent)
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
                .opacity(0.5)

            // Bullets
            VStack(alignment: .leading, spacing: 7) {
                ForEach(bulletPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: isAnalytics ? "sparkle" : "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(isAnalytics ? accent : .green)
                            .frame(width: 16, height: 16)
                            .padding(.top, 1)
                        Text(point)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // Footer row
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Text("Open")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(
                    color: Color.black.opacity(scheme == .dark ? 0.30 : 0.08),
                    radius: 12,
                    x: 0,
                    y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
