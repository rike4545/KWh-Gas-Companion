import Foundation

struct SavingsScoreSummary: Hashable, Sendable {
    let totalScore: Int
    let rateScore: Int
    let fastChargeScore: Int
    let consistencyScore: Int
    let summary: String
    let habitNotes: [String]

    static func compute(from entries: [ExpenseEntry]) -> SavingsScoreSummary {
        let recent = entries.sorted { $0.date > $1.date }.prefix(30)
        let currency = Locale.current.currency?.identifier ?? "USD"

        let prices = recent.compactMap { $0.costPerKWh }.filter { $0 > 0 }
        let avgPrice = prices.isEmpty ? nil : prices.reduce(0, +) / Double(prices.count)

        let rateScore: Int
        if let avg = avgPrice {
            switch avg {
            case ..<0.20: rateScore = 90
            case ..<0.28: rateScore = 80
            case ..<0.36: rateScore = 70
            case ..<0.45: rateScore = 55
            default: rateScore = 40
            }
        } else {
            rateScore = 60
        }

        let fastSessions = recent.filter { $0.charging?.isSupercharger == true }
        let fastShare = recent.isEmpty ? 0 : Double(fastSessions.count) / Double(recent.count)
        let fastChargeScore: Int
        switch fastShare {
        case ..<0.2: fastChargeScore = 90
        case ..<0.4: fastChargeScore = 75
        case ..<0.6: fastChargeScore = 60
        default: fastChargeScore = 45
        }

        let kwh = recent.compactMap { $0.energyAddedKWh }.filter { $0 > 0 }
        let avgKwh = kwh.isEmpty ? nil : kwh.reduce(0, +) / Double(kwh.count)
        let topoffCount = kwh.filter { $0 < 6 }.count
        let consistencyScore: Int
        if let avgKwh, avgKwh >= 18 && topoffCount < 3 {
            consistencyScore = 85
        } else if topoffCount > 6 {
            consistencyScore = 50
        } else {
            consistencyScore = 65
        }

        let total = Int(Double(rateScore + fastChargeScore + consistencyScore) / 3.0)

        var habits: [String] = []
        if fastShare > 0.5 {
            habits.append("High fast‑charging share (\(Int(fastShare * 100))%). Consider shifting more sessions to off‑peak home charging.")
        }
        if topoffCount >= 4 {
            habits.append("Frequent small top‑offs detected. Consolidating sessions can reduce overhead and time.")
        }
        if let avg = avgPrice, avg > 0.40 {
            habits.append("Average cost is \(avg.formatted(.currency(code: currency))). Explore off‑peak windows or alternate chargers.")
        }

        let summary: String
        if total >= 80 {
            summary = "Excellent cost control and charging habits."
        } else if total >= 65 {
            summary = "Solid performance with a few opportunities to save more."
        } else {
            summary = "We found several ways to reduce costs quickly."
        }

        return SavingsScoreSummary(
            totalScore: total,
            rateScore: rateScore,
            fastChargeScore: fastChargeScore,
            consistencyScore: consistencyScore,
            summary: summary,
            habitNotes: habits
        )
    }
}
