// CarbonOffsetView.swift
// MyKwH Companion
// Created by Bryan on 7/15/25.

import SwiftUI

/// View for calculating annual CO₂ offset when switching from a gas vehicle to an EV
struct CarbonOffsetView: View {
    @State private var annualMiles: Double = 12000
    @State private var gasMpg: Double = 25
    @State private var evKwhPer100: Double = 30

    // Constants for CO₂ conversion
    private let co2PerGallon = 8.887 // kg CO₂ per gallon gasoline
    private let co2PerKWh = 0.453    // kg CO₂ per kWh

    private var offsetKg: Double {
        let gallons = annualMiles / gasMpg
        let gasEmissions = gallons * co2PerGallon
        let evEnergy = (annualMiles / 100) * evKwhPer100
        let evEmissions = evEnergy * co2PerKWh
        return gasEmissions - evEmissions
    }

    var body: some View {
        Form {
            Section(header: Text("Inputs")) {
                VStack(alignment: .leading) {
                    Text("Annual Miles: \(Int(annualMiles)) mi")
                    Slider(value: $annualMiles, in: 1000...50000, step: 500)
                }
                VStack(alignment: .leading) {
                    Text("Gas Vehicle Efficiency: \(Int(gasMpg)) mpg")
                    Slider(value: $gasMpg, in: 5...100, step: 1)
                }
                VStack(alignment: .leading) {
                    Text("EV Efficiency: \(Int(evKwhPer100)) kWh/100 mi")
                    Slider(value: $evKwhPer100, in: 10...150, step: 1)
                }
            }

            Section(header: Text("Result")) {
                HStack {
                    Text("Annual CO₂ Offset:")
                    Spacer()
                    Text(String(format: "%.0f kg", offsetKg))
                        .fontWeight(.semibold)
                }
                Text(offsetKg > 0 ? "You save CO₂ by using an EV." : "No savings; adjust inputs.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Carbon Offset")
    }
}

// MARK: - Preview
#if DEBUG
struct CarbonOffsetView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CarbonOffsetView()
        }
    }
}
#endif
