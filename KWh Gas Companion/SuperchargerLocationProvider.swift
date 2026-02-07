//
//  SuperchargerLocationProvider.swift
//  KWh Gas Companion
//
//  Created by Bryan on 11/30/25.
//


//
//  SuperchargerLocationProvider.swift
//  My KWh Companion
//
//  Lightweight location helper for Supercharger Helper.
//  • Publishes lastLocation + authorizationStatus
//  • Safe for @StateObject usage in SwiftUI
//

import Foundation
import CoreLocation
import Combine

final class SuperchargerLocationProvider: NSObject, ObservableObject {

    // Latest known user location (meters-level accuracy is fine for nearest Supercharger)
    @Published var lastLocation: CLLocation?

    // Current authorization status
    @Published var authorizationStatus: CLAuthorizationStatus

    private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100 // meters; tweak if you want more/less frequent updates
    }

    // MARK: - Public API

    /// Ask the user for "When In Use" location access.
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Start location updates (no-op if not authorized).
    func start() {
        manager.startUpdatingLocation()
    }

    /// Stop location updates (optional, if you want to be explicit).
    func stop() {
        manager.stopUpdatingLocation()
    }
}

// MARK: - CLLocationManagerDelegate

extension SuperchargerLocationProvider: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
        }

        Task { @MainActor in
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                self.start()
            default:
                self.stop()
            }
        }
    }

    // For older iOS SDKs – some projects still see this invoked:
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.authorizationStatus = status
        }

        Task { @MainActor in
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                self.start()
            default:
                self.stop()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = latest
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // You could publish an error string if you want, but for now just log.
        print("SuperchargerLocationProvider error: \(error)")
    }
}
