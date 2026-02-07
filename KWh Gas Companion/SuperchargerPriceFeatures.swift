//
//  SuperchargerPriceFeatures.swift
//  My KWh Companion
//
//  Builds the feature vector for SuperchargerPriceNN.
//  Input order matches the training CSV:
//
//  0: stationNumericId        (Double)
//  1: hourOfDay               (0–23)
//  2: weekday                 (1–7, Sunday = 1)
//  3: month                   (1–12)
//  4: isWeekend               (0 or 1)
//  5: localAveragePrice       (Double, default 0)
//  6: rollingStdDevPrice      (Double, default 0)
//  7: daysSinceLastVisit      (Double, default 0)
//

import Foundation
import CoreML

@MainActor
struct SuperchargerPriceFeatures {

    static let featureCount = 8

    /// Core feature builder used by the prediction engine.
    /// Returns an MLMultiArray of shape [8].
    static func featureVector(
        stationNumericId: Int,
        date: Date,
        localAveragePrice: Double?,
        rollingStdDevPrice: Double?,
        daysSinceLastVisit: Double?
    ) throws -> MLMultiArray {

        let features = try MLMultiArray(
            shape: [NSNumber(value: featureCount)],
            dataType: .double
        )

        let calendar = Calendar(identifier: .gregorian)

        let hour = calendar.component(.hour, from: date)          // 0–23
        let weekday = calendar.component(.weekday, from: date)    // 1–7
        let month = calendar.component(.month, from: date)        // 1–12
        let isWeekendFlag = (weekday == 1 || weekday == 7) ? 1.0 : 0.0

        // Normalize / clamp lightly if desired
        let stationIdValue = Double(stationNumericId)

        let avgPrice = localAveragePrice ?? 0.0
        let stdDev   = rollingStdDevPrice ?? 0.0
        let daysLast = daysSinceLastVisit ?? 0.0

        // Fill the vector in the same order used in training.
        features[0] = NSNumber(value: stationIdValue)
        features[1] = NSNumber(value: Double(hour))
        features[2] = NSNumber(value: Double(weekday))
        features[3] = NSNumber(value: Double(month))
        features[4] = NSNumber(value: isWeekendFlag)
        features[5] = NSNumber(value: avgPrice)
        features[6] = NSNumber(value: stdDev)
        features[7] = NSNumber(value: daysLast)

        return features
    }

    // MARK: - Convenience wrappers
    // These are just thin aliases so whatever name we used earlier in the engine
    // (makeFeatureVector / makeFeatures) keeps working.

    /// Alias: same as `featureVector`.
    static func makeFeatureVector(
        stationNumericId: Int,
        date: Date,
        localAveragePrice: Double?,
        rollingStdDevPrice: Double?,
        daysSinceLastVisit: Double?
    ) throws -> MLMultiArray {
        try featureVector(
            stationNumericId: stationNumericId,
            date: date,
            localAveragePrice: localAveragePrice,
            rollingStdDevPrice: rollingStdDevPrice,
            daysSinceLastVisit: daysSinceLastVisit
        )
    }

    /// Alias: same as `featureVector`. Useful if call-sites were named `makeFeatures`.
    static func makeFeatures(
        stationNumericId: Int,
        date: Date,
        localAveragePrice: Double?,
        rollingStdDevPrice: Double?,
        daysSinceLastVisit: Double?
    ) throws -> MLMultiArray {
        try featureVector(
            stationNumericId: stationNumericId,
            date: date,
            localAveragePrice: localAveragePrice,
            rollingStdDevPrice: rollingStdDevPrice,
            daysSinceLastVisit: daysSinceLastVisit
        )
    }
}
