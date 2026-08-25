//
//  TeslaFiTrip 2.swift
//  KWh Gas Companion
//
//

// TeslaFiTrip.swift

import Foundation

public struct TeslaFiTrip: Identifiable, Equatable, Codable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date
    public let startOdometer: Double?
    public let endOdometer: Double?
    public let startLocation: String?
    public let endLocation: String?
    public let energyKWh: Double?
    public let startBatteryLevel: Double?
    public let endBatteryLevel: Double?
    public let averageSpeedMPH: Double?
    public let maxSpeedMPH: Double?
    public let outsideTempC: Double?
    public let elevationFt: Double?

    public init(
        id: UUID = UUID(),
        date: Date,
        odometer: Double? = nil,
        location: String? = nil,
        energyKWh: Double? = nil,
        endDate: Date? = nil,
        endOdometer: Double? = nil,
        endLocation: String? = nil,
        startBatteryLevel: Double? = nil,
        endBatteryLevel: Double? = nil,
        averageSpeedMPH: Double? = nil,
        maxSpeedMPH: Double? = nil,
        outsideTempC: Double? = nil,
        elevationFt: Double? = nil
    ) {
        self.id = id
        self.startDate = date
        self.endDate = endDate ?? date
        self.startOdometer = odometer
        self.endOdometer = endOdometer ?? odometer
        self.startLocation = location
        self.endLocation = endLocation ?? location
        self.energyKWh = energyKWh
        self.startBatteryLevel = startBatteryLevel
        self.endBatteryLevel = endBatteryLevel
        self.averageSpeedMPH = averageSpeedMPH
        self.maxSpeedMPH = maxSpeedMPH
        self.outsideTempC = outsideTempC
        self.elevationFt = elevationFt
    }
}

public extension TeslaFiTrip {
    var date: Date { startDate }
    var odometer: Double? { startOdometer }
    var location: String? { startLocation ?? endLocation }
    var duration: TimeInterval { max(0, endDate.timeIntervalSince(startDate)) }
    var distanceMiles: Double? {
        guard let startOdometer, let endOdometer, endOdometer >= startOdometer else { return nil }
        return endOdometer - startOdometer
    }
}
