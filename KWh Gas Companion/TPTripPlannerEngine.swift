//  TPTripPlannerEngine 2.swift
//  KWh Gas Companion
//
//  Engine ONLY. No model/protocol redeclarations.
//
//  Swift 6 • iOS 17+
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class TPTripPlannerEngine: ObservableObject {

    @Published private(set) var lastPlan: TPTripPlan?
    @Published private(set) var isPlanning: Bool = false
    @Published private(set) var errorMessage: String?

    private let router: TPRoutingProvider
    private let chargers: TPChargerProvider

    init(router: TPRoutingProvider, chargers: TPChargerProvider) {
        self.router = router
        self.chargers = chargers
    }

    func resetPlan() {
        lastPlan = nil
        errorMessage = nil
        isPlanning = false
    }

    func clearError() { errorMessage = nil }
    func setError(_ message: String) { errorMessage = message }

    func plan(_ req: TPTripRequest) async {
        guard !isPlanning else { return }
        isPlanning = true
        errorMessage = nil
        defer { isPlanning = false }

        do {
            let route = try await router.buildRoute(
                origin: req.origin,
                destination: req.destination,
                waypoints: req.waypoints
            )

            guard route.fullPolyline.count >= 2 else {
                setError("Couldn’t build a route. Try different endpoints.")
                return
            }

            let candidateChargers = await chargers.searchChargers(
                along: route.fullPolyline,
                corridorMeters: req.corridorMeters
            )

            // --- Simple energy model (good-enough, not a physics sim) ---

            let miles = route.distanceMeters / 1609.344
            let whPerMile = effectiveWhPerMile(
                baseline: req.vehicle.baselineWhPerMile,
                cruiseMPH: req.env.cruiseMPH,
                temperatureF: req.env.temperatureF,
                windDeltaMPH: req.env.windDeltaMPH,
                considerElevation: req.env.considerElevation
            )

            let neededKWhTotal = (miles * whPerMile) / 1000.0
            let battery = max(req.vehicle.batteryKWh, 1)

            let startSOC = clamp(req.startSOC, 0.05, 1.0)
            let arrivalBufferSOC = clamp(req.vehicle.arrivalBuffer, 0.02, 0.25)
            let targetDepartSOC = clamp(req.vehicle.targetDepartSOC, 0.40, 1.0)

            let firstLegUsableKWh = max(0, (startSOC - arrivalBufferSOC) * battery)
            let nextLegUsableKWh  = max(0, (targetDepartSOC - arrivalBufferSOC) * battery)

            // No stops needed
            if neededKWhTotal <= firstLegUsableKWh {
                lastPlan = TPTripPlan(route: route, stops: [])
                return
            }

            if nextLegUsableKWh <= 0.5 {
                setError("Charging targets make usable energy per leg too small. Increase Depart Target or reduce Arrival Buffer.")
                return
            }

            // Determine stop count (cap to keep UX sane)
            let remaining = max(0, neededKWhTotal - firstLegUsableKWh)
            var stopsCount = Int(ceil(remaining / nextLegUsableKWh))
            stopsCount = min(max(stopsCount, 1), 6)

            // Place stops roughly evenly along route
            let fractions: [Double] = (0..<stopsCount).map { Double($0 + 1) / Double(stopsCount + 1) }
            let stopCoords = fractions.map { coordinate(on: route.fullPolyline, fraction: $0) }

            // Pick chargers closest to those coords (fallback to synthetic stop)
            let chosenChargers: [TPCharger] = stopCoords.enumerated().map { (i, coord) in
                if let best = nearestCharger(to: coord, candidates: candidateChargers) {
                    return best
                }
                let id = "fallback|\(i)|\(String(format: "%.5f", coord.latitude))|\(String(format: "%.5f", coord.longitude))"
                return TPCharger(
                    id: id,
                    name: "Charging Stop \(i + 1)",
                    coordinate: coord,
                    maxPowerKW: min(req.vehicle.maxDCPowerKW, 150),
                    network: .unknown,
                    priceNote: nil
                )
            }

            // Approximate SOC and charge times per stop
            let legs = stopsCount + 1
            let legMiles = miles / Double(legs)
            let legKWh = (legMiles * whPerMile) / 1000.0

            var currentSOC = startSOC
            var stops: [TPChargingStop] = []
            stops.reserveCapacity(stopsCount)

            for i in 0..<stopsCount {
                let arriveSOC = clamp(currentSOC - (legKWh / battery), 0.0, 1.0)

                // How much we need after this stop
                let legsRemainingAfter = (legs - (i + 1))
                let kWhRemaining = Double(legsRemainingAfter) * legKWh
                let requiredDepartSOC = clamp((kWhRemaining / battery) + arrivalBufferSOC, arrivalBufferSOC, 1.0)
                let departSOC = clamp(max(targetDepartSOC, requiredDepartSOC), arrivalBufferSOC, 1.0)

                let addKWh = max(0, (departSOC - arriveSOC) * battery)

                // Crude DC charging taper approximation
                let peakKW = max(20, min(req.vehicle.maxDCPowerKW, chosenChargers[i].maxPowerKW))
                let avgKW = peakKW * 0.55
                var seconds = (addKWh / avgKW) * 3600.0
                seconds = clamp(seconds, 4 * 60, 75 * 60)

                stops.append(
                    TPChargingStop(
                        charger: chosenChargers[i],
                        arriveSOC: arriveSOC,
                        departSOC: departSOC,
                        chargeSeconds: seconds
                    )
                )

                currentSOC = departSOC
            }

            lastPlan = TPTripPlan(route: route, stops: stops)

        } catch {
            setError("Planning failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Energy model

    private func effectiveWhPerMile(
        baseline: Double,
        cruiseMPH: Double,
        temperatureF: Double,
        windDeltaMPH: Double,
        considerElevation: Bool
    ) -> Double {
        var factor: Double = 1.0

        let speed = max(35, min(cruiseMPH, 90))
        let speedFactor = 0.88 + 0.12 * pow(speed / 65.0, 2.0)
        factor *= speedFactor

        if temperatureF < 60 {
            factor *= (1.0 + min(0.28, (60 - temperatureF) * 0.006))
        } else if temperatureF > 85 {
            factor *= (1.0 + min(0.15, (temperatureF - 85) * 0.004))
        }

        factor *= (1.0 + min(0.25, max(-0.18, windDeltaMPH * 0.010)))

        if considerElevation { factor *= 1.03 }

        factor = clamp(factor, 0.70, 1.70)
        return max(100, baseline * factor)
    }

    // MARK: - Geometry helpers

    private func coordinate(on poly: [CLLocationCoordinate2D], fraction: Double) -> CLLocationCoordinate2D {
        let f = clamp(fraction, 0.0, 1.0)
        if poly.count == 1 { return poly[0] }
        let idx = Int(round(Double(poly.count - 1) * f))
        return poly[max(0, min(poly.count - 1, idx))]
    }

    private func nearestCharger(to coord: CLLocationCoordinate2D, candidates: [TPCharger]) -> TPCharger? {
        guard !candidates.isEmpty else { return nil }
        let target = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        return candidates.min(by: { a, b in
            let da = target.distance(from: CLLocation(latitude: a.coordinate.latitude, longitude: a.coordinate.longitude))
            let db = target.distance(from: CLLocation(latitude: b.coordinate.latitude, longitude: b.coordinate.longitude))
            return da < db
        })
    }

    private func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { min(max(v, lo), hi) }
}
