// EditChargeEntryView.swift
// KWh Gas Companion

import SwiftUI

struct EditChargeEntryView: View {
    @Environment(\.dismiss) private var dismiss

    // You provide an initial ExpenseEntry and an onSave sink
    @State private var draft: ExpenseEntry
    let onSave: (ExpenseEntry) -> Void

    // MARK: - Init
    init(expense: ExpenseEntry, onSave: @escaping (ExpenseEntry) -> Void) {
        _draft = State(initialValue: expense)
        self.onSave = onSave
    }

    // Convenience init for creating a brand-new charge entry
    init(onSave: @escaping (ExpenseEntry) -> Void) {
        let fresh = ExpenseEntry(
            date: Date(),
            amount: 0,
            category: "Charging",
            energyKWh: nil,
            odometer: nil,
            location: nil,
            notes: nil,
            vehicleName: nil,
            stateOfCharge: nil,
            chargeType: "Home",
            vehicleID: nil,
            isBusiness: false,
            vin: nil,
            isEnergy: true
        )
        _draft = State(initialValue: fresh)
        self.onSave = onSave
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                Section("When & Where") {
                    DatePicker("Date", selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
                    TextField("Location", text: bindingString(\.location))
                        .textInputAutocapitalization(.words)
                    TextField("Vehicle name (optional)", text: bindingString(\.vehicleName))
                        .textInputAutocapitalization(.words)
                    TextField("VIN (optional)", text: bindingString(\.vin))
                        .textInputAutocapitalization(.never)
                }

                Section("Energy & Cost") {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: bindingDouble(\.amount))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Energy (kWh)")
                        Spacer()
                        TextField("e.g. 28.75", text: bindingOptionalDouble(\.energyKWh))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }

                    if let kWh = draft.energyKWh, kWh > 0 {
                        let cpk = draft.amount / kWh
                        HStack {
                            Text("Cost per kWh")
                            Spacer()
                            Text(String(format: "$%.3f", cpk))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }

                    Picker("Charge type", selection: bindingString(\.chargeType, default: "Home")) {
                        Text("Home").tag("Home")
                        Text("Supercharger").tag("Supercharger")
                        Text("Work").tag("Work")
                        Text("Destination").tag("Destination")
                        Text("Other").tag("Other")
                    }
                }

                Section("Vehicle & Session") {
                    HStack {
                        Text("Odometer")
                        Spacer()
                        TextField("mi / km", text: bindingOptionalDouble(\.odometer))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }

                    HStack {
                        Text("State of Charge")
                        Spacer()
                        TextField("% (0–100)", text: bindingOptionalDouble(\.stateOfCharge, clamp0to100: true))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                }

                Section("Categorization") {
                    // FIX: bind directly because `category` is a non-optional String
                    TextField("Category", text: $draft.category)
                        .textInputAutocapitalization(.words)
                    Toggle("Business expense", isOn: $draft.isBusiness)
                    Toggle("Is energy-related", isOn: $draft.isEnergy)
                }

                Section("Notes") {
                    TextField("Optional notes", text: bindingString(\.notes))
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("Edit Charge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft.category = draft.category.isEmpty ? "Charging" : draft.category
                        draft.isEnergy = true
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Validation
    private var canSave: Bool {
        let amountOK = draft.amount >= 0
        let kwhOK = (draft.energyKWh ?? 0) >= 0
        return amountOK && kwhOK
    }

    // MARK: - Bindings bridges
    private func bindingString(_ kp: WritableKeyPath<ExpenseEntry, String?>, default def: String? = nil) -> Binding<String> {
        Binding<String>(
            get: { draft[keyPath: kp] ?? (def ?? "") },
            set: { draft[keyPath: kp] = $0.isEmpty ? nil : $0 }
        )
    }

    private func bindingDouble(_ kp: WritableKeyPath<ExpenseEntry, Double>) -> Binding<String> {
        Binding<String>(
            get: { String(draft[keyPath: kp]) },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                draft[keyPath: kp] = Double(trimmed) ?? 0
            }
        )
    }

    private func bindingOptionalDouble(
        _ kp: WritableKeyPath<ExpenseEntry, Double?>,
        clamp0to100: Bool = false
    ) -> Binding<String> {
        Binding<String>(
            get: {
                if let v = draft[keyPath: kp] { return String(v) }
                return ""
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    draft[keyPath: kp] = nil
                } else if var v = Double(trimmed) {
                    if clamp0to100 { v = max(0, min(100, v)) }
                    draft[keyPath: kp] = v
                }
            }
        )
    }
}

#if DEBUG
#Preview("New Charge") {
    NavigationStack {
        EditChargeEntryView { _ in }
    }
}
#endif
