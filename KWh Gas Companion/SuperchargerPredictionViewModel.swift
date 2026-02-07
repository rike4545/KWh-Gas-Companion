//
//  SuperchargerPredictionViewModel.swift
//  My KWh Companion
//
//  View-model for “Cheapest Time to Charge”.
//  Uses SuperchargerPredictionEngine (Core ML) to score the next N hours.
//

import Foundation
import SwiftUI

@MainActor
final class SuperchargerPredictionViewModel: ObservableObject {

    // MARK: - Station metadata (no stub values)

    /// Human-readable station name, if known (e.g. "Lake Grove Supercharger").
    @Published var stationName: String = ""

    /// City / region label, if known (e.g. "Lake Grove, NY").
    @Published var stationCity: String? = nil

    // MARK: - Prediction state

    @Published private(set) var prediction: SuperchargerPrediction?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    /// How many hours ahead to score (e.g. 24).
    let horizonHours: Int

    private let predictor: SuperchargerPricePredicting
    private var lastStationId: UUID?

    // MARK: - Init

    init(
        horizonHours: Int = 24,
        predictor: SuperchargerPricePredicting? = nil
    ) {
        self.horizonHours = max(1, min(horizonHours, 48))

        if let predictor {
            self.predictor = predictor
        } else {
            do {
                self.predictor = try SuperchargerPredictionEngine()
            } catch {
                // If we can’t load the Core ML model, fail loudly in debug.
                fatalError("Failed to initialize SuperchargerPredictionEngine: \(error)")
            }
        }
    }

    // MARK: - Derived flags

    var hasPrediction: Bool {
        prediction != nil
    }

    // MARK: - Station metadata helpers

    /// Update the station name / city from a real station object
    /// (e.g. nearest Supercharger from your location provider).
    func updateStationMetadata(name: String?, city: String?) {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        stationName = trimmedName

        if let rawCity = city?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawCity.isEmpty {
            stationCity = rawCity
        } else {
            stationCity = nil
        }
    }

    // MARK: - Refresh

    /// Convenience used by the helper view when it doesn’t have a specific id.
    /// Uses the last station id if available, otherwise creates a stable UUID
    /// for this run. No sample names / locations are set here.
    func refreshDefaultStation(now: Date = Date()) {
        let effectiveId: UUID
        if let last = lastStationId {
            effectiveId = last
        } else {
            effectiveId = UUID()
            lastStationId = effectiveId
        }
        refresh(for: effectiveId, now: now)
    }

    /// Run the model for a given station id and update published state.
    func refresh(for stationId: UUID, now: Date = Date()) {
        isLoading = true
        errorMessage = nil
        lastStationId = stationId

        do {
            let result = try predictor.prediction(
                for: stationId,
                startingAt: now,
                horizonHours: horizonHours
            )
            prediction = result
        } catch {
            prediction = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Presentation helpers

    var bestWindowText: String {
        guard let p = prediction,
              let start = p.bestStart,
              let end = p.bestEnd else {
            return "No clear best hour yet"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.timeZone = p.timezone

        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    var bestPriceText: String {
        guard let price = prediction?.bestPrice else { return "—" }
        return String(format: "$%.3f /kWh", price)
    }

    var medianPriceText: String {
        guard let price = prediction?.medianPrice else { return "—" }
        return String(format: "$%.3f /kWh", price)
    }

    var spreadText: String {
        guard let min = prediction?.minPrice,
              let max = prediction?.maxPrice else { return "—" }
        return String(format: "$%.3f – $%.3f /kWh", min, max)
    }

    var confidenceText: String {
        guard let score = prediction?.confidenceScore else { return "—" }
        let label = prediction?.confidenceLabel ?? "Confidence"
        return "\(label) · \(Int(score * 100))%"
    }

    var hourlyBuckets: [HourlyPriceBucket] {
        prediction?.priceBuckets ?? []
    }
}
