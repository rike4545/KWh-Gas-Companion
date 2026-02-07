//
//  GarageVehicleSummary 2.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/23/25.
//


//
//  GarageVehicleSummary.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//
//  NOTE:
//  This file intentionally does NOT declare a `GarageView`.
//  Your app’s user-facing Garage is now the Vehicle Profile flow.
//

import SwiftUI
import Foundation

// MARK: - Model

public struct GarageVehicleSummary: Identifiable, Hashable, Sendable {
    public let id: UUID

    public let displayName: String
    public let nickname: String?
    public let make: String
    public let model: String
    public let year: Int?
    public let vin: String?
    public let trim: String?
    public let isPrimary: Bool

    public let odometerMiles: Double?
    public let lifetimeKWh: Double
    public let lifetimeCost: Double
    public let lifetimeMiles: Double?
    public let estimatedDegradationPercent: Double?

    public init(
        id: UUID = UUID(),
        displayName: String,
        nickname: String? = nil,
        make: String,
        model: String,
        year: Int? = nil,
        vin: String? = nil,
        trim: String? = nil,
        isPrimary: Bool = false,
        odometerMiles: Double? = nil,
        lifetimeKWh: Double,
        lifetimeCost: Double,
        lifetimeMiles: Double? = nil,
        estimatedDegradationPercent: Double? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.nickname = nickname
        self.make = make
        self.model = model
        self.year = year
        self.vin = vin
        self.trim = trim
        self.isPrimary = isPrimary
        self.odometerMiles = odometerMiles
        self.lifetimeKWh = lifetimeKWh
        self.lifetimeCost = lifetimeCost
        self.lifetimeMiles = lifetimeMiles
        self.estimatedDegradationPercent = estimatedDegradationPercent
    }
}

// MARK: - Provider + Environment Key (optional)

public struct GarageVehiclesProvider: Sendable {
    public var fetch: @Sendable () async -> [GarageVehicleSummary]
    public init(fetch: @escaping @Sendable () async -> [GarageVehicleSummary]) { self.fetch = fetch }
}

private struct GarageVehiclesProviderKey: EnvironmentKey {
    static let defaultValue: GarageVehiclesProvider? = nil
}

public extension EnvironmentValues {
    var garageVehiclesProvider: GarageVehiclesProvider? {
        get { self[GarageVehiclesProviderKey.self] }
        set { self[GarageVehiclesProviderKey.self] = newValue }
    }
}
