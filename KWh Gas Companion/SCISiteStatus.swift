//  SCISiteModels.swift
//  KWh Gas Companion
//
//  Core data models used across the app.
//  IMPORTANT: This file should be the ONLY place these types are defined.
//

import Foundation

public enum SCISiteStatus: String, Codable, CaseIterable, Equatable {
    case open, construction, permit, closed, unknown
}

public struct Address: Codable, Hashable, Equatable {
    public var street: String?
    public var city: String?
    public var state: String?
    public var zip: String?
    public var country: String?
    public init(street: String? = nil, city: String? = nil, state: String? = nil, zip: String? = nil, country: String? = nil) {
        self.street = street
        self.city = city
        self.state = state
        self.zip = zip
        self.country = country
    }
}

public struct GPS: Codable, Hashable, Equatable {
    public var latitude: Double
    public var longitude: Double
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct SCISite: Identifiable, Codable, Hashable, Equatable {
    public var id: Int
    public var name: String
    public var address: Address
    public var gps: GPS
    public var status: SCISiteStatus
    public var stallCount: Int?
    public var maxPower: Int?
    /// Optional, human-friendly plug summary elements, e.g. ["NACS=8","CCS1=4"]
    public var plugs: [String]?

    public init(
        id: Int,
        name: String,
        address: Address,
        gps: GPS,
        status: SCISiteStatus,
        stallCount: Int? = nil,
        maxPower: Int? = nil,
        plugs: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.gps = gps
        self.status = status
        self.stallCount = stallCount
        self.maxPower = maxPower
        self.plugs = plugs
    }
}

/// Optional richer details for the sheet. Populated on demand from the site-detail endpoint.
public struct SCISiteDetail: Codable, Equatable {
    public var id: Int
    /// Versioned stalls, e.g. ["V3": 8, "V4": 12]
    public var stallsByVersion: [String:Int]?
    /// Plug counts, e.g. ["NACS": 8, "CCS1": 4]
    public var plugsByType: [String:Int]?
    public var parking: String?
    /// If provided by API (e.g., "2020-12-11")
    public var dateOpened: Date?
    /// Feet if available (client converts from meters if necessary)
    public var elevationFeet: Int?
    /// Hours string or "24/7"
    public var hours: String?
    /// Free-form note for compatibility info
    public var otherEVsNote: String?
}
