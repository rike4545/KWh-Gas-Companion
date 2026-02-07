//
//  TPOpenRouterProvider.swift
//  KWh Gas Companion
//
//  MapKit-backed routing + a lightweight MapKit charger search provider.
//  (Names preserved: TPOpenRouterProvider / TPOpenChargeMapProvider)
//
//  Swift 6 • iOS 17+
//

import Foundation
import CoreLocation
import MapKit

struct TPOpenRouterProvider: TPRoutingProvider {

    func buildRoute(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D]
    ) async throws -> TPRoute {

        let points = [origin] + waypoints + [destination]
        guard points.count >= 2 else {
            throw NSError(domain: "TPRoute", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not enough points to route."])
        }

        var polyline: [CLLocationCoordinate2D] = []
        var totalMeters: Double = 0
        var totalSeconds: Double = 0

        for i in 0..<(points.count - 1) {
            let leg = try await routeLeg(from: points[i], to: points[i + 1])
            totalMeters += leg.distanceMeters
            totalSeconds += leg.durationSeconds

            if polyline.isEmpty {
                polyline = leg.fullPolyline
            } else {
                polyline.append(contentsOf: leg.fullPolyline.dropFirst())
            }
        }

        return TPRoute(distanceMeters: totalMeters, durationSeconds: totalSeconds, fullPolyline: polyline)
    }

    private func routeLeg(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> TPRoute {
        let req = MKDirections.Request()
        req.transportType = .automobile
        req.requestsAlternateRoutes = false
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))

        let resp = try await MKDirections(request: req).calculate()
        guard let r = resp.routes.first else {
            throw NSError(domain: "TPRoute", code: 2, userInfo: [NSLocalizedDescriptionKey: "No route found."])
        }

        return TPRoute(
            distanceMeters: r.distance,
            durationSeconds: r.expectedTravelTime,
            fullPolyline: r.polyline.tp_coordinates
        )
    }
}

struct TPOpenChargeMapProvider: TPChargerProvider {

    func searchChargers(
        along polyline: [CLLocationCoordinate2D],
        corridorMeters: Double
    ) async -> [TPCharger] {

        guard polyline.count >= 2 else { return [] }

        // Sample points along the route to search around
        let samples = samplePoints(from: polyline, maxPoints: 6)
        let span = spanDegrees(forMeters: corridorMeters)

        var results: [TPCharger] = []
        results.reserveCapacity(60)

        // Sequential (stable + avoids Sendable/taskgroup headaches)
        for c in samples {
            let region = MKCoordinateRegion(
                center: c,
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
            let batch = await search(region: region)
            results.append(contentsOf: batch)
        }

        // Dedup by name + rounded coordinate
        var seen = Set<String>()
        var out: [TPCharger] = []
        for ch in results {
            let key = "\(ch.name.lowercased())|\(Int((ch.coordinate.latitude*10_000).rounded()))|\(Int((ch.coordinate.longitude*10_000).rounded()))"
            if seen.insert(key).inserted { out.append(ch) }
        }

        return out
    }

    private func search(region: MKCoordinateRegion) async -> [TPCharger] {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = "EV charger"
        req.region = region

        do {
            let resp = try await MKLocalSearch(request: req).start()
            return resp.mapItems.compactMap { item in
                guard let name = item.name else { return nil }
                let c = item.placemark.coordinate
                let net = inferNetwork(fromName: name)
                let id = "mk|\(name)|\(String(format: "%.5f", c.latitude))|\(String(format: "%.5f", c.longitude))"

                return TPCharger(
                    id: id,
                    name: name,
                    coordinate: c,
                    maxPowerKW: net == .tesla ? 250 : 150,
                    network: net,
                    priceNote: nil
                )
            }
        } catch {
            return []
        }
    }

    private func inferNetwork(fromName name: String) -> TPChargerNetwork {
        let s = name.lowercased()
        if s.contains("supercharger") { return .tesla }
        if s.contains("electrify america") { return .electrifyAmerica }
        if s.contains("chargepoint") { return .chargePoint }
        if s.contains("evgo") { return .evgo }
        if s.contains("shell") { return .shellRecharge }
        return .unknown
    }

    private func samplePoints(from poly: [CLLocationCoordinate2D], maxPoints: Int) -> [CLLocationCoordinate2D] {
        guard poly.count > maxPoints else { return poly }
        let step = max(1, poly.count / maxPoints)
        var pts: [CLLocationCoordinate2D] = []
        var i = 0
        while i < poly.count && pts.count < maxPoints {
            pts.append(poly[i])
            i += step
        }
        return pts
    }

    private func spanDegrees(forMeters meters: Double) -> Double {
        // ~111km per degree latitude
        let deg = (meters / 111_000.0) * 2.0
        return min(max(deg, 0.06), 2.0)
    }
}

// MARK: - MKPolyline to coordinates

private extension MKPolyline {
    var tp_coordinates: [CLLocationCoordinate2D] {
        guard pointCount > 0 else { return [] }
        var coords = Array(repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords.filter { CLLocationCoordinate2DIsValid($0) }
    }
}
