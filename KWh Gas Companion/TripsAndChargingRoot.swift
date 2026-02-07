//
//  TripsAndChargingRoot.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/23/25.
//


//
//  TabRoots.swift
//  KWh Gas Companion
//
//  Small “tab root” wrappers referenced by MainTabView.
//

import SwiftUI

@MainActor
struct TripsAndChargingRoot: View {
    var body: some View {
        // Prefer your newer charging hub if it exists in the project.
        // If you don’t have ChargingDataHubView, switch to ChargingImportHubView or another view you do have.
        ChargingDataHubView()
    }
}

@MainActor
struct EntriesRootView: View {
    var body: some View {
        // If you already have an entries list/home, put it here.
        // Common names in your project history: EntriesView, ExpensesView, LogbookView, etc.
        EntriesHomeFallback()
    }
}

/// Minimal fallback so the app compiles even if you haven't wired the real Entries UI yet.
@MainActor
private struct EntriesHomeFallback: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 34, weight: .semibold))
            Text("Entries")
                .font(.title3.weight(.semibold))
            Text("Wire your entries list here (e.g., EntriesView / ExpensesView).")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    NavigationStack { TripsAndChargingRoot() }
}

#Preview {
    NavigationStack { EntriesRootView() }
}
