//
//  ALVRules.swift
//  KWh Gas Companion
//
//

// ALVRules.swift
import Foundation

public struct ALVRules: Equatable, Sendable {
    // Tune these however your anomalies logic expects
    public var minSessionDuration: TimeInterval        // seconds
    public var minKWh: Double
    public var maxRatePerKWh: Double?                  // optional clamp

    public static let `default` = ALVRules(
        minSessionDuration: 5 * 60,
        minKWh: 0.1,
        maxRatePerKWh: nil
    )

    public init(minSessionDuration: TimeInterval,
                minKWh: Double,
                maxRatePerKWh: Double?) {
        self.minSessionDuration = minSessionDuration
        self.minKWh = minKWh
        self.maxRatePerKWh = maxRatePerKWh
    }
}
