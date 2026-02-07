//
//  SuperchargerStationDatabase.swift
//  KWh Gas Companion
//
//  Created by Bryan on 11/30/25.
//


//
//  SuperchargerStationDatabase.swift
//  My KWh Companion
//
//  Loads Tesla Supercharger metadata from a bundled JSON file
//  and finds the nearest station to a given CLLocation.
//
//  • On-device only (no network calls)
//  • Uses a small in-memory cache to avoid decoding repeatedly
//

import Foundation
import CoreLocation

enum SuperchargerStationDatabase {

    // MARK: - Internal cache

    /// Cached list of stations decoded from the bundled JSON.
    private static var cachedStations: [LocalSuperchargerStation]?

    // MARK: - Public API

    /// Load all Superchargers from superchargers.json in the main bundle.
    ///
    /// Expected JSON format:
    /// [
    ///   {
    ///     "id": "lakegrove-ny",
    ///     "name": "Lake Grove, NY Supercharger",
    ///     "latitude": 40.857,
    ///     "longitude": -73.120,
    ///     "city": "Lake Grove",
    ///     "state": "NY",
    ///     "country": "USA"
    ///   },
    ///   ...
    /// ]
    static func loadStations() -> [LocalSuperchargerStation] {
        if let cached = cachedStations {
            return cached
        }

        guard let url = Bundle.main.url(forResource: "superchargers", withExtension: "json") else {
            print("SuperchargerStationDatabase: superchargers.json not found in bundle")
            cachedStations = []
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([LocalSuperchargerStation].self, from: data)
            cachedStations = decoded
            return decoded
        } catch {
            print("SuperchargerStationDatabase: failed to decode superchargers.json: \(error)")
            cachedStations = []
            return []
        }
    }

    /// Find the nearest station to a location among a given list of stations.
    ///
    /// - Parameters:
    ///   - location: User location.
    ///   - stations: Candidate stations to search within.
    ///   - maxDistanceMeters: Optional maximum distance; if provided and no
    ///                         station is within this radius, returns nil.
    static func nearestStation(
        to location: CLLocation,
        among stations: [LocalSuperchargerStation],
        maxDistanceMeters: CLLocationDistance? = nil
    ) -> LocalSuperchargerStation? {
        guard !stations.isEmpty else { return nil }

        let nearest = stations.min { lhs, rhs in
            let lLoc = CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
            let rLoc = CLLocation(latitude: rhs.latitude, longitude: rhs.longitude)
            return lLoc.distance(from: location) < rLoc.distance(from: location)
        }

        guard let nearestStation = nearest else { return nil }

        if let maxDistance = maxDistanceMeters {
            let stationLocation = CLLocation(latitude: nearestStation.latitude,
                                             longitude: nearestStation.longitude)
            let distance = stationLocation.distance(from: location)
            if distance > maxDistance {
                return nil
            }
        }

        return nearestStation
    }

    /// Convenience overload that searches all known stations from the bundled JSON.
    static func nearestStation(
        to location: CLLocation,
        maxDistanceMeters: CLLocationDistance? = nil
    ) -> LocalSuperchargerStation? {
        let all = loadStations()
        return nearestStation(to: location, among: all, maxDistanceMeters: maxDistanceMeters)
    }
}
