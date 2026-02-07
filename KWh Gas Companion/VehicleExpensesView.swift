//  VehicleExpensesView.swift
//  KWh Gas Companion
//
//  Lists expenses grouped by vehicle with per-vehicle totals and an overall summary.
//  - Standalone: no EnvironmentObject assumptions
//  - Uses ExpenseEntry (amount, date, category, energyKWh, vehicleName, vin, isBusiness)

import SwiftUI

struct VehicleExpensesView: View {
    // Provide your expenses when constructing the view
    var expenses: [ExpenseEntry]

    // Simple filters
    @State private var showBusinessOnly = false
    @State private var query: String = ""

    var body: some View {
        VStack(spacing: 12) {
            header

            // Filters
            HStack {
                Toggle(isOn: $showBusinessOnly) {
                    Text("Business only")
                }
                .toggleStyle(.switch)
                .fixedSize()

                Spacer()

                // Lightweight search field
                TextField("Search notes/category…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
            }
            .padding(.horizontal, 12)

            // Grouped list
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

    // MARK: - Header

    private var header: some View {
        let filtered = filteredExpenses
        let total = filtered.reduce(0.0) { $0 + $1.amount }
        let kwhTotal = filtered.compactMap(\.energyKWh).reduce(0.0, +)
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
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
            let q = query.lowercased()
            let text = [
                e.category.lowercased(),
                e.vehicleName?.lowercased() ?? "",
                e.vin?.lowercased() ?? "",
                e.notes?.lowercased() ?? e.note?.lowercased() ?? ""
            ].joined(separator: " ")
            return text.contains(q)
        }
    }

    private var vehicleGroupsFilteredSorted: [VehicleGroup] {
        let dict = Dictionary(grouping: filteredExpenses, by: { keyForVehicle($0) })
        let groups: [VehicleGroup] = dict.map { (key, entries) in
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

        // Explicit maker to avoid any synthesized-init ambiguities
        static func make(id: String, displayName: String, vin: String?, entries: [ExpenseEntry]) -> VehicleGroup {
            let total = entries.reduce(0.0) { $0 + $1.amount }
            let kwh = entries.compactMap(\.energyKWh).reduce(0.0, +)
            return VehicleGroup(id: id, displayName: displayName, vin: vin, totalAmount: total, totalKWh: kwh, entries: entries)
        }

        var entriesSorted: [ExpenseEntry] {
            entries.sorted { $0.date > $1.date }
        }
    }

    private struct VehicleGroupRow: View {
        var group: VehicleGroup

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.displayName)
                        .font(.headline)
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

    // Single entry row
    private struct ExpenseRow: View {
        var entry: ExpenseEntry

        var body: some View {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.category.isEmpty ? "Expense" : entry.category)
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 6) {
                        if let kwh = entry.energyKWh, kwh > 0 {
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
                    Text(Self.dateShort(entry.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }

        private static func dateShort(_ d: Date) -> String {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .none
            return df.string(from: d)
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
                    .strokeBorder(Color.black.opacity(0.06))
            )
        }
    }

    // MARK: - Formatting

    static func currencyString(_ value: Double?) -> String {
        guard let value = value else { return "—" }
        if #available(iOS 15.0, macOS 12.0, *) {
            return value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
        } else {
            let nf = NumberFormatter()
            nf.numberStyle = .currency
            nf.currencyCode = Locale.current.currencyCode ?? "USD"
            return nf.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
        }
    }

    static func kwhString(_ value: Double?) -> String {
        guard let value = value else { return "—" }
        if #available(iOS 15.0, macOS 12.0, *) {
            return value.formatted(.number.precision(.fractionLength(0...2))) + " kWh"
        } else {
            let nf = NumberFormatter()
            nf.minimumFractionDigits = 0
            nf.maximumFractionDigits = 2
            return (nf.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)) + " kWh"
        }
    }

    static func currencyPerKWhString(_ value: Double?) -> String {
        guard let value = value else { return "—" }
        return currencyString(value) + "/kWh"
    }
}

#if DEBUG
struct VehicleExpensesView_Previews: PreviewProvider {
    static var previews: some View {
        // Inline sample data to avoid any cross-file sample dependencies
        let cal = Calendar.current
        let now = Date()
        let e1 = ExpenseEntry(
            date: now,
            amount: 24.50,
            category: "Charging",
            energyKWh: 14.0,
            odometer: 24_300,
            location: "Home",
            notes: "Overnight",
            vehicleName: "Model 3",
            stateOfCharge: 0.8,
            chargeType: "Home",
            vehicleID: nil,
            isBusiness: true,
            vin: "5YJ3E1EA7KF123456",
            isEnergy: true
        )
        let e2 = ExpenseEntry(
            date: cal.date(byAdding: .day, value: -3, to: now)!,
            amount: 18.10,
            category: "Charging",
            energyKWh: 9.0,
            odometer: 24_000,
            location: "Supercharger",
            notes: "Trip top-up",
            vehicleName: "Model 3",
            stateOfCharge: 0.5,
            chargeType: "Supercharger",
            vehicleID: nil,
            isBusiness: false,
            vin: "5YJ3E1EA7KF123456",
            isEnergy: true
        )
        let e3 = ExpenseEntry(
            date: cal.date(byAdding: .day, value: -8, to: now)!,
            amount: 62.00,
            category: "Maintenance",
            energyKWh: nil,
            odometer: 40_120,
            location: "Service Center",
            notes: "Tire rotation",
            vehicleName: "Model Y",
            stateOfCharge: nil,
            chargeType: nil,
            vehicleID: nil,
            isBusiness: false,
            vin: "7SAYGDEE9NF654321",
            isEnergy: false
        )

        NavigationStack {
            VehicleExpensesView(expenses: [e1, e2, e3])
        }
        .previewDisplayName("Vehicle Expenses")
    }
}
#endif
