//
//  TPCoordinateCodable.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/18/25.
//


//
//  TripPlannerModels.swift
//  KWh Gas Companion
//
//  Single source of truth for Trip Planner models.
//  Fixes Codable/Hashable issues caused by CLLocationCoordinate2D.
//
//  Swift 6 • iOS 17+
//

import Foundation
import CoreLocation

// MARK: - Helpers

fileprivate struct TPCoordinateCodable: Codable, Hashable {
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ c: CLLocationCoordinate2D) {
        self.latitude = c.latitude
        self.longitude = c.longitude
    }

    var cl: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }

    func hash(into hasher: inout Hasher) {
        // Quantize to reduce “tiny float jitter” hash changes
        hasher.combine(Int((latitude * 1_000_000).rounded()))
        hasher.combine(Int((longitude * 1_000_000).rounded()))
    }
}

fileprivate func tpCoordEqual(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
    abs(a.latitude - b.latitude) < 0.0000005 && abs(a.longitude - b.longitude) < 0.0000005
}

fileprivate func tpCoordHash(_ c: CLLocationCoordinate2D, into hasher: inout Hasher) {
    hasher.combine(Int((c.latitude * 1_000_000).rounded()))
    hasher.combine(Int((c.longitude * 1_000_000).rounded()))
}

// MARK: - Core Models

enum TPChargerNetwork: String, Codable, CaseIterable, Hashable {
    case tesla
    case electrifyAmerica
    case chargePoint
    case evgo
    case shellRecharge
    case unknown
}

struct TPCharger: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var coordinate: CLLocationCoordinate2D
    var maxPowerKW: Double
    var network: TPChargerNetwork
    var priceNote: String?

    enum CodingKeys: String, CodingKey {
        case id, name, coordinate, maxPowerKW, network, priceNote
    }

    init(
        id: String,
        name: String,
        coordinate: CLLocationCoordinate2D,
        maxPowerKW: Double,
        network: TPChargerNetwork,
        priceNote: String? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.maxPowerKW = maxPowerKW
        self.network = network
        self.priceNote = priceNote
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        let coord = try c.decode(TPCoordinateCodable.self, forKey: .coordinate)
        coordinate = coord.cl
        maxPowerKW = try c.decode(Double.self, forKey: .maxPowerKW)
        network = try c.decode(TPChargerNetwork.self, forKey: .network)
        priceNote = try c.decodeIfPresent(String.self, forKey: .priceNote)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(TPCoordinateCodable(coordinate), forKey: .coordinate)
        try c.encode(maxPowerKW, forKey: .maxPowerKW)
        try c.encode(network, forKey: .network)
        try c.encodeIfPresent(priceNote, forKey: .priceNote)
    }

    static func == (lhs: TPCharger, rhs: TPCharger) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        tpCoordEqual(lhs.coordinate, rhs.coordinate) &&
        lhs.maxPowerKW == rhs.maxPowerKW &&
        lhs.network == rhs.network &&
        lhs.priceNote == rhs.priceNote
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        tpCoordHash(coordinate, into: &hasher)
        hasher.combine(maxPowerKW)
        hasher.combine(network)
        hasher.combine(priceNote)
    }
}

struct TPChargingStop: Identifiable, Codable, Hashable {
    var id: UUID
    var charger: TPCharger
    var arriveSOC: Double
    var departSOC: Double
    /// Seconds (Double). TripPlannerView expects this.
    var chargeSeconds: Double

    init(charger: TPCharger, arriveSOC: Double, departSOC: Double, chargeSeconds: Double) {
        self.id = UUID()
        self.charger = charger
        self.arriveSOC = arriveSOC
        self.departSOC = departSOC
        self.chargeSeconds = chargeSeconds
    }
}

struct TPRoute: Codable, Hashable {
    var distanceMeters: Double
    var durationSeconds: Double
    var fullPolyline: [CLLocationCoordinate2D]

    enum CodingKeys: String, CodingKey {
        case distanceMeters, durationSeconds, fullPolyline
    }

    init(distanceMeters: Double, durationSeconds: Double, fullPolyline: [CLLocationCoordinate2D]) {
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.fullPolyline = fullPolyline
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        distanceMeters = try c.decode(Double.self, forKey: .distanceMeters)
        durationSeconds = try c.decode(Double.self, forKey: .durationSeconds)
        let poly = try c.decode([TPCoordinateCodable].self, forKey: .fullPolyline)
        fullPolyline = poly.map { $0.cl }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(distanceMeters, forKey: .distanceMeters)
        try c.encode(durationSeconds, forKey: .durationSeconds)
        try c.encode(fullPolyline.map { TPCoordinateCodable($0) }, forKey: .fullPolyline)
    }

    static func == (lhs: TPRoute, rhs: TPRoute) -> Bool {
        guard lhs.distanceMeters == rhs.distanceMeters,
              lhs.durationSeconds == rhs.durationSeconds,
              lhs.fullPolyline.count == rhs.fullPolyline.count
        else { return false }
        for (a, b) in zip(lhs.fullPolyline, rhs.fullPolyline) {
            if !tpCoordEqual(a, b) { return false }
        }
        return true
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(distanceMeters)
        hasher.combine(durationSeconds)
        hasher.combine(fullPolyline.count)
        // hash first/last few points to keep it stable and cheap
        if let first = fullPolyline.first { tpCoordHash(first, into: &hasher) }
        if fullPolyline.count > 2 { tpCoordHash(fullPolyline[fullPolyline.count/2], into: &hasher) }
        if let last = fullPolyline.last { tpCoordHash(last, into: &hasher) }
    }
}

struct TPTripPlan: Codable, Hashable {
    var route: TPRoute
    var stops: [TPChargingStop]
}

struct TPVehicleProfile: Codable, Hashable {
    var name: String
    var batteryKWh: Double
    var baselineWhPerMile: Double
    var maxDCPowerKW: Double
    var arrivalBuffer: Double
    var targetDepartSOC: Double
}

struct TPEnvironmentProfile: Codable, Hashable {
    var temperatureF: Double
    var cruiseMPH: Double
    var windDeltaMPH: Double
    var considerElevation: Bool
}

struct TPTripRequest: Codable, Hashable {
    var origin: CLLocationCoordinate2D
    var destination: CLLocationCoordinate2D
    var startSOC: Double
    var vehicle: TPVehicleProfile
    var env: TPEnvironmentProfile
    var corridorMeters: Double
    var waypoints: [CLLocationCoordinate2D]

    enum CodingKeys: String, CodingKey {
        case origin, destination, startSOC, vehicle, env, corridorMeters, waypoints
    }

    init(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        startSOC: Double,
        vehicle: TPVehicleProfile,
        env: TPEnvironmentProfile,
        corridorMeters: Double,
        waypoints: [CLLocationCoordinate2D] = []
    ) {
        self.origin = origin
        self.destination = destination
        self.startSOC = startSOC
        self.vehicle = vehicle
        self.env = env
        self.corridorMeters = corridorMeters
        self.waypoints = waypoints
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        origin = try c.decode(TPCoordinateCodable.self, forKey: .origin).cl
        destination = try c.decode(TPCoordinateCodable.self, forKey: .destination).cl
        startSOC = try c.decode(Double.self, forKey: .startSOC)
        vehicle = try c.decode(TPVehicleProfile.self, forKey: .vehicle)
        env = try c.decode(TPEnvironmentProfile.self, forKey: .env)
        corridorMeters = try c.decode(Double.self, forKey: .corridorMeters)
        waypoints = try c.decode([TPCoordinateCodable].self, forKey: .waypoints).map { $0.cl }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(TPCoordinateCodable(origin), forKey: .origin)
        try c.encode(TPCoordinateCodable(destination), forKey: .destination)
        try c.encode(startSOC, forKey: .startSOC)
        try c.encode(vehicle, forKey: .vehicle)
        try c.encode(env, forKey: .env)
        try c.encode(corridorMeters, forKey: .corridorMeters)
        try c.encode(waypoints.map { TPCoordinateCodable($0) }, forKey: .waypoints)
    }

    static func == (lhs: TPTripRequest, rhs: TPTripRequest) -> Bool {
        tpCoordEqual(lhs.origin, rhs.origin) &&
        tpCoordEqual(lhs.destination, rhs.destination) &&
        lhs.startSOC == rhs.startSOC &&
        lhs.vehicle == rhs.vehicle &&
        lhs.env == rhs.env &&
        lhs.corridorMeters == rhs.corridorMeters &&
        lhs.waypoints.count == rhs.waypoints.count &&
        zip(lhs.waypoints, rhs.waypoints).allSatisfy(tpCoordEqual)
    }

    func hash(into hasher: inout Hasher) {
        tpCoordHash(origin, into: &hasher)
        tpCoordHash(destination, into: &hasher)
        hasher.combine(startSOC)
        hasher.combine(vehicle)
        hasher.combine(env)
        hasher.combine(Int(corridorMeters.rounded()))
        hasher.combine(waypoints.count)
        if let first = waypoints.first { tpCoordHash(first, into: &hasher) }
        if let last = waypoints.last { tpCoordHash(last, into: &hasher) }
    }
}

// Optional model some projects use (kept here so it won’t break builds if referenced)
struct TPChargerPOI: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var coordinate: CLLocationCoordinate2D
    var maxPowerKW: Double
    var network: TPChargerNetwork

    enum CodingKeys: String, CodingKey { case id, name, coordinate, maxPowerKW, network }

    init(id: String, name: String, coordinate: CLLocationCoordinate2D, maxPowerKW: Double, network: TPChargerNetwork) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.maxPowerKW = maxPowerKW
        self.network = network
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        coordinate = try c.decode(TPCoordinateCodable.self, forKey: .coordinate).cl
        maxPowerKW = try c.decode(Double.self, forKey: .maxPowerKW)
        network = try c.decode(TPChargerNetwork.self, forKey: .network)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(TPCoordinateCodable(coordinate), forKey: .coordinate)
        try c.encode(maxPowerKW, forKey: .maxPowerKW)
        try c.encode(network, forKey: .network)
    }

    static func == (lhs: TPChargerPOI, rhs: TPChargerPOI) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        tpCoordEqual(lhs.coordinate, rhs.coordinate) &&
        lhs.maxPowerKW == rhs.maxPowerKW &&
        lhs.network == rhs.network
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        tpCoordHash(coordinate, into: &hasher)
        hasher.combine(maxPowerKW)
        hasher.combine(network)
    }
}
