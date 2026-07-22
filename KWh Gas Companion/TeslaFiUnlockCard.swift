//
//  TeslaFiUnlockCard.swift
//  KWh Gas Companion
//
//  Legacy TeslaFi entitlement card. TeslaFi import is now included.
//

import SwiftUI

@MainActor
struct TeslaFiUnlockCard: View {
    @StateObject private var store = TeslaFiEntitlementStore.shared

    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.title3.weight(.semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    Task { await store.purchaseUnlock() }
                } label: {
                    HStack(spacing: 6) {
                        if store.purchaseInFlight { ProgressView().scaleEffect(0.9) }
                        Text(store.purchaseInFlight ? "Processing…" : store.displayPrice)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.purchaseInFlight)

                Button("Refresh") { Task { await store.restore() } }
                    .buttonStyle(.bordered)
                    .disabled(store.purchaseInFlight)
            }

            if let error = store.lastError, !error.isEmpty {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
        )
        .task { await store.load() }
    }
}
