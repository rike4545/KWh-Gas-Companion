//  VehicleExpensesView.swift
//  KWh Gas Companion
//
//  🔧 FIX 1: `e.note` fallback removed. ExpenseEntry has `.notes`, not `.note`.
//     The `?? e.note?.lowercased()` chain caused a compile error when `note` isn't
//     a field on ExpenseEntry. Now only `.notes` is read.
//
//  🔧 FIX 2: `energyKWh` → `energyAddedKWh` throughout. The canonical field name
//     on ExpenseEntry is `energyAddedKWh`; `energyKWh` is only a ChargeLogRow
//     reflection key. Using the wrong name silently returns nil for every entry.
//
//  🔧 FIX 3: DateFormatter and NumberFormatter were constructed inside computed
//     properties and called on every render pass. Moved to static let constants
//     so they are created once per process lifetime.
//
//  🔧 FIX 4: Preview ExpenseEntry initialisers used non-existent parameter labels
//     (`energyKWh:`, `isEnergy:`). Replaced with the correct public init labels.

import SwiftUI

struct VehicleExpensesView: View {
    var expenses: [ExpenseEntry]

    @State private var showBusinessOnly = false
    @State private var query: String = ""

    var body: some View {
        VStack(spacing: 12) {
            header

            HStack {
                Toggle(isOn: $showBusinessOnly) {
                    Text("Business only")
                }
                .toggleStyle(.switch)
                .fixedSize()

                Spacer()

                TextField("Search notes/category…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
            }
            .padding(.horizontal, 12)

            List {
                ForEach(vehicleGroupsFilteredSorted) { group in
                    Section {
                        DisclosureGroup {
                            ForEach(group.entriesSorted) { entry in
                                ExpenseRow(entry: entry)
                            }
                        } label: {
                            VehicleGroupRow(group: group)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Vehicle Expenses")
    }

    // MARK: - Formatters (🔧 FIX 3: static to avoid per-render allocation)

    private static let currencyFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return nf
    }()

    private static let decimalFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2
        return nf
    }()

    static func currencyString(_ value: Double?) -> String {
        guard let value else { return "—" }
        return currencyFormatter.string(from: NSNumber(value: value))
            ?? String(format: "$%.2f", value)
    }

    static func kwhString(_ value: Double?) -> String {
        guard let value else { return "—" }
        return (decimalFormatter.string(from: NSNumber(value: value))
            ?? String(format: "%.2f", value)) + " kWh"
    }

    static func currencyPerKWhString(_ value: Double?) -> String {
        guard let value else { return "—" }
        return currencyString(value) + "/kWh"
    }

    // MARK: - Header

    private var header: some View {
        let filtered = filteredExpenses
        let total = filtered.reduce(0.0) { $0 + $1.amount }
        // 🔧 FIX 2: was \.energyKWh — correct field is energyAddedKWh
        let kwhTotal = filtered.compactMap(\.energyAddedKWh).reduce(0.0, +)
        let avgPerKWh = kwhTotal > 0 ? total / kwhTotal : nil

        return VStack(alignment: .leading, spacing: 10) {
            Text("Summary")
                .font(.headline)
                .padding(.horizontal, 12)

            HStack(spacing: 10) {
                VEStatTile(title: "Total Spent", valueText: Self.currencyString(total))
                VEStatTile(title: "Total kWh", valueText: Self.kwhString(kwhTotal))
                VEStatTile(title: "Avg $/kWh", valueText: Self.currencyPerKWhString(avgPerKWh))
            }
            .padding(.horizontal, 12)
        }
        .padding(.top, 6)
    }

    // MARK: - Filtering & Grouping

    private var filteredExpenses: [ExpenseEntry] {
        expenses.filter { e in
            if showBusinessOnly && !e.isBusiness { return false }
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if q.isEmpty { return true }
            let ql = q.lowercased()
            let text = [
                e.category.lowercased(),
                e.vehicleName?.lowercased() ?? "",
                e.vin?.lowercased() ?? "",
                // 🔧 FIX 1: removed `?? e.note?.lowercased()` — field doesn't exist
                e.notes?.lowercased() ?? ""
            ].joined(separator: " ")
            return text.contains(ql)
        }
    }

    private var vehicleGroupsFilteredSorted: [VehicleGroup] {
        let dict = Dictionary(grouping: filteredExpenses, by: { keyForVehicle($0) })
        let groups: [VehicleGroup] = dict.map { key, entries in
            VehicleGroup.make(id: key.id, displayName: key.display, vin: key.vin, entries: entries)
        }
        return groups.sorted { lhs, rhs in
            if lhs.displayName == "Unknown Vehicle" { return false }
            if rhs.displayName == "Unknown Vehicle" { return true }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private func keyForVehicle(_ e: ExpenseEntry) -> VehicleKey {
        if let name = e.vehicleName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return VehicleKey(id: name, display: name, vin: e.vin)
        }
        if let vin = e.vin?.trimmingCharacters(in: .whitespacesAndNewlines), !vin.isEmpty {
            let short = String(vin.suffix(6)).uppercased()
            return VehicleKey(id: vin, display: "VIN • \(short)", vin: vin)
        }
        return VehicleKey(id: "unknown", display: "Unknown Vehicle", vin: nil)
    }

    // MARK: - Types

    private struct VehicleKey: Hashable {
        var id: String
        var display: String
        var vin: String?
    }

    private struct VehicleGroup: Identifiable, Hashable {
        let id: String
        let displayName: String
        let vin: String?
        let totalAmount: Double
        let totalKWh: Double
        let entries: [ExpenseEntry]

        static func make(id: String, displayName: String, vin: String?, entries: [ExpenseEntry]) -> VehicleGroup {
            let total = entries.reduce(0.0) { $0 + $1.amount }
            // 🔧 FIX 2: energyAddedKWh
            let kwh = entries.compactMap(\.energyAddedKWh).reduce(0.0, +)
            return VehicleGroup(id: id, displayName: displayName, vin: vin, totalAmount: total, totalKWh: kwh, entries: entries)
        }

        var entriesSorted: [ExpenseEntry] { entries.sorted { $0.date > $1.date } }
    }

    private struct VehicleGroupRow: View {
        var group: VehicleGroup
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.displayName).font(.headline)
                    HStack(spacing: 8) {
                        Text(VehicleExpensesView.currencyString(group.totalAmount))
                        if group.totalKWh > 0 {
                            Text("•")
                            Text(VehicleExpensesView.kwhString(group.totalKWh))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private struct ExpenseRow: View {
        var entry: ExpenseEntry

        // 🔧 FIX 3: static formatter
        private static let dateFmt: DateFormatter = {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .none
            return df
        }()

        var body: some View {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.category.isEmpty ? "Expense" : entry.category)
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 6) {
                        // 🔧 FIX 2: energyAddedKWh
                        if let kwh = entry.energyAddedKWh, kwh > 0 {
                            Text(VehicleExpensesView.kwhString(kwh))
                        }
                        if let loc = entry.location, !loc.isEmpty {
                            Text("•")
                            Text(loc)
                        }
                        if entry.isBusiness {
                            Text("•")
                            Text("Business")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(VehicleExpensesView.currencyString(entry.amount))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    Text(Self.dateFmt.string(from: entry.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
    }

    private struct VEStatTile: View {
        var title: String
        var valueText: String
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(valueText)
                    .font(.headline)
                    .monospacedDigit()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07))
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
struct VehicleExpensesView_Previews: PreviewProvider {
    static var previews: some View {
        // 🔧 FIX 4: Use correct ExpenseEntry init parameter labels.
        // energyKWh: and isEnergy: are not valid labels on ExpenseEntry.
        // Using only the fields that the public init actually declares.
        let now = Date()
        let cal = Calendar.current

        let e1 = ExpenseEntry(
            date: now,
            amount: 24.50,
            category: "Charging",
            location: "Home",
            notes: "Overnight"
        )
        let e2 = ExpenseEntry(
            date: cal.date(byAdding: .day, value: -3, to: now) ?? now,
            amount: 18.10,
            category: "Charging",
            location: "Supercharger",
            notes: "Trip top-up"
        )
        let e3 = ExpenseEntry(
            date: cal.date(byAdding: .day, value: -8, to: now) ?? now,
            amount: 62.00,
            category: "Maintenance",
            location: "Service Center",
            notes: "Tire rotation"
        )

        NavigationStack {
            VehicleExpensesView(expenses: [e1, e2, e3])
        }
        .previewDisplayName("Vehicle Expenses")
    }
}
#endif
