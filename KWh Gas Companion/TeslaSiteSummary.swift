//
//  TeslaSiteSummary.swift
//  KWh Gas Companion
//
//

// TeslaSitesService.swift
// My KWh Companion
//
// Swift 6 / iOS 17+
// Fetch Tesla sites for the given bounds; hydrates details lazily.
// Includes HTML fallback if JSON API changes.

import Foundation
import CoreLocation

public struct TeslaSiteSummary: Codable, Hashable, Sendable, Identifiable {
    public var id: String                // Tesla location id
    public var title: String
    public var types: [String]           // e.g., ["supercharger","store","service"]
    public var lat: Double
    public var lng: Double
}

public struct TeslaSiteDetail: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var address: String?
    public var city: String?
    public var state: String?
    public var postalCode: String?
    public var country: String?
    public var hours: String?
    public var phone: String?
    public var types: [String]
    public var latitude: Double
    public var longitude: Double
    public var amenities: [String]?
    public var stallCount: Int?
    public var powerKW: Int?         // nominal/peak if exposed
    public var status: String?       // planned/open/temporary/etc.
    public var webURL: URL?
}

@MainActor
public final class TeslaSitesService: ObservableObject, Sendable {

    public enum ServiceError: Error, LocalizedError {
        case badResponse, decoding, network, cancelled
        public var errorDescription: String? {
            switch self {
            case .badResponse: return "Unexpected response from Tesla."
            case .decoding:    return "Couldn’t parse Tesla data."
            case .network:     return "Network error contacting Tesla."
            case .cancelled:   return "Cancelled."
            }
        }
    }

    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    // MARK: Public API

    /// Fetch site summaries inside a bounding box (lat/lng).
    public func sites(in bounds: (n: Double, e: Double, s: Double, w: Double)) async throws -> [TeslaSiteSummary] {
        // Preferred JSON endpoint (community documented)
        if let list = try? await fetchJSONList(in: bounds) { return list }
        // Fallback to HTML scrape:
        if let list = try? await scrapeListFromFindUsHTML(bounds: bounds) { return list }
        throw ServiceError.badResponse
    }

    /// Fetch a single site’s details by id.
    public func siteDetail(id: String) async throws -> TeslaSiteDetail {
        if let d = try? await fetchJSONDetail(id: id) { return d }
        if let d = try? await scrapeDetailFromHTML(id: id) { return d }
        throw ServiceError.badResponse
    }

    // MARK: JSON (preferred)

    private func fetchJSONList(in b: (n: Double, e: Double, s: Double, w: Double)) async throws -> [TeslaSiteSummary] {
        // Tesla’s list endpoint typically doesn’t require params for bbox.
        // We filter client-side since the API returns a global set by region.
        // If the endpoint supports params later, you can add &bounds=...
        let url = URL(string: "https://www.tesla.com/cua-api/tesla-locations")!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.badResponse
        }

        // Response typically: { "places": [ ... ] }
        struct Root: Decodable { var places: [Place] }
        struct Place: Decodable {
            var id: String
            var name: String
            var types: [String]
            var latitude: Double
            var longitude: Double
        }

        let root = try JSONDecoder().decode(Root.self, from: data)
        let filtered = root.places.filter { p in
            p.latitude <= b.n && p.latitude >= b.s && p.longitude <= b.e && p.longitude >= b.w
        }

        return filtered.map { p in
            TeslaSiteSummary(id: p.id, title: p.name, types: p.types, lat: p.latitude, lng: p.longitude)
        }
    }

    private func fetchJSONDetail(id: String) async throws -> TeslaSiteDetail {
        let u = URL(string: "https://www.tesla.com/cua-api/tesla-location?id=\(id)")!
        var req = URLRequest(url: u, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.badResponse
        }

        // Example shape (varies a bit by site — keep fields optional)
        struct Detail: Decodable {
            var id: String
            var name: String
            var address: String?
            var city: String?
            var state: String?
            var postalCode: String?
            var country: String?
            var hours: String?
            var phone: String?
            var types: [String]
            var latitude: Double
            var longitude: Double
            var amenities: [String]?
            var stallCount: Int?
            var powerKW: Int?
            var status: String?
            var website: String?
        }

        let d = try JSONDecoder().decode(Detail.self, from: data)
        return TeslaSiteDetail(
            id: d.id,
            title: d.name,
            address: d.address, city: d.city, state: d.state, postalCode: d.postalCode, country: d.country,
            hours: d.hours, phone: d.phone, types: d.types,
            latitude: d.latitude, longitude: d.longitude,
            amenities: d.amenities, stallCount: d.stallCount, powerKW: d.powerKW, status: d.status,
            webURL: d.website.flatMap(URL.init(string:))
        )
    }

    // MARK: HTML fallback (parses embedded JSON in Find-Us page)

    private func scrapeListFromFindUsHTML(bounds b: (n: Double, e: Double, s: Double, w: Double)) async throws -> [TeslaSiteSummary] {
        let url = URL(string:
          "https://www.tesla.com/findus?bounds=\(b.n)%2C\(b.e)%2C\(b.s)%2C\(b.w)"
        )!
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else { throw ServiceError.badResponse }

        // Very robust but simple: look for JSON after `"places":` then parse a bracketed array.
        guard let range = html.range(of: "\"places\":") else { throw ServiceError.decoding }
        let tail = html[range.upperBound...]
        guard let start = tail.firstIndex(of: "["),
              let end = tail.firstIndex(of: "]") else { throw ServiceError.decoding }
        let json = String(tail[start...end])

        struct Place: Decodable {
            var id: String
            var name: String
            var latitude: Double
            var longitude: Double
            var types: [String]
        }
        let places = try JSONDecoder().decode([Place].self, from: Data(json.utf8))

        return places.filter { p in
            p.latitude <= b.n && p.latitude >= b.s && p.longitude <= b.e && p.longitude >= b.w
        }.map { p in
            TeslaSiteSummary(id: p.id, title: p.name, types: p.types, lat: p.latitude, lng: p.longitude)
        }
    }

    private func scrapeDetailFromHTML(id: String) async throws -> TeslaSiteDetail {
        // Many site pages embed JSON; we keep a minimal fallback:
        let url = URL(string: "https://www.tesla.com/findus/location/supercharger/\(id)")!
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else { throw ServiceError.badResponse }

        // Minimal parse (title + coords); you can enrich further if needed.
        let title = match(html, pattern: "<title>(.*?)</title>") ?? "Tesla Site"
        let lat = match(html, pattern: "\"latitude\"\\s*:\\s*([0-9\\.-]+)")?.doubleValue ?? 0
        let lng = match(html, pattern: "\"longitude\"\\s*:\\s*([0-9\\.-]+)")?.doubleValue ?? 0

        return TeslaSiteDetail(
            id: id,
            title: title,
            address: nil, city: nil, state: nil, postalCode: nil, country: nil,
            hours: nil, phone: nil, types: ["supercharger"],
            latitude: lat, longitude: lng,
            amenities: nil, stallCount: nil, powerKW: nil, status: nil, webURL: url
        )
    }

    // MARK: tiny regex helper
    private func match(_ s: String, pattern: String) -> String? {
        (try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]))?
            .firstMatch(in: s, options: [], range: NSRange(s.startIndex..., in: s))
            .flatMap { m in
                guard m.numberOfRanges >= 2, let r = Range(m.range(at: 1), in: s) else { return nil }
                return String(s[r])
            }
    }
}

private extension String {
    var doubleValue: Double? { Double(self) }
}
