//
//  NotificationIntegrationShim.swift
//  My KWh Companion
//
//  Back-compat layer so legacy code that references `NotificationIntegration`
//  keeps compiling. Forwards to the new NotificationManager/AppNotifications wrapper,
//  and implements `ensureRepeatingSchedules()` for daily/weekly repeating nudges.
//

import Foundation
import UserNotifications

@MainActor
struct NotificationIntegration {

    // MARK: Legacy forwards

    static func requestAuthorization() async -> Bool {
        await NotificationManager.requestAuthorization()
    }

    static func registerCategories() {
        NotificationManager.registerCategories()
    }

    static func scheduleDemo() async {
        await NotificationManager.scheduleDemo()
    }

    static func clearAll() async {
        await NotificationManager.clearAll()
    }

    static func configureOnLaunch(requestAuthorizationIfNeeded: Bool = false) async {
        await NotificationManager.configureOnLaunch(requestAuthorizationIfNeeded: requestAuthorizationIfNeeded)
    }

    // MARK: New: ensure repeating schedules (daily/weekly)
    //
    // - Idempotent: checks pending requests and only adds missing ones.
    // - Safe defaults: 9:00 AM daily “Charging Insight”, Mondays 9:05 AM weekly “Cost Summary”.
    // - Customize times/titles as you wish.

    static func ensureRepeatingSchedules() async {
        let center = UNUserNotificationCenter.current()

        // Make sure categories exist
        NotificationManager.registerCategories()

        // Fetch pending to avoid duplicates
        let pending = await center.pendingRequestIDs()
        var requestsToAdd: [UNNotificationRequest] = []

        // Daily insight @ 09:00 local, repeats
        if !pending.contains(IDs.dailyInsight) {
            let content = UNMutableNotificationContent()
            content.title = "Daily EV Insight"
            content.body  = "Quick check: your average cost per kWh and yesterday’s charging summary are ready."
            content.sound = .default
            content.categoryIdentifier = "ev.insight" // from NotificationIntegration.swift shim

            var date = DateComponents()
            date.hour = 9
            date.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            requestsToAdd.append(.init(identifier: IDs.dailyInsight, content: content, trigger: trigger))
        }

        // Weekly summary (Monday) @ 09:05 local, repeats
        if !pending.contains(IDs.weeklySummary) {
            let content = UNMutableNotificationContent()
            content.title = "Weekly EV Summary"
            content.body  = "Your weekly cost & efficiency summary is ready."
            content.sound = .default
            content.categoryIdentifier = "ev.insight"

            var date = DateComponents()
            date.weekday = 2 // Monday (1=Sunday)
            date.hour = 9
            date.minute = 5
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            requestsToAdd.append(.init(identifier: IDs.weeklySummary, content: content, trigger: trigger))
        }

        // Commit any missing requests
        for req in requestsToAdd {
            do { try await center.add(req) } catch { /* swallow or log */ }
        }
    }

    // Stable identifiers used above
    private enum IDs {
        static let dailyInsight  = "ev.repeat.dailyInsight"
        static let weeklySummary = "ev.repeat.weeklySummary"
    }
}

// MARK: - Small helper to read pending IDs

fileprivate extension UNUserNotificationCenter {
    func pendingRequestIDs() async -> Set<String> {
        await withCheckedContinuation { cont in
            getPendingNotificationRequests { requests in
                cont.resume(returning: Set(requests.map(\.identifier)))
            }
        }
    }
}
