//
//  VehicleMenu.swift
//  KWh Gas Companion
//
//  Tesla-style quick vehicle switcher.
//  - Menu rows and label avatar follow photo rules:
//      * Custom photo wins
//      * Otherwise automatic Tesla/Rivian model image
//  - UI tokens: uses AppThemeSpec for avatar surfaces, AppAppearance for accent
//
//  Swift 6 • iOS 17+
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct VehicleMenu: View {

    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var appearance: AppAppearance
    @Environment(\.appThemeBox) private var themeBox

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        Menu {
            ForEach(profileStore.vehicles.sorted(by: { $0.displayName < $1.displayName })) { v in
                Button {
                    select(v.id)
                } label: {
                    HStack(spacing: 10) {
                        #if canImport(UIKit)
                        VehicleMenuAvatar(theme: theme, accent: appearance.accentColor, vehicle: v, size: 18)
                        #endif
                        Text(v.displayName)
                        Spacer()
                        if selectedVehicleID == v.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            NavigationLink {
                VehicleProfileListView()
            } label: {
                Label("Manage Vehicles", systemImage: "car.2")
            }
        } label: {
            HStack(spacing: 8) {
                #if canImport(UIKit)
                VehicleMenuLabelAvatar(theme: theme, accent: appearance.accentColor, vehicle: selectedVehicle, size: 20)
                #else
                Image(systemName: "car.fill").foregroundStyle(.secondary)
                #endif

                Text(selectedVehicle?.displayName ?? "Vehicle")
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .tint(appearance.accentColor)
        .accessibilityLabel("Vehicle menu")
    }

    // MARK: - Selection readback

    private var selectedVehicleID: UUID? {
        profileStore.selectedVehicleID
    }

    private var selectedVehicle: VehicleProfile? {
        guard let id = selectedVehicleID else { return nil }
        return profileStore.vehicles.first(where: { $0.id == id })
    }

    // MARK: - Selection writeback

    private func select(_ id: UUID) {
        // Keeps the same storage assumption used across your vehicle files (UUID?).
        profileStore.selectedVehicleID = id
    }
}

#if canImport(UIKit)
fileprivate struct VehicleMenuAvatar: View {
    let theme: any AppThemeSpec
    let accent: Color
    let vehicle: VehicleProfile
    let size: CGFloat

    @State private var custom: UIImage? = nil
    private var auto: UIImage? { VehicleImageStore.automaticImage(for: vehicle) }
    private var effective: UIImage? { custom ?? auto }

    var body: some View {
        ZStack {
            if let img = effective {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(theme.cardBackground)
                    Image(systemName: "car.fill")
                        .font(.system(size: size * 0.55, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(theme.separator.opacity(0.85), lineWidth: 1))
        .task(id: vehicle.id) { custom = await VehicleImageStore.load(id: vehicle.id) }
    }
}

fileprivate struct VehicleMenuLabelAvatar: View {
    let theme: any AppThemeSpec
    let accent: Color
    let vehicle: VehicleProfile?
    let size: CGFloat

    @State private var custom: UIImage? = nil

    private var auto: UIImage? {
        guard let vehicle else { return nil }
        return VehicleImageStore.automaticImage(for: vehicle)
    }

    private var effective: UIImage? { custom ?? auto }

    var body: some View {
        ZStack {
            if let img = effective {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(theme.cardBackground)
                    Image(systemName: "car.fill")
                        .font(.system(size: size * 0.55, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(theme.separator.opacity(0.85), lineWidth: 1))
        .task(id: vehicle?.id) {
            guard let id = vehicle?.id else { custom = nil; return }
            custom = await VehicleImageStore.load(id: id)
        }
    }
}
#endif
