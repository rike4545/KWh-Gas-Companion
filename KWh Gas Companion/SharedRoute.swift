//
//  SharedRoute.swift
//  KWh Gas Companion
//
//  Model for Route Discovery — shared driving routes that open directly in the
//  embedded LibreNav screen.
//
//  The payload is deliberately LibreNav's own share-link query
//  (`trip=lat,lng,name|lat,lng,name&opts=thfwa`). That format already round-trips
//  every stop and every routing preference, it is stable enough that LibreNav
//  still decodes its own legacy `?to=` links, and it means a shared route needs
//  no second map stack — `LibreNavView(tripQuery:)` just opens it.
//
//  Swift 6 • iOS 17+
//

import Foundation
import CoreLocation

// MARK: - Route

struct SharedRoute: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    var title: String
    var summary: String

    /// LibreNav share-link query, without the leading `?`.
    var tripQuery: String

    /// Human region label, e.g. "Long Island, NY". Used for browsing/filtering.
    var region: String
    var tags: [String]

    /// Author-stated driving distance. Optional because we can only *estimate*
    /// it locally (see `straightLineMiles`) — real road distance comes from
    /// Valhalla once the route is opened in LibreNav.
    var statedMiles: Double?

    var authorName: String
    var authorID: String
    var createdAt: Date

    /// Marks routes whose author says charging is available along the way.
    /// Advisory only — LibreNav's charger overlay is the real source.
    var hasChargingNoted: Bool = false

    // MARK: Derived

    var stops: [SharedRouteStop] { Self.parseStops(from: tripQuery) }

    var stopCount: Int { stops.count }

    /// Sum of great-circle hops between consecutive stops.
    ///
    /// This is a *lower bound* on driving distance, never the real thing — roads
    /// are not straight. It exists so a route with no author-stated distance
    /// still sorts and filters sensibly. Anything user-facing must label it as
    /// an approximation; see `distanceLabel`.
    var straightLineMiles: Double {
        let points = stops.map(\.coordinate)
        guard points.count > 1 else { return 0 }
        var meters = 0.0
        for idx in 1..<points.count {
            let a = CLLocation(latitude: points[idx - 1].latitude, longitude: points[idx - 1].longitude)
            let b = CLLocation(latitude: points[idx].latitude, longitude: points[idx].longitude)
            meters += a.distance(from: b)
        }
        return meters / 1609.344
    }

    /// Distance for display. Prefers what the author stated; otherwise falls
    /// back to the straight-line figure and says so, rather than passing an
    /// underestimate off as a real route length.
    var distanceLabel: String {
        if let statedMiles, statedMiles > 0 {
            return "\(Int(statedMiles.rounded())) mi"
        }
        let approx = straightLineMiles
        guard approx > 0 else { return "—" }
        return "~\(Int(approx.rounded())) mi direct"
    }

    /// Sort key that tolerates a missing stated distance.
    var sortableMiles: Double {
        if let statedMiles, statedMiles > 0 { return statedMiles }
        return straightLineMiles
    }

    var searchHaystack: String {
        ([title, summary, region, authorName] + tags)
            .joined(separator: " ")
            .lowercased()
    }

    // MARK: Trip query parsing

    /// Decodes LibreNav's `trip=` parameter. Mirrors `decodeTrip` in
    /// LibreNav's `lib/trip.ts`, including its coordinate sanity bounds, so a
    /// route that parses here is one LibreNav will also accept.
    static func parseStops(from query: String) -> [SharedRouteStop] {
        var components = URLComponents()
        // `percentEncodedQuery`, not `query`. `makeTripQuery` emits an encoded
        // string (the `|` separators arrive as %7C), and the `query` setter
        // treats its input as *decoded* — assigning there re-escapes the `%`
        // itself, so `%7C` becomes `%257C` and `queryItems` hands back a literal
        // "%7C" that never splits. Every multi-stop route then parsed as one stop.
        components.percentEncodedQuery = query
        guard let raw = components.queryItems?.first(where: { $0.name == "trip" })?.value else {
            return []
        }

        return raw.split(separator: "|").enumerated().compactMap { index, chunk in
            let parts = chunk.split(separator: ",", omittingEmptySubsequences: false)
            guard parts.count >= 2,
                  let lat = Double(parts[0]),
                  let lng = Double(parts[1]),
                  lat.isFinite, lng.isFinite,
                  abs(lat) <= 90, abs(lng) <= 180
            else { return nil }

            let name = parts.count > 2
                ? parts[2...].joined(separator: ",").trimmingCharacters(in: .whitespaces)
                : ""

            return SharedRouteStop(
                name: name.isEmpty ? "Stop \(index + 1)" : name,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
            )
        }
    }

    /// Builds a trip query from stops — the inverse of `parseStops`, matching
    /// LibreNav's `encodeTrip`. Commas and pipes are the separators, so they are
    /// stripped from names exactly as LibreNav does.
    static func makeTripQuery(stops: [SharedRouteStop], options: SharedRouteOptions = .init()) -> String {
        let trip = stops.map { stop in
            let lat = String(format: "%.5f", stop.coordinate.latitude)
            let lng = String(format: "%.5f", stop.coordinate.longitude)
            let name = stop.name
                .replacingOccurrences(of: "|", with: " ")
                .replacingOccurrences(of: ",", with: " ")
                .trimmingCharacters(in: .whitespaces)
                .prefix(60)
            return "\(lat),\(lng),\(name)"
        }.joined(separator: "|")

        var items = [URLQueryItem(name: "trip", value: trip)]
        if !options.flags.isEmpty {
            items.append(URLQueryItem(name: "opts", value: options.flags))
        }

        var components = URLComponents()
        components.queryItems = items
        return components.percentEncodedQuery ?? ""
    }

    /// True when the query yields at least a start and an end LibreNav can use.
    static func isUsable(tripQuery: String) -> Bool {
        parseStops(from: tripQuery).count >= 2
    }
}

// MARK: - Stop

struct SharedRouteStop: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var coordinate: CLLocationCoordinate2D

    static func == (lhs: SharedRouteStop, rhs: SharedRouteStop) -> Bool {
        lhs.name == rhs.name
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
}

// MARK: - Route options

/// LibreNav's `opts` flag string: t=tolls, h=highways, f=ferries, w=twisty, a=alternatives.
struct SharedRouteOptions: Hashable, Codable {
    var avoidTolls = false
    var avoidHighways = false
    var avoidFerries = false
    var preferTwisty = false
    var alternatives = false

    var flags: String {
        [avoidTolls ? "t" : "",
         avoidHighways ? "h" : "",
         avoidFerries ? "f" : "",
         preferTwisty ? "w" : "",
         alternatives ? "a" : ""].joined()
    }

    init(avoidTolls: Bool = false,
         avoidHighways: Bool = false,
         avoidFerries: Bool = false,
         preferTwisty: Bool = false,
         alternatives: Bool = false) {
        self.avoidTolls = avoidTolls
        self.avoidHighways = avoidHighways
        self.avoidFerries = avoidFerries
        self.preferTwisty = preferTwisty
        self.alternatives = alternatives
    }

    init(flags: String) {
        avoidTolls = flags.contains("t")
        avoidHighways = flags.contains("h")
        avoidFerries = flags.contains("f")
        preferTwisty = flags.contains("w")
        alternatives = flags.contains("a")
    }
}
