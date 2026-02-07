// ExpenseListView.swift
// KWh Gas Companion

import SwiftUI

struct ExpenseListView: View {
    // Inputs
    var entries: [ExpenseEntry]
    var onDeleteEntry: ((ExpenseEntry) -> Void)? = nil

    // UI State
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "All"
    @State private var sort: Sort = .newest

    enum Sort: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case oldest = "Oldest"
        case amountHighLow = "Amount ↓"
        case amountLowHigh = "Amount ↑"
        var id: String { rawValue }
    }

    var body: some View {
        // single expression -> implicit return ok, but keeping it simple here
        VStack(spacing: 0) {
            summaryHeader()
            listContent()
        }
        .navigationTitle("Expenses")
        .searchable(text: $searchText, prompt: "Search notes, location, vehicle…")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(Sort.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Category", selection: $selectedCategory) {
                        Text("All").tag("All")
                        ForEach(derivedCategories, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    // MARK: - Header (totals)

    private func summaryHeader() -> some View {
        let items = filteredAndSorted
        var total = 0.0
        for e in items { total += e.amount }

        var kWhTotal = 0.0
        for e in items {
            if let k = e.energyKWh { kWhTotal += k }
        }

        return VStack(alignment: .leading, spacing: 6) {
            Text("Summary")
                .font(.headline)
            HStack(spacing: 16) {
                MetricPill(title: "Total",
                           valueText: total.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")),
                           systemImage: "sum")
                MetricPill(title: "kWh",
                           valueText: String(format: "%.1f", kWhTotal),
                           systemImage: "bolt.fill")
                MetricPill(title: "Count",
                           valueText: "\(items.count)",
                           systemImage: "number")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - List

    private func listContent() -> some View {
        return List {
            ForEach(sortedMonths, id: \.self) { monthStart in
                if let items = groupedByMonth[monthStart] {
                    Section(header: Text(Self.monthFormatter.string(from: monthStart))) {
                        ForEach(items) { entry in
                            row(entry)
                                .swipeActions {
                                    if let onDeleteEntry {
                                        Button(role: .destructive) {
                                            onDeleteEntry(entry)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func row(_ e: ExpenseEntry) -> some View {
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(e.category.isEmpty ? "Uncategorized" : e.category)
                    .font(.body)
                HStack(spacing: 8) {
                    Text(Self.dateTimeFormatter.string(from: e.date))
                    if let loc = e.location, !loc.isEmpty {
                        Text("· \(loc)")
                    }
                    if let car = e.vehicleName, !car.isEmpty {
                        Text("· \(car)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let note = e.notes, !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(e.amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                    .font(.headline)
                if let k = e.energyKWh, k > 0 {
                    Text(String(format: "%.1f kWh", k))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Derived collections

    private var filteredAndSorted: [ExpenseEntry] {
        var items = entries

        // Category filter
        if selectedCategory != "All" {
            items = items.filter { $0.category.caseInsensitiveCompare(selectedCategory) == .orderedSame }
        }

        // Search
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            let lower = q.lowercased()
            items = items.filter { e in
                if e.category.lowercased().contains(lower) { return true }
                if e.location?.lowercased().contains(lower) == true { return true }
                if e.vehicleName?.lowercased().contains(lower) == true { return true }
                if e.notes?.lowercased().contains(lower) == true { return true }
                return false
            }
        }

        // Sort
        switch sort {
        case .newest:
            items.sort { $0.date > $1.date }
        case .oldest:
            items.sort { $0.date < $1.date }
        case .amountHighLow:
            items.sort { $0.amount > $1.amount }
        case .amountLowHigh:
            items.sort { $0.amount < $1.amount }
        }
        return items
    }

    private var groupedByMonth: [Date: [ExpenseEntry]] {
        var dict: [Date: [ExpenseEntry]] = [:]
        let cal = Calendar.current
        for e in filteredAndSorted {
            let comps = cal.dateComponents([.year, .month], from: e.date)
            let key = cal.date(from: comps) ?? e.date
            dict[key, default: []].append(e)
        }
        return dict
    }

    private var sortedMonths: [Date] {
        groupedByMonth.keys.sorted(by: >)
    }

    private var derivedCategories: [String] {
        let set = Set(entries.map { $0.category.isEmpty ? "Uncategorized" : $0.category })
        return Array(set).sorted()
    }

    // MARK: - Formatters

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

// MARK: - Small Metric Pill

private struct MetricPill: View {
    let title: String
    let valueText: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .imageScale(.medium)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(valueText).font(.body).bold()
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
    }
}

#if DEBUG
struct ExpenseListView_Previews: PreviewProvider {
    static var previews: some View {
        let now = Date()
        let cal = Calendar.current

        func make(_ daysAgo: Int, amount: Double, cat: String, kWh: Double?, loc: String?, note: String?) -> ExpenseEntry {
            let date = cal.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            var e = ExpenseEntry(date: date, amount: amount)
            e.category = cat
            e.energyKWh = kWh
            e.location = loc
            e.notes = note
            e.vehicleName = "Model 3"
            return e
        }

        let demo: [ExpenseEntry] = [
            make(1, amount: 14.22, cat: "Charging", kWh: 38.4, loc: "Home", note: "Night rate"),
            make(3, amount: 7.88,  cat: "Charging", kWh: 20.1, loc: "Supercharger", note: "Quick top-up"),
            make(5, amount: 86.00, cat: "Maintenance", kWh: nil, loc: "Service", note: "Tire rotation"),
            make(8, amount: 120.00, cat: "Insurance", kWh: nil, loc: nil, note: "Monthly premium"),
            make(10, amount: 11.05, cat: "Charging", kWh: 30.0, loc: "Work", note: "Garage L2")
        ]

        // Because we executed statements above, we must explicitly return a View
        return NavigationStack {
            ExpenseListView(entries: demo) { _ in }
        }
    }
}
#endif
