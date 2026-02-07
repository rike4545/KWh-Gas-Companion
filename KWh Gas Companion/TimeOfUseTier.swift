//
//  TimeOfUseTier.swift
//  KWh Gas Companion
//
//  Created by Bryan on 9/3/25.
//


//  RateModel.swift
//  My KWh Companion
//
//  Time-of-use tiers and a generic rate model for charging providers.
//
//  This file defines only pricing primitives so they can be used across
//  analyzers and UI without circular dependencies.

import Foundation

public struct TimeOfUseTier: Hashable, Codable {
    /// Start hour [0, 23], inclusive
    public let startHour: Int
    /// End hour [1, 24], exclusive
    public let endHour: Int
    /// Price in $/kWh within this window
    public let pricePerKWh: Double

    public init(_ startHour: Int, _ endHour: Int, _ pricePerKWh: Double) {
        self.startHour = max(0, min(23, startHour))
        self.endHour = max(1, min(24, endHour))
        self.pricePerKWh = pricePerKWh
    }

    public func contains(hour: Int) -> Bool {
        let h = max(0, min(23, hour))
        return h >= startHour && h < endHour
    }

    public var hours: Int { max(0, endHour - startHour) }
}

public enum RateModel: Hashable, Codable {
    /// Direct energy price
    case perKWh(_ pricePerKWh: Double)
    /// Time-based price where caller provides an assumed average charging power (kW)
    case perMinute(_ pricePerMinute: Double, avgPowerkW: Double)
    case perHour(_ pricePerHour: Double, avgPowerkW: Double)
    /// Tiered time-of-use energy prices; optionally weight by an hour-of-day mix (0–23 → fraction)
    case timeOfUse(_ tiers: [TimeOfUseTier], hourMix: [Int: Double]? = nil)
}
