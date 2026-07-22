//
//  ExpenseRowView 2.swift
//  KWh Gas Companion
//
//

import SwiftUI

struct ExpenseRowView: View {
    let entry: ExpenseEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.category.isEmpty ? "Expense" : entry.category)
                    .font(.body.weight(.semibold))
                Text(entry.date, style: .date)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                if entry.isEnergy, let kWh = entry.energyKWh {
                    Text("\(kWh, specifier: "%.2f") kWh")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let odo = entry.odometer {
                    Text("\(Int(odo)) mi")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}
