//
//  TeslaMateActivityAttributes.swift
//  KWh Gas Companion
//
//  Shared ActivityKit attributes (app + widget extension).
//

import ActivityKit

struct TeslaMateChargeAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let batteryLevel: Int
        let chargingState: String
        let energyAddedKWh: Double?
        let cost: Double?
    }

    let vehicleName: String
}
