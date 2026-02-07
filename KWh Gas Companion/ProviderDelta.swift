//
//  ProviderDelta.swift
//  KWh Gas Companion
//
//  Created by Bryan on 9/3/25.
//


//  ProviderDelta.swift
//  My KWh Companion
//
//  What‑if comparison item used by Month‑to‑Date panel in the UI.

import Foundation

public struct ProviderDelta: Hashable, Codable, CustomStringConvertible {
    public let label: String
    public let estMonthlyCost: Double
    /// If actual spend is known for MTD, show the delta (what‑if − actual)
    public let deltaVsActualMTD: Double?
    /// Convenience delta vs Tesla in the same scenario (what‑if − Tesla)
    public let deltaVsTesla: Double

    public init(label: String, estMonthlyCost: Double, deltaVsActualMTD: Double?, deltaVsTesla: Double) {
        self.label = label
        self.estMonthlyCost = estMonthlyCost
        self.deltaVsActualMTD = deltaVsActualMTD
        self.deltaVsTesla = deltaVsTesla
    }

    public var description: String {
        let a = deltaVsActualMTD.map { String(format: " • Δ vs actual MTD: $%.2f", $0) } ?? ""
        return String(format: "%@ • What‑if Monthly: $%.2f • Δ vs Tesla: $%.2f%@", label, estMonthlyCost, deltaVsTesla, a)
    }
}
