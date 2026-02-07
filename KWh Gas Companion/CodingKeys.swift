//
//  CodingKeys.swift
//  KWh Gas Companion
//
//  Created by Bryan on 10/19/25.
//


// TPGeoCodable.swift
import CoreLocation

extension CLLocationCoordinate2D: @retroactive Codable {
    private enum CodingKeys: String, CodingKey { case latitude, longitude }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(latitude, forKey: .latitude)
        try c.encode(longitude, forKey: .longitude)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let lat = try c.decode(Double.self, forKey: .latitude)
        let lon = try c.decode(Double.self, forKey: .longitude)
        self.init(latitude: lat, longitude: lon)
    }
}
