//
//  SuperchargerPredictionEngineError.swift
//  KWh Gas Companion
//
//  NOTE: This file intentionally contains BOTH:
//  - SuperchargerPredictionEngineError
//  - SuperchargerPredictionEngine
//
//  Keep ONLY ONE engine file in the build target.
//

import Foundation
import CoreML

// MARK: - Errors

public enum SuperchargerPredictionEngineError: Error, LocalizedError {
    case missingInputDescription
    case missingOutputDescription
    case missingOutputFeature
    case unsupportedOutputType
    case modelNotReady(String)

    public var errorDescription: String? {
        switch self {
        case .missingInputDescription:
            return "Core ML model has no input descriptions."
        case .missingOutputDescription:
            return "Core ML model has no output descriptions."
        case .missingOutputFeature:
            return "Core ML model output feature could not be read."
        case .unsupportedOutputType:
            return "Core ML model returned an unsupported output type."
        case .modelNotReady(let details):
            return "Core ML model could not be initialized: \(details)"
        }
    }
}

// MARK: - Engine

@MainActor
public final class SuperchargerPredictionEngine: SuperchargerPricePredicting {

    private let model: MLModel
    private let inputName: String
    private let outputName: String
    private let priceStore: SuperchargerPriceStore

    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }()

    // Small cache to avoid re-running 24–48 predictions on rapid UI refresh.
    private struct CacheKey: Hashable {
        let stationId: UUID
        let alignedStart: Date
        let horizon: Int
    }
    private var cache: [CacheKey: SuperchargerPrediction] = [:]

    // MARK: Init

    public init(configuration: MLModelConfiguration = MLModelConfiguration()) throws {
        do {
            // Generated wrapper from SuperchargerPriceNN.mlmodel
            let wrapped = try SuperchargerPriceNN(configuration: configuration)
            self.model = wrapped.model
        } catch {
            throw SuperchargerPredictionEngineError.modelNotReady(error.localizedDescription)
        }

        let desc = model.modelDescription

        guard let firstInput = desc.inputDescriptionsByName.keys.first else {
            throw SuperchargerPredictionEngineError.missingInputDescription
        }
        guard let firstOutput = desc.outputDescriptionsByName.keys.first else {
            throw SuperchargerPredictionEngineError.missingOutputDescription
        }

        self.inputName = firstInput
        self.outputName = firstOutput
        self.priceStore = SuperchargerPriceStore.shared
    }

    // MARK: Protocol

    public func prediction(
        for stationId: UUID,
        startingAt startDate: Date,
        horizonHours: Int
    ) throws -> SuperchargerPrediction {

        let clampedHorizon = max(1, min(horizonHours, 48))
        let tz = TimeZone.current

        let aligned = alignedStart(for: startDate, in: tz)
        let key = CacheKey(stationId: stationId, alignedStart: aligned, horizon: clampedHorizon)

        if let cached = cache[key] { return cached }

        // Stable-ish numeric id derived from UUID (replace with real stationNumericId if you store one)
        let numericId: Int = {
            let h = stationId.uuidString.hashValue
            return abs(h % 10_000)
        }()

        var cal = calendar
        cal.timeZone = tz

        let stationKey = stationId.uuidString
        let historyStats = historyStats(for: stationKey, at: aligned)

        var times: [Date] = []
        times.reserveCapacity(clampedHorizon)

        var scores: [Double] = []
        scores.reserveCapacity(clampedHorizon)

        var cursor = aligned
        for _ in 0..<clampedHorizon {
            times.append(cursor)

            let features = try SuperchargerPriceFeatures.featureVector(
                stationNumericId: numericId,
                date: cursor,
                localAveragePrice: historyStats.average,
                rollingStdDevPrice: historyStats.stdDev,
                daysSinceLastVisit: historyStats.daysSince
            )

            scores.append(try rawScore(for: features))
            cursor = cal.date(byAdding: .hour, value: 1, to: cursor) ?? cursor.addingTimeInterval(3600)
        }

        // Map raw NN scores to a plausible $/kWh band while preserving relative order.
        let baseline = historyStats.average ?? 0.35
        let prices = calibratedPrices(from: scores, baseline: baseline, stdDev: historyStats.stdDev)

        // Buckets
        var buckets: [HourlyPriceBucket] = []
        buckets.reserveCapacity(clampedHorizon)

        for i in 0..<clampedHorizon {
            let start = times[i]
            let end = cal.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
            buckets.append(
                HourlyPriceBucket(
                    hourStart: start,
                    hourEnd: end,
                    predictedPrice: prices[i],
                    isBestWindow: false
                )
            )
        }

        // Mark best (cheapest) window
        if let minP = prices.min(), let idx = prices.firstIndex(of: minP), buckets.indices.contains(idx) {
            let bestId = buckets[idx].id
            buckets = buckets.map { b in
                HourlyPriceBucket(
                    id: b.id,
                    hourStart: b.hourStart,
                    hourEnd: b.hourEnd,
                    predictedPrice: b.predictedPrice,
                    isBestWindow: b.id == bestId
                )
            }
        }

        let sorted = prices.sorted()
        let minPrice = sorted.first
        let maxPrice = sorted.last
        let medianPrice = median(of: sorted)

        let best = buckets.first(where: { $0.isBestWindow })

        let confidenceScore = confidenceScore(
            prices: prices,
            historyCount: historyStats.count,
            daysSinceLastSample: historyStats.daysSince
        )
        let confidenceLabel = confidenceLabel(for: confidenceScore)

        let result = SuperchargerPrediction(
            stationId: stationId,
            stationName: "Supercharger",
            stationCity: nil,
            timezone: tz,
            horizonHours: clampedHorizon,
            generatedAt: Date(),
            bestStart: best?.hourStart,
            bestEnd: best?.hourEnd,
            bestPrice: best?.predictedPrice,
            medianPrice: medianPrice,
            minPrice: minPrice,
            maxPrice: maxPrice,
            confidenceScore: confidenceScore,
            confidenceLabel: confidenceLabel,
            priceBuckets: buckets,
            hasEnoughHistory: historyStats.count > 6,
            notes: "On-device Core ML NN · samples: \(historyStats.count) · confidence: \(confidenceLabel)"
        )

        cache[key] = result
        return result
    }

    public func hourlyBuckets(
        for stationId: UUID,
        startingAt startDate: Date,
        horizonHours: Int
    ) throws -> [HourlyPriceBucket] {
        try prediction(for: stationId, startingAt: startDate, horizonHours: horizonHours).priceBuckets
    }

    public func priceEstimate(
        for stationId: UUID,
        at date: Date
    ) throws -> Double {
        let p = try prediction(for: stationId, startingAt: date, horizonHours: 1)
        return p.priceBuckets.first?.predictedPrice ?? .nan
    }

    // MARK: Internals

    private func rawScore(for features: MLMultiArray) throws -> Double {
        let provider = try MLDictionaryFeatureProvider(
            dictionary: [inputName: MLFeatureValue(multiArray: features)]
        )

        let result = try model.prediction(from: provider)

        guard let feature = result.featureValue(for: outputName) else {
            throw SuperchargerPredictionEngineError.missingOutputFeature
        }

        if let array = feature.multiArrayValue {
            guard array.count > 0 else { throw SuperchargerPredictionEngineError.missingOutputFeature }
            return array[0].doubleValue
        }

        if feature.type == .double {
            return feature.doubleValue
        }

        throw SuperchargerPredictionEngineError.unsupportedOutputType
    }

    private func alignedStart(for date: Date, in timeZone: TimeZone) -> Date {
        var cal = calendar
        cal.timeZone = timeZone

        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        comps.minute = 0
        comps.second = 0
        comps.nanosecond = 0

        let floored = cal.date(from: comps) ?? date
        if abs(floored.timeIntervalSince(date)) < 1 { return floored }

        return cal.date(byAdding: .hour, value: 1, to: floored) ?? floored
    }

    private func calibratedPrices(from scores: [Double], baseline: Double, stdDev: Double?) -> [Double] {
        guard !scores.isEmpty else { return [] }
        guard let minS = scores.min(), let maxS = scores.max(), maxS > minS else {
            return Array(repeating: baseline, count: scores.count)
        }

        // plausible band, widened by recent price volatility when available
        let sigma = max(0.04, min(0.30, (stdDev ?? 0.08) * 1.15))
        let minBand = max(0.08, baseline - sigma)
        let maxBand = min(1.20, baseline + sigma)
        let span = maxS - minS

        return scores.map { s in
            let t = (s - minS) / span
            return minBand + (maxBand - minBand) * t
        }
    }

    private func historyStats(for stationKey: String, at date: Date) -> (average: Double?, stdDev: Double?, daysSince: Double?, count: Int) {
        let history = priceStore.history(for: stationKey)
            .filter { $0.timestamp <= date }

        guard !history.isEmpty else {
            return (average: nil, stdDev: nil, daysSince: nil, count: 0)
        }

        let recentWindow: TimeInterval = 60 * 60 * 24 * 30 // 30 days
        let cutoff = date.addingTimeInterval(-recentWindow)
        let recent = history.filter { $0.timestamp >= cutoff }
        let sample = recent.isEmpty ? history : recent

        let values = sample.map { $0.pricePerKwh }.filter { $0 > 0 }
        guard !values.isEmpty else {
            return (average: nil, stdDev: nil, daysSince: nil, count: history.count)
        }

        let avg = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - avg, 2) } / Double(values.count)
        let stdDev = sqrt(variance)

        let last = history.max(by: { $0.timestamp < $1.timestamp })
        let daysSince = last.map { date.timeIntervalSince($0.timestamp) / (60 * 60 * 24) }

        return (average: avg, stdDev: stdDev, daysSince: daysSince, count: history.count)
    }

    private func confidenceScore(
        prices: [Double],
        historyCount: Int,
        daysSinceLastSample: Double?
    ) -> Double {
        guard !prices.isEmpty else { return 0.20 }

        let minP = prices.min() ?? 0
        let maxP = prices.max() ?? 0
        let medianP = median(of: prices.sorted()) ?? max(minP, 0.01)

        let spread = max(0, maxP - minP)
        let spreadRatio = min(1.0, spread / max(0.06, medianP * 0.35))
        let stabilityScore = 1.0 - spreadRatio

        let historyScore = min(1.0, log1p(Double(historyCount)) / log1p(60.0))

        let recencyScore: Double = {
            guard let days = daysSinceLastSample else { return 0.35 }
            let clamped = max(0, min(1, 1.0 - (days / 30.0)))
            return 0.35 + clamped * 0.65
        }()

        let raw = 0.18 + (0.42 * stabilityScore) + (0.25 * historyScore) + (0.15 * recencyScore)
        return max(0.05, min(0.98, raw))
    }

    private func confidenceLabel(for score: Double) -> String {
        switch score {
        case 0.78...:
            return "High"
        case 0.58...:
            return "Medium"
        default:
            return "Low"
        }
    }

    private func median(of sorted: [Double]) -> Double? {
        guard !sorted.isEmpty else { return nil }
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2.0
        } else {
            return sorted[mid]
        }
    }
}
