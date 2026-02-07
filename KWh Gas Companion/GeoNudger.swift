//  GeoNudger.swift
//  My KWh Companion
//
//  Lightweight geofence nudges (max 20 regions).
//  Requires Always location for background enter/exit delivery.

import Foundation
import CoreLocation
import UserNotifications

final class GeoNudger: NSObject, CLLocationManagerDelegate {
    private let lm = CLLocationManager()

    override init() {
        super.init()
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Request permissions and begin monitoring up to 20 circular regions.
    /// - Parameters:
    ///   - regions: Provide *at most* 20 regions (iOS hard limit); older ones will be stopped.
    func startMonitoring(regions: [CLCircularRegion]) {
        // Ask for Always to get background enter/exit notifications.
        if lm.authorizationStatus == .notDetermined {
            lm.requestAlwaysAuthorization()
        }

        // Stop anything we were monitoring previously to stay under the limit.
        for region in lm.monitoredRegions {
            if let r = region as? CLCircularRegion { lm.stopMonitoring(for: r) }
        }

        // Configure and start monitoring (cap at 20).
        for r in regions.prefix(20) {
            r.notifyOnEntry = true
            r.notifyOnExit  = true
            lm.startMonitoring(for: r)
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region is CLCircularRegion else { return }
        notify(
            title: "Charging here today?",
            body: "Quick add a session at \(region.identifier).",
            deeplink: "mykwh://dashboard"
        )
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region is CLCircularRegion else { return }
        notify(
            title: "Finished charging?",
            body: "Log your session for \(region.identifier).",
            deeplink: "mykwh://tab/expenses"
        )
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Optional: surface a local nudge if Always is not granted.
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            notify(
                title: "Location disabled",
                body: "Enable Always Location for geofence reminders.",
                deeplink: "mykwh://dashboard"
            )
        }
    }

    // MARK: - Local notify helper (explicit types to avoid inference errors)

    private func notify(title: String, body: String, deeplink: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = UNNotificationSound.default
        content.userInfo = ["deeplink": deeplink]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Convenience: build regions from coordinates

extension CLCircularRegion {
    /// Factory for a standard charger geofence (100m radius).
    static func chargerRegion(identifier: String, latitude: Double, longitude: Double, radius: CLLocationDistance = 100) -> CLCircularRegion {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return CLCircularRegion(center: center, radius: radius, identifier: identifier)
    }
}
