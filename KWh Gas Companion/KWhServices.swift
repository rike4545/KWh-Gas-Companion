//
//  KWhServices.swift
//  KWh Gas Companion
//
//  Created by Bryan on 11/2/25.
//


//  KWhServices.swift
//  My KWh Companion
//  MetricKit + BackgroundTasks wrappers (compile-safe, Swift 6)

import Foundation
import MetricKit
import BackgroundTasks
import OSLog

enum KWhServices {
    static var bgRefreshID: String = "com.your.bundle.refresh"

    static func startMetricKit() {
        MXMetricManager.shared.add(MetricSubscriber.shared)
    }
    static func stopMetricKit() {
        MXMetricManager.shared.remove(MetricSubscriber.shared)
    }

    static func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: bgRefreshID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            scheduleBackgroundRefresh(earliest: Date().addingTimeInterval(60 * 60))
            Task { await refreshCaches(); task.setTaskCompleted(success: true) }
        }
    }

    static func scheduleBackgroundRefresh(earliest: Date? = nil) {
        let request = BGAppRefreshTaskRequest(identifier: bgRefreshID)
        if let t = earliest { request.earliestBeginDate = t }
        try? BGTaskScheduler.shared.submit(request)
    }

    nonisolated private static func refreshCaches() async {
        // Hook: rotate cache (prices/chargers/forecast precompute)
        os_log("Background refresh tick", type: .info)
    }
}

// MARK: - Metric subscriber

final class MetricSubscriber: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricSubscriber()
    func didReceive(_ payloads: [MXMetricPayload]) { /* optionally export */ }
    func didReceive(_ payloads: [MXDiagnosticPayload]) { /* optionally export */ }
}
