//
//  ProviderComparison.swift
//  KWh Gas Companion
//
//  Created by Bryan on 9/3/25.
//


//  ProviderComparison.swift
//  My KWh Companion
//
//  Lightweight model used by the UI to render sorted provider rows.

import Foundation

public struct ProviderComparison: Hashable, Codable, CustomStringConvertible {
    public let label: String
    public let monthly: Double
    /// Positive = cheaper than Tesla, Negative = more expensive than Tesla
    public let savingsVsTesla: Double

    public init(label: String, monthly: Double, savingsVsTesla: Double) {
        self.label = label
        self.monthly = monthly
        self.savingsVsTesla = savingsVsTesla
    }

    public var description: String {
        String(format: "%@ • Monthly: $%.2f • Savings vs Tesla: $%.2f", label, monthly, savingsVsTesla)
    }
}
