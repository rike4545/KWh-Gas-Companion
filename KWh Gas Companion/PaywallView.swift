//
//  PaywallView.swift
//  KWh Gas Companion
//
//

import SwiftUI

struct PaywallView: View {
    @StateObject private var proStore = DirectConnectionAccessStore.shared

    var body: some View {
        VStack(spacing: 16) {
            Text("Direct Connection")
                .font(.largeTitle).bold()

            VStack(alignment: .leading, spacing: 8) {
                Label("Direct dashboard connection (no relay)", systemImage: "server.rack")
                Label("Dashboards, activities, and charging stats", systemImage: "chart.line.uptrend.xyaxis")
                Label("Geofence-based charging costs", systemImage: "mappin.and.ellipse")
                Label("Widgets + Live Activities", systemImage: "rectangle.stack.badge.clock")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Continue") { Task { await proStore.load() } }
                .buttonStyle(.borderedProminent)

            Button("Refresh Access") { Task { await proStore.restore() } }
                .buttonStyle(.plain)
                .padding(.top, 4)

            Text("Connection access is included.")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .task { await proStore.load() }
    }
}
