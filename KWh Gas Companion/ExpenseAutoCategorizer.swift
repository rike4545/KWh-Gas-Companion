import Foundation

/// Lightweight expense auto-categorizer with learning memory.
/// Uses UserDefaults to persist merchant/location -> category mappings.
struct ExpenseAutoCategorizer {
    static let shared = ExpenseAutoCategorizer()

    private let memoryKey = "expense.autoCategorize.memory.v1"

    // MARK: - Public API

    func suggestCategory(for entry: ExpenseEntry) -> ExpenseCategory? {
        let key = normalizedKey(for: entry)
        if let remembered = memory()[key], let cat = ExpenseCategory(rawValue: remembered) {
            return cat
        }
        return heuristicCategory(for: entry)
    }

    func remember(entry: ExpenseEntry, category: ExpenseCategory) {
        let key = normalizedKey(for: entry)
        guard !key.isEmpty else { return }
        var mem = memory()
        mem[key] = category.rawValue
        saveMemory(mem)
    }

    // MARK: - Heuristics

    private func heuristicCategory(for entry: ExpenseEntry) -> ExpenseCategory? {
        let text = [
            entry.charging?.siteName,
            entry.location,
            entry.notes,
            entry.vehicleName
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()

        if text.contains("supercharg") || text.contains("tesla") { return .fastDCFC }
        if text.contains("chargepoint") || text.contains("evgo") || text.contains("electrify") { return .publicCharging }
        if text.contains("home") || text.contains("garage") { return .homeCharging }
        if text.contains("toll") || text.contains("parking") { return .parkingTolling }
        if text.contains("insurance") || text.contains("registration") { return .insuranceRegistration }
        if text.contains("lease") { return .lease }
        if text.contains("loan") || text.contains("finance") || text.contains("payment") { return .autoPayment }
        if text.contains("maintenance") || text.contains("service") { return .maintenance }
        if text.contains("accessory") || text.contains("part") { return .accessoriesConsumables }
        if text.contains("subscription") || text.contains("software") { return .softwareSubscriptions }

        if entry.isEnergyEffective { return .energy }
        return nil
    }

    // MARK: - Memory

    private func normalizedKey(for entry: ExpenseEntry) -> String {
        let parts = [
            entry.charging?.siteName,
            entry.location,
            entry.notes
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        let raw = parts.joined(separator: " ").lowercased()
        return raw
            .replacingOccurrences(of: #"[^\w\s]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func memory() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: memoryKey) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    private func saveMemory(_ map: [String: String]) {
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: memoryKey)
        }
    }
}
