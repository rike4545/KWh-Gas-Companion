//
//  BusinessDeductionReportView.swift
//  My KWh Companion
//
//  Swift 6 / iOS 17+
//
//  - Generic over Item with adapter closures (no concrete model dependency)
//  - Real filtering (date windows), search, category chips, eligible-only toggle
//  - Sort by date/amount, CSV export via ShareLink
//  - Small subviews for compiler friendliness
//
//  Notes (Swift 6 compile hardening):
//  - Uses Color.primary (not .primary) anywhere a ternary feeds .foregroundStyle,
//    preventing Color vs HierarchicalShapeStyle mismatch errors.
//  - Flow layout avoids UIScreen (no UIKit import needed).
//

import SwiftUI
import Foundation

// MARK: - Report (generic over Item)

@MainActor
public struct BusinessDeductionReportView<Item>: View {

    // MARK: Adapter closures (how to read fields from your Item)
    public typealias DateOf     = (Item) -> Date
    public typealias AmountOf   = (Item) -> Double
    public typealias CategoryOf = (Item) -> String
    public typealias VendorOf   = (Item) -> String
    public typealias NoteOf     = (Item) -> String
    public typealias Eligible   = (Item) -> Bool

    // Required
    private let items: [Item]
    private let dateOf: DateOf
    private let amountOf: AmountOf

    // Optional (with sensible defaults)
    private let categoryOf: CategoryOf
    private let vendorOf: VendorOf
    private let noteOf: NoteOf
    private let isEligible: Eligible

    // Optional actions
    private let onEdit: ((Item) -> Void)?
    private let onDelete: ((Item) -> Void)?

    // Deduction assumptions (e.g., business-use percentage)
    private let businessUsePercent: Double // 0...1

    // MARK: - Init

    /// Generic constructor with adapter closures so this view can work with any model.
    public init(
        items: [Item],
        dateOf: @escaping DateOf,
        amountOf: @escaping AmountOf,
        categoryOf: @escaping CategoryOf = { _ in "" },
        vendorOf: @escaping VendorOf = { _ in "" },
        noteOf: @escaping NoteOf = { _ in "" },
        isEligible: @escaping Eligible = { _ in true },
        businessUsePercent: Double = 1.0,
        onEdit: ((Item) -> Void)? = nil,
        onDelete: ((Item) -> Void)? = nil
    ) {
        self.items = items
        self.dateOf = dateOf
        self.amountOf = amountOf
        self.categoryOf = categoryOf
        self.vendorOf = vendorOf
        self.noteOf = noteOf
        self.isEligible = isEligible
        self.businessUsePercent = max(0, min(1, businessUsePercent))
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    // MARK: - UI State

    @State private var selectedQuick: QuickFilter = .all
    @State private var eligibleOnly: Bool = false
    @State private var search: String = ""
    @State private var selectedCategories: Set<String> = []
    @State private var sortKey: SortKey = .date
    @State private var sortAscending: Bool = false
    @State private var csvURL: URL? = nil

    // MARK: - Derived datasets

    private var dateWindow: (start: Date?, end: Date?) {
        switch selectedQuick {
        case .all:
            return (nil, nil)
        case .last12Months:
            let end = Date()
            let start = Calendar.current.date(byAdding: .month, value: -12, to: end)
            return (start, end)
        case .yearToDate:
            let now = Date()
            let comps = Calendar.current.dateComponents([.year], from: now)
            let start = Calendar.current.date(from: comps)
            return (start, now)
        case .thisMonth:
            let now = Date()
            var comps = Calendar.current.dateComponents([.year, .month], from: now)
            comps.day = 1
            let start = Calendar.current.date(from: comps)
            let end = Calendar.current.date(byAdding: .month, value: 1, to: start ?? now)
                .flatMap { Calendar.current.date(byAdding: .day, value: -1, to: $0) } ?? now
            return (start, end)
        }
    }

    private func normalized(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var availableCategories: [String] {
        let cats = items.map { normalized(categoryOf($0)) }
        return Array(Set(cats.filter { !$0.isEmpty })).sorted()
    }

    private var filteredSorted: [Item] {
        var list = items

        // Quick date window
        if let start = dateWindow.start {
            list = list.filter { dateOf($0) >= start }
        }
        if let end = dateWindow.end {
            list = list.filter { dateOf($0) <= end }
        }

        // Eligible-only
        if eligibleOnly {
            list = list.filter { isEligible($0) }
        }

        // Category chips
        if !selectedCategories.isEmpty {
            list = list.filter { selectedCategories.contains(normalized(categoryOf($0))) }
        }

        // Search (category/vendor/note)
        let q = normalized(search).lowercased()
        if !q.isEmpty {
            list = list.filter { item in
                let fields = [
                    normalized(categoryOf(item)).lowercased(),
                    normalized(vendorOf(item)).lowercased(),
                    normalized(noteOf(item)).lowercased()
                ]
                return fields.contains(where: { $0.contains(q) })
            }
        }

        // Sort
        list.sort { a, b in
            switch sortKey {
            case .date:
                return sortAscending ? (dateOf(a) < dateOf(b)) : (dateOf(a) > dateOf(b))
            case .amount:
                return sortAscending ? (amountOf(a) < amountOf(b)) : (amountOf(a) > amountOf(b))
            }
        }
        return list
    }

    // Totals
    private var totalAmount: Double {
        filteredSorted.reduce(0) { $0 + amountOf($1) }
    }

    private var eligibleAmount: Double {
        filteredSorted
            .filter { isEligible($0) }
            .reduce(0) { $0 + amountOf($1) }
    }

    private var estimatedDeduction: Double {
        eligibleAmount * businessUsePercent
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                quickFilters
                controlsRow
                categoryChips
                summaryCard
                listSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("Business Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Business Deduction Report")
                .font(.title2.weight(.semibold))
            Text("Filter, review, and export potential deductible expenses.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Quick Filters

    private var quickFilters: some View {
        BDRFlowLayout(spacing: 8) {
            ForEach(QuickFilter.allCases, id: \.self) { chip in
                Button {
                    selectedQuick = chip
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: chip.icon)
                        Text(chip.title)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(
                            chip == selectedQuick
                            ? Color.accentColor.opacity(0.20)
                            : Color.secondary.opacity(0.12)
                        )
                    )
                    // IMPORTANT: Color.primary avoids Color vs HierarchicalShapeStyle mismatch
                    .foregroundStyle(chip == selectedQuick ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Filter: \(chip.title)"))
            }
        }
    }

    // MARK: - Controls row (eligible toggle + search + sort)

    private var controlsRow: some View {
        VStack(spacing: 10) {
            Toggle(isOn: $eligibleOnly) {
                Label("Eligible only", systemImage: "checkmark.seal")
            }
            .toggleStyle(.switch)

            TextField("Search (category, vendor, note…)", text: $search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.10))
                )

            HStack {
                Menu {
                    Picker("Sort by", selection: $sortKey) {
                        ForEach(SortKey.allCases) { key in
                            Label(key.title, systemImage: key.systemImage).tag(key)
                        }
                    }
                    Toggle(isOn: $sortAscending) {
                        Label(sortAscending ? "Ascending" : "Descending",
                              systemImage: sortAscending ? "arrow.up" : "arrow.down")
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                        .labelStyle(.titleAndIcon)
                }

                Spacer()

                Button {
                    csvURL = exportCSVToTempURL()
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: - Category chips

    private var categoryChips: some View {
        Group {
            if !availableCategories.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Categories")
                        .font(.headline)
                    BDRFlowLayout(spacing: 8) {
                        ForEach(availableCategories, id: \.self) { name in
                            let isOn = selectedCategories.contains(name)
                            Button {
                                if isOn { selectedCategories.remove(name) }
                                else { selectedCategories.insert(name) }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                    Text(name)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(isOn ? Color.accentColor.opacity(0.20) : Color.secondary.opacity(0.12))
                                )
                                // IMPORTANT: Color.primary avoids Color vs HierarchicalShapeStyle mismatch
                                .foregroundStyle(isOn ? Color.accentColor : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if !selectedCategories.isEmpty {
                        Button(role: .destructive) {
                            selectedCategories.removeAll()
                        } label: {
                            Label("Clear Category Filters", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        BDRSummaryCardView(
            totalCount: filteredSorted.count,
            totalAmount: totalAmount,
            eligibleAmount: eligibleAmount,
            businessUsePercent: businessUsePercent,
            estimatedDeduction: estimatedDeduction
        )
    }

    // MARK: - List

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if filteredSorted.isEmpty {
                BDREmptyStateView()
            } else {
                ForEach(Array(filteredSorted.enumerated()), id: \.offset) { pair in
                    rowView(index: pair.offset, item: pair.element)
                }
            }
        }
    }

    private func rowView(index: Int, item: Item) -> some View {
        let d = dateOf(item)
        let cat = normalized(categoryOf(item))
        let ven = normalized(vendorOf(item))
        let note = normalized(noteOf(item))
        let amt = amountOf(item)
        let eligible = isEligible(item)

        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(ven.isEmpty ? (cat.isEmpty ? "Expense \(index + 1)" : cat) : ven)
                        .font(.headline)
                    if eligible {
                        Text("eligible")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green.opacity(0.18)))
                    }
                }
                if !note.isEmpty {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 10) {
                    pill(text: d.formatted(date: .abbreviated, time: .omitted))
                    if !cat.isEmpty { pill(text: cat) }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(currency(amt))
                    .font(.headline)
                    .monospacedDigit()

                Text(eligible ? "× \(percent(businessUsePercent))" : "—")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contextMenu {
            if let onEdit {
                Button { onEdit(item) } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            if let onDelete {
                Button(role: .destructive) { onDelete(item) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func pill(text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.secondary.opacity(0.14)))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if let url = csvURL {
                ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Share CSV")
            } else {
                Button {
                    csvURL = exportCSVToTempURL()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Export CSV")
            }
        }
    }

    // MARK: - CSV Export

    private func exportCSVToTempURL() -> URL {
        var rows: [[String]] = []
        rows.append(["Date", "Category", "Amount", "Vendor", "Note", "Eligible", "BusinessUse%", "EstimatedDeduction"])

        for item in filteredSorted {
            let d = dateOf(item)
            let cat = normalized(categoryOf(item))
            let amt = amountOf(item)
            let ven = normalized(vendorOf(item))
            let note = normalized(noteOf(item))
            let elig = isEligible(item)
            let est = elig ? (amt * businessUsePercent) : 0

            rows.append([
                dateFormatter.string(from: d),
                cat,
                currency(amt),
                ven,
                note.replacingOccurrences(of: "\n", with: " "),
                elig ? "yes" : "no",
                percent(businessUsePercent),
                currency(est)
            ].map(csvEscape))
        }

        let csv = rows.map { $0.joined(separator: ",") }.joined(separator: "\n")
        let fname = "business-report-\(UUID().uuidString.prefix(8)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fname)

        // Explicit Foundation.Data to avoid any shadowing
        try? Foundation.Data(csv.utf8).write(to: url, options: .atomic)
        return url
    }
}

// MARK: - Quick Filter & Sort

fileprivate enum QuickFilter: CaseIterable, Hashable {
    case all, last12Months, yearToDate, thisMonth

    var title: String {
        switch self {
        case .all: return "All"
        case .last12Months: return "Last 12 Mo"
        case .yearToDate: return "YTD"
        case .thisMonth: return "This Month"
        }
    }

    var icon: String {
        switch self {
        case .all: return "line.3.horizontal.decrease.circle"
        case .last12Months: return "calendar"
        case .yearToDate: return "chart.line.uptrend.xyaxis"
        case .thisMonth: return "calendar.circle"
        }
    }
}

fileprivate enum SortKey: String, CaseIterable, Identifiable {
    case date, amount
    var id: String { rawValue }
    var title: String { self == .date ? "Date" : "Amount" }
    var systemImage: String { self == .date ? "calendar" : "dollarsign.circle" }
}

// MARK: - Summary Card

fileprivate struct BDRSummaryCardView: View {
    let totalCount: Int
    let totalAmount: Double
    let eligibleAmount: Double
    let businessUsePercent: Double
    let estimatedDeduction: Double

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Summary")
                    .font(.headline)
                HStack(spacing: 16) {
                    summaryPill(title: "Items", value: "\(totalCount)")
                    summaryPill(title: "Total", value: currency(totalAmount))
                    summaryPill(title: "Eligible", value: currency(eligibleAmount))
                    summaryPill(title: "Est. Deduct", value: currency(estimatedDeduction))
                }
                Text("Assuming business use \(percent(businessUsePercent)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.10))
        )
    }
}

// MARK: - Empty State

fileprivate struct BDREmptyStateView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No expenses match your filters.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - File-local Flow Layout (simple wrap)

fileprivate struct BDRFlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let availableWidth: CGFloat = max(1, proposal.width ?? 320)

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > availableWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: availableWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            sub.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Utilities

fileprivate let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
}()

fileprivate func currency(_ amount: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    return f.string(from: amount as NSNumber) ?? "$0.00"
}

fileprivate func percent(_ p: Double) -> String {
    let pct = max(0, min(1, p))
    let f = NumberFormatter()
    f.numberStyle = .percent
    f.minimumFractionDigits = 0
    f.maximumFractionDigits = 0
    return f.string(from: pct as NSNumber) ?? "0%"
}

fileprivate func csvEscape(_ field: String) -> String {
    if field.contains(",") || field.contains("\"") || field.contains("\n") {
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    return field
}
