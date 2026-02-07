//
//  SuperchargerRateControl.swift
//  KWh Gas Companion
//
//  Created by Bryan on 8/9/25.
//


import SwiftUI

/// Global setting stored in UserDefaults for $/kWh used by summaries and forecasting.
struct SuperchargerRateControl: View {
    @AppStorage("superchargerRateUSDPerKWh") private var superchargerRate: Double = 0.35

    var body: some View {
        HStack {
            Text("Supercharger Rate")
            Spacer()
            TextField("0.35", value: $superchargerRate,
                      format: .number.precision(.fractionLength(3)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text("$ / kWh")
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Supercharger rate, dollars per kilowatt hour")
    }
}
