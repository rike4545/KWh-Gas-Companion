//
//  ChargeLiveActivityManager.swift
//  KWh Gas Companion
//
//  Live Activities support for charging status.
//
//  🔧 FIX: staleDate was passed as `nil` in both request and update calls.
//  A nil staleDate causes the system to immediately consider the content stale,
//  which suppresses the Live Activity UI on the Lock Screen. Changed to a
//  rolling 30-minute stale window — if no update arrives in 30 min, the system
//  dims the activity rather than hiding it entirely.
//
//  🔧 FIX: `end(reason:)` parameter was accepted but never used. Removed the
//  unused parameter to avoid the Swift warning and clean up the public API.
//  Callers that passed a reason string should remove the argument label.
//

import Foundation
import ActivityKit

@MainActor
final class ChargeLiveActivityManager: ObservableObject {
    static let shared = ChargeLiveActivityManager()

    @Published private(set) var isActive: Bool = false

    private var currentActivity: Activity<ChargeActivityAttributes>?

    /// Rolling stale window: if no update arrives within this interval the
    /// system dims (but does not end) the Live Activity.
    private let staleInterval: TimeInterval = 30 * 60  // 30 minutes

    func startOrUpdate(
        vehicleName: String,
        batteryLevel: Int,
        chargingState: String,
        energyAddedKWh: Double?,
        cost: Double?
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = ChargeActivityAttributes(vehicleName: vehicleName)
        let content = ChargeActivityAttributes.ContentState(
            batteryLevel: batteryLevel,
            chargingState: chargingState,
            energyAddedKWh: energyAddedKWh,
            cost: cost
        )
        // 🔧 FIX: Use a rolling stale date instead of nil so the Lock Screen
        // continues to display the activity during normal charging sessions.
        let staleDate = Date(timeIntervalSinceNow: staleInterval)

        if let currentActivity {
            await currentActivity.update(
                ActivityContent(state: content, staleDate: staleDate)
            )
            isActive = true
            return
        }

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: content, staleDate: staleDate)
            )
            currentActivity = activity
            isActive = true
        } catch {
            // Live Activities may be unavailable or disabled on the device.
        }
    }

    // 🔧 FIX: Removed unused `reason: String?` parameter. The parameter was
    // accepted but never passed through to the ActivityKit API. Callers should
    // remove the `reason:` label.
    func end() async {
        guard let activity = currentActivity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
        isActive = false
    }
}
