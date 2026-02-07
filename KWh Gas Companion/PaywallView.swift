//
//  PaywallView.swift
//  KWh Gas Companion
//
//  Created by Bryan on 9/4/25.
//


import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var proStore = TeslaMateProStore.shared

    var body: some View {
        VStack(spacing: 16) {
            Text("Unlock TeslaMate Client")
                .font(.largeTitle).bold()

            VStack(alignment: .leading, spacing: 8) {
                Label("Direct TeslaMate connection (no middleman)", systemImage: "lock.shield")
                Label("Dashboards, activities, and charging stats", systemImage: "chart.line.uptrend.xyaxis")
                Label("Geofence-based charging costs", systemImage: "mappin.and.ellipse")
                Label("Widgets + Live Activities", systemImage: "rectangle.stack.badge.clock")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let product = proStore.product {
                Button {
                    Task {
                        await proStore.purchasePro()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if proStore.purchaseInFlight {
                            ProgressView().scaleEffect(0.9)
                        }
                        Text(proStore.purchaseInFlight
                             ? "Processing…"
                             : "Subscribe for \(product.displayPrice)/month")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(proStore.purchaseInFlight)
            } else {
                ProgressView("Loading…")
            }

            Button("Restore Purchases") { Task { await proStore.restore() } }
                .buttonStyle(.plain)
                .padding(.top, 4)

            Text("No trial. \(proStore.displayPrice)/month, auto‑renewing. Cancel anytime in Settings.")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let error = proStore.lastError, !error.isEmpty {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .task { await proStore.load() }
    }
}
