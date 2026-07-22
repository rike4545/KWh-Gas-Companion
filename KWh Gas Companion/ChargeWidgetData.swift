//
//  ChargeWidgetData.swift
//  KWh Gas Companion
//
//  Shared model for widgets and Live Activities.
//

import Foundation

struct ChargeWidgetSnapshot: Codable, Hashable {
    let vehicleName: String
    let batteryLevel: Int
    let chargingState: String
    let energyAddedKWh: Double?
    let cost: Double?
    let updatedAt: Date
}

enum ChargeWidgetStore {
    static let appGroupID = "group.com.my_ev_companion"
    private static let key = "direct_connection.widget.snapshot"

    static func save(_ snapshot: ChargeWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: appGroupID)?.set(data, forKey: key)
    }

    static func load() -> ChargeWidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ChargeWidgetSnapshot.self, from: data)
    }
}
