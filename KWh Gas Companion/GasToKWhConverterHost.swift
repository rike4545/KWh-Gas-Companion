//
//  GasToKWhConverterHost.swift
//  My KWh Companion
//
//  Host wrapper for Gas → kWh converter.
//  Swift 6 • iOS 17+
//

import SwiftUI

@MainActor
public struct GasToKWhConverterHost: View {

    @EnvironmentObject private var entriesStore: EntriesStore

    public init() {}

    public var body: some View {
        // Bridge converter inputs to the app's expense log.
        GasToKWhConverterView(expensesProvider: { entriesStore.entries })
    }
}
