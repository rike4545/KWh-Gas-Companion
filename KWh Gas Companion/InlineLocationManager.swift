//  InlineLocationManager.swift — Swift 6 actor‑safe
//  My KWh Companion
//
//  Lightweight one-shot location fetcher for nearby tools (e.g., CheapestChargerShift).
//  Swift 6 fix: remove @MainActor from the class (delegate conformance),
//  and hop to the main actor inside delegate callbacks when mutating @Published state.
//
//  Info.plist requirement:
//  • NSLocationWhenInUseUsageDescription = "Allow location to find nearby EV chargers."
//
import Foundation
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

final class InlineLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Published state (must be written on main actor)
    @Published var authorization: CLAuthorizationStatus
    @Published var location: CLLocation?
    @Published var isRequesting: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private
    private let manager = CLLocationManager()

    // MARK: - Init
    override init() {
        // Initialize the cached auth value from the manager
        self.authorization = manager.authorizationStatus
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters     // good-enough for nearby search
        manager.distanceFilter = 50                                    // ignore tiny moves
        manager.pausesLocationUpdatesAutomatically = true
        manager.activityType = .otherNavigation
    }

    // MARK: - Public API

    /// Request a single location update. Safe to call multiple times.
    func request() {
        Task { @MainActor in self.errorMessage = nil }

        // Ensure services are enabled at the device level
        guard CLLocationManager.locationServicesEnabled() else {
            Task { @MainActor in self.errorMessage = "Location Services are disabled." }
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            // One-shot request (no need to manage start/stop lifecycle)
            Task { @MainActor in self.isRequesting = true }
            manager.requestLocation()

        case .denied, .restricted:
            // Do not spam the user; offer a Settings link in UI
            Task { @MainActor in self.errorMessage = "Location permission denied. Enable it in Settings to find nearby chargers." }

        @unknown default:
            Task { @MainActor in self.errorMessage = "Unknown location authorization state." }
        }
    }

    /// Manual retry convenience (e.g., from a “Try Again” button).
    func retry() { request() }

    /// Convenience for a Settings deep-link if permission is denied.
    func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        #endif
    }

    // MARK: - CLLocationManagerDelegate (hop to main actor when mutating state)

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let auth = manager.authorizationStatus
        Task { @MainActor in self.authorization = auth }

        switch auth {
        case .authorizedAlways, .authorizedWhenInUse:
            Task { @MainActor in self.isRequesting = true }
            manager.requestLocation()
        case .denied, .restricted:
            Task { @MainActor in self.errorMessage = "Location permission denied. Enable it in Settings to find nearby chargers." }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        Task { @MainActor in
            self.isRequesting = false
            self.errorMessage = nil
            self.location = last
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.isRequesting = false }

        // Handle common Core Location errors gracefully
        if let clErr = error as? CLError {
            switch clErr.code {
            case .denied:
                Task { @MainActor in self.errorMessage = "Location permission denied." }
            case .locationUnknown:
                Task { @MainActor in self.errorMessage = "Current location unavailable. Try again." }
            default:
                Task { @MainActor in self.errorMessage = clErr.localizedDescription }
            }
        } else {
            Task { @MainActor in self.errorMessage = error.localizedDescription }
        }
    }
}
