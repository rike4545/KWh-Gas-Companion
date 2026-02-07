// LeaseCalculatorView.swift
// MyKwH Companion
// Calculates total lease cost including mileage overage charges

import SwiftUI

struct LeaseCalculatorView: View {
    @State private var monthlyPaymentText: String = ""
    @State private var termMonthsText: String = ""
    @State private var annualMileageText: String = ""
    @State private var selectedAllowedMiles: Int = 10000

    private let allowedMilesOptions = [10000, 12000, 15000]
    private let overageRate: Double = 0.25 // $ per mile overage

    private var monthlyPayment: Double {
        Double(monthlyPaymentText) ?? 0
    }
    private var termMonths: Double {
        Double(termMonthsText) ?? 0
    }
    private var annualMileage: Double {
        Double(annualMileageText) ?? 0
    }
    private var allowedMiles: Double {
        Double(selectedAllowedMiles)
    }

    private var totalLeaseCost: Double {
        monthlyPayment * termMonths
    }
    private var overageMiles: Double {
        max(annualMileage - allowedMiles, 0)
    }
    private var overageCost: Double {
        overageMiles * overageRate
    }
    private var totalCost: Double {
        totalLeaseCost + overageCost
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Lease Details")) {
                    TextField("Monthly Payment ($)", text: $monthlyPaymentText)
                        .keyboardType(.decimalPad)
                    TextField("Term (months)", text: $termMonthsText)
                        .keyboardType(.numberPad)
                }

                Section(header: Text("Mileage")) {
                    TextField("Annual Mileage Driven", text: $annualMileageText)
                        .keyboardType(.numberPad)

                    Picker("Allowed Miles/Year", selection: $selectedAllowedMiles) {
                        ForEach(allowedMilesOptions, id: \.self) { miles in
                            Text("\(miles) mi").tag(miles)
                        }
                    }
                }

                Section(header: Text("Overage Rate")) {
                    HStack {
                        Text("Overage Charge")
                        Spacer()
                        Text("$\(String(format: "%.2f", overageRate))/mi")
                    }
                }

                Section(header: Text("Results")) {
                    HStack {
                        Text("Total Lease Cost")
                        Spacer()
                        Text("$\(String(format: "%.2f", totalLeaseCost))")
                    }
                    HStack {
                        Text("Overage Miles")
                        Spacer()
                        Text("\(Int(overageMiles)) mi")
                    }
                    HStack {
                        Text("Overage Cost")
                        Spacer()
                        Text("$\(String(format: "%.2f", overageCost))")
                    }
                    Divider()
                    HStack {
                        Text("Total Cost")
                            .font(.headline)
                        Spacer()
                        Text("$\(String(format: "%.2f", totalCost))")
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Lease Calculator")
        }
    }
}

struct LeaseCalculatorView_Previews: PreviewProvider {
    static var previews: some View {
        LeaseCalculatorView()
    }
}
