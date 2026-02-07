//
//  SiteStore.swift
//  My KWh Companion
//
//  Central loader for nearby public EV charging sites.
//  • Primary: supercharge.info (JSON)
//  • Fallback: Apple Maps POI (.evCharger) if primary fails/empty
//  • Preloads up to 288 nearest sites (no source mixing)
//  • Lightweight in-memory cache keyed by coarse grid around user
//
//  iOS 17+ • Swift 6
//

import Foundation
import MapKit
import CoreLocation

@MainActor
final class SiteStore: ObservableObject {
    // MARK: Singleton (legacy compat for existing call sites)
    static let live: SiteStore = SiteStore()

    // MARK: State

    enum LoadState: Equatable {
        case idle
        case loadingPrimary
        case primaryLoaded            // loaded from supercharge.info
        case primaryFailedLoadingBackup
        case backupLoaded             // loaded from Apple POI
        case error(String)
    }

    /// Preloaded sites (sorted by distance; capped to `preloadMax`)
    @Published private(set) var allSites: [EVSite] = []

    /// Sites filtered to current radius (consumer-facing array)
    @Published private(set) var sites: [EVSite] = []

    @Published private(set) var state: LoadState = .idle

    // Echo of last inputs to support re-filter without refetch
    @Published private(set) var lastUserCoordinate: CLLocationCoordinate2D?
    @Published private(set) var lastRadiusMeters: Double = 0

    /// Human-friendly label for toolbars
    var sourceLabel: String {
        switch state {
        case .primaryLoaded: return "supercharge.info"
        case .backupLoaded:  return "Apple"
        default:             return "—"
        }
    }

    // MARK: Tuning

    /// Max preloaded items from primary source (after distance sort)
    private let preloadMax: Int = 288

    /// Cache entry lifetime (seconds)
    private let cacheTTL: TimeInterval = 30 * 60

    // MARK: In-Memory Cache

    private struct CacheEntry {
        let timestamp: Date
        let sites: [EVSite]
        let sourceWasPrimary: Bool
    }

    /// Coarse-grid cache (keyed by ~0.25° lat/lon cells)
    private static var memoryCache: [String: CacheEntry] = [:]

    // MARK: Public API

    /// Load sites near a coordinate. Tries supercharge.info first; falls back to Apple EV chargers if needed.
    /// - Parameters:
    ///   - userCoordinate: Center coordinate.
    ///   - radiusMeters: Radius for the filtered `sites` array (does not affect 288 preload).
    ///   - allowCache: Use recent in-memory cache if available.
    func load(
        userCoordinate: CLLocationCoordinate2D,
        radiusMeters: Double,
        allowCache: Bool = true
    ) async {
        lastUserCoordinate = userCoordinate
        lastRadiusMeters = radiusMeters

        // Cache check
        if allowCache,
           let cached = Self.memoryCache[gridKey(for: userCoordinate)],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            self.allSites = cached.sites
            self.state = cached.sourceWasPrimary ? .primaryLoaded : .backupLoaded
            self.applyRadiusFilter()
            return
        }

        // Primary fetch
        state = .loadingPrimary
        do {
            let primary = try await fetchSuperchargeInfo()
            let nearest = Self.sortedNearest(sites: primary, to: userCoordinate).prefix(preloadMax)
            let preloaded = Array(nearest)

            if preloaded.isEmpty {
                // Fallback (no mixing)
                state = .primaryFailedLoadingBackup
                let backup = try await fetchAppleEVChargers(center: userCoordinate, radiusMeters: radiusMeters)
                let backupSorted = Self.sortedNearest(sites: backup, to: userCoordinate).prefix(preloadMax)
                self.allSites = Array(backupSorted)
                self.state = .backupLoaded
                Self.memoryCache[gridKey(for: userCoordinate)] = CacheEntry(
                    timestamp: Date(), sites: self.allSites, sourceWasPrimary: false
                )
            } else {
                self.allSites = preloaded
                self.state = .primaryLoaded
                Self.memoryCache[gridKey(for: userCoordinate)] = CacheEntry(
                    timestamp: Date(), sites: self.allSites, sourceWasPrimary: true
                )
            }
            applyRadiusFilter()
        } catch {
            // Primary failed; fallback to Apple
            state = .primaryFailedLoadingBackup
            do {
                let backup = try await fetchAppleEVChargers(center: userCoordinate, radiusMeters: radiusMeters)
                let backupSorted = Self.sortedNearest(sites: backup, to: userCoordinate).prefix(preloadMax)
                self.allSites = Array(backupSorted)
                self.state = .backupLoaded
                Self.memoryCache[gridKey(for: userCoordinate)] = CacheEntry(
                    timestamp: Date(), sites: self.allSites, sourceWasPrimary: false
                )
                applyRadiusFilter()
            } catch {
                self.allSites = []
                self.sites = []
                self.state = .error("Could not load chargers from either source.")
            }
        }
    }

    /// Re-applies the radius filter on `allSites` using `lastRadiusMeters` / `lastUserCoordinate`.
    func applyRadiusFilter() {
        guard let center = lastUserCoordinate else {
            self.sites = self.allSites
            return
        }
        self.sites = Self.filteredWithinRadius(sites: allSites, center: center, radiusMeters: lastRadiusMeters)
    }

    /// Update radius (meters) and re-filter without refetching.
    func updateRadius(_ radiusMeters: Double) {
        self.lastRadiusMeters = radiusMeters
        applyRadiusFilter()
    }

    /// Clear in-memory cache (manual invalidation).
    func clearCache() {
        Self.memoryCache.removeAll()
    }

    // MARK: Primary (supercharge.info)

    private func fetchSuperchargeInfo() async throws -> [EVSite] {
        guard let url = URL(string: "https://supercharge.info/service/supercharge/allSites") else {
            throw URLError(.badURL)
        }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        let raws = try decoder.decode([SCISiteDTO].self, from: data)

        let mapped: [EVSite] = raws.compactMap { raw in
            guard let lat = raw.latitude, let lon = raw.longitude else { return nil }
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)

            let status: EVSite.Status = {
                switch (raw.status ?? "").lowercased() {
                case "open":         return .open
                case "construction": return .construction
                case "permit":       return .permit
                case "closed":       return .closed
                default:             return .unknown
                }
            }()

            return EVSite(
                id: "sci-\(raw.id ?? Int.random(in: 1...9_999_999))",
                title: raw.name ?? "Supercharger",
                coordinate: coord,
                source: .supercharge,
                status: status,
                stalls: raw.stalls,
                powerKW: raw.powerKilowatt,
                addressLine: nil,
                city: raw.addressCity,
                state: raw.addressState,
                country: raw.addressCountry,
                url: URL(string: raw.urlTesla ?? ""),
                distanceMeters: nil
            )
        }

        return mapped
    }

    // MARK: Backup (Apple POI)

    private func fetchAppleEVChargers(center: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [EVSite] {
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusMeters * 2.2,
            longitudinalMeters: radiusMeters * 2.2
        )

        let request = MKLocalSearch.Request()
        request.region = region
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.evCharger])

        let response = try await MKLocalSearch(request: request).start()

        let mapped: [EVSite] = response.mapItems.compactMap { item in
            guard let loc = item.placemark.location else { return nil }
            return EVSite(
                id: "apple-\(item.placemark.coordinate.latitude)-\(item.placemark.coordinate.longitude)",
                title: item.name ?? "EV Charger",
                coordinate: item.placemark.coordinate,
                source: .apple,
                status: .unknown,
                stalls: nil,
                powerKW: nil,
                addressLine: [item.placemark.subThoroughfare, item.placemark.thoroughfare]
                    .compactMap { $0 }.joined(separator: " ").nilIfEmpty,
                city: item.placemark.locality,
                state: item.placemark.administrativeArea,
                country: item.placemark.isoCountryCode,
                url: item.url,
                distanceMeters: loc.distance(from: CLLocation(latitude: center.latitude, longitude: center.longitude))
            )
        }

        return mapped
    }

    // MARK: Helpers

    private static func sortedNearest(sites: [EVSite], to center: CLLocationCoordinate2D) -> [EVSite] {
        let centerLoc = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return sites
            .map { site in
                var s = site
                s.distanceMeters = centerLoc.distance(
                    from: CLLocation(latitude: s.coordinate.latitude, longitude: s.coordinate.longitude)
                )
                return s
            }
            .sorted { ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude) }
    }

    private static func filteredWithinRadius(
        sites: [EVSite],
        center: CLLocationCoordinate2D,
        radiusMeters: Double
    ) -> [EVSite] {
        guard radiusMeters > 0 else { return sites }
        return sites.filter { ($0.distanceMeters ?? .greatestFiniteMagnitude) <= radiusMeters }
    }

    /// Coarse grid key (~0.25° cells) for cache entries.
    private func gridKey(for coord: CLLocationCoordinate2D, cellDegrees: Double = 0.25) -> String {
        func snap(_ v: Double, _ step: Double) -> Double { (v / step).rounded(.toNearestOrAwayFromZero) * step }
        let la = snap(coord.latitude, cellDegrees)
        let lo = snap(coord.longitude, cellDegrees)
        return String(format: "%.2f,%.2f", la, lo)
    }
}

// MARK: - Private DTO (supercharge.info)

private struct SCISiteDTO: Decodable {
    let id: Int?
    let name: String?
    let status: String?
    let latitude: Double?
    let longitude: Double?
    let stalls: Int?
    let powerKilowatt: Int?
    let urlTesla: String?
    let addressCity: String?
    let addressState: String?
    let addressCountry: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, status, latitude, longitude, stalls, stallCount, powerKilowatt, power, url, teslaUrl, gps, address
        case addressCity, addressState, addressCountry
    }

    private struct GPS: Decodable { let latitude: Double?; let longitude: Double? }
    private struct Address: Decodable { let city: String?; let state: String?; let country: String? }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try? c.decodeIfPresent(Int.self, forKey: .id)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Supercharger"
        status = try? c.decodeIfPresent(String.self, forKey: .status)

        // Coordinates (multiple shapes supported)
        if let lat = try? c.decodeIfPresent(Double.self, forKey: .latitude),
           let lon = try? c.decodeIfPresent(Double.self, forKey: .longitude) {
            latitude = lat; longitude = lon
        } else if let gps = try? c.decodeIfPresent(GPS.self, forKey: .gps) {
            latitude = gps.latitude; longitude = gps.longitude
        } else {
            latitude = nil; longitude = nil
        }

        stalls = (try? c.decodeIfPresent(Int.self, forKey: .stalls))
            ?? (try? c.decodeIfPresent(Int.self, forKey: .stallCount))
        powerKilowatt = (try? c.decodeIfPresent(Int.self, forKey: .powerKilowatt))
            ?? (try? c.decodeIfPresent(Int.self, forKey: .power))

        // URL could be in different keys
        urlTesla = (try? c.decodeIfPresent(String.self, forKey: .teslaUrl))
            ?? (try? c.decodeIfPresent(String.self, forKey: .url))

        // Address may be flat or nested
        if let addr = try? c.decodeIfPresent(Address.self, forKey: .address) {
            addressCity = addr.city; addressState = addr.state; addressCountry = addr.country
        } else {
            addressCity = try? c.decodeIfPresent(String.self, forKey: .addressCity)
            addressState = try? c.decodeIfPresent(String.self, forKey: .addressState)
            addressCountry = try? c.decodeIfPresent(String.self, forKey: .addressCountry)
        }
    }
}

// MARK: - Small convenience

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
