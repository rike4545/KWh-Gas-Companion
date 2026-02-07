//
//  ChargerSite.swift
//  My KWh Companion
//
//  Canonical model for public EV charging sites.
//  • Lean-only data model (no MapKit search, no providers here)
//  • Explicit Equatable/Hashable by `id`
//  • Codable with safe lat/lon encoding
//

import Foundation
import CoreLocation

public struct ChargerSite: Identifiable, Codable {
    public enum Network: String, Codable {
        case tesla
        case other
    }

    public enum Access: String, Codable {
        // Rough access hints; refine elsewhere as needed
        case teslaOnly
        case nacsOpen
        case ccs
        case chademo
        case mixed
    }

    // MARK: Identity & Basics
    public let id: String                   // stable identifier (e.g., slug, or "<lat>,<lon>")
    public var name: String
    public var address: String?

    // MARK: Location
    public var coordinate: CLLocationCoordinate2D

    // MARK: Network / Capabilities
    public var network: Network
    public var access: Access
    public var maxPowerKW: Double?
    public var stalls: Int?

    // MARK: Initializers
    public init(
        id: String,
        name: String,
        address: String? = nil,
        coordinate: CLLocationCoordinate2D,
        network: Network,
        access: Access,
        maxPowerKW: Double? = nil,
        stalls: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.network = network
        self.access = access
        self.maxPowerKW = maxPowerKW
        self.stalls = stalls
    }
}

// MARK: - Equatable / Hashable (by id only)
extension ChargerSite: Equatable {
    public static func == (lhs: ChargerSite, rhs: ChargerSite) -> Bool {
        lhs.id == rhs.id
    }
}

extension ChargerSite: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Codable helpers for CLLocationCoordinate2D
private struct _CoordDTO: Codable {
    let lat: Double
    let lon: Double
}

extension ChargerSite {
    private enum CodingKeys: String, CodingKey {
        case id, name, address, coordinate, network, access, maxPowerKW, stalls
        case latitude, longitude // accept legacy keys if present
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.address = try c.decodeIfPresent(String.self, forKey: .address)
        self.network = try c.decode(Network.self, forKey: .network)
        self.access = try c.decode(Access.self, forKey: .access)
        self.maxPowerKW = try c.decodeIfPresent(Double.self, forKey: .maxPowerKW)
        self.stalls = try c.decodeIfPresent(Int.self, forKey: .stalls)

        // Prefer {lat, lon} under `coordinate` if present
        if let coordDTO = try? c.decode(_CoordDTO.self, forKey: .coordinate) {
            self.coordinate = CLLocationCoordinate2D(latitude: coordDTO.lat, longitude: coordDTO.lon)
        } else {
            // Legacy: decode latitude/longitude if present
            let lat = try c.decode(Double.self, forKey: .latitude)
            let lon = try c.decode(Double.self, forKey: .longitude)
            self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(address, forKey: .address)
        try c.encode(network, forKey: .network)
        try c.encode(access, forKey: .access)
        try c.encodeIfPresent(maxPowerKW, forKey: .maxPowerKW)
        try c.encodeIfPresent(stalls, forKey: .stalls)
        try c.encode(_CoordDTO(lat: coordinate.latitude, lon: coordinate.longitude), forKey: .coordinate)
    }
}

// MARK: - Convenience
public extension ChargerSite {
    /// Great-circle distance in meters to another coordinate.
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        let a = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let b = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return a.distance(from: b)
    }
}
