//
//  KWChargeLogEntry.swift
//  KWh Gas Companion
//
//

// KWChargeLogEntry.swift
// MyKwH Companion

import Foundation

/// Represents a logged EV charging session with optional location, vehicle, and notes
struct KWChargeLogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date
    var kWh: Double
    var cost: Double
    var mileage: Double?
    var vehicleID: UUID?
    var location: String?
    var notes: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        kWh: Double,
        cost: Double,
        mileage: Double? = nil,
        vehicleID: UUID? = nil,
        location: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.kWh = kWh
        self.cost = cost
        self.mileage = mileage
        self.vehicleID = vehicleID
        self.location = location
        self.notes = notes
    }

    var costPerKWh: Double? {
        guard kWh > 0 else { return nil }
        return cost / kWh
    }

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
