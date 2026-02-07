//
//  EVSite.swift
//  KWh Gas Companion
//
//  Created by Bryan on 9/15/25.
//


//
//  EVSite.swift
//  KWh Gas Companion
//
//  Unified model for a public EV charging site.
//  - Primary source: supercharge.info
//  - Fallback source: Apple Maps POI (.evCharger)
//  - Codable with safe lat/lon encoding
//  - Hashable/Equatable by stable id
//  - Sendable for concurrency
//

import Foundation
import MapKit
import CoreLocation

public struct EVSite: Identifiable, Hashable, Codable, Sendable {
    // MARK: Types
    public enum Source: String, Codable, Sendable {
        case supercharge
        case apple
    }

    public enum Status: String, Codable, Sendable {
        case open
        case construction
        case permit
        case closed
        case unknown
    }

    // MARK: Stored properties
    public let id: String
    public var title: String
    public var coordinate: CLLocationCoordinate2D
    public var source: Source
    public var status: Status
    public var stalls: Int?
    public var powerKW: Int?
    public var addressLine: String?
    public var city: String?
    public var state: String?
    public var country: String?
    public var url: URL?

    /// Transient distance from current user center (meters). Not required for identity.
    public var distanceMeters: CLLocationDistance?

    // MARK: Init
    public init(
        id: String,
        title: String,
        coordinate: CLLocationCoordinate2D,
        source: Source,
        status: Status = .unknown,
        stalls: Int? = nil,
        powerKW: Int? = nil,
        addressLine: String? = nil,
        city: String? = nil,
        state: String? = nil,
        country: String? = nil,
        url: URL? = nil,
        distanceMeters: CLLocationDistance? = nil
    ) {
        self.id = id
        self.title = title
        self.coordinate = coordinate
        self.source = source
        self.status = status
        self.stalls = stalls
        self.powerKW = powerKW
        self.addressLine = addressLine
        self.city = city
        self.state = state
        self.country = country
        self.url = url
        self.distanceMeters = distanceMeters
    }

    // MARK: Hashable/Equatable
    public static func == (lhs: EVSite, rhs: EVSite) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Codable (lat/lon encoding)

extension EVSite {
    private enum CodingKeys: String, CodingKey {
        case id, title, source, status, stalls, powerKW, addressLine, city, state, country, url, distanceMeters
        case latitude, longitude
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(String.self, forKey: .id)
        title        = try c.decode(String.self, forKey: .title)
        source       = try c.decode(Source.self, forKey: .source)
        status       = try c.decodeIfPresent(Status.self, forKey: .status) ?? .unknown
        stalls       = try c.decodeIfPresent(Int.self, forKey: .stalls)
        powerKW      = try c.decodeIfPresent(Int.self, forKey: .powerKW)
        addressLine  = try c.decodeIfPresent(String.self, forKey: .addressLine)
        city         = try c.decodeIfPresent(String.self, forKey: .city)
        state        = try c.decodeIfPresent(String.self, forKey: .state)
        country      = try c.decodeIfPresent(String.self, forKey: .country)
        url          = try c.decodeIfPresent(URL.self, forKey: .url)
        distanceMeters = try c.decodeIfPresent(Double.self, forKey: .distanceMeters)

        let lat = try c.decode(Double.self, forKey: .latitude)
        let lon = try c.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(source, forKey: .source)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(stalls, forKey: .stalls)
        try c.encodeIfPresent(powerKW, forKey: .powerKW)
        try c.encodeIfPresent(addressLine, forKey: .addressLine)
        try c.encodeIfPresent(city, forKey: .city)
        try c.encodeIfPresent(state, forKey: .state)
        try c.encodeIfPresent(country, forKey: .country)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encodeIfPresent(distanceMeters, forKey: .distanceMeters)

        try c.encode(coordinate.latitude, forKey: .latitude)
        try c.encode(coordinate.longitude, forKey: .longitude)
    }
}

// MARK: - Convenience

public extension EVSite {
    /// Returns a copy with distanceMeters set from a point.
    func withDistance(from center: CLLocationCoordinate2D) -> EVSite {
        var copy = self
        let d = CLLocation(latitude: center.latitude, longitude: center.longitude)
            .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        copy.distanceMeters = d
        return copy
    }

    /// An `MKMapItem` for opening in Apple Maps.
    var mapItem: MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = title
        return item
    }

    /// Apple Maps driving directions URL (web, always works).
    var appleMapsURL: URL {
        URL(string: "https://maps.apple.com/?daddr=\(coordinate.latitude),\(coordinate.longitude)&dirflg=d")!
    }

    /// Google Maps directions URL (web; use comgooglemaps:// separately if available).
    var googleMapsWebURL: URL {
        URL(string: "https://maps.google.com/?daddr=\(coordinate.latitude),\(coordinate.longitude)&directionsmode=driving")!
    }
}
