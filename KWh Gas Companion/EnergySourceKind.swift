//
//  EnergySourceKind.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/17/25.
//


//
//  EnergyEvent.swift
//  My KWh Companion
//
//  Unifies TeslaFi sessions + ExpenseEntry charging into one canonical stream.
//  Swift 6 • iOS 17+
//

import Foundation

public enum EnergySourceKind: String, Codable, Hashable, Sendable {
    case teslaFi
    case ledger
}

public enum ChargingKind: String, Codable, Hashable, Sendable {
    case home
    case fastDC
    case destination
    case unknown
}

public struct EnergyEvent: Identifiable, Codable, Hashable, Sendable {
    public var sourceKind: EnergySourceKind
    public var sourceID: String        // TeslaFi: sessionHash, Ledger: entry UUID string

    public var startDate: Date
    public var endDate: Date?

    public var kWh: Double?
    public var amountGross: Double?
    public var amountNet: Double?      // excludes VAT where available
    public var currencyCode: String?

    public var locationName: String?
    public var siteKey: String          // normalized key used for clustering

    public var latitude: Double?
    public var longitude: Double?

    public var chargingKind: ChargingKind

    public var vehicleName: String?
    public var vin: String?

    public var notes: String?

    public var id: String { "\(sourceKind.rawValue)|\(sourceID)" }

    /// Correlation key used for matching TeslaFi ↔︎ Ledger (minute bucket + kWh bucket + siteKey).
    public var correlationKey: String {
        let minute = Int(startDate.timeIntervalSince1970 / 60.0)
        let kwhBucket: Int = {
            guard let kWh, kWh > 0 else { return -1 }
            return Int((kWh * 10.0).rounded()) // 0.1 kWh resolution
        }()
        return "\(minute)|k=\(kwhBucket)|site=\(siteKey)"
    }

    public var costPerKWhGross: Double? {
        guard let a = amountGross, let k = kWh, k > 0 else { return nil }
        return a / k
    }

    public var costPerKWhNet: Double? {
        guard let a = amountNet, let k = kWh, k > 0 else { return nil }
        return a / k
    }
}
