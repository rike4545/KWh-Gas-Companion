//
//  KWhRatesView.swift
//  MyKwH Companion
//
//  Created by Bryan on 7/15/25.
//

import SwiftUI

struct KWhRatesView: View {
    // Persisted user-defined rates
    @AppStorage("dailyServiceCharge") private var dailyServiceChargeText: String = "0.5400"
    @AppStorage("summerDeliveryRate") private var summerRateText: String = "0.1049"
    @AppStorage("winterDeliveryRate") private var winterRateText: String = "0.0891"

    // Sample calculation input
    @State private var sampleKWhText: String = "30"
    @State private var season: Season = .summer

    enum Season: String, CaseIterable, Identifiable {
        case summer = "June–Sept"
        case winter = "Oct–May"
        var id: String { rawValue }
    }

    // Parsed values
    private var dailyServiceCharge: Double? { Double(dailyServiceChargeText) }
    private var summerRate: Double? { Double(summerRateText) }
    private var winterRate: Double? { Double(winterRateText) }
    private var sampleKWh: Double? { Double(sampleKWhText) }

    private var selectedRate: Double? {
        season == .summer ? summerRate : winterRate
    }

    private var sampleCost: Double? {
        guard let svc = dailyServiceCharge,
              let rate = selectedRate,
              let kwh = sampleKWh
        else { return nil }
        return svc + (rate * kwh)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("Daily Service Charge"),
                    footer: Text("Enter your fixed daily utility charge (per day).")
                ) {
                    TextField("Service Charge ($)", text: $dailyServiceChargeText)
                        .keyboardType(.decimalPad)
                }

                Section(
                    header: Text("Delivery Charge Rates"),
                    footer: Text("Enter your delivery cost per kWh for each season.")
                ) {
                    TextField("Summer Rate ($/kWh)", text: $summerRateText)
                        .keyboardType(.decimalPad)
                    TextField("Winter Rate ($/kWh)", text: $winterRateText)
                        .keyboardType(.decimalPad)
                }

                Section(
                    header: Text("Sample Cost Calculator"),
                    footer: Text("Estimate the total cost for a given kWh usage.")
                ) {
                    Picker("Season", selection: $season) {
                        ForEach(Season.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("kWh Consumed", text: $sampleKWhText)
                        .keyboardType(.decimalPad)

                    if let cost = sampleCost {
                        Text("Estimated Cost: $\(String(format: "%.2f", cost))")
                            .fontWeight(.semibold)
                    } else {
                        Text("Enter valid numbers above.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Energy Rates")
        }
    }
}

struct KWhRatesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            KWhRatesView()
        }
    }
}
