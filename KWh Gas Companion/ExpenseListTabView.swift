//
//  ExpenseListTabView.swift
//  My KWh Companion
//
//  Swift 6 / iOS 17+
//
//  - “+ Add” (sheet hosts AddEditEntryView(onSave:onCancel:))
//  - Uses EntriesStore as canonical source of truth (no local staging)
//  - Search, Filter (dynamic categories), Sort (date/amount)
//  - CSV Export via temp URL + ShareLink
//  - Edit, Delete, Move to Category (local overrides; store persistence hooks optional)
//  - Tesla-glass background + accent-aware glass rows
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public struct ExpenseListTabView: View {
    public init() {}

    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var appearance: AppAppearance
    @EnvironmentObject private var entriesStore: EntriesStore
    @StateObject private var adsStore = AdsEntitlementStore.shared

    @AppStorage("defaultCurrencyCode")
    private var defaultCurrencyCode: String = (Locale.current.currency?.identifier ?? "USD")

    @State private var query: String = ""
    @State private var selectedCategories: Set<String> = []
    @State private var sortKey: SortKey = .date
    @State private var sortAscending: Bool = false

    // Add
    @State private var showingAddSheet = false

    // CSV export
    @State private var csvURL: URL? = nil

    // Local edit/move/delete support
    @State private var hiddenIDs: Set<ExpenseEntry.ID> = []
    @State private var overrides: [ExpenseEntry.ID: DisplayOverride] = [:]
    @State private var editing: DisplayExpense? = nil
    @State private var moving: DisplayExpense? = nil
    @State private var showMoveSheet: Bool = false

    enum SortKey: String, CaseIterable, Identifiable {
        case date, amount
        var id: String { rawValue }
        var title: String { self == .date ? "Date" : "Amount" }
        var systemImage: String { self == .date ? "calendar" : "dollarsign.circle" }
    }

    // MARK: - Sources (EntriesStore is canonical)

    private var allEntries: [ExpenseEntry] {
        entriesStore.entries
    }

    // Display models with local overrides applied, minus hidden
    private var allDisplay: [DisplayExpense] {
        allEntries
            .filter { !hiddenIDs.contains($0.id) }
            .map { DisplayExpense(from: $0, override: overrides[$0.id]) }
    }

    private var availableCategories: [String] {
        Set(allDisplay.map { $0.categoryString.trimmed }.filter { !$0.isEmpty }).sorted()
    }

    private var workingEntries: [DisplayExpense] {
        var list = allDisplay

        if !selectedCategories.isEmpty {
            list = list.filter { selectedCategories.contains($0.categoryString) }
        }

        let q = query.trimmed.lowercased()
        if !q.isEmpty {
            list = list.filter { e in
                let parts: [String] = [
                    e.categoryString,
                    e.titleString,
                    e.noteString,
                    Self.dateFormatter.string(from: e.date),
                    currency(e.amount)
                ]
                return parts.contains(where: { $0.lowercased().contains(q) })
                    || String(describing: e).lowercased().contains(q)
            }
        }

        list.sort { lhs, rhs in
            switch sortKey {
            case .date:   return sortAscending ? (lhs.date < rhs.date) : (lhs.date > rhs.date)
            case .amount: return sortAscending ? (lhs.amount < rhs.amount) : (lhs.amount > rhs.amount)
            }
        }
        return list
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("Expenses")
                .toolbar { toolbar }
                .searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search notes, merchant, …"
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
        }
        // ADD: use existing AddEditEntryView(onSave:onCancel:) and persist via EntriesStore
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                AddEditEntryView(
                    onSave: { newEntry in
                        handleAdd(newEntry)    // persists to EntriesStore
                        showingAddSheet = false
                    },
                    onCancel: {
                        showingAddSheet = false
                    }
                )
                .environmentObject(entriesStore)
            }
        }
        // QUICK EDIT: local overrides; persistence hook is still optional
        .sheet(item: $editing) { item in
            QuickEditSheet(
                initial: item,
                categories: availableCategories
            ) { newOverride in
                overrides[item.id] = newOverride

                // If later you want quick edits to affect the budget,
                // this is where you'd construct a new ExpenseEntry from
                // item.source + override and call entriesStore.upsert(updated).
            }
        }
        // MOVE CATEGORY: local override + optional persistence hook
        .sheet(isPresented: $showMoveSheet) {
            if let moving {
                MoveCategorySheet(
                    current: moving.categoryString,
                    categories: availableCategories
                ) { newCategory in
                    var ov = overrides[moving.id] ?? DisplayOverride()
                    ov.categoryString = newCategory
                    overrides[moving.id] = ov

                    // Same idea: if you want this to be permanent,
                    // build an updated ExpenseEntry and call entriesStore.upsert(updated).
                }
            }
        }
        .background(backgroundView)
        .task {
            await adsStore.load()
        }
    }

    // MARK: - Themed Background (accent-tinted, dark-mode aware)

    private var backgroundView: some View {
        let accent = appearance.accentColor

        return Group {
            if scheme == .dark {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.04, blue: 0.10),
                            Color(red: 0.01, green: 0.01, blue: 0.03)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    RadialGradient(
                        colors: [
                            accent.opacity(0.55),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 480
                    )
                    .blur(radius: 34)
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.32),
                            Color.clear
                        ],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: 420
                    )
                    .blur(radius: 40)
                }
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            accent.opacity(0.30),
                            Color(.systemBackground),
                            Color(.secondarySystemBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    RadialGradient(
                        colors: [
                            accent.opacity(0.18),
                            Color.clear
                        ],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 420
                    )
                    .blur(radius: 26)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if workingEntries.isEmpty {
            emptyState
        } else {
            List {
                ForEach(workingEntries) { entry in
                    row(entry)
                        .asGlassRow()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onDelete(perform: delete)

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    private var emptyState: some View {
        let accent = appearance.accentColor

        return VStack(spacing: 18) {
            Spacer(minLength: 40)

            ZStack {
                Circle()
                    .fill(accent.opacity(0.10))
                    .frame(width: 96, height: 96)
                Circle()
                    .stroke(accent.opacity(0.25), lineWidth: 1)
                    .frame(width: 96, height: 96)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(accent)
            }

            Text("No matching expenses")
                .font(.title3.weight(.semibold))
            Text("Add entries or import data to see them here.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
                Button { showingAddSheet = true } label: {
                    Label("Add Manually", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)

                NavigationLink {
                    TeslaFiCSVImportView()
                } label: {
                    Label("Import CSV", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(accent)
            }
            .padding(.top, 6)

            if !query.isEmpty || !selectedCategories.isEmpty {
                Button {
                    query = ""
                    selectedCategories.removeAll()
                } label: {
                    Label("Clear Filters", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .tint(accent)
                .padding(.top, 4)
            }

            if !adsStore.hasRemovedAds {
                AdBannerCard(adsStore: adsStore)
                    .padding(.top, 12)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Row

    @ViewBuilder
    private func row(_ e: DisplayExpense) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(e.titleString.isEmpty ? e.categoryString : e.titleString)
                    .font(.headline)
                    .lineLimit(1)
                if !e.noteString.isEmpty {
                    Text(e.noteString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(currency(e.amount))
                    .monospacedDigit()
                    .font(.headline)
                Text(Self.dateFormatter.string(from: e.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button { editing = e } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button { showMoveSheet(for: e) } label: {
                Label("Move to Category…", systemImage: "folder")
            }
            Divider()
            Button(role: .destructive) { delete(e) } label: {
                Label("Delete", systemImage: "trash")
            }
            #if canImport(UIKit)
            Divider()
            Button {
                UIPasteboard.general.string = currency(e.amount)
            } label: { Label("Copy Amount", systemImage: "doc.on.doc") }
            if !e.noteString.isEmpty {
                Button {
                    UIPasteboard.general.string = e.noteString
                } label: { Label("Copy Note", systemImage: "doc.on.doc") }
            }
            #endif
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button { editing = e } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(appearance.accentColor)

            Button(role: .destructive) { delete(e) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button { showMoveSheet(for: e) } label: {
                Label("Move", systemImage: "folder")
            }
            .tint(appearance.accentColor.opacity(0.85))
        }
    }

    private func showMoveSheet(for e: DisplayExpense) {
        moving = e
        showMoveSheet = true
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) {
            Menu {
                if !availableCategories.isEmpty {
                    Section("Categories") {
                        ForEach(availableCategories, id: \.self) { name in
                            let isOn = selectedCategories.contains(name)
                            Button {
                                if isOn { selectedCategories.remove(name) }
                                else { selectedCategories.insert(name) }
                            } label: {
                                Label(name, systemImage: isOn ? "checkmark.circle.fill" : "circle")
                            }
                        }
                        if !selectedCategories.isEmpty {
                            Divider()
                            Button(role: .destructive) {
                                selectedCategories.removeAll()
                            } label: {
                                Label("Clear Category Filters", systemImage: "xmark.circle")
                            }
                        }
                    }
                }
                Section("Sort") {
                    Picker("Sort by", selection: $sortKey) {
                        ForEach(SortKey.allCases) { key in
                            Label(key.title, systemImage: key.systemImage).tag(key)
                        }
                    }
                    Toggle(isOn: $sortAscending) {
                        Label(
                            sortAscending ? "Ascending" : "Descending",
                            systemImage: sortAscending ? "arrow.up" : "arrow.down"
                        )
                    }
                }
            } label: {
                Label("Filter & Sort", systemImage: "line.3.horizontal.decrease.circle")
            }
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if !workingEntries.isEmpty {
                if let url = csvURL {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share CSV")
                } else {
                    Button { csvURL = exportCSVToTempURL() } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Export CSV")
                }
            }

            Button { showingAddSheet = true } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add Expense")
            .tint(appearance.accentColor)
        }
    }

    // MARK: - Actions

    /// Canonical write path: EntriesStore.upsert(_:)
    private func handleAdd(_ entry: ExpenseEntry) {
        entriesStore.upsert(entry)
    }

    private func delete(_ e: DisplayExpense) {
        hiddenIDs.insert(e.id)
        entriesStore.remove(id: e.id)
    }

    private func delete(_ offsets: IndexSet) {
        let ids = offsets.map { workingEntries[$0].id }
        ids.forEach { id in
            hiddenIDs.insert(id)
            entriesStore.remove(id: id)
        }
    }

    // MARK: - CSV Export

    private func exportCSVToTempURL() -> URL {
        var rows: [[String]] = []
        rows.append(["Date", "Category", "Amount", "Merchant/Title", "Note"])
        for e in workingEntries {
            rows.append([
                Self.dateFormatter.string(from: e.date),
                e.categoryString,
                currency(e.amount),
                e.titleString,
                e.noteString.replacingOccurrences(of: "\n", with: " ")
            ])
        }
        let csv = rows.map { $0.map(Self.csvEscape).joined(separator: ",") }.joined(separator: "\n")
        let fname = "expenses-\(UUID().uuidString.prefix(8)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fname)
        try? Data(csv.utf8).write(to: url, options: .atomic)
        return url
    }

    // MARK: - Utilities

    private func currency(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = defaultCurrencyCode
        return f.string(from: amount as NSNumber) ?? "\(defaultCurrencyCode) \(amount)"
    }

    private static func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}

// MARK: - Display layer (safe wrapper + overrides)

fileprivate struct DisplayExpense: Identifiable, Hashable {
    let id: ExpenseEntry.ID
    let date: Date
    let amount: Double
    let categoryString: String
    let titleString: String
    let noteString: String

    // Keep original source around if you want to upsert later
    let source: ExpenseEntry

    init(from e: ExpenseEntry, override ov: DisplayOverride?) {
        self.id = e.id
        self.date = ov?.date ?? e.date
        self.amount = ov?.amount ?? e.amount
        let cat = e.categoryString
        let ttl = e.titleString
        self.categoryString = (ov?.categoryString ?? cat).trimmed
        self.titleString    = (ov?.titleString ?? ttl).trimmed
        self.noteString     = (ov?.noteString ?? e.noteString).trimmed
        self.source = e
    }
}

fileprivate struct DisplayOverride: Hashable {
    var titleString: String? = nil
    var categoryString: String? = nil
    var noteString: String? = nil
    var amount: Double? = nil
    var date: Date? = nil
}

// MARK: - Safe model helpers (string-backed)

fileprivate extension ExpenseEntry {
    var categoryString: String {
        if let s: String = Mirror.get(self, "category"), !s.trimmed.isEmpty { return s.trimmed }
        if let rep = Mirror.get(self, "category") as (any RawRepresentable)? {
            let v = String(describing: rep.rawValue)
            if !v.trimmed.isEmpty { return v.trimmed }
        }
        return ""
    }

    /// Notes helper updated to look for `notes` (plural) first, then `note` as a fallback.
    var noteString: String {
        if let s: String = Mirror.get(self, "notes"), !s.trimmed.isEmpty { return s.trimmed }
        if let s: String = Mirror.get(self, "note"), !s.trimmed.isEmpty { return s.trimmed }
        return ""
    }

    var titleString: String {
        for key in ["merchant", "title", "vendor", "name"] {
            if let v: String = Mirror.get(self, key), !v.trimmed.isEmpty { return v.trimmed }
        }
        return ""
    }
}

// MARK: - Tiny reflection helpers

fileprivate extension Mirror {
    static func get<T>(_ value: Any, _ label: String) -> T? {
        for child in Mirror(reflecting: value).children {
            if child.label?.lowercased() == label.lowercased() {
                return child.value as? T
            }
        }
        return nil
    }
}

fileprivate extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Quick edit UI

fileprivate struct QuickEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initial: DisplayExpense
    let categories: [String]
    var onSave: (DisplayOverride) -> Void

    @State private var title: String
    @State private var category: String
    @State private var amount: Double
    @State private var date: Date
    @State private var note: String

    init(initial: DisplayExpense, categories: [String], onSave: @escaping (DisplayOverride) -> Void) {
        self.initial = initial
        self.categories = categories
        self.onSave = onSave
        _title = State(initialValue: initial.titleString)
        _category = State(initialValue: initial.categoryString)
        _amount = State(initialValue: initial.amount)
        _date = State(initialValue: initial.date)
        _note = State(initialValue: initial.noteString)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Title / Merchant", text: $title)
                    HStack {
                        Text("Category")
                        Spacer()
                        Menu(category.isEmpty ? "Select…" : category) {
                            ForEach(categories, id: \.self) { c in
                                Button(c) { category = c }
                            }
                        }
                    }
                    TextField("Or type a category", text: $category)
                        .textInputAutocapitalization(.words)
                }
                Section("Amount & Date") {
                    TextField("Amount", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Note") {
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("Edit Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(DisplayOverride(
                            titleString: title.trimmed,
                            categoryString: category.trimmed,
                            noteString: note.trimmed,
                            amount: amount,
                            date: date
                        ))
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Move category UI

fileprivate struct MoveCategorySheet: View {
    @Environment(\.dismiss) private var dismiss

    let current: String
    let categories: [String]
    var onPick: (String) -> Void

    @State private var newCategory: String = ""

    var body: some View {
        NavigationStack {
            List {
                if !categories.isEmpty {
                    Section("Pick a Category") {
                        ForEach(categories, id: \.self) { c in
                            Button {
                                onPick(c)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(c)
                                    Spacer()
                                    if c == current { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                }
                Section("New Category") {
                    TextField("Type a new category", text: $newCategory)
                        .textInputAutocapitalization(.words)
                    Button {
                        let picked = newCategory.trimmed
                        guard !picked.isEmpty else { return }
                        onPick(picked)
                        dismiss()
                    } label: {
                        Label(
                            "Move to “\(newCategory.trimmed.isEmpty ? "…" : newCategory.trimmed)”",
                            systemImage: "plus"
                        )
                    }
                    .disabled(newCategory.trimmed.isEmpty)
                }
            }
            .navigationTitle("Move to Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Local Glass Styling (accent-aware, conflict-safe)

fileprivate struct AsGlassRow: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var appearance: AppAppearance

    func body(content: Content) -> some View {
        let accent = appearance.accentColor

        return content
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(scheme == .dark ? 0.04 : 0.16),
                        accent.opacity(scheme == .dark ? 0.14 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        Color.white.opacity(scheme == .dark ? 0.34 : 0.20),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: .black.opacity(scheme == .dark ? 0.40 : 0.14),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}

fileprivate extension View {
    func asGlassRow() -> some View { modifier(AsGlassRow()) }
}
