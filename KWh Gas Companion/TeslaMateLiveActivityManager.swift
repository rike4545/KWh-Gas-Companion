//
//  TeslaMateLiveActivityManager.swift
//  KWh Gas Companion
//
//  Live Activities support for TeslaMate charging status.
//

import Foundation
import ActivityKit

@MainActor
final class TeslaMateLiveActivityManager: ObservableObject {
    static let shared = TeslaMateLiveActivityManager()

    @Published private(set) var isActive: Bool = false

    private var currentActivity: Activity<TeslaMateChargeAttributes>?

    func startOrUpdate(
        vehicleName: String,
        batteryLevel: Int,
        chargingState: String,
        energyAddedKWh: Double?,
        cost: Double?
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = TeslaMateChargeAttributes(vehicleName: vehicleName)
        let content = TeslaMateChargeAttributes.ContentState(
            batteryLevel: batteryLevel,
            chargingState: chargingState,
            energyAddedKWh: energyAddedKWh,
            cost: cost
        )

        if let currentActivity {
            await currentActivity.update(ActivityContent(state: content, staleDate: nil))
            isActive = true
            return
        }

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: content, staleDate: nil)
            )
            currentActivity = activity
            isActive = true
        } catch {
            // Silent failure: Live Activities may be disabled on device
        }
    }

    func end(reason: String? = nil) async {
        guard let currentActivity else { return }
        await currentActivity.end(nil, dismissalPolicy: .immediate)
        self.currentActivity = nil
        isActive = false
    }
}
