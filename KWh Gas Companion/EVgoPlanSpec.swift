//
//  EVgoPlanSpec.swift
//  KWh Gas Companion
//
//  Created by Bryan on 9/3/25.
//


//  EVgoPlanSpec.swift
//  My KWh Companion
//
//  Pricing rules for each EVgo plan (monthly fee, energy discount, per‑session & card fees).

import Foundation

public struct EVgoPlanSpec: Codable, Hashable {
    public let plan: EVgoPlan
    public let monthlyFee: Double
    /// Fractional discount on the station's base unit price (e.g., 0.30 = 30% off $/kWh or converted rate).
    public let energyDiscount: Double

    /// Per-session fixed fee (e.g., $0.99). Some plans also add a credit card transaction fee.
    public let baseSessionFee: Double
    /// Additional fee if paying by credit card for this plan.
    public let creditCardTransactionFee: Double

    public init(plan: EVgoPlan,
                monthlyFee: Double,
                energyDiscount: Double,
                baseSessionFee: Double,
                creditCardTransactionFee: Double) {
        self.plan = plan
        self.monthlyFee = monthlyFee
        self.energyDiscount = energyDiscount
        self.baseSessionFee = baseSessionFee
        self.creditCardTransactionFee = creditCardTransactionFee
    }

    /// Create a copy overriding only the energy discount (useful for comparing L2 if the discount does not apply).
    public func withEnergyDiscount(_ d: Double) -> EVgoPlanSpec {
        .init(plan: plan,
              monthlyFee: monthlyFee,
              energyDiscount: d,
              baseSessionFee: baseSessionFee,
              creditCardTransactionFee: creditCardTransactionFee)
    }
}

public extension EVgoPlanSpec {
    /// Default specs based on the user's provided summary. Adjust locally as needed.
    static func defaults(for plan: EVgoPlan) -> EVgoPlanSpec {
        switch plan {
        case .plusMax:
            return .init(plan: plan,
                         monthlyFee: 12.99,
                         energyDiscount: 0.30,
                         baseSessionFee: 0.0,
                         creditCardTransactionFee: 0.0)
        case .plus:
            return .init(plan: plan,
                         monthlyFee: 6.99,
                         energyDiscount: 0.15,
                         baseSessionFee: 0.0,
                         creditCardTransactionFee: 0.0)
        case .payAsYouGo:
            return .init(plan: plan,
                         monthlyFee: 0.0,
                         energyDiscount: 0.00,
                         baseSessionFee: 0.99,
                         creditCardTransactionFee: 2.99) // applies when PaymentMethod == .creditCard
        case .uberBlue:
            return .init(plan: plan,
                         monthlyFee: 0.0,
                         energyDiscount: 0.25,
                         baseSessionFee: 0.0,
                         creditCardTransactionFee: 2.99) // no session fee; CC txn may apply per provided text
        case .uberGoldPlatinumDiamond:
            return .init(plan: plan,
                         monthlyFee: 0.0,
                         energyDiscount: 0.45,
                         baseSessionFee: 0.0,
                         creditCardTransactionFee: 0.0)
        }
    }
}
