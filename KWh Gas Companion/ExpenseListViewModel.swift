//
//  ExpenseListViewModel.swift
//  My KWh Companion
//  Regenerated hotfix+polish (2025-10-29 → +source-aware 2025-12-10)
//
//  Improvements:
//  - Debounced/merged refresh pipeline to avoid redundant recomputes while typing
//  - Inclusive dateTo (end-of-day) handling
//  - CSV export uses UTC + invariant number formatting and robust CSV escaping
//  - Safer mirror lookups (case-insensitive keys) with graceful fallbacks
//  - Source-aware filtering + source column in CSV export
//    (implemented via reflection so it works even if ChargingDetails
//     does not yet declare a `source` property)
//

import Foundation
import Combine

@MainActor
final class ExpenseListViewModel: ObservableObject {

    // MARK: - Types

    enum SortMode: String, CaseIterable, Codable {
        case dateDesc, dateAsc
        case amountDesc, amountAsc
        case odometerDesc, odometerAsc
    }

    /// Filter by charging data source (or show all).
    enum SourceFilter: String, CaseIterable, Codable, Identifiable {
        case all
        case teslaOfficial
        case teslaFi
        case manual
        case other

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all:           return "All Sources"
            case .teslaOfficial: return "Tesla"
            case .teslaFi:       return "Imported"
            case .manual:        return "Manual"
            case .other:         return "Other"
            }
        }

        /// Map to ChargingDataSource when applicable.
        var matchingSource: ChargingDataSource? {
            switch self {
            case .all:           return nil
            case .teslaOfficial: return .teslaOfficial
            case .teslaFi:       return .teslaFi
            case .manual:        return .manual
            case .other:         return .other
            }
        }
    }

    struct MonthSection: Identifiable, Hashable {
        let id: String          // "YYYY-MM"
        let monthStart: Date
        let entries: [ExpenseEntry]
        let totalAmount: Double
        let count: Int

        init(calendar: Calendar, entries: [ExpenseEntry]) {
            guard let first = entries.first else {
                self.id = "0000-00"
                self.monthStart = .distantPast
                self.entries = []
                self.totalAmount = 0
                self.count = 0
                return
            }
            let comps = calendar.dateComponents([.year, .month], from: first.date)
            self.monthStart = calendar.date(from: comps) ?? first.date
            let y = comps.year ?? 0
            let m = comps.month ?? 0
            self.id = String(format: "%04d-%02d", y, m)
            self.entries = entries
            self.totalAmount = entries.reduce(0) { $0 + $1.amount }
            self.count = entries.count
        }
    }

    // MARK: - Inputs

    private let store: EntriesStore

    @Published var searchText: String = ""
    @Published var dateFrom: Date? = nil
    @Published var dateTo: Date? = nil
    @Published var showOnlyEnergy: Bool = false
    @Published var sortMode: SortMode = .dateDesc

    /// Filter by ChargingDataSource (All / Tesla / Imported / Manual / Other)
    @Published var sourceFilter: SourceFilter = .all

    // MARK: - Outputs

    @Published private(set) var filtered: [ExpenseEntry] = []
    @Published private(set) var sections: [MonthSection] = []
    @Published private(set) var totalCount: Int = 0
    @Published private(set) var totalAmount: Double = 0

    // MARK: - Internals

    private var cancellables = Set<AnyCancellable>()
    private let calendar = Calendar(identifier: .gregorian)

    // MARK: - Formatters

    private static let exportDateFormatter: ISO8601DateFormatter = {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withFullDate]     // YYYY-MM-DD
        df.timeZone = TimeZone(secondsFromGMT: 0) // UTC for stability
        return df
    }()
    private static let titleDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeZone = TimeZone.current
        df.locale = Locale.current
        return df
    }()
    private static let invLocale = Locale(identifier: "en_US_POSIX")

    // MARK: - Init

    init(store: EntriesStore) {
        self.store = store

        // Base combine of the original 4 inputs
        let baseInputs = Publishers.CombineLatest4(
            $searchText.removeDuplicates().debounce(for: .milliseconds(250), scheduler: DispatchQueue.main),
            $showOnlyEnergy.removeDuplicates(),
            $sortMode.removeDuplicates(),
            Publishers.CombineLatest($dateFrom.removeDuplicates(), $dateTo.removeDuplicates())
        )

        // Layer sourceFilter into the pipeline as well
        baseInputs
            .combineLatest($sourceFilter.removeDuplicates())
            .combineLatest(store.$entries.map { $0 }) // when entries change
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        // Initial compute
        refresh()
    }

    // MARK: - Public API

    func clearFilters() {
        searchText = ""
        dateFrom = nil
        dateTo = nil
        showOnlyEnergy = false
        sortMode = .dateDesc
        sourceFilter = .all
        // refresh will be triggered by publishers
    }

    func setDateRange(from: Date?, to: Date?) { dateFrom = from; dateTo = to }
    func toggleEnergyOnly() { showOnlyEnergy.toggle() }
    func setSort(_ mode: SortMode) { sortMode = mode }

    /// Set the current source filter
    func setSourceFilter(_ filter: SourceFilter) { sourceFilter = filter }

    // CRUD passthroughs
    func add(_ entry: ExpenseEntry) { store.add(entry) }
    func update(_ entry: ExpenseEntry) { store.update(entry) }
    func remove(_ entry: ExpenseEntry) { store.remove(entry) }
    func remove(ids: [UUID]) { ids.forEach { store.remove(id: $0) } }
    func clearAll() { store.clearAll() }

    // CSV export of the current filtered set
    func exportFilteredAsCSV(filename: String = "expenses_export.csv") throws -> URL {
        // Add "source" column at the end
        let header = "id,date,amount,odometer,isEnergy,category,location,notes,source"

        func esc(_ s: String) -> String {
            // RFC 4180-style escaping for commas, quotes, newlines
            if s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") {
                return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
            }
            return s
        }

        // Invariant number formatting (decimal point is a dot)
        func amt(_ v: Double) -> String {
            let nf = NumberFormatter()
            nf.locale = Self.invLocale
            nf.minimumFractionDigits = 2
            nf.maximumFractionDigits = 2
            nf.numberStyle = .decimal
            return nf.string(from: NSNumber(value: v)) ?? "0.00"
        }
        func odo(_ v: Double?) -> String {
            guard let v = v else { return "" }
            let nf = NumberFormatter()
            nf.locale = Self.invLocale
            nf.minimumFractionDigits = 1
            nf.maximumFractionDigits = 1
            nf.numberStyle = .decimal
            return nf.string(from: NSNumber(value: v)) ?? ""
        }

        let rows = filtered.map { e -> String in
            let id = e.id.uuidString
            let date = Self.exportDateFormatter.string(from: e.date)
            let amount = amt(e.amount)
            let od = odo(e.odometer)
            let isEnergy = e.isEnergy ? "true" : "false"
            let category = esc(e._category)
            let location = esc(e._location)
            let notes = esc(e._notes)
            let sourceLabel = esc(e._sourceLabel.isEmpty ? "" : e._sourceLabel)
            return [id, date, amount, od, isEnergy, category, location, notes, sourceLabel]
                .joined(separator: ",")
        }

        let csv = ([header] + rows).joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try csv.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Core Compute

    private func refresh() {
        guard !store.entries.isEmpty else {
            filtered = []
            sections = []
            totalCount = 0
            totalAmount = 0
            return
        }

        var work = store.entries

        // Energy filter
        if showOnlyEnergy { work = work.filter { $0.isEnergy } }

        // Source filter (default == all, so no restriction)
        if let requiredSource = sourceFilter.matchingSource {
            work = work.filter { effectiveSource(for: $0) == requiredSource }
        }

        // Date range (inclusive for 'to' by pushing to end-of-day)
        if let from = dateFrom {
            work = work.filter { $0.date >= from }
        }
        if let to = dateTo {
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: to) ?? to
            work = work.filter { $0.date <= end }
        }

        // Search
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            work = work.filter { e in
                if e._titleString(lowerDateFormatter: Self.titleDateFormatter).contains(q) { return true }
                // invariant amount string search
                let amountStr = String(format: "%.2f", e.amount)
                if amountStr.contains(q) { return true }
                if let od = e.odometer, String(format: "%.1f", od).contains(q) { return true }
                if e._sourceLabel.lowercased().contains(q) { return true }   // search by source
                return false
            }
        }

        // Sort
        switch sortMode {
        case .dateDesc:     work.sort { $0.date > $1.date }
        case .dateAsc:      work.sort { $0.date < $1.date }
        case .amountDesc:   work.sort { $0.amount > $1.amount }
        case .amountAsc:    work.sort { $0.amount < $1.amount }
        case .odometerDesc: work.sort { ($0.odometer ?? -Double.infinity) > ($1.odometer ?? -Double.infinity) }
        case .odometerAsc:  work.sort { ($0.odometer ?? Double.infinity) < ($1.odometer ?? Double.infinity) }
        }

        // Publish
        filtered = work
        totalCount = work.count
        totalAmount = work.reduce(0.0) { $0 + $1.amount }

        sections = Self.buildMonthSections(from: work, calendar: calendar)
    }

    /// Uses reflection to find a `source` property on `charging` if present.
    /// Falls back to `.manual` when not found.
    private func effectiveSource(for entry: ExpenseEntry) -> ChargingDataSource {
        entry._sourceRaw ?? .manual
    }

    private static func buildMonthSections(from entries: [ExpenseEntry], calendar: Calendar) -> [MonthSection] {
        let grouped = Dictionary(grouping: entries) { (e: ExpenseEntry) -> String in
            let c = calendar.dateComponents([.year, .month], from: e.date)
            return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
        }
        // Sort keys lexicographically (YYYY-MM) which matches chronological order
        return grouped.keys.sorted(by: >).compactMap { key in
            guard var bucket = grouped[key] else { return nil }
            bucket.sort { $0.date > $1.date }
            return MonthSection(calendar: calendar, entries: bucket)
        }
    }
}

// MARK: - ExpenseEntry conveniences (non-invasive)

private extension ExpenseEntry {
    var _location: String { mirrorLookup(["location"]) ?? "" }
    var _category: String { mirrorLookup(["category", "group", "type"]) ?? "" }
    var _notes: String { mirrorLookup(["notes", "memo", "description", "desc"]) ?? "" }

    /// Raw ChargingDataSource if it exists on `charging.source` (via reflection).
    /// Returns nil if the property does not exist or has a different type.
    var _sourceRaw: ChargingDataSource? {
        guard let charging = charging else { return nil }
        let mirror = Mirror(reflecting: charging)
        if let child = mirror.children.first(where: { ($0.label ?? "").lowercased() == "source" }),
           let value = child.value as? ChargingDataSource {
            return value
        }
        return nil
    }

    /// Human-readable source label for UI/CSV/search.
    var _sourceLabel: String {
        guard let src = _sourceRaw else { return "" }
        return src.shortLabel
    }

    func _titleString(lowerDateFormatter df: DateFormatter) -> String {
        let s: String
        if !_notes.isEmpty { s = _notes }
        else if !_location.isEmpty { s = _location }
        else if !_category.isEmpty { s = _category }
        else { s = "\(df.string(from: date)) – \(String(format: "$%.2f", amount))" }
        return s.lowercased()
    }

    /// Case-insensitive mirror lookup across candidate keys.
    func mirrorLookup(_ names: [String]) -> String? {
        let children = Array(Mirror(reflecting: self).children)
        for name in names {
            if let match = children.first(where: { ($0.label ?? "").lowercased() == name.lowercased() }) {
                return match.value as? String
            }
        }
        return nil
    }
}
