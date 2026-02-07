import SwiftUI

struct CarsVsEVCalculatorView: View {
    @EnvironmentObject var profileStore: ProfileStore

    @State private var annualMileage: Double = 12000
    @State private var electricityCostPerKWh: String = "0.13"
    @State private var gasCostPerGallon: String = "3.50"
    @State private var efficiencyEV: Double = 3.5 // mi/kWh
    @State private var efficiencyGas: Double = 30.0 // mpg
    @State private var evMaintPerMile: Double = 0.04
    @State private var iceMaintPerMile: Double = 0.08

    private var annualEVCost: Double? {
        guard let elecRate = Double(electricityCostPerKWh), elecRate > 0 else { return nil }
        let kWhNeeded = annualMileage / efficiencyEV
        let energyCost = kWhNeeded * elecRate
        let maintCost = annualMileage * evMaintPerMile
        return energyCost + maintCost
    }

    private var annualGasCost: Double? {
        guard let gasRate = Double(gasCostPerGallon), gasRate > 0 else { return nil }
        let gallonsNeeded = annualMileage / efficiencyGas
        let fuelCost = gallonsNeeded * gasRate
        let maintCost = annualMileage * iceMaintPerMile
        return fuelCost + maintCost
    }

    var body: some View {
        Form {
            Section(header: Text("Inputs")) {
                VStack(alignment: .leading) {
                    Text("Annual Mileage: \(Int(annualMileage)) miles")
                    Slider(value: $annualMileage, in: 0...30000, step: 500)
                }
                TextField("Electricity Rate ($/kWh)", text: $electricityCostPerKWh)
                    .keyboardType(.decimalPad)
                TextField("Gas Rate ($/gal)", text: $gasCostPerGallon)
                    .keyboardType(.decimalPad)
                VStack(alignment: .leading) {
                    Text("EV Efficiency: \(efficiencyEV, specifier: "%.1f") mi/kWh")
                    Slider(value: $efficiencyEV, in: 1...6, step: 0.1)
                }
                VStack(alignment: .leading) {
                    Text("Gas Efficiency: \(Int(efficiencyGas)) mpg")
                    Slider(value: $efficiencyGas, in: 5...60, step: 1)
                }
                VStack(alignment: .leading) {
                    Text("EV Maintenance: \(evMaintPerMile, specifier: "%.2f") $/mi")
                    Slider(value: $evMaintPerMile, in: 0...0.50, step: 0.01)
                }
                VStack(alignment: .leading) {
                    Text("Gas Maintenance: \(iceMaintPerMile, specifier: "%.2f") $/mi")
                    Slider(value: $iceMaintPerMile, in: 0...0.75, step: 0.01)
                }
            }

            Section(header: Text("Annual Cost Comparison")) {
                if let evCost = annualEVCost, let gasCost = annualGasCost {
                    HStack {
                        Text("EV:")
                        Spacer()
                        Text(evCost, format: .currency(code: profileStore.currencyCode))
                    }
                    HStack {
                        Text("Gas:")
                        Spacer()
                        Text(gasCost, format: .currency(code: profileStore.currencyCode))
                    }
                    HStack {
                        Text("Savings:")
                        Spacer()
                        let savings = gasCost - evCost
                        Text(savings, format: .currency(code: profileStore.currencyCode))
                            .foregroundColor(savings >= 0 ? .green : .red)
                    }
                } else {
                    Text("Please enter valid rates and mileage to see comparison.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("EV vs Gas Budget")
        .navigationBarTitleDisplayMode(.inline)
    }
}
