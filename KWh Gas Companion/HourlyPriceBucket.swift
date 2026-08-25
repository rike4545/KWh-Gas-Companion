//  SuperchargerPredictionModels.swift
//  My KWh Companion
//
//  Data models for the Supercharger price prediction UI.
//

import Foundation

// MARK: - Hourly Bucket

/// Per-hour bucket used for charts and detail view.
public struct HourlyPriceBucket: Identifiable, Hashable {
    public let id: UUID
    /// Inclusive start of this hour-long bucket (in the station’s local time).
    public let hourStart: Date
    /// Exclusive end of the bucket (usually start + 1 hour).
    public let hourEnd: Date
    /// Predicted price for this hour window, in the station’s currency (e.g. $/kWh).
    public let predictedPrice: Double
    /// True if this bucket is part of the “best” (cheapest) window.
    public let isBestWindow: Bool

    public init(
        id: UUID = UUID(),
        hourStart: Date,
        hourEnd: Date,
        predictedPrice: Double,
        isBestWindow: Bool
    ) {
        self.id = id
        self.hourStart = hourStart
        self.hourEnd = hourEnd
        self.predictedPrice = predictedPrice
        self.isBestWindow = isBestWindow
    }
}

// MARK: - Aggregate Prediction

/// High-level summary of a best-price window for a given Supercharger station.
public struct SuperchargerPrediction: Identifiable, Hashable {
    public let id: UUID

    // Station / context
    public let stationId: UUID
    public let stationName: String
    /// Optional city/label to show in cards (“Lake Grove, NY”).
    public let stationCity: String?
    /// Time zone the prediction was computed in (usually the station’s local zone).
    public let timezone: TimeZone
    /// Number of hours forward that were evaluated (e.g. 24).
    public let horizonHours: Int
    /// When this prediction was generated.
    public let generatedAt: Date

    // Best window
    public let bestStart: Date?
    public let bestEnd: Date?
    public let bestPrice: Double?

    // Summary stats over all evaluated hours
    public let medianPrice: Double?
    public let minPrice: Double?
    public let maxPrice: Double?

    // Confidence estimate (0–1). Higher = more reliable.
    public let confidenceScore: Double?
    public let confidenceLabel: String?

    // Full per-hour series used by charts/detail view
    public let priceBuckets: [HourlyPriceBucket]

    // Meta
    public let hasEnoughHistory: Bool
    public let notes: String

    public init(
        id: UUID = UUID(),
        stationId: UUID,
        stationName: String,
        stationCity: String? = nil,
        timezone: TimeZone = .current,
        horizonHours: Int,
        generatedAt: Date = Date(),
        bestStart: Date?,
        bestEnd: Date?,
        bestPrice: Double?,
        medianPrice: Double?,
        minPrice: Double?,
        maxPrice: Double?,
        confidenceScore: Double? = nil,
        confidenceLabel: String? = nil,
        priceBuckets: [HourlyPriceBucket],
        hasEnoughHistory: Bool,
        notes: String
    ) {
        self.id = id
        self.stationId = stationId
        self.stationName = stationName
        self.stationCity = stationCity
        self.timezone = timezone
        self.horizonHours = horizonHours
        self.generatedAt = generatedAt
        self.bestStart = bestStart
        self.bestEnd = bestEnd
        self.bestPrice = bestPrice
        self.medianPrice = medianPrice
        self.minPrice = minPrice
        self.maxPrice = maxPrice
        self.confidenceScore = confidenceScore
        self.confidenceLabel = confidenceLabel
        self.priceBuckets = priceBuckets
        self.hasEnoughHistory = hasEnoughHistory
        self.notes = notes
    }
}

// MARK: - Preview / Convenience Mocks

public extension HourlyPriceBucket {
    static func mock(
        startingAt start: Date,
        price: Double,
        isBest: Bool = false
    ) -> HourlyPriceBucket {
        let end = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start
        return HourlyPriceBucket(
            hourStart: start,
            hourEnd: end,
            predictedPrice: price,
            isBestWindow: isBest
        )
    }
}

public extension SuperchargerPrediction {
    /// Simple mock for previews / tests.
    static func mock(
        stationName: String = "Sample Supercharger",
        stationCity: String? = "Example, NY",
        horizonHours: Int = 24,
        timezone: TimeZone = .current
    ) -> SuperchargerPrediction {
        let now = Date()
        var buckets: [HourlyPriceBucket] = []
        var current = now

        for i in 0..<horizonHours {
            let price = 0.30 + Double(i) * 0.005
            let isBest = (i >= 3 && i <= 4) // cheap around 3–5 hours ahead
            buckets.append(.mock(startingAt: current, price: price, isBest: isBest))
            current = Calendar.current.date(byAdding: .hour, value: 1, to: current) ?? current
        }

        let best = buckets.first(where: { $0.isBestWindow })

        let prices = buckets.map { $0.predictedPrice }.sorted()
        let minPrice = prices.first
        let maxPrice = prices.last
        let medianPrice: Double? = {
            guard !prices.isEmpty else { return nil }
            let mid = prices.count / 2
            if prices.count % 2 == 0 {
                return (prices[mid - 1] + prices[mid]) / 2.0
            } else {
                return prices[mid]
            }
        }()

        return SuperchargerPrediction(
            stationId: UUID(),
            stationName: stationName,
            stationCity: stationCity,
            timezone: timezone,
            horizonHours: horizonHours,
            bestStart: best?.hourStart,
            bestEnd: best?.hourEnd,
            bestPrice: best?.predictedPrice,
            medianPrice: medianPrice,
            minPrice: minPrice,
            maxPrice: maxPrice,
            confidenceScore: 0.72,
            confidenceLabel: "Medium",
            priceBuckets: buckets,
            hasEnoughHistory: true,
            notes: "Mock prediction for previews"
        )
    }
}
