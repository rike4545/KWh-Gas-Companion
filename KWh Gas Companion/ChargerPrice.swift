//
//  ChargerPrice.swift
//  My KWh Companion
//
//  Canonical pricing model + estimator + provider protocol.
//  Works with ChargerSite, TeslaFindUsPriceProvider_SlugResolver, and SmartChargerShift_NoModel.
//
//  Swift 6 • iOS 17+
//

import Foundation
import CoreLocation

// MARK: - Provider protocol & composition

/// Async provider of a price quote for a given site.
/// Implementations may return `nil` if they cannot price the site.
public protocol PriceProvider {
    func price(
        for site: ChargerSite,
        vehicleIsTesla: Bool,
        hasNonTeslaMembership: Bool
    ) async throws -> PriceQuote?
}

/// Tries each provider in order and returns the first non-nil quote.
public struct ComposedPriceProvider: PriceProvider {
    public let providers: [PriceProvider]
    public init(_ providers: [PriceProvider]) { self.providers = providers }

    public func price(
        for site: ChargerSite,
        vehicleIsTesla: Bool,
        hasNonTeslaMembership: Bool
    ) async throws -> PriceQuote? {
        for p in providers {
            if let q = try await p.price(for: site, vehicleIsTesla: vehicleIsTesla, hasNonTeslaMembership: hasNonTeslaMembership) {
                return q
            }
        }
        return nil
    }
}

// MARK: - Price quote model

/// Normalized price description. Supports per-kWh or per-minute bases, with optional power tiers.
public struct PriceQuote: Codable, Sendable {
    public enum Basis: Codable, Sendable {
        case perKWh(Double)     // $ / kWh
        case perMinute(Double)  // $ / minute
    }

    public struct Tier: Codable, Sendable {
        public let thresholdKW: Double    // e.g., tier applies ≥ thresholdKW (or use 0 if n/a)
        public let basis: Basis
        public init(thresholdKW: Double, basis: Basis) {
            self.thresholdKW = thresholdKW
            self.basis = basis
        }
    }

    public let forNonTesla: Bool
    public let membershipActive: Bool     // e.g., non-Tesla Supercharging membership
    public let tiers: [Tier]              // if multiple power bands/time windows map to distinct rates
    public let idleFeePerMinute: Double?  // $ / minute when idle fees apply (if published)
    public let lastUpdated: Date

    public init(
        forNonTesla: Bool,
        membershipActive: Bool,
        tiers: [Tier],
        idleFeePerMinute: Double?,
        lastUpdated: Date
    ) {
        self.forNonTesla = forNonTesla
        self.membershipActive = membershipActive
        self.tiers = tiers
        self.idleFeePerMinute = idleFeePerMinute
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Session cost/time estimation

/// Estimated cost/time bands for a planned DCFC session.
public struct PriceEstimation: Sendable {
    public let effectiveRateUSDPerKWh: ClosedRange<Double>
    public let estMinutes: ClosedRange<Double>
    public let estSessionCost: ClosedRange<Double>
    public let source: String
}

/// Converts a `PriceQuote` (possibly per-minute) into effective $/kWh and session cost/time bands.
public struct SessionEstimator: Sendable {

    public struct Input: Sendable {
        public let batteryKWh: Double            // usable capacity
        public let startSOC: Double              // 0...100
        public let targetSOC: Double             // 0...100
        public let vehicleMaxKW: Double          // vehicle DC peak
        public let ambientC: Double?             // optional hint
        public let siteMaxKW: Double?            // site headline power
        public let quote: PriceQuote?            // may be nil

        public init(
            batteryKWh: Double,
            startSOC: Double,
            targetSOC: Double,
            vehicleMaxKW: Double,
            ambientC: Double?,
            siteMaxKW: Double?,
            quote: PriceQuote?
        ) {
            self.batteryKWh = batteryKWh
            self.startSOC = startSOC
            self.targetSOC = targetSOC
            self.vehicleMaxKW = vehicleMaxKW
            self.ambientC = ambientC
            self.siteMaxKW = siteMaxKW
            self.quote = quote
        }
    }

    public init() {}

    public func estimate(_ x: Input) -> PriceEstimation {
        // Energy to add
        let deltaSOC = max(0, x.targetSOC - x.startSOC)
        let addKWh = x.batteryKWh * (deltaSOC / 100.0)

        // Conservative taper-aware average kW band
        let capKW = min(x.vehicleMaxKW, x.siteMaxKW ?? x.vehicleMaxKW)
        let avgKWLow = max(20, capKW * 0.45)
        let avgKWHigh = max(avgKWLow, capKW * 0.75)

        let minutesLow = (addKWh / avgKWHigh) * 60.0
        let minutesHigh = (addKWh / avgKWLow) * 60.0

        // Convert basis to effective $/kWh band
        let rateBand: ClosedRange<Double> = {
            guard let q = x.quote, let first = q.tiers.first else {
                // Generic fallback band when no quote is available
                return 0.28...0.42
            }
            switch first.basis {
            case .perKWh(let r):
                return r...r
            case .perMinute(let p):
                // $/min ÷ (kWh/min) = $/kWh
                let lo = p / (avgKWHigh / 60.0)
                let hi = p / (avgKWLow / 60.0)
                return min(lo, hi)...max(lo, hi)
            }
        }()

        let costLow = rateBand.lowerBound * addKWh
        let costHigh = rateBand.upperBound * addKWh

        return PriceEstimation(
            effectiveRateUSDPerKWh: rateBand,
            estMinutes: minutesLow...minutesHigh,
            estSessionCost: costLow...costHigh,
            source: x.quote == nil ? "Heuristic" : "Published/Converted"
        )
    }
}

// MARK: - Minimal public providers

/// Best-effort OCM parser (stub). Returns nil to allow other providers to handle pricing.
/// You can flesh this out later to query OCM by coordinates/name and parse UsageCost.
public struct OCMPriceProvider: PriceProvider {
    public init() {}
    public func price(
        for site: ChargerSite,
        vehicleIsTesla: Bool,
        hasNonTeslaMembership: Bool
    ) async throws -> PriceQuote? {
        // TODO: Implement OCM lookup + UsageCost parser.
        return nil
    }
}

/// Heuristic provider for when only $/min is known (or nothing is published).
/// Here we return nil so the estimator uses a safe default band (0.28...0.42 $/kWh).
/// If you want, you can emit a synthetic per-minute-based quote here.
public struct HeuristicPriceProvider: PriceProvider {
    public init() {}
    public func price(
        for site: ChargerSite,
        vehicleIsTesla: Bool,
        hasNonTeslaMembership: Bool
    ) async throws -> PriceQuote? {
        // Example (commented): synthesize a broad estimate if you wish.
        // let tiers: [PriceQuote.Tier] = [.init(thresholdKW: 0, basis: .perKWh(0.35))]
        // return PriceQuote(forNonTesla: !vehicleIsTesla, membershipActive: hasNonTeslaMembership, tiers: tiers, idleFeePerMinute: nil, lastUpdated: Date())
        return nil
    }
}
