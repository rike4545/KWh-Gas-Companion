//
//  VehicleAvatarView.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/24/25.
//


//
//  VehicleAvatarView.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import UIKit

@MainActor
struct VehicleAvatarView: View {

    let vehicleId: UUID
    var size: CGFloat = 44

    @State private var uiImage: UIImage?

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
        .task { await load() }
        .onChange(of: vehicleId) { _, _ in Task { await load() } }
    }

    private func load() async {
        uiImage = await VehicleImageStore.load(id: vehicleId)
    }
}
