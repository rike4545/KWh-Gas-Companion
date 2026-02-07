//
//  SuperchargerPricePredicting.swift
//  My KWh Companion
//
//  Protocol abstraction for anything that can predict Supercharger prices
//  using the Core ML model (SuperchargerPriceNN) + your price history.
//
//  Implemented by SuperchargerPredictionEngine.
//

import Foundation

/// High-level summary of a best-price window for a given station.
///
/// This is the core value the view model should bind to.
/// (Defined in your prediction engine file; listed here just for context.)
///
/// public struct SuperchargerPrediction: Identifiable, Hashable {
///     public let id: UUID
///     public let stationId: UUID
///     public let stationName: String
///     public let timezone: TimeZone
///     public let horizonHours: Int
///
///     public let bestStart: Date?
///     public let bestEnd: Date?
///     public let bestPrice: Double?
///
///     public let medianPrice: Double?
///     public let priceBuckets: [HourlyPriceBucket]
///
///     public let hasEnoughHistory: Bool
///     public let notes: String
/// }

/// Per-hour bucket used for charts / detail view.
///
/// public struct HourlyPriceBucket: Identifiable, Hashable {
///     public let id: UUID
///     public let hourStart: Date
///     public let hourEnd: Date
///     public let predictedPrice: Double
///     public let isBestWindow: Bool
/// }

/// A type that can produce Supercharger price predictions given a station
/// and time horizon.
///
/// Marked @MainActor because the generated Core ML interface for
/// `SuperchargerPriceNN` is main-actor–isolated; this keeps callers simple
/// (no cross-actor calls when instantiating / running the model).
@MainActor
public protocol SuperchargerPricePredicting: AnyObject {

    /// Primary API: compute a 24-hour (or custom horizon) prediction
    /// for a given station, starting at the provided date.
    ///
    /// - Parameters:
    ///   - stationId: The UUID for the Supercharger station.
    ///   - startDate: The anchor date/time (usually "now" in the station's timezone).
    ///   - horizonHours: How many hours forward to evaluate (default 24).
    ///
    /// - Returns: A `SuperchargerPrediction` containing the best window,
    ///            summary stats, and per-hour buckets.
    func prediction(
        for stationId: UUID,
        startingAt startDate: Date,
        horizonHours: Int
    ) throws -> SuperchargerPrediction

    /// Convenience helper: return only the buckets for a station over a
    /// given horizon. Useful for charts or debug UIs that don't need the
    /// full `SuperchargerPrediction` struct.
    ///
    /// Implementations may simply call `prediction(…)` and forward
    /// `prediction.priceBuckets`.
    func hourlyBuckets(
        for stationId: UUID,
        startingAt startDate: Date,
        horizonHours: Int
    ) throws -> [HourlyPriceBucket]

    /// Convenience helper: one-off price estimate for a specific date/time.
    ///
    /// Implementations may:
    ///  - build features for that single hour, or
    ///  - reuse the cached 24-hour run and pick the bucket whose start/end
    ///    contains `date`.
    func priceEstimate(
        for stationId: UUID,
        at date: Date
    ) throws -> Double
}
