//
//  VehicleProfileListView.swift
//  KWh Gas Companion
//
//  Garage list
//  - Search matches name/make/model AND VIN + Plate/Marker
//  - Add/Edit uses VehicleProfileView so end users can always enter VIN + Plate/Marker
//  - Avatars follow photo rules: custom wins; else automatic Tesla/Rivian model image
//  - UI tokens: uses AppThemeSpec for avatar surfaces + badges
//
//  Swift 6 • iOS 17+
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct VehicleProfileListView: View {

    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var appearance: AppAppearance
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme

    @StateObject private var adsStore = AdsEntitlementStore.shared
    @State private var searchText: String = ""
    @State private var showingAdd: Bool = false
    @State private var editing: EditingVehicleID? = nil
    @State private var confirmDelete: VehicleProfile? = nil

    // Keep compatibility with older store edge cases (if you ever bridged IDs)
    @State private var showingBadIDAlert: Bool = false
    @State private var badIDName: String = "this vehicle"

    private var theme: any AppThemeSpec { themeBox.base }

    // sheet(item:) needs Identifiable
    private struct EditingVehicleID: Identifiable, Hashable {
        let id: UUID
    }

    private var vehicles: [VehicleProfile] {
        let all = profileStore.vehicles
        let q = normalizedQuery(searchText)
        if q.isEmpty { return all.sorted(by: sortByName) }
        return all.filter { matchesQuery($0, q: q) }.sorted(by: sortByName)
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    VehicleStoryTimelineView()
                } label: {
                    toolRow(
                        title: "Vehicle Story timeline",
                        subtitle: "Expenses + DIY service in one feed",
                        systemImage: "clock.arrow.circlepath"
                    )
                }

                NavigationLink {
                    DIYServiceVaultView()
                } label: {
                    toolRow(
                        title: "DIY part install log",
                        subtitle: "Save receipts, photos, and notes",
                        systemImage: "wrench.and.screwdriver"
                    )
                }

                NavigationLink {
                    ServiceRemindersView()
                        .navigationTitle("Service Reminders")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    toolRow(
                        title: "Baseline checklist",
                        subtitle: "Track recurring service tasks",
                        systemImage: "checklist"
                    )
                }

                NavigationLink {
                    ChargingDataHubView()
                } label: {
                    toolRow(
                        title: "Import / Export",
                        subtitle: "Keep charging history portable",
                        systemImage: "tray.and.arrow.down"
                    )
                }
            } header: {
                Text("Story & Care")
            }

            if vehicles.isEmpty {
                ContentUnavailableView(
                    "No Vehicles",
                    systemImage: "car",
                    description: Text("Add a vehicle to enable VIN tools, better assumptions, and vehicle-aware analytics.")
                )
            } else {
                Section {
                    ForEach(vehicles) { v in
                        NavigationLink {
                            VehicleProfileView(profileID: v.id)
                        } label: {
                            row(v)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                profileStore.selectVehicle(id: v.id)
                            } label: {
                                Label("Set Current", systemImage: "checkmark.circle")
                            }
                            .tint(appearance.accentColor)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                editing = EditingVehicleID(id: v.id)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(appearance.accentColor)

                            Button(role: .destructive) {
                                confirmDelete = v
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Vehicles")
                }
            }

            if !adsStore.hasRemovedAds {
                Section {
                    AdBannerCard(adsStore: adsStore)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Garage")
        .navigationBarTitleDisplayMode(.inline)
        .tint(appearance.accentColor)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search name, VIN, plate…")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add vehicle")
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                VehicleProfileView(profileID: UUID(), setSelected: false)
            }
        }
        .sheet(item: $editing) { edit in
            NavigationStack {
                VehicleProfileView(profileID: edit.id)
            }
        }
        .alert("Can’t edit \(badIDName)", isPresented: $showingBadIDAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This vehicle’s identifier isn’t a valid UUID. If it was migrated from older storage, opening and re-saving it may regenerate a valid ID.")
        }
        .confirmationDialog(
            "Delete vehicle?",
            isPresented: Binding(
                get: { confirmDelete != nil },
                set: { if !$0 { confirmDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let v = confirmDelete {
                    profileStore.removeVehicle(id: v.id)
                    Task { await VehicleImageStore.delete(id: v.id) }
                }
                confirmDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("This removes the vehicle profile and any attached custom photo stored on-device.")
        }
        .task {
            await adsStore.load()
        }
        .background(listBackground)
    }

    private var listBackground: some View {
        ZStack {
            Rectangle()
                .fill(theme.screenBackground)
                .ignoresSafeArea()

            RadialGradient(
                colors: [appearance.accentColor.opacity(scheme == .dark ? 0.18 : 0.10), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
            .blur(radius: 30)
            .ignoresSafeArea()
        }
    }

    // MARK: - Row

    private func row(_ v: VehicleProfile) -> some View {
        HStack(spacing: 12) {
            #if canImport(UIKit)
            GarageAvatar(theme: theme, accent: appearance.accentColor, vehicle: v, size: 44)
                .accessibilityHidden(true)
            #else
            Image(systemName: "car.fill").accessibilityHidden(true)
            #endif

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(v.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    if profileStore.selectedVehicleID == v.id {
                        Text("Current")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(theme.pillTint.opacity(0.35))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(theme.separator.opacity(0.85), lineWidth: 1)
                            )
                    }
                }

                Text(v.summarySubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func toolRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: theme.smallCorner + 4, style: .continuous)
                    .fill(theme.pillTint.opacity(scheme == .dark ? 0.22 : 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.smallCorner + 4, style: .continuous)
                            .strokeBorder(theme.separator.opacity(scheme == .dark ? 0.78 : 0.55), lineWidth: 1)
                    )
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(appearance.accentColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Search helpers

    private func normalizedQuery(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func sortByName(_ a: VehicleProfile, _ b: VehicleProfile) -> Bool {
        a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
    }

    private func matchesQuery(_ v: VehicleProfile, q: String) -> Bool {
        // ✅ VIN + Plate/Marker included
        let fields: [String] = [
            v.displayName,
            v.make,
            v.model,
            v.vin,
            v.plateOrMarker
        ]
        return fields.contains(where: { $0.lowercased().contains(q) })
    }
}

#if canImport(UIKit)
fileprivate struct GarageAvatar: View {
    let theme: any AppThemeSpec
    let accent: Color
    let vehicle: VehicleProfile
    let size: CGFloat

    @State private var custom: UIImage? = nil

    private var auto: UIImage? { VehicleImageStore.automaticImage(for: vehicle) }
    private var effective: UIImage? { custom ?? auto } // ✅ custom wins

    var body: some View {
        ZStack {
            if let img = effective {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: theme.smallCorner + 6, style: .continuous)
                        .fill(theme.cardBackground)
                    Image(systemName: "car.fill")
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: theme.smallCorner + 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.smallCorner + 6, style: .continuous)
                .strokeBorder(theme.separator.opacity(0.85), lineWidth: 1)
        )
        .task(id: vehicle.id) {
            custom = await VehicleImageStore.load(id: vehicle.id)
        }
    }
}
#endif
