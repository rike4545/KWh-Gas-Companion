//
//  ExpenseEditorView.swift
//  KWh Gas Companion
//
//

import SwiftUI

// Helpers to bind optionals in TextFields without crashing
private extension Binding where Value == Double? {
    func defaulting(to def: Double = 0) -> Binding<Double> {
        .init(get: { self.wrappedValue ?? def },
              set: { self.wrappedValue = $0 })
    }
}
private extension Binding where Value == String? {
    func defaulting(to def: String = "") -> Binding<String> {
        .init(get: { self.wrappedValue ?? def },
              set: { self.wrappedValue = $0 })
    }
}

struct ExpenseEditorView: View {
    @Binding var entry: ExpenseEntry
    @Environment(\.dismiss) private var dismiss

    // Some gentle suggestions for charge types
    private let chargeTypes = ["Supercharger", "Home", "DC Fast", "AC / L2", "Destination", "Other"]

    var body: some View {
        Form {
            Section("Overview") {
                TextField("Category", text: $entry.category)
                DatePicker("Date", selection: $entry.date, displayedComponents: .date)
                TextField("Amount",
                          value: $entry.amount,
                          format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .keyboardType(.decimalPad)
                TextField("Odometer (mi)", value: $entry.odometer.defaulting(), format: .number)
                    .keyboardType(.numberPad)

                Toggle("Energy/Charging Expense", isOn: $entry.isEnergy)
            }

            if entry.isEnergy {
                Section("Charging Details") {
                    TextField("Energy (kWh)", value: $entry.energyAddedKWh.defaulting(), format: .number.precision(.fractionLength(0...3)))
                        .keyboardType(.decimalPad)

                    if let cpp = entry.costPerKWh {
                        LabeledContent("Cost per kWh") {
                            Text(cpp, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Charge Type picker with free entry fallback
                    Picker("Charge Type", selection: $entry.chargeType.defaulting()) {
                        ForEach(chargeTypes, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Location", text: $entry.location.defaulting())
                    TextField("Vendor", text: $entry.vehicleName.defaulting()) // keep as your display/vendor
                    HStack {
                        Text("State of Charge (%)")
                        Spacer()
                        TextField("SOC", value: $entry.stateOfCharge.defaulting(), format: .number.precision(.fractionLength(0...1)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: 120)
                    }
                }
            }

            Section("Vehicle") {
                TextField("Vehicle Name", text: $entry.vehicleName.defaulting())
                TextField("VIN", text: $entry.vin.defaulting())
                Toggle("Business Expense", isOn: $entry.isBusiness)
            }

            Section("Notes") {
                TextField("Notes", text: $entry.note.defaulting(), axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }

            Section("Metadata") {
                LabeledContent("ID") {
                    Text(entry.id.uuidString).textSelection(.enabled)
                }
                LabeledContent("Summary") {
                    Text(entry.summaryLabel).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(entry.category.isEmpty ? "Expense" : entry.category)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}
