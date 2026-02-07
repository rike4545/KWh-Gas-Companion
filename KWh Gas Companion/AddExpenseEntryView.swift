import SwiftUI

/// A self-contained SwiftUI view for creating a new expense/charge entry
/// without any external model dependencies. Wire it up by providing an
/// `onSave` closure that receives an `ExpenseNew` value.
///
/// - No references to `EntriesStore`, `ExpenseEntry`, etc.
/// - Local validation and lightweight formatting.
/// - Shows derived metrics like cost/kWh when energy is provided.
public struct AddExpenseEntryView: View {
    // MARK: - Public API

    /// The model emitted on save. Conformances allow easy persistence later.
    public struct ExpenseNew: Identifiable, Hashable, Codable {
        public enum Category: String, CaseIterable, Identifiable, Codable {
            case homeCharging = "Home Charging"
            case supercharger = "DC Fast / Supercharger"
            case publicAC = "Public AC"
            case maintenance = "Maintenance"
            case parking = "Parking"
            case toll = "Toll"
            case other = "Other"

            public var id: String { rawValue }
        }

        public var id: UUID = .init()
        public var date: Date
        public var category: Category
        public var amount: Decimal          // currency paid
        public var energyKWh: Decimal?      // optional: kWh charged
        public var odometerMiles: Decimal?  // optional: mileage at time of expense
        public var notes: String

        public init(id: UUID = .init(), date: Date, category: Category, amount: Decimal, energyKWh: Decimal? = nil, odometerMiles: Decimal? = nil, notes: String = "") {
            self.id = id
            self.date = date
            self.category = category
            self.amount = amount
            self.energyKWh = energyKWh
            self.odometerMiles = odometerMiles
            self.notes = notes
        }
    }

    /// Called when the user taps Save with a valid entry.
    public var onSave: (ExpenseNew) -> Void
    /// Called when the user cancels (optional)
    public var onCancel: (() -> Void)?

    // MARK: - State

    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = .init()
    @State private var category: ExpenseNew.Category = .homeCharging

    @State private var amountText: String = ""
    @State private var energyText: String = ""        // kWh (optional)
    @State private var odometerText: String = ""      // miles (optional)
    @State private var notes: String = ""

    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case amount, energy, odometer, notes }

    // MARK: - Body

    public init(onSave: @escaping (ExpenseNew) -> Void, onCancel: (() -> Void)? = nil) {
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("When & what") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseNew.Category.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }

                Section("Amounts") {
                    currencyField(title: "Amount", text: $amountText)
                        .focused($focusedField, equals: .amount)
                    decimalField(title: "Energy (kWh)", text: $energyText, hint: "Optional")
                        .focused($focusedField, equals: .energy)
                    decimalField(title: "Odometer (mi)", text: $odometerText, hint: "Optional")
                        .focused($focusedField, equals: .odometer)

                    if let costPerKWh = derivedCostPerKWh {
                        HStack {
                            Label("Cost per kWh", systemImage: "bolt.circle")
                            Spacer()
                            Text(costPerKWh, format: .currency(code: currencyCode))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                Section("Notes") {
                    TextField("Optional notes…", text: $notes, axis: .vertical)
                        .focused($focusedField, equals: .notes)
                        .lineLimit(3, reservesSpace: true)
                }

                if !validationMessage.isEmpty {
                    Section {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Derived

    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    private var amountDecimal: Decimal? { Self.decimal(from: amountText) }
    private var energyDecimal: Decimal? { Self.decimal(from: energyText) }
    private var odometerDecimal: Decimal? { Self.decimal(from: odometerText) }

    private var isValid: Bool {
        guard let amount = amountDecimal else { return false }
        return amount > 0
    }

    private var validationMessage: String {
        if amountText.isEmpty { return "Enter an amount." }
        if amountDecimal == nil { return "Amount must be a number." }
        if let e = energyText.nonEmpty, Self.decimal(from: e) == nil { return "Energy must be a number (kWh)." }
        if let o = odometerText.nonEmpty, Self.decimal(from: o) == nil { return "Odometer must be a number (miles)." }
        return ""
    }

    private var derivedCostPerKWh: Decimal? {
        guard let amount = amountDecimal, amount > 0, let kWh = energyDecimal, kWh > 0 else { return nil }
        return amount / kWh
    }

    // MARK: - Actions

    private func cancel() {
        onCancel?()
        dismiss()
    }

    private func save() {
        guard let amount = amountDecimal else { return }
        let model = ExpenseNew(
            date: date,
            category: category,
            amount: amount,
            energyKWh: energyDecimal,
            odometerMiles: odometerDecimal,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        onSave(model)
        dismiss()
    }

    // MARK: - Field helpers

    /// Localized decimal parsing using the current locale.
    private static func decimal(from text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.locale = .current
        if let number = nf.number(from: trimmed) { return number.decimalValue }
        // Allow plain Double fallback (e.g., programming locales)
        if let d = Double(trimmed) { return Decimal(d) }
        return nil
    }

    // MARK: - View builders

    private func currencyField(title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0.00", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .submitLabel(.done)
        }
        .accessibilityElement(children: .combine)
    }

    private func decimalField(title: String, text: Binding<String>, hint: String? = nil) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(hint ?? "", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .submitLabel(.done)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Small utilities

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Preview

struct AddExpenseEntryView_Previews: PreviewProvider {
    static var previews: some View {
        AddExpenseEntryView { new in
            // Example save handler for preview/demo
            print("Saved: \(new)")
        }
    }
}
