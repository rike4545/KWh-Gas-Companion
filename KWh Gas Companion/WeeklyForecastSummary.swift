import Foundation

struct WeeklyForecastSummary: Hashable, Sendable {
    let forecastCost: Double
    let forecastKWh: Double
    let currencyCode: String
    let confidenceText: String?

    static func build(from entries: [ExpenseEntry]) -> WeeklyForecastSummary {
        let currency = Locale.current.currency?.identifier ?? "USD"
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -28, to: end) ?? end

        let recent = entries.filter { $0.date >= start && $0.date <= end }
        guard !recent.isEmpty else {
            return WeeklyForecastSummary(
                forecastCost: 0,
                forecastKWh: 0,
                currencyCode: currency,
                confidenceText: "Not enough recent data to forecast."
            )
        }

        let grouped = Dictionary(grouping: recent) { entry in
            calendar.dateInterval(of: .weekOfYear, for: entry.date)?.start ?? entry.date
        }

        let weeklyCosts = grouped.values.map { $0.reduce(0) { $0 + $1.amount } }
        let weeklyKWh = grouped.values.map { $0.compactMap { $0.energyAddedKWh }.reduce(0, +) }

        let avgCost = weeklyCosts.reduce(0, +) / Double(max(1, weeklyCosts.count))
        let avgKWh = weeklyKWh.reduce(0, +) / Double(max(1, weeklyKWh.count))

        let variability = standardDeviation(weeklyCosts) / max(1, avgCost)
        let confidence = variability < 0.25 ? "High confidence" : variability < 0.45 ? "Medium confidence" : "Low confidence"

        return WeeklyForecastSummary(
            forecastCost: avgCost,
            forecastKWh: avgKWh,
            currencyCode: currency,
            confidenceText: "\(confidence) based on last 4 weeks."
        )
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
        return sqrt(variance)
    }
}
