//
//  TeslaMateWidgetData.swift
//  KWh Gas Companion
//
//  Shared model for widgets + Live Activity.
//

import Foundation

struct TeslaMateWidgetSnapshot: Codable, Hashable {
    let vehicleName: String
    let batteryLevel: Int
    let chargingState: String
    let energyAddedKWh: Double?
    let cost: Double?
    let updatedAt: Date
}

enum TeslaMateWidgetStore {
    // IMPORTANT: Enable App Groups in Xcode and match this identifier.
    static let appGroupID = "group.com.my_ev_companion"
    private static let key = "teslamate.widget.snapshot"

    static func save(_ snapshot: TeslaMateWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: appGroupID)?.set(data, forKey: key)
    }

    static func load() -> TeslaMateWidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TeslaMateWidgetSnapshot.self, from: data)
    }
}
