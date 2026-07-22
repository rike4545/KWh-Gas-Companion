//
//  SuperchargeInfoClient 2.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//
//  Minimal supercharge.info client + models
//  Fixes missing types:
//  - SuperchargeInfoSite
//  - SuperchargeInfoDatabaseInfo
//
//  Endpoints:
//  - https://supercharge.info/service/supercharge/allSites
//  - https://supercharge.info/service/supercharge/databaseInfo
//

import Foundation
import CoreLocation

// MARK: - Models (supercharge.info)

public struct SuperchargeInfoSite: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let locationId: String
    public let name: String?
    public let status: String?

    public let stallCount: Int?
    public let powerKilowatt: Int?

    public let gps: GPS
    public let address: Address?

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: gps.latitude, longitude: gps.longitude)
    }

    public struct GPS: Codable, Hashable, Sendable {
        public let latitude: Double
        public let longitude: Double

        public init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)

            // supercharge.info has had varying key names; decode common variants defensively.
            func decodeFirst(_ keys: [CodingKeys]) -> Double? {
                for k in keys {
                    if let v = try? c.decode(Double.self, forKey: k) { return v }
                    if let s = try? c.decode(String.self, forKey: k), let v = Double(s) { return v }
                }
                return nil
            }

            let lat = decodeFirst([.latitude, .lat, .y])
            let lon = decodeFirst([.longitude, .lng, .lon, .x])

            guard let latitude = lat, let longitude = lon else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Missing GPS coordinates"
                ))
            }

            self.latitude = latitude
            self.longitude = longitude
        }

        // ✅ Required because we implemented init(from:), so Swift won’t synthesize Encodable.
        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            // Encode canonical keys
            try c.encode(latitude, forKey: .latitude)
            try c.encode(longitude, forKey: .longitude)
        }

        private enum CodingKeys: String, CodingKey {
            case latitude, longitude
            case lat, lng, lon
            case x, y
        }
    }

    public struct Address: Codable, Hashable, Sendable {
        public let street: String?
        public let city: String?
        public let state: String?
        public let zip: String?
        public let country: String?
        public let county: String?

        public init(
            street: String? = nil,
            city: String? = nil,
            state: String? = nil,
            zip: String? = nil,
            country: String? = nil,
            county: String? = nil
        ) {
            self.street = street
            self.city = city
            self.state = state
            self.zip = zip
            self.country = country
            self.county = county
        }
    }
}

public struct SuperchargeInfoDatabaseInfo: Codable, Hashable, Sendable {
    /// Milliseconds since epoch
    public let lastModified: Int64?
    public let lastModifiedString: String?

    public var lastModifiedDate: Date? {
        guard let lastModified else { return nil }
        return Date(timeIntervalSince1970: Double(lastModified) / 1000.0)
    }

    public init(lastModified: Int64?, lastModifiedString: String?) {
        self.lastModified = lastModified
        self.lastModifiedString = lastModifiedString
    }
}

// MARK: - Client

public final class SuperchargeInfoClient: ObservableObject {

    public static let shared = SuperchargeInfoClient()
    public init() {}

    private let base = URL(string: "https://supercharge.info/service/supercharge")!

    private var allSitesURL: URL { base.appendingPathComponent("allSites") }
    private var dbInfoURL: URL { base.appendingPathComponent("databaseInfo") }

    /// Fetches all sites (worldwide). Filter to US in your store/viewmodel.
    public func fetchAllSites(timeout: TimeInterval = 45) async throws -> [SuperchargeInfoSite] {
        var req = URLRequest(url: allSitesURL)
        req.timeoutInterval = timeout
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        return try decoder.decode([SuperchargeInfoSite].self, from: data)
    }

    /// Fetches DB info: {"lastModified":<ms>,"lastModifiedString":"..."}
    public func fetchDatabaseInfo(timeout: TimeInterval = 20) async throws -> SuperchargeInfoDatabaseInfo {
        var req = URLRequest(url: dbInfoURL)
        req.timeoutInterval = timeout
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(SuperchargeInfoDatabaseInfo.self, from: data)
    }
}
