// Copyright Bryan Carroll. Made with Love in New York. All rights reserved. 2026.

import SwiftUI
import CoreLocation
import UserNotifications
import Photos
import AVFoundation
import os.log

@MainActor
final class AppPermissionBootstrapper: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    private static let completedKey = "permissions.bootstrap.completed"

    private let log = Logger(subsystem: "KWhGasCompanion", category: "Permissions")
    private var isRequesting = false
    private var locationManager: CLLocationManager?
    private var locationContinuation: CheckedContinuation<Void, Never>?

    func requestIfNeeded() async {
        guard !isCompleted else { return }
        guard !isRequesting else { return }
        isRequesting = true
        defer { isRequesting = false }

        // Request core permissions on first run so users see prompts up-front.
        #if !targetEnvironment(simulator)
        await requestNotificationsIfNeeded()
        await pauseBetweenPrompts()
        await requestLocationIfNeeded()
        await pauseBetweenPrompts()
        await requestPhotosIfNeeded()
        await pauseBetweenPrompts()
        await requestCameraIfNeeded()
        #endif

        markCompleted()
    }

    private func requestLocationIfNeeded() async {
        guard locationContinuation == nil else { return }
        guard hasUsageDescription("NSLocationWhenInUseUsageDescription") else {
            log.error("Skipping location permission request because NSLocationWhenInUseUsageDescription is missing.")
            return
        }

        let manager = CLLocationManager()
        let status = manager.authorizationStatus
        guard status == .notDetermined else { return }

        manager.delegate = self
        locationManager = manager

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            locationContinuation = cont
            manager.requestWhenInUseAuthorization()
        }
    }

    private func requestNotificationsIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    private func requestPhotosIfNeeded() async {
        guard hasUsageDescription("NSPhotoLibraryUsageDescription") else {
            log.error("Skipping photo library permission request because NSPhotoLibraryUsageDescription is missing.")
            return
        }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .notDetermined else { return }
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    private func requestCameraIfNeeded() async {
        guard hasUsageDescription("NSCameraUsageDescription") else {
            log.error("Skipping camera permission request because NSCameraUsageDescription is missing.")
            return
        }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status == .notDetermined else { return }
        _ = await AVCaptureDevice.requestAccess(for: .video)
    }

    private var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: Self.completedKey)
    }

    private func markCompleted() {
        UserDefaults.standard.set(true, forKey: Self.completedKey)
    }

    private func pauseBetweenPrompts() async {
        try? await Task.sleep(for: .milliseconds(350))
    }

    private func hasUsageDescription(_ key: String) -> Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return false
        }

        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status != .notDetermined else { return }
        let continuation = locationContinuation
        locationContinuation = nil
        locationManager = nil
        continuation?.resume()
    }
}
