//
//  StationRatesManagerView.swift
//  KWh Gas Companion
//
//

import SwiftUI

struct StationRatesManagerView: View {
    @State private var items: [(location: String, rate: Double)] = []

    private func reload() { items = RatesService.allSavedRates() }

    var body: some View {
        List {
            ForEach(items, id: \.location) { item in
                HStack {
                    Text(item.location).lineLimit(2)
                    Spacer()
                    Text(item.rate, format: .number.precision(.fractionLength(4)))
                    Text("$/kWh").foregroundStyle(.secondary)
                }
                .contextMenu {
                    Button("Delete") {
                        RatesService.remove(location: item.location)
                        reload()
                    }
                }
            }
            if !items.isEmpty {
                Button(role: .destructive) {
                    RatesService.clearAll()
                    reload()
                } label: {
                    Text("Clear all")
                }
            }
        }
        .navigationTitle("Station Rates")
        .onAppear(perform: reload)
    }
}
