//
//  BudgetStore.swift
//  My KWh Companion
//
//  Simple monthly budgets for Energy & Non-Energy + top 5 category budgets.
//  SwiftUI-safe (no @Published writes from View.body); JSON persistence.
//

import Foundation

// MARK: - YearMonth (internal, used across the app)

struct YearMonth: Hashable, Comparable, Codable {
    let year: Int
    let month: Int // 1...12

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month], from: date)
        self.year = c.year ?? 0
        self.month = c.month ?? 1
    }

    static func from(_ date: Date, calendar: Calendar = .current) -> YearMonth {
        .init(date: date, calendar: calendar)
    }

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        lhs.year != rhs.year ? (lhs.year < rhs.year) : (lhs.month < rhs.month)
    }

    func startDate(calendar: Calendar = .current) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }

    func monthRange(_ calendar: Calendar = .current) -> ClosedRange<Date> {
        let start = startDate(calendar: calendar) ?? Date()
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? start
        return start...end
    }

    var keyString: String { String(format: "%04d-%02d", year, month) }

    init?(keyString: String) {
        let parts = keyString.split(separator: "-")
        guard parts.count == 2,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              (1...12).contains(m) else { return nil }
        self.init(year: y, month: m)
    }
}

// MARK: - Models

struct BudgetPlan: Codable, Hashable {
    var energyBudget: Double
    var nonEnergyBudget: Double
    /// Per-category budgets (up to 5).
    var categoryBudgets: [String: Double]
    var updatedAt: Date

    static let empty = BudgetPlan(
        energyBudget: 0,
        nonEnergyBudget: 0,
        categoryBudgets: [:],
        updatedAt: Date()
    )
}

// MARK: - File IO Actor (serializes disk access off the main thread)

actor FileIOActor {
    func read(from url: URL) -> Data? {
        do { return try Data(contentsOf: url) }
        catch { return nil }
    }

    func write(_ data: Data, to url: URL) {
        do { try data.write(to: url, options: .atomic) }
        catch { print("BudgetStore write error: \(error)") }
    }
}

// MARK: - Store

@MainActor
final class BudgetStore: ObservableObject {
    @Published private(set) var plans: [YearMonth: BudgetPlan] = [:] {
        didSet { scheduleSave() }
    }

    // Persistence
    private let fileURL: URL = BudgetStore.makeFileURL()

    // Save control
    private var suppressSaves = false
    private let io = FileIOActor()
    private var saveTask: Task<Void, Never>?

    // Encoders/decoders with stable date strategy
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.withoutEscapingSlashes]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private nonisolated static func makeFileURL(fileManager: FileManager = .default) -> URL {
        let baseDir =
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory

        if !fileManager.fileExists(atPath: baseDir.path) {
            try? fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true)
        }

        return baseDir.appendingPathComponent("budget.plans.json")
    }

    init() {
        load()
    }

    // MARK: - View-safe access

    /// Returns stored plan if present, else a suggested ephemeral plan (no write).
    func displayPlan(for ym: YearMonth, entries: [ExpenseEntry]) -> BudgetPlan {
        if let p = plans[ym] { return p }
        return suggestPlan(for: ym, from: entries)
    }

    /// Creates and stores a plan **only if missing**. Call from `.task` / `.onChange`.
    func createPlanIfMissing(for ym: YearMonth, entries: [ExpenseEntry]) {
        guard plans[ym] == nil else { return }
        plans[ym] = suggestPlan(for: ym, from: entries)
    }

    // MARK: - Totals (read-only)

    func totalEnergySpend(in ym: YearMonth, entries: [ExpenseEntry]) -> Double {
        let range = ym.monthRange()
        return entries
            .filter { range.contains($0.date) && $0.isEnergyEffective }
            .reduce(0) { $0 + $1.amount }
    }

    func totalNonEnergySpend(in ym: YearMonth, entries: [ExpenseEntry]) -> Double {
        let range = ym.monthRange()
        return entries
            .filter { range.contains($0.date) && !$0.isEnergyEffective }
            .reduce(0) { $0 + $1.amount }
    }

    func totalForCategory(in ym: YearMonth, category: String, entries: [ExpenseEntry]) -> Double {
        let range = ym.monthRange()
        return entries
            .filter { range.contains($0.date) && $0.category.caseInsensitiveCompare(category) == .orderedSame }
            .reduce(0) { $0 + $1.amount }
    }

    // MARK: - Mutations (call from settings/editor screens)

    func setEnergyBudget(for ym: YearMonth, to value: Double) {
        var p = plans[ym] ?? .empty
        p.energyBudget = max(0, value)
        p.updatedAt = Date()
        plans[ym] = p
    }

    func setNonEnergyBudget(for ym: YearMonth, to value: Double) {
        var p = plans[ym] ?? .empty
        p.nonEnergyBudget = max(0, value)
        p.updatedAt = Date()
        plans[ym] = p
    }

    func setCategoryBudget(for ym: YearMonth, category: String, to value: Double) {
        var p = plans[ym] ?? .empty
        var cats = p.categoryBudgets
        cats[category] = max(0, value)

        // Keep only top 5 by amount — explicit types for clarity.
        let sortedPairs: [(String, Double)] = cats
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { ($0.key, $0.value) }

        p.categoryBudgets = Dictionary(uniqueKeysWithValues: sortedPairs)
        p.updatedAt = Date()
        plans[ym] = p
    }

    func clearAllPlans() {
        plans.removeAll()
    }

    // MARK: - Suggestion logic (pure)

    /// Suggests a plan from the average of the previous 3 full months.
    private func suggestPlan(for ym: YearMonth, from entries: [ExpenseEntry]) -> BudgetPlan {
        let cal = Calendar.current

        // Build the 3 months *before* ym
        var sampleMonths: [YearMonth] = []
        if let base = ym.startDate(calendar: cal) {
            for i in 1...3 {
                let d = cal.date(byAdding: .month, value: -i, to: base) ?? base
                sampleMonths.append(YearMonth.from(d, calendar: cal))
            }
        }

        func averageMonthlySpend(where predicate: (ExpenseEntry) -> Bool) -> Double {
            guard !sampleMonths.isEmpty else { return 0 }
            let sums = sampleMonths.map { key -> Double in
                let range = key.monthRange(cal)
                return entries
                    .filter { predicate($0) && range.contains($0.date) }
                    .reduce(0) { $0 + $1.amount }
            }
            return sums.reduce(0, +) / Double(sampleMonths.count)
        }

        let energyAvg = averageMonthlySpend { $0.isEnergyEffective }
        let nonEnergyAvg = averageMonthlySpend { !$0.isEnergyEffective }

        // Top 5 categories by average monthly spend over the same window
        var catAverages: [String: Double] = [:]
        let categories = Set(entries.compactMap { $0.category.isEmpty ? nil : $0.category })
        for cat in categories {
            let v = averageMonthlySpend { $0.category.caseInsensitiveCompare(cat) == .orderedSame }
            if v > 0 { catAverages[cat] = v }
        }
        let topPairs: [(String, Double)] = catAverages
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { ($0.key, $0.value) }

        return BudgetPlan(
            energyBudget: energyAvg.roundedToCents(),
            nonEnergyBudget: nonEnergyAvg.roundedToCents(),
            categoryBudgets: Dictionary(uniqueKeysWithValues: topPairs.map { ($0.0, $0.1.roundedToCents()) }),
            updatedAt: Date()
        )
    }

    // MARK: - Persistence

    private func scheduleSave() {
        if suppressSaves { return }
        saveTask?.cancel()
        // Debounce a bit to coalesce multiple quick edits
        saveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(250))
            await self.saveNow()
        }
    }

    private func saveNow() async {
        // Convert to string-keyed dictionary
        let encodable: [String: BudgetPlan] = Dictionary(uniqueKeysWithValues:
            plans.map { ($0.key.keyString, $0.value) }
        )
        do {
            let data = try encoder.encode(encodable)
            await io.write(data, to: fileURL)
        } catch {
            print("BudgetStore encode error: \(error)")
        }
    }

    private func load() {
        suppressSaves = true
        // defer must live inside the Task body so it fires after the async
        // disk read completes, not immediately after Task creation.
        Task { @MainActor in
            defer { self.suppressSaves = false }
            if let data = await io.read(from: fileURL) {
                do {
                    let decoded = try decoder.decode([String: BudgetPlan].self, from: data)
                    var map: [YearMonth: BudgetPlan] = [:]
                    for (k, v) in decoded {
                        if let ym = YearMonth(keyString: k) { map[ym] = v }
                    }
                    self.plans = map
                } catch {
                    self.plans = [:]
                }
            } else {
                self.plans = [:]
            }
        }
    }
}

// MARK: - Small numeric helper
private extension Double {
    func roundedToCents() -> Double { (self * 100).rounded() / 100 }
}
