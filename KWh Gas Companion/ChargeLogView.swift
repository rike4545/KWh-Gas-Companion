// ChargeLogView.swift
// KWh Gas Companion
//
// 🔧 FIX — Invalid redeclaration of 'ChargeLogView':
//   Delete the old ChargeLogView.swift from your project navigator and use
//   only this file. The error means Xcode is compiling both copies.
//
// Changes vs the original:
//   1. Explicit init(entries:) replaces the `let entries: [ExpenseEntry]? = nil`
//      stored-property-with-default pattern (clearer intent, no ambiguity).
//   2. Filter uses energyAddedKWh — the canonical field name used everywhere
//      else in the codebase — instead of energyKWh.
//   3. ChargeRow.kwhText reads energyAddedKWh for the same reason.

import SwiftUI

struct ChargeLogView: View {
    private let injectedEntries: [ExpenseEntry]?
    @EnvironmentObject private var entriesStore: EntriesStore

    /// Pass entries directly (e.g. from a dashboard card), or omit to use
    /// the shared EntriesStore automatically.
    init(entries: [ExpenseEntry]? = nil) {
        self.injectedEntries = entries
    }

    private var sessions: [ExpenseEntry] {
        let src = injectedEntries ?? entriesStore.entries
        return src
            .filter { $0.isEnergy && (($0.energyAddedKWh ?? 0) > 0 || $0.amount > 0) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if sessions.isEmpty {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.slash").foregroundStyle(.secondary)
                        Text("No charging sessions yet").foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            } else {
                Section("Charging Sessions") {
                    ForEach(sessions, id: \.id) { entry in
                        ChargeRow(entry: entry)
                            .contentShape(Rectangle())
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Charge Log")
        .toolbar {
            if !sessions.isEmpty { EditButton() }
        }
    }

    private func delete(at offsets: IndexSet) {
        let ids = offsets.compactMap { sessions[$0].id }
        ids.forEach { entriesStore.remove(id: $0) }
    }
}

// MARK: - Row

private struct ChargeRow: View {
    let entry: ExpenseEntry

    private static let dateFmt: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    private static let currencyFmt: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = Locale.current.currency?.identifier ?? "USD"
        nf.maximumFractionDigits = 2
        return nf
    }()

    private var titleText: String {
        if let loc = entry.location, !loc.isEmpty { return loc }
        if let t = entry.chargeType, !t.isEmpty { return t }
        return "Charging"
    }

    private var amountText: String {
        Self.currencyFmt.string(from: NSNumber(value: entry.amount)) ?? "$0.00"
    }

    private var kwhText: String? {
        guard let k = entry.energyAddedKWh, k > 0 else { return nil }
        return String(format: "%.1f kWh", k)
    }

    private var socText: String? {
        guard let s = entry.stateOfCharge else { return nil }
        return "\(Int(s))% SoC"
    }

    private var odoText: String? {
        guard let o = entry.odometer, o > 0 else { return nil }
        return "\(Int(o)) mi"
    }

    private var metaLine: String {
        var parts: [String] = []
        if let k = kwhText { parts.append(k) }
        parts.append(amountText)
        if let s = socText { parts.append(s) }
        if let o = odoText { parts.append(o) }
        return parts.joined(separator: " • ")
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(metaLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(Self.dateFmt.string(from: entry.date))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ChargeLogView()
            .environmentObject(EntriesStore())
    }
}
#endif
