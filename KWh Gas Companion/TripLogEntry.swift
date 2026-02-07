// TripLogEntry.swift
import Foundation

struct TripLogEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var date: Date
    var currentDrive: CurrentDriveData
    var sinceLastCharge: SinceLastChargeData
    var tripA: TripSegmentData
    var tripB: TripSegmentData

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        currentDrive: CurrentDriveData = .init(),
        sinceLastCharge: SinceLastChargeData = .init(),
        tripA: TripSegmentData = .init(),
        tripB: TripSegmentData = .init()
    ) {
        self.id = id
        self.date = date
        self.currentDrive = currentDrive
        self.sinceLastCharge = sinceLastCharge
        self.tripA = tripA
        self.tripB = tripB
    }
}

struct CurrentDriveData: Codable, Hashable {
    var distance: Double = 0
    var durationMinutes: Double = 0
    var avgWhPerMile: Double = 0
}

struct SinceLastChargeData: Codable, Hashable {
    var distance: Double = 0
    var totalEnergyKWh: Double = 0
    var avgWhPerMile: Double = 0
}

struct TripSegmentData: Codable, Hashable {
    var distance: Double = 0
    var totalEnergyKWh: Double = 0
    var avgWhPerMile: Double = 0
}
