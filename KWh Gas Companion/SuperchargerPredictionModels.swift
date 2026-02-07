//
//  SuperchargerPredictionModels.swift
//  KWh Gas Companion
//
//  Local station + observation models used by SuperchargerStationDatabase.
//

import Foundation
import CoreLocation

public struct LocalSuperchargerStation: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let city: String?
    public let state: String?
    public let country: String?

    public init(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double,
        city: String? = nil,
        state: String? = nil,
        country: String? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.city = city
        self.state = state
        self.country = country
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

public struct PriceObservation: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var stationId: String
    public var timestamp: Date
    public var pricePerKWh: Double

    public init(stationId: String, timestamp: Date, pricePerKWh: Double) {
        self.stationId = stationId
        self.timestamp = timestamp
        self.pricePerKWh = pricePerKWh
    }
}

public struct PricePredictionWindow: Hashable {
    public let start: Date
    public let end: Date
    public let expectedPricePerKWh: Double

    public init(start: Date, end: Date, expectedPricePerKWh: Double) {
        self.start = start
        self.end = end
        self.expectedPricePerKWh = expectedPricePerKWh
    }
}

public struct StationPrediction: Hashable {
    public let station: LocalSuperchargerStation
    public let currentPrice: Double?
    public let bestWindow: PricePredictionWindow?

    public init(station: LocalSuperchargerStation, currentPrice: Double?, bestWindow: PricePredictionWindow?) {
        self.station = station
        self.currentPrice = currentPrice
        self.bestWindow = bestWindow
    }
}
