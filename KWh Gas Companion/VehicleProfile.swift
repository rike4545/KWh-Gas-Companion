//
//  VehicleProfile.swift
//  KWh Gas Companion
//
//  Vehicle profile model used by ProfileStore + vehicle UI.
//  Includes VIN + Plate/Marker to preserve other feature integrations.
//
//  Swift 6 • iOS 17+
//

import Foundation

public struct VehicleProfile: Identifiable, Codable, Hashable, Sendable {

    // MARK: - Identity

    public var id: UUID

    /// User-facing label (e.g., "Model 3", "Work Truck", "Rivian")
    public var name: String

    public var make: String
    public var model: String
    public var year: Int?

    /// Vehicle identification
    public var vin: String
    public var plateOrMarker: String
    public var plateState: String?
    public var plateStyle: String?
    public var registrationExpires: Date?

    /// EV vs ICE flag (used by various tools)
    public var isEV: Bool

    // MARK: - EV / Efficiency (optional)

    public var batteryCapacityKWh: Double?
    public var efficiencyWhPerMile: Double?
    public var estimatedRangeMiles: Double?
    public var maxRangeMiles: Double?

    /// Some importers/tools store energy added
    public var chargeEnergyAddedKWh: Double?

    // MARK: - Odometer / Trim / Purchase (optional)

    public var odometerMiles: Double?
    public var wheelType: String?
    public var carVersion: String?
    public var purchasePrice: Double?
    public var trim: String?
    public var colorName: String?
    public var badge: String?
    public var accentHex: String?

    // MARK: - Gallery

    public var galleryPhotoIds: [UUID]
    public var coverPhotoId: UUID?

    // MARK: - Notes / timestamps

    public var notes: String?
    public var createdAt: Date
    public var updatedAt: Date

    // MARK: - Convenience

    public init(
        id: UUID = UUID(),
        name: String = "",
        make: String = "",
        model: String = "",
        year: Int? = nil,
        vin: String = "",
        plateOrMarker: String = "",
        plateState: String? = nil,
        plateStyle: String? = nil,
        registrationExpires: Date? = nil,
        isEV: Bool = true,
        batteryCapacityKWh: Double? = nil,
        efficiencyWhPerMile: Double? = nil,
        estimatedRangeMiles: Double? = nil,
        maxRangeMiles: Double? = nil,
        chargeEnergyAddedKWh: Double? = nil,
        odometerMiles: Double? = nil,
        wheelType: String? = nil,
        carVersion: String? = nil,
        purchasePrice: Double? = nil,
        trim: String? = nil,
        colorName: String? = nil,
        badge: String? = nil,
        accentHex: String? = nil,
        galleryPhotoIds: [UUID] = [],
        coverPhotoId: UUID? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.make = make
        self.model = model
        self.year = year
        self.vin = vin
        self.plateOrMarker = plateOrMarker
        self.plateState = plateState
        self.plateStyle = plateStyle
        self.registrationExpires = registrationExpires
        self.isEV = isEV
        self.batteryCapacityKWh = batteryCapacityKWh
        self.efficiencyWhPerMile = efficiencyWhPerMile
        self.estimatedRangeMiles = estimatedRangeMiles
        self.maxRangeMiles = maxRangeMiles
        self.chargeEnergyAddedKWh = chargeEnergyAddedKWh
        self.odometerMiles = odometerMiles
        self.wheelType = wheelType
        self.carVersion = carVersion
        self.purchasePrice = purchasePrice
        self.trim = trim
        self.colorName = colorName
        self.badge = badge
        self.accentHex = accentHex
        self.galleryPhotoIds = galleryPhotoIds
        self.coverPhotoId = coverPhotoId
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Derived UI strings

    public var displayName: String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { return n }

        let y = year.map(String.init) ?? ""
        let base = [y, make, model]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return base.isEmpty ? "Vehicle" : base
    }

    public var summarySubtitle: String {
        var parts: [String] = []
        let y = year.map(String.init) ?? ""
        let mm = [make, model]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let top = [y, mm]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if !top.isEmpty { parts.append(top) }

        let p = plateOrMarker.trimmingCharacters(in: .whitespacesAndNewlines)
        if !p.isEmpty { parts.append("Plate/Marker: \(p)") }

        let v = vin.trimmingCharacters(in: .whitespacesAndNewlines)
        if !v.isEmpty {
            let suffix = String(v.suffix(min(6, v.count)))
            parts.append("VIN: …\(suffix)")
        }

        return parts.joined(separator: " • ")
    }

    // MARK: - Back-compat aliases used by older code (non-binding)

    public var evBatteryKWh: Double? {
        get { batteryCapacityKWh }
        set { batteryCapacityKWh = newValue }
    }

    public var batteryCapacity: Double? {
        get { batteryCapacityKWh }
        set { batteryCapacityKWh = newValue }
    }

    public var efficiency: Double? {
        get { efficiencyWhPerMile }
        set { efficiencyWhPerMile = newValue }
    }
}
