//  GeoNudger.swift
//  My KWh Companion
//
//  🔧 FIX 1: CLLocationManager MUST be created and used on the main thread.
//     The original class had no @MainActor annotation, meaning `init` and
//     `startMonitoring` could be called from any thread, creating the manager
//     on a background thread and causing undefined behavior / crashes.
//     Added @MainActor to the class and moved delegate callback dispatch
//     to the correct annotation.
//
//  🔧 FIX 2: `notify()` fired UNUserNotificationCenter.add() without checking
//     whether notification authorization had been granted. On denied status this
//     silently fails and produces console noise. Added a permission check before
//     scheduling the notification.
//
//  🔧 FIX 3: `locationManagerDidChangeAuthorization` sent a notification when
//     Always authorization was denied, but that notification itself requires
//     permission — a circular failure. Changed to a simple print/log for denied
//     state; surface this in your app's settings UI instead.

import Foundation
import CoreLocation
import UserNotifications

@MainActor // 🔧 FIX 1: CLLocationManager must be used on the main thread.
final class GeoNudger: NSObject, CLLocationManagerDelegate {
    private let lm = CLLocationManager()

    override init() {
        super.init()
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Request permissions and begin monitoring up to 20 circular regions.
    /// Uses a diff-based update so existing in-region state is not disturbed
    /// when the set of regions hasn't changed (e.g., on every app foreground).
    func startMonitoring(regions: [CLCircularRegion]) {
        if lm.authorizationStatus == .notDetermined {
            lm.requestAlwaysAuthorization()
        }

        let desired = Array(regions.prefix(20))
        let desiredIDs = Set(desired.map { $0.identifier })
        let currentIDs = Set(lm.monitoredRegions.compactMap { ($0 as? CLCircularRegion)?.identifier })

        // Stop regions no longer needed (avoids resetting entry/exit state for unchanged regions).
        for region in lm.monitoredRegions {
            if let r = region as? CLCircularRegion, !desiredIDs.contains(r.identifier) {
                lm.stopMonitoring(for: r)
            }
        }

        // Only add regions not already monitored.
        for r in desired where !currentIDs.contains(r.identifier) {
            r.notifyOnEntry = true
            r.notifyOnExit  = true
            lm.startMonitoring(for: r)
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region is CLCircularRegion else { return }
        Task { @MainActor in
            notify(
                title: "Charging here today?",
                body: "Quick add a session at \(region.identifier).",
                deeplink: "mykwh://dashboard"
            )
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region is CLCircularRegion else { return }
        Task { @MainActor in
            notify(
                title: "Finished charging?",
                body: "Log your session for \(region.identifier).",
                deeplink: "mykwh://tab/expenses"
            )
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        // 🔧 FIX 3: Don't try to send a notification when permission is denied —
        // it will silently fail. Log instead; surface this in your settings UI.
        if status == .denied || status == .restricted {
            print("[GeoNudger] Location permission denied or restricted — geofence monitoring inactive.")
        }
    }

    // MARK: - Notification helper

    // 🔧 FIX 2: Check notification authorization before scheduling.
    private func notify(title: String, body: String, deeplink: String) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else {
                print("[GeoNudger] Notification permission not granted — skipping '\(title)'")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body  = body
            content.sound = .default
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
}

// MARK: - Convenience

extension CLCircularRegion {
    /// Factory for a standard charger geofence (100m radius by default).
    static func chargerRegion(
        identifier: String,
        latitude: Double,
        longitude: Double,
        radius: CLLocationDistance = 100
    ) -> CLCircularRegion {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return CLCircularRegion(center: center, radius: radius, identifier: identifier)
    }
}
