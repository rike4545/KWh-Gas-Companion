//
//  ChargeLogEntry.swift
//  MyKWh Companion
//
//  Represents a single charge or expense entry in the lightweight charge log.
//  This is separate from TeslaFiSession and from the official Tesla CSV pipeline,
//  but can still be tagged with a ChargingDataSource for clarity.
//

import Foundation

/// Represents a single charge or expense entry
struct ChargeLogEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var date: Date
    var kWh: Double?
    var cost: Double?
    var mileage: Double?
    var vehicleID: UUID?
    var location: String?
    var notes: String?
    var category: ExpenseCategory?

    /// Indicates where this log entry came from (optional).
    /// - `.teslaOfficial`  → official Tesla Supercharging CSV
    /// - `.teslaFi`        → TeslaFi-derived entry
    /// - `.manual`         → user-created / in-app
    /// - `.other`          → anything else / legacy
    var source: ChargingDataSource?

    /// Convenience: treat `nil` as `.manual` in the UI.
    var effectiveSource: ChargingDataSource {
        source ?? .manual
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        kWh: Double? = nil,
        cost: Double? = nil,
        mileage: Double? = nil,
        vehicleID: UUID? = nil,
        location: String? = nil,
        notes: String? = nil,
        category: ExpenseCategory? = nil,
        source: ChargingDataSource? = nil
    ) {
        self.id = id
        self.date = date
        self.kWh = kWh
        self.cost = cost
        self.mileage = mileage
        self.vehicleID = vehicleID
        self.location = location
        self.notes = notes
        self.category = category
        self.source = source
    }
}
