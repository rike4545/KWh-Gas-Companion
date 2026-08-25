// ExpenseListView.swift
// KWh Gas Companion
//
// Performance pass:
// - Compute derived collections once per render (not 2–3x)
// - Cache currency formatter (no repeated formatter work)
// - Debounce search text slightly to reduce churn while typing
//

import SwiftUI

struct ExpenseListView: View {
    var entries: [ExpenseEntry]
    var onDeleteEntry: ((ExpenseEntry) -> Void)? = nil

    @State private var searchText: String = ""
    @State private var debouncedSearch: String = ""
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
        let derived = Derived.build(
            entries: entries,
            search: debouncedSearch,
            selectedCategory: selectedCategory,
            sort: sort
        )

        VStack(spacing: 0) {
            summaryHeader(items: derived.items, total: derived.total, kWhTotal: derived.kWhTotal)
            listContent(sections: derived.sections)
        }
        .navigationTitle("Expenses")
        .searchable(text: $searchText, prompt: "Search notes, location, vehicle…")
        .onChange(of: searchText) { _, newValue in
            // Lightweight debounce (avoids recomputing groups on every keystroke)
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                if searchText == newValue {
                    debouncedSearch = trimmed
                }
            }
        }
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
                        ForEach(derived.categories, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    private func summaryHeader(items: [ExpenseEntry], total: Double, kWhTotal: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Summary").font(.headline)
            HStack(spacing: 16) {
                MetricPill(
                    title: "Total",
                    valueText: CurrencyFormatterCache.string(total, code: Locale.current.currency?.identifier ?? "USD"),
                    systemImage: "sum"
                )
                MetricPill(
                    title: "kWh",
                    valueText: String(format: "%.1f", kWhTotal),
                    systemImage: "bolt.fill"
                )
                MetricPill(
                    title: "Count",
                    valueText: "\(items.count)",
                    systemImage: "number"
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func listContent(sections: [Derived.MonthSection]) -> some View {
        List {
            ForEach(sections) { section in
                Section(header: Text(Self.monthFormatter.string(from: section.monthStart))) {
                    ForEach(section.entries) { entry in
                        row(entry)
                            .swipeActions {
                                if let onDeleteEntry {
                                    Button(role: .destructive) { onDeleteEntry(entry) } label: {
                                        Label("Delete", systemImage: "trash")
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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(e.category.isEmpty ? "Uncategorized" : e.category)
                    .font(.body)

                HStack(spacing: 8) {
                    Text(Self.dateTimeFormatter.string(from: e.date))
                    if let loc = e.location, !loc.isEmpty { Text("· \(loc)") }
                    if let car = e.vehicleName, !car.isEmpty { Text("· \(car)") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let note = e.notes, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatterCache.string(e.amount, code: Locale.current.currency?.identifier ?? "USD"))
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

// MARK: - Derived

private enum Derived {
    struct MonthSection: Identifiable {
        let id: Date
        let monthStart: Date
        let entries: [ExpenseEntry]
    }

    struct Output {
        let items: [ExpenseEntry]
        let sections: [MonthSection]
        let categories: [String]
        let total: Double
        let kWhTotal: Double
    }

    static func build(
        entries: [ExpenseEntry],
        search: String,
        selectedCategory: String,
        sort: ExpenseListView.Sort
    ) -> Output {
        var items = entries

        // categories (cheap)
        let categorySet = Set(entries.map { $0.category.isEmpty ? "Uncategorized" : $0.category })
        let categories = Array(categorySet).sorted()

        if selectedCategory != "All" {
            items = items.filter { $0.category.caseInsensitiveCompare(selectedCategory) == .orderedSame }
        }

        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            items = items.filter { e in
                if e.category.lowercased().contains(q) { return true }
                if (e.location ?? "").lowercased().contains(q) { return true }
                if (e.vehicleName ?? "").lowercased().contains(q) { return true }
                if (e.notes ?? "").lowercased().contains(q) { return true }
                return false
            }
        }

        switch sort {
        case .newest: items.sort { $0.date > $1.date }
        case .oldest: items.sort { $0.date < $1.date }
        case .amountHighLow: items.sort { $0.amount > $1.amount }
        case .amountLowHigh: items.sort { $0.amount < $1.amount }
        }

        // totals (single pass)
        var total = 0.0
        var kWhTotal = 0.0
        for e in items {
            total += e.amount
            if let k = e.energyKWh { kWhTotal += k }
        }

        // grouping (single pass)
        let cal = Calendar.current
        var dict: [Date: [ExpenseEntry]] = [:]
        for e in items {
            let comps = cal.dateComponents([.year, .month], from: e.date)
            let key = cal.date(from: comps) ?? e.date
            dict[key, default: []].append(e)
        }

        let monthKeys = dict.keys.sorted(by: >)
        let sections = monthKeys.map { key in
            MonthSection(id: key, monthStart: key, entries: dict[key] ?? [])
        }

        return Output(items: items, sections: sections, categories: categories, total: total, kWhTotal: kWhTotal)
    }
}

// MARK: - Small Metric Pill

private struct MetricPill: View {
    let title: String
    let valueText: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage).imageScale(.medium)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(valueText).font(.body).bold()
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
    }
}

// Shared cache for this file too
@MainActor
private enum CurrencyFormatterCache {
    private static var cache: [String: NumberFormatter] = [:]

    static func string(_ amount: Double, code: String) -> String {
        let f: NumberFormatter
        if let existing = cache[code] {
            f = existing
        } else {
            let nf = NumberFormatter()
            nf.numberStyle = .currency
            nf.currencyCode = code
            nf.locale = .current
            cache[code] = nf
            f = nf
        }
        return f.string(from: amount as NSNumber) ?? "\(code) \(amount)"
    }
}
