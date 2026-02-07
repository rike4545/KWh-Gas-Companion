//
//  TeslaFiTrip 2.swift
//  KWh Gas Companion
//
//  Created by Bryan on 8/9/25.
//


// TeslaFiTrip.swift

import Foundation

public struct TeslaFiTrip: Identifiable, Equatable, Codable {
    public let id: UUID
    public let date: Date
    public let odometer: Double?
    public let location: String?
    public let energyKWh: Double?

    public init(
        id: UUID = UUID(),
        date: Date,
        odometer: Double? = nil,
        location: String? = nil,
        energyKWh: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.odometer = odometer
        self.location = location
        self.energyKWh = energyKWh
    }
}
