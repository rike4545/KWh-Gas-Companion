//  VehicleAvatarView.swift
//  KWh Gas Companion
//
//  🔧 FIX 1: The old view accepted only a `vehicleId: UUID`, so it could only
//     attempt to load a custom legacy photo and would never show automatic
//     Tesla/Rivian fallback images. Changed to accept a full `VehicleProfile`
//     so `VehicleImageStore.preferredAvatarImage(for:)` can be used, which
//     tries gallery → legacy → automatic in the correct priority order.
//
//  🔧 FIX 2: `VehicleImageStore.load(id:)` has both a sync and an async overload.
//     Calling `await VehicleImageStore.load(id:)` resolves to the async version,
//     which internally calls Task.detached → the sync version. That's two hops.
//     Using `preferredAvatarImage(for:maxPixel:)` async directly is both correct
//     and more efficient (one Task.detached call, includes thumbnail downsampling).
//
//  🔧 FIX 3: `onChange(of: vehicleId)` used the old two-parameter closure form
//     `{ _, _ in }`. Swift 5.9 / iOS 17 requires `{ newValue in }` (one param)
//     for the `onChange(of:)` modifier. Fixed to the single-argument form.
//
//  Swift 6 • iOS 17+

import SwiftUI
import UIKit

@MainActor
struct VehicleAvatarView: View {

    // 🔧 FIX 1 & 2: Accept full VehicleProfile instead of bare UUID so the
    // automatic Tesla/Rivian fallback chain works correctly.
    let vehicle: VehicleProfile
    var size: CGFloat = 44

    @State private var uiImage: UIImage?

    // Stable task identity: changes whenever any photo-relevant field changes.
    private var imageTaskID: String {
        let cover = vehicle.coverPhotoId?.uuidString ?? "none"
        let first = vehicle.galleryPhotoIds.first?.uuidString ?? "none"
        return "\(vehicle.id)|\(cover)|\(first)|\(vehicle.make)|\(vehicle.model)"
    }

    var body: some View {
        ZStack {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: max(10, size * 0.22), style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                    Image(systemName: "car.fill")
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(10, size * 0.22), style: .continuous))
        // 🔧 FIX 3: Use task(id:) so the image reloads whenever the vehicle changes.
        .task(id: imageTaskID) { await load() }
    }

    private func load() async {
        // 🔧 FIX 1 & 2: Use preferredAvatarImage which cascades:
        // gallery cover → first gallery photo → legacy custom photo → automatic Tesla/Rivian image
        let targetPixel = max(128, size * UIScreen.main.scale)
        uiImage = await VehicleImageStore.preferredAvatarImage(for: vehicle, maxPixel: targetPixel)
    }
}

// MARK: - Back-compat shim
// Callers that passed a bare UUID can use this until they migrate.
// Prefer VehicleAvatarView(vehicle:size:) for new code.
@MainActor
struct VehicleAvatarViewByID: View {
    let vehicleId: UUID
    var size: CGFloat = 44
    @EnvironmentObject private var profileStore: ProfileStore

    var body: some View {
        if let vehicle = profileStore.vehicles.first(where: { $0.id == vehicleId }) {
            VehicleAvatarView(vehicle: vehicle, size: size)
        } else {
            // Unknown ID fallback
            ZStack {
                RoundedRectangle(cornerRadius: max(10, size * 0.22), style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                Image(systemName: "car.fill")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: size, height: size)
        }
    }
}
