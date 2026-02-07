//
//  TPPlannerProtocols.swift
//  KWh Gas Companion
//
//  Single source of truth for Trip Planner protocols.
//
//  Swift 6 • iOS 17+
//

import Foundation
import CoreLocation

protocol TPRoutingProvider {
    func buildRoute(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D]
    ) async throws -> TPRoute
}

protocol TPChargerProvider {
    func searchChargers(
        along polyline: [CLLocationCoordinate2D],
        corridorMeters: Double
    ) async -> [TPCharger]
}
