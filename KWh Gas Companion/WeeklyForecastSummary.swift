import Foundation

struct WeeklyForecastSummary: Hashable, Sendable {
    let forecastCost: Double
    let forecastKWh: Double
    let currencyCode: String
    let confidenceText: String?
    let modelSummary: String?
    let reinforcementSummary: String?

    static func build(from entries: [ExpenseEntry]) -> WeeklyForecastSummary {
        let currency = Locale.current.currency?.identifier ?? "USD"
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -28, to: end) ?? end

        let recent = entries
            .filter { $0.date >= start && $0.date <= end }
            .filter { ($0.energyAddedKWh ?? 0) > 0 }
            .sorted { $0.date < $1.date }

        guard !recent.isEmpty else {
            return WeeklyForecastSummary(
                forecastCost: 0,
                forecastKWh: 0,
                currencyCode: currency,
                confidenceText: "Not enough recent data to forecast.",
                modelSummary: nil,
                reinforcementSummary: nil
            )
        }

        let observations = recent.enumerated().map { index, entry in
            ChargingForecastObservation(
                index: index,
                weekday: calendar.component(.weekday, from: entry.date),
                isWeekend: calendar.isDateInWeekend(entry.date),
                isHome: (entry.location ?? "").localizedCaseInsensitiveContains("home"),
                cost: entry.amount,
                energyKWh: entry.energyAddedKWh ?? 0,
                ratePerKWh: entry.costPerKWh ?? 0
            )
        }

        guard observations.count >= 3,
              let neural = TinyChargingForecaster.forecast(from: observations) else {
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
                confidenceText: "\(confidence) based on recent weekly history.",
                modelSummary: "Neural net needs at least 3 usable sessions.",
                reinforcementSummary: "RL stage waiting for baseline."
            )
        }

        let confidence = neural.costRMSE <= 2.5 ? "High confidence" : neural.costRMSE <= 6.0 ? "Medium confidence" : "Low confidence"

        return WeeklyForecastSummary(
            forecastCost: neural.predictedCost,
            forecastKWh: neural.predictedEnergyKWh,
            currencyCode: currency,
            confidenceText: "\(confidence) from on-device neural forecast with RL fine-tuning.",
            modelSummary: neural.summary,
            reinforcementSummary: neural.reinforcementSummary
        )
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
        return sqrt(variance)
    }
}

private struct ChargingForecastObservation: Sendable, Hashable {
    let index: Int
    let weekday: Int
    let isWeekend: Bool
    let isHome: Bool
    let cost: Double
    let energyKWh: Double
    let ratePerKWh: Double
}

private struct TinyChargingForecast: Sendable, Hashable {
    let predictedCost: Double
    let predictedEnergyKWh: Double
    let costRMSE: Double
    let rateRMSE: Double
    let reinforcementReward: Double
    let reinforcementSummary: String
    let summary: String
}

private enum TinyChargingForecaster {
    static func forecast(from observations: [ChargingForecastObservation]) -> TinyChargingForecast? {
        guard observations.count >= 3 else { return nil }

        let energyValues = observations.map(\.energyKWh)
        let costValues = observations.map(\.cost)
        let rateValues = observations.map(\.ratePerKWh)

        let energyStats = NormalizationStats(values: energyValues)
        let costStats = NormalizationStats(values: costValues)
        let rateStats = NormalizationStats(values: rateValues)
        let maxIndex = max(1.0, Double(observations.count - 1))

        let rows = observations.map { observation in
            TrainingRow(
                features: [
                    Double(observation.index) / maxIndex,
                    Double(observation.weekday) / 7.0,
                    observation.isWeekend ? 1.0 : 0.0,
                    observation.isHome ? 1.0 : 0.0,
                    observation.energyKWh / max(1.0, energyStats.mean + energyStats.stdDev),
                    observation.ratePerKWh / max(0.1, rateStats.mean + rateStats.stdDev)
                ],
                energyTarget: energyStats.normalize(observation.energyKWh),
                costTarget: costStats.normalize(observation.cost),
                rateTarget: rateStats.normalize(observation.ratePerKWh)
            )
        }

        let energyModel = TinyDenseRegressor(inputSize: rows[0].features.count, seed: 11)
        let costModel = TinyDenseRegressor(inputSize: rows[0].features.count, seed: 23)
        let rateModel = TinyDenseRegressor(inputSize: rows[0].features.count, seed: 37)

        energyModel.fit(samples: rows.map { ($0.features, $0.energyTarget) })
        costModel.fit(samples: rows.map { ($0.features, $0.costTarget) })
        rateModel.fit(samples: rows.map { ($0.features, $0.rateTarget) })

        let reinforcementReward = [
            energyModel.reinforce(samples: rows.map { ($0.features, $0.energyTarget) }),
            costModel.reinforce(samples: rows.map { ($0.features, $0.costTarget) }),
            rateModel.reinforce(samples: rows.map { ($0.features, $0.rateTarget) })
        ].reduce(0, +) / 3.0

        let costRMSE = rmse(
            rows.map { row in
                costStats.denormalize(costModel.predict(features: row.features)) - costStats.denormalize(row.costTarget)
            }
        )
        let rateRMSE = rmse(
            rows.map { row in
                rateStats.denormalize(rateModel.predict(features: row.features)) - rateStats.denormalize(row.rateTarget)
            }
        )

        guard let last = observations.last else { return nil }
        let nextFeatures = [
            Double(observations.count) / maxIndex,
            Double(last.weekday) / 7.0,
            last.isWeekend ? 1.0 : 0.0,
            last.isHome ? 1.0 : 0.0,
            last.energyKWh / max(1.0, energyStats.mean + energyStats.stdDev),
            last.ratePerKWh / max(0.1, rateStats.mean + rateStats.stdDev)
        ]

        let predictedCost = max(0, costStats.denormalize(costModel.predict(features: nextFeatures)))
        let predictedEnergy = max(0, energyStats.denormalize(energyModel.predict(features: nextFeatures)))

        let fitLabel: String
        switch costRMSE {
        case ..<2.5: fitLabel = "Tight fit"
        case ..<6.0: fitLabel = "Usable fit"
        default: fitLabel = "Early fit"
        }

        let reinforcementSummary = reinforcementStageLabel(for: reinforcementReward)
        let summary = "\(fitLabel) from \(observations.count) sessions. RMSE \(String(format: "$%.2f", costRMSE)) cost and \(String(format: "%.3f", rateRMSE))/kWh rate. \(reinforcementSummary)."
        return TinyChargingForecast(
            predictedCost: predictedCost,
            predictedEnergyKWh: predictedEnergy,
            costRMSE: costRMSE,
            rateRMSE: rateRMSE,
            reinforcementReward: reinforcementReward,
            reinforcementSummary: reinforcementSummary,
            summary: summary
        )
    }

    private static func rmse(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let squares = values.reduce(0.0) { $0 + ($1 * $1) }
        return sqrt(squares / Double(values.count))
    }

    private static func reinforcementStageLabel(for reward: Double) -> String {
        let rewardBand: String
        switch reward {
        case 0.86...:
            rewardBand = "RL aligned"
        case 0.72...:
            rewardBand = "RL adapting"
        default:
            rewardBand = "RL exploring"
        }
        return "\(rewardBand) • \(String(format: "%.2f", min(1.0, max(0.0, reward)))) reward"
    }
}

private struct TrainingRow {
    let features: [Double]
    let energyTarget: Double
    let costTarget: Double
    let rateTarget: Double
}

private struct NormalizationStats {
    let mean: Double
    let stdDev: Double

    init(values: [Double]) {
        let localMean = values.reduce(0, +) / Double(max(1, values.count))
        mean = localMean
        let variance = values.reduce(0.0) { $0 + pow($1 - localMean, 2) } / Double(max(1, values.count))
        stdDev = max(0.0001, sqrt(variance))
    }

    func normalize(_ value: Double) -> Double {
        (value - mean) / stdDev
    }

    func denormalize(_ value: Double) -> Double {
        (value * stdDev) + mean
    }
}

private final class TinyDenseRegressor {
    private let learningRate: Double = 0.035
    private let epochs: Int = 900
    private let reinforcementEpochs: Int = 180
    private let policyActions: [Double] = [-0.12, -0.06, -0.025, 0, 0.025, 0.06, 0.12]
    private var hiddenWeights: [[Double]]
    private var hiddenBias: [Double]
    private var outputWeights: [Double]
    private var outputBias: Double

    init(inputSize: Int, hiddenSize: Int = 8, seed: UInt64) {
        var generator = SeededGenerator(state: seed)
        hiddenWeights = (0..<hiddenSize).map { _ in
            (0..<inputSize).map { _ in Double.random(in: -0.175...0.175, using: &generator) }
        }
        hiddenBias = Array(repeating: 0, count: hiddenSize)
        outputWeights = (0..<hiddenSize).map { _ in Double.random(in: -0.175...0.175, using: &generator) }
        outputBias = 0
    }

    func fit(samples: [([Double], Double)]) {
        guard !samples.isEmpty else { return }
        for _ in 0..<epochs {
            for (features, target) in samples {
                trainStep(features: features, target: target)
            }
        }
    }

    func reinforce(samples: [([Double], Double)]) -> Double {
        guard !samples.isEmpty else { return 0 }

        var rewardTotal = 0.0
        var rewardCount = 0
        for _ in 0..<reinforcementEpochs {
            for (features, target) in samples {
                let prediction = predict(features: features)
                let action = policyActions.max { lhs, rhs in
                    reward(adjustedPrediction: prediction + lhs, target: target, action: lhs)
                        < reward(adjustedPrediction: prediction + rhs, target: target, action: rhs)
                } ?? 0
                rewardTotal += reward(adjustedPrediction: prediction + action, target: target, action: action)
                rewardCount += 1
                trainStep(features: features, target: prediction + action)
            }
        }

        return rewardCount == 0 ? 0 : rewardTotal / Double(rewardCount)
    }

    func predict(features: [Double]) -> Double {
        let hidden = hiddenActivation(features: features)
        return zip(outputWeights, hidden).reduce(outputBias) { $0 + ($1.0 * $1.1) }
    }

    private func trainStep(features: [Double], target: Double) {
        let hiddenLinear = hiddenLinear(features: features)
        let hidden = hiddenLinear.map(tanh)
        let prediction = zip(outputWeights, hidden).reduce(outputBias) { $0 + ($1.0 * $1.1) }
        let error = prediction - target

        let previousOutputWeights = outputWeights
        for index in outputWeights.indices {
            outputWeights[index] -= learningRate * error * hidden[index]
        }
        outputBias -= learningRate * error

        for hiddenIndex in hiddenWeights.indices {
            let derivative = 1 - (hidden[hiddenIndex] * hidden[hiddenIndex])
            let delta = error * previousOutputWeights[hiddenIndex] * derivative
            for featureIndex in features.indices {
                hiddenWeights[hiddenIndex][featureIndex] -= learningRate * delta * features[featureIndex]
            }
            hiddenBias[hiddenIndex] -= learningRate * delta
        }
    }

    private func hiddenActivation(features: [Double]) -> [Double] {
        hiddenLinear(features: features).map(tanh)
    }

    private func hiddenLinear(features: [Double]) -> [Double] {
        hiddenWeights.indices.map { hiddenIndex in
            zip(hiddenWeights[hiddenIndex], features).reduce(hiddenBias[hiddenIndex]) { $0 + ($1.0 * $1.1) }
        }
    }

    private func reward(adjustedPrediction: Double, target: Double, action: Double) -> Double {
        let errorPenalty = abs(adjustedPrediction - target)
        let movementPenalty = abs(action) * 0.15
        return 1.0 - errorPenalty - movementPenalty
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = 2862933555777941757 &* state &+ 3037000493
        return state
    }
}
