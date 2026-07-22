// ExpenseListContentView.swift
// KWh Gas Companion
//
// Performance pass:
// - Cache the sorted array so List diffs are cheaper
// - Cache currency formatter (no per-call alloc)
//

import SwiftUI

struct ExpenseListContentView: View {
    let title: String
    let items: [ExpenseEntry]
    var showTotals: Bool = true
    var deleteAction: ((IndexSet, [ExpenseEntry]) -> Void)? = nil
    var tapAction: ((ExpenseEntry) -> Void)? = nil

    @EnvironmentObject private var entriesStore: EntriesStore

    @State private var cachedSorted: [ExpenseEntry] = []
    @State private var cachedIDs: [UUID] = []

    var body: some View {
        List {
            if showTotals, !cachedSorted.isEmpty {
                Section {
                    HStack {
                        Text(title)
                        Spacer()
                        Text(totalSummary(for: cachedSorted))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                ForEach(cachedSorted, id: \.id) { entry in
                    if let tapAction {
                        ExpenseRowView(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture { tapAction(entry) }
                    } else {
                        NavigationLink {
                            ExpenseDetailView(entry: binding(for: entry))
                                .environmentObject(entriesStore)
                        } label: {
                            ExpenseRowView(entry: entry)
                        }
                    }
                }
                .onDelete { offsets in
                    if let deleteAction {
                        deleteAction(offsets, cachedSorted)
                    } else {
                        let ids = offsets.map { cachedSorted[$0].id }
                        ids.forEach { entriesStore.remove(id: $0) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .onAppear { refreshCacheIfNeeded(force: true) }
        .onChange(of: items.map(\.id)) { _, newIDs in
            // Update on inserts/deletes/reorders (biggest impact on list diffing)
            cachedIDs = newIDs
            refreshCacheIfNeeded(force: true)
        }
    }

    private func refreshCacheIfNeeded(force: Bool) {
        guard force || cachedSorted.isEmpty else { return }
        cachedSorted = items.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.id.uuidString > rhs.id.uuidString
        }
    }

    private func binding(for entry: ExpenseEntry) -> Binding<ExpenseEntry> {
        Binding(
            get: { entriesStore.entries.first(where: { $0.id == entry.id }) ?? entry },
            set: { updated in entriesStore.update(updated) }
        )
    }

    private func totalSummary(for entries: [ExpenseEntry]) -> String {
        let total = entries.reduce(0.0) { $0 + $1.amount }
        return CurrencyFormatterCache.string(total, code: Locale.current.currency?.identifier ?? "USD")
    }
}

// MARK: - Currency formatter cache (local to this file)

@MainActor
private enum CurrencyFormatterCache {
    private static var cache: [String: NumberFormatter] = [:]

    static func string(_ amount: Double, code: String) -> String {
        let formatter: NumberFormatter
        if let existing = cache[code] {
            formatter = existing
        } else {
            let nf = NumberFormatter()
            nf.numberStyle = .currency
            nf.currencyCode = code
            nf.locale = .current
            cache[code] = nf
            formatter = nf
        }
        return formatter.string(from: amount as NSNumber) ?? "\(code) \(amount)"
    }
}
