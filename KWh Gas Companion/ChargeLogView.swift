// ChargeLogView.swift
// KWh Gas Companion

import SwiftUI

struct ChargeLogView: View {
    // Optional injection; dashboard can call no-arg init
    let entries: [ExpenseEntry]? = nil
    @EnvironmentObject private var entriesStore: EntriesStore

    // Precompute data to keep body simple
    private var sessions: [ExpenseEntry] {
        let src = entries ?? entriesStore.entries
        return src
            .filter { $0.isEnergy && ((($0.energyKWh ?? 0) > 0) || $0.amount > 0) }
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

    // Deletion by ID against the store
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

    // Split complex formatting into tiny computed props
    private var titleText: String {
        if let loc = entry.location, !loc.isEmpty { return loc }
        if let t = entry.chargeType, !t.isEmpty { return t }
        return "Charging"
    }

    private var amountText: String {
        Self.currencyFmt.string(from: NSNumber(value: entry.amount)) ?? "$0.00"
    }

    private var kwhText: String? {
        guard let k = entry.energyKWh, k > 0 else { return nil }
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
        // Build a bullet-separated string from available parts
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
