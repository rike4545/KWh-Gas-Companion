// ExpenseListContentView.swift
// KWh Gas Companion

import SwiftUI

struct ExpenseListContentView: View {
    let title: String
    let items: [ExpenseEntry]
    var showTotals: Bool = true
    /// Caller-provided delete handler (receives offsets + the *sorted* array).
    var deleteAction: ((IndexSet, [ExpenseEntry]) -> Void)? = nil
    /// Caller-provided tap handler (if nil, we push an editable detail view).
    var tapAction: ((ExpenseEntry) -> Void)? = nil

    @EnvironmentObject private var entriesStore: EntriesStore

    // MARK: - Derived

    private var sortedItems: [ExpenseEntry] {
        items.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date > rhs.date
            }
            // Stable-ish fallback if dates are identical
            return lhs.id.uuidString > rhs.id.uuidString
        }
    }

    // MARK: - Body

    var body: some View {
        List {
            if showTotals, !sortedItems.isEmpty {
                Section {
                    HStack {
                        Text(title)
                        Spacer()
                        Text(totalSummary(for: sortedItems))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                ForEach(sortedItems, id: \.id) { entry in
                    if let tapAction {
                        // Caller-controlled tap behavior
                        ExpenseRowView(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture { tapAction(entry) }
                    } else {
                        // Default: editable detail with a Binding to EntriesStore
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
                        // Let caller handle deletion based on the same sorted view
                        deleteAction(offsets, sortedItems)
                    } else {
                        // Default: delete by id via EntriesStore (canonical write path)
                        let ids = offsets.map { sortedItems[$0].id }
                        ids.forEach { entriesStore.remove(id: $0) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
    }

    // MARK: - Bind a visible row to the source of truth

    private func binding(for entry: ExpenseEntry) -> Binding<ExpenseEntry> {
        Binding(
            get: {
                entriesStore.entries.first(where: { $0.id == entry.id }) ?? entry
            },
            set: { updated in
                // Canonical update path: use the store API
                entriesStore.update(updated)
            }
        )
    }

    // MARK: - Totals / formatting

    private func totalSummary(for entries: [ExpenseEntry]) -> String {
        let total = entries.reduce(0.0) { $0 + $1.amount }
        return currency(total)
    }

    private func currency(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        return f.string(from: NSNumber(value: amount)) ?? String(format: "$%.2f", amount)
    }
}
