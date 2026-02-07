//
//  DashboardGasToKWhConverterHost.swift
//  KWh Gas Companion
//
//  Shortcut host from Dashboard → Gas → kWh Converter
//  Swift 6 • iOS 17+
//

import SwiftUI
import Foundation

@MainActor
struct DashboardGasToKWhConverterHost: View {
    @EnvironmentObject private var entriesStore: EntriesStore

    var body: some View {
        GasToKWhConverterView(
            expensesProvider: { entriesStore.entries }
        )
        .navigationTitle("Gas → kWh Converter")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    let entries = EntriesStore()
    NavigationStack {
        DashboardGasToKWhConverterHost()
            .environmentObject(entries)
    }
}
#endif
