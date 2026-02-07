import Foundation

struct DataQualityDuplicate: Identifiable, Hashable {
    let id: String
    let entry: ExpenseEntry
    let session: TeslaFiSession
    let kwhDelta: Double
    let minutesApart: Double
}

struct DataQualitySummary: Hashable {
    let costSpikes: [ExpenseEntry]
    let idleFeeRisk: [ExpenseEntry]
    let outliers: [ExpenseEntry]
    let duplicates: [DataQualityDuplicate]
    let consistencyScore: Int
    let consistencyNote: String
}

enum DataQualityAnalyzer {
    static func summarize(entries: [ExpenseEntry], sessions: [TeslaFiSession]) -> DataQualitySummary {
        let energy = entries.filter { $0.isEnergyEffective }

        let costSpikes = detectCostSpikes(energy)
        let idleRisk = detectIdleFeeRisk(energy)
        let outliers = detectOutliers(energy)
        let duplicates = detectDuplicates(energy, sessions)
        let (score, note) = consistencyScore(for: energy)

        return DataQualitySummary(
            costSpikes: costSpikes,
            idleFeeRisk: idleRisk,
            outliers: outliers,
            duplicates: duplicates,
            consistencyScore: score,
            consistencyNote: note
        )
    }

    private static func detectCostSpikes(_ entries: [ExpenseEntry]) -> [ExpenseEntry] {
        let costs = entries.compactMap { $0.costPerKWh }.filter { $0 > 0 }
        guard !costs.isEmpty else { return [] }
        let avg = costs.reduce(0, +) / Double(costs.count)
        let threshold = max(avg * 1.6, 0.45)
        return entries.filter { ($0.costPerKWh ?? 0) >= threshold }
            .sorted { ($0.costPerKWh ?? 0) > ($1.costPerKWh ?? 0) }
    }

    private static func detectIdleFeeRisk(_ entries: [ExpenseEntry]) -> [ExpenseEntry] {
        return entries.filter {
            ($0.charging?.isSupercharger == true || ($0.chargeType ?? "").lowercased().contains("super"))
            && (($0.charging?.durationMinutes ?? $0.chargeDurationMinutes ?? 0) >= 45)
        }
        .sorted { ($0.charging?.durationMinutes ?? $0.chargeDurationMinutes ?? 0) >
                  ($1.charging?.durationMinutes ?? $1.chargeDurationMinutes ?? 0) }
    }

    private static func detectOutliers(_ entries: [ExpenseEntry]) -> [ExpenseEntry] {
        return entries.filter { entry in
            let kwh = entry.energyAddedKWh ?? 0
            let cpk = entry.costPerKWh ?? 0
            return kwh > 180 || cpk > 1.25 || entry.amount > 200
        }
        .sorted { $0.date > $1.date }
    }

    private static func detectDuplicates(_ entries: [ExpenseEntry], _ sessions: [TeslaFiSession]) -> [DataQualityDuplicate] {
        guard !entries.isEmpty, !sessions.isEmpty else { return [] }
        var out: [DataQualityDuplicate] = []
        for entry in entries {
            guard let kwh = entry.energyAddedKWh, kwh > 0 else { continue }
            let date = entry.date
            let match = sessions.first { s in
                let deltaMin = abs(s.startDate.timeIntervalSince(date)) / 60.0
                let kwhDelta = abs((s.energyAddedKWh) - kwh)
                return deltaMin <= 90 && kwhDelta <= 1.5
            }
            if let s = match {
                let deltaMin = abs(s.startDate.timeIntervalSince(date)) / 60.0
                let kwhDelta = abs(s.energyAddedKWh - kwh)
                out.append(
                    DataQualityDuplicate(
                        id: "\(entry.id.uuidString)-\(s.id.uuidString)",
                        entry: entry,
                        session: s,
                        kwhDelta: kwhDelta,
                        minutesApart: deltaMin
                    )
                )
            }
        }
        return out
    }

    private static func consistencyScore(for entries: [ExpenseEntry]) -> (Int, String) {
        let kwh = entries.compactMap { $0.energyAddedKWh }.filter { $0 > 0 }
        guard kwh.count >= 5 else { return (60, "Not enough data to score consistency.") }
        let mean = kwh.reduce(0, +) / Double(kwh.count)
        let variance = kwh.reduce(0) { $0 + pow($1 - mean, 2) } / Double(max(1, kwh.count - 1))
        let std = sqrt(variance)
        let cv = std / max(1, mean)

        if cv < 0.25 { return (88, "Very consistent session sizes. Great for predictable costs.") }
        if cv < 0.45 { return (72, "Moderate variation. Small tweaks could improve predictability.") }
        return (55, "High variation detected. Consider larger, fewer sessions.")
    }
}
