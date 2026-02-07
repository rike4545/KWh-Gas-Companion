// ExpenseLoggerView.swift
// Form to create or edit an ExpenseEntry (store-agnostic)

import SwiftUI

struct ExpenseLoggerView: View {
    // Editing support (nil = create)
    let entryToEdit: ExpenseEntry?
    let onSave: (ExpenseEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var date: Date
    @State private var amountText: String
    @State private var category: String
    @State private var energyText: String
    @State private var odometerText: String
    @State private var location: String
    @State private var notes: String
    @State private var vehicleName: String
    @State private var vin: String
    @State private var socText: String
    @State private var chargeType: String
    @State private var isBusiness: Bool

    init(
        entryToEdit: ExpenseEntry? = nil,
        onSave: @escaping (ExpenseEntry) -> Void
    ) {
        self.entryToEdit = entryToEdit
        self.onSave = onSave

        // Pre-fill state from entry (or sensible defaults)
        _date = State(initialValue: entryToEdit?.date ?? Date())
        _amountText = State(initialValue: entryToEdit.map { String(format: "%.2f", $0.amount) } ?? "")
        _category = State(initialValue: entryToEdit?.category ?? "Charging")
        _energyText = State(initialValue: entryToEdit?.energyKWh.map { Self.trimZeros($0) } ?? "")
        _odometerText = State(initialValue: entryToEdit?.odometer.map { Self.trimZeros($0) } ?? "")
        _location = State(initialValue: entryToEdit?.location ?? "")
        _notes = State(initialValue: entryToEdit?.notes ?? "")
        _vehicleName = State(initialValue: entryToEdit?.vehicleName ?? "")
        _vin = State(initialValue: entryToEdit?.vin ?? "")
        _socText = State(initialValue: entryToEdit?.stateOfCharge.map { Self.trimZeros($0) } ?? "")
        _chargeType = State(initialValue: entryToEdit?.chargeType ?? "")
        _isBusiness = State(initialValue: entryToEdit?.isBusiness ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When & Amount") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                }

                Section("Category & Details") {
                    Picker("Category", selection: $category) {
                        ForEach(Self.commonCategories, id: \.self) { Text($0) }
                    }
                    TextField("Location (optional)", text: $location)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("Energy (optional)") {
                    HStack {
                        Text("Energy (kWh)")
                        Spacer()
                        TextField("e.g. 32.5", text: $energyText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                    HStack {
                        Text("State of Charge (%)")
                        Spacer()
                        TextField("e.g. 65", text: $socText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }
                    TextField("Charge Type (Home, Supercharger…)", text: $chargeType)
                }

                Section("Vehicle (optional)") {
                    TextField("Vehicle Name", text: $vehicleName)
                    TextField("VIN", text: $vin)
                    HStack {
                        Text("Odometer")
                        Spacer()
                        TextField("miles", text: $odometerText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                }

                Section {
                    Toggle("Business Expense", isOn: $isBusiness)
                }
            }
            .navigationTitle(entryToEdit == nil ? "New Expense" : "Edit Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Validation & Save

    private var isValid: Bool {
        (Double(amountText.trimmed) ?? 0) > 0
    }

    private func save() {
        let amount = Double(amountText.trimmed) ?? 0
        let energy = Double(energyText.trimmed)
        let odo = Double(odometerText.trimmed)
        let soc = Double(socText.trimmed)

        var entry = ExpenseEntry(
            id: entryToEdit?.id ?? UUID(),
            date: date,
            amount: amount,
            category: category,
            energyKWh: energy,
            odometer: odo,
            location: location.nonEmpty,
            notes: notes.nonEmpty,
            vehicleName: vehicleName.nonEmpty,
            stateOfCharge: soc,
            chargeType: chargeType.nonEmpty,
            vehicleID: entryToEdit?.vehicleID, // preserve if present
            isBusiness: isBusiness,
            vin: vin.nonEmpty,
            isEnergy: category.lowercased().contains("charge") || category.lowercased().contains("energy")
        )

        // Keep alias parity just in case other views set via alias
        entry.energyAddedKWh = entry.energyKWh
        entry.note = entry.notes

        onSave(entry)
        dismiss()
    }

    // MARK: - Helpers

    private static let commonCategories = [
        "Charging", "Maintenance", "Insurance", "Registration",
        "Tires", "Accessories", "Parking", "Tolls", "Other"
    ]

    private static func trimZeros(_ value: Double) -> String {
        // 32.50 -> "32.5", 32.00 -> "32"
        let s = String(format: "%.2f", value)
        return s.replacingOccurrences(of: #"(\.0+|(?<=\.\d)0+)$"#, with: "", options: .regularExpression)
    }
}

// MARK: - Small conveniences

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nonEmpty: String? { let t = trimmed; return t.isEmpty ? nil : t }
}
