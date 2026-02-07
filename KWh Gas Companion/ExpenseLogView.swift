import SwiftUI

struct ExpenseLogView: View {
    @EnvironmentObject private var entriesStore: EntriesStore

    // Single source of truth for what sheet is active
    private enum ActiveSheet: Identifiable {
        case add
        case edit(ExpenseEntry)

        var id: String {
            switch self {
            case .add:
                return "add"
            case .edit(let entry):
                // We don't assume a concrete ID type; String(describing:) is fine
                return "edit-\(String(describing: entry.id))"
            }
        }
    }

    @State private var activeSheet: ActiveSheet? = nil

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    private var sortedEntries: [ExpenseEntry] {
        entriesStore.entries.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List(sortedEntries) { entry in
                row(for: entry)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        activeSheet = .edit(entry)
                    }
            }
            .navigationTitle("Expense Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeSheet = .add
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add expense")
                }
            }
            // Single sheet that handles both Add + Edit
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .add:
                    AddEditEntryView(
                        onSave: { new in
                            entriesStore.upsert(new)
                            activeSheet = nil
                        },
                        onCancel: {
                            activeSheet = nil
                        }
                    )
                    .environmentObject(entriesStore)

                case .edit(let entry):
                    AddEditEntryView(
                        entry: entry,
                        onSave: { updated in
                            entriesStore.upsert(updated)
                            activeSheet = nil
                        },
                        onCancel: {
                            activeSheet = nil
                        }
                    )
                    .environmentObject(entriesStore)
                }
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for e: ExpenseEntry) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                if let cat = ExpenseCategory(rawValue: e.category) {
                    Label(cat.rawValue, systemImage: cat.icon)
                        .labelStyle(.titleAndIcon)
                } else {
                    Text(e.category)
                        .font(.headline)
                }

                if let loc = e.location, !loc.isEmpty {
                    Text(loc)
                        .foregroundStyle(.secondary)
                }

                Text(e.date, style: .date)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(
                    e.amount,
                    format: .currency(code: e.currencyCode ?? currencyCode)
                )
                .monospacedDigit()

                if let rate = effectiveCostPerKWh(
                    amount: e.amount,
                    kWh: e.energyKWh,
                    location: e.location
                ) {
                    HStack(spacing: 2) {
                        Text(
                            rate,
                            format: .currency(code: e.currencyCode ?? currencyCode)
                        )
                        .monospacedDigit()
                        Text("/kWh")
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
        }
    }
}
