//
//  NotificationIntegration.swift
//  My KWh Companion
//
//  Swift 6 / iOS 17+
//  - Self-contained local notifications wrapper (no external dependencies)
//  - Safe to call from app launch
//  - Includes a lightweight `NotificationManager` shim for back-compat
//

import Foundation
import UserNotifications

// MARK: - Identifiers

fileprivate enum NotifID {
    // Categories
    static let general     = "ev.general"
    static let reminder    = "ev.reminder"
    static let insight     = "ev.insight"

    // Actions
    static let openApp     = "ev.action.openApp"
    static let dismiss     = "ev.action.dismiss"
}

// MARK: - Core integration (new API)

@MainActor
enum AppNotifications {
    /// Configure categories and optionally request auth on first launch.
    static func configure(requestAuthorizationIfNeeded: Bool = false) async {
        registerCategories()
        if requestAuthorizationIfNeeded {
            _ = await requestAuthorization()
        }
    }

    /// Request alert/badge/sound authorization.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            // You may want to log this with your logging system
            return false
        }
    }

    /// Register categories + actions used by the app.
    static func registerCategories() {
        let open = UNNotificationAction(
            identifier: NotifID.openApp,
            title: "Open",
            options: [.foreground]
        )
        let dismiss = UNNotificationAction(
            identifier: NotifID.dismiss,
            title: "Dismiss",
            options: [.destructive]
        )

        let general = UNNotificationCategory(
            identifier: NotifID.general,
            actions: [open, dismiss],
            intentIdentifiers: [],
            options: []
        )
        let reminder = UNNotificationCategory(
            identifier: NotifID.reminder,
            actions: [open, dismiss],
            intentIdentifiers: [],
            options: []
        )
        let insight = UNNotificationCategory(
            identifier: NotifID.insight,
            actions: [open],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([general, reminder, insight])
    }

    /// Schedule a single local notification after a time interval.
    static func scheduleLocal(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        category: String = NotifID.general,
        userInfo: [AnyHashable: Any] = [:],
        in seconds: TimeInterval = 3
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        if !userInfo.isEmpty { content.userInfo = userInfo }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // swallow or log
        }
    }

    /// Clear all delivered and pending notifications.
    static func clearAll() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
    }

    /// Convenience: schedule a demo "Insight" nudge (handy for QA).
    static func scheduleDemoInsight() async {
        await scheduleLocal(
            title: "Charging Insight",
            body: "Your average cost per kWh dropped 8% this week.",
            category: NotifID.insight,
            in: 2
        )
    }
}

// MARK: - Back-compat shim (old call sites can keep using `NotificationManager`)

@MainActor
struct NotificationManager {

    /// Old: `NotificationManager.requestAuthorization()`
    static func requestAuthorization() async -> Bool {
        await AppNotifications.requestAuthorization()
    }

    /// Old: `NotificationManager.registerCategories()`
    static func registerCategories() {
        AppNotifications.registerCategories()
    }

    /// Old: `NotificationManager.scheduleDemo()` or similar
    static func scheduleDemo() async {
        await AppNotifications.scheduleDemoInsight()
    }

    /// Old: `NotificationManager.clearAll()`
    static func clearAll() async {
        await AppNotifications.clearAll()
    }

    /// Optional: call at app launch to set up notifications
    static func configureOnLaunch(requestAuthorizationIfNeeded: Bool = false) async {
        await AppNotifications.configure(requestAuthorizationIfNeeded: requestAuthorizationIfNeeded)
    }
}
