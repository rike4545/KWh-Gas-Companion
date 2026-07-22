//
//  KWh.swift
//  My KWh Companion
//
//  Facade for OS integrations used across the app:
//  - MetricKit subscription (nonisolated; Swift 6 safe)
//  - BackgroundTasks registration + scheduling (refresh + processing)
//  - Double-registration guard, cancellation-safe handlers, and DEBUG diagnostics
//
//  Swift 6 / iOS 17+
//

import Foundation
import MetricKit
import BackgroundTasks

// MARK: - Public Facade

public enum KWh: Sendable {

    // MARK: Identifiers (should also be listed in Info.plist → BGTaskSchedulerPermittedIdentifiers)
    public static var backgroundRefreshIdentifier: String    = defaultBackgroundIdentifier(suffix: "refresh")
    public static var backgroundProcessingIdentifier: String = defaultBackgroundIdentifier(suffix: "processing")

    // MARK: MetricKit

    /// Begin listening for MetricKit payloads (safe in Swift 6).
    public static func startMetricKit() {
        MXMetricManager.shared.add(_MetricSubscriber.shared)
    }

    /// Stop listening for MetricKit payloads.
    public static func stopMetricKit() {
        MXMetricManager.shared.remove(_MetricSubscriber.shared)
    }

    // MARK: BackgroundTasks — Registration

    /// Register background task handlers. Call once during app launch (main actor).
    /// - Parameters:
    ///   - onRefresh:    Lightweight refresh body (fast; system time-limits).
    ///   - onProcessing: Heavier background body (optional). Only registered if provided.
    ///   - autoReschedule: If true, best-effort reschedules the same task on completion.
    @MainActor
    public static func registerBackgroundHandlers(
        onRefresh: @escaping @Sendable () -> Void,
        onProcessing: (@Sendable () -> Void)? = nil,   // keep optional non-escaping type to avoid Swift warning
        autoReschedule: Bool = true
    ) {
        // Try to load identifiers from Info.plist automatically (DEBUG only).
        // If they remain placeholders, we log but do NOT crash.
        _loadBGIdentifiersFromPlistIfPresent_DEBUG()

        // Prevent duplicate registration across multiple scenes.
        struct _Once { static var didRegister = false }
        guard !_Once.didRegister else { return }
        _Once.didRegister = true

        // Gentle warning if IDs still look like placeholders (doesn't crash).
        _warnIfIdentifiersLookUnconfigured_DEBUG()

        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundRefreshIdentifier, using: .main) { task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            _handleRefresh(task, autoReschedule: autoReschedule, body: onRefresh)
        }

        if let onProcessing {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundProcessingIdentifier, using: .main) { task in
                guard let task = task as? BGProcessingTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                _handleProcessing(task, autoReschedule: autoReschedule, body: onProcessing)
            }
        }
    }

    // MARK: BackgroundTasks — Scheduling

    /// Schedule a Background App Refresh. (Best-effort; logs errors in DEBUG.)
    public static func scheduleBackgroundRefresh(earliest date: Date?) {
        Task { @MainActor in
            let req = BGAppRefreshTaskRequest(identifier: backgroundRefreshIdentifier)
            if let date { req.earliestBeginDate = date }
            do {
                try BGTaskScheduler.shared.submit(req)
            } catch {
                #if DEBUG
                print("⚠️ BG refresh submit failed: \(error)")
                #endif
            }
        }
    }

    /// Schedule a Background Processing task (heavier work).
    public static func scheduleBackgroundProcessing(
        earliest date: Date?,
        requiresNetwork: Bool,
        requiresExternalPower: Bool
    ) {
        Task { @MainActor in
            let req = BGProcessingTaskRequest(identifier: backgroundProcessingIdentifier)
            req.requiresNetworkConnectivity = requiresNetwork
            req.requiresExternalPower = requiresExternalPower
            if let date { req.earliestBeginDate = date }
            do {
                try BGTaskScheduler.shared.submit(req)
            } catch {
                #if DEBUG
                print("⚠️ BG processing submit failed: \(error)")
                #endif
            }
        }
    }

    /// Cancel all scheduled background tasks for this app.
    @MainActor
    public static func cancelAllScheduledTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
    }
}

// MARK: - Private: BGTask Handlers (cancellation-safe)

@MainActor
private extension KWh {

    static func _handleRefresh(
        _ task: BGAppRefreshTask,
        autoReschedule: Bool,
        body: @escaping @Sendable () -> Void
    ) {
        var worker: Task<Void, Never>?
        task.expirationHandler = { worker?.cancel() }

        worker = Task.detached(priority: .background) {
            await withTaskCancellationHandler {
                body()
            } onCancel: {
                // Optional cleanup; keep idempotent
            }

            await MainActor.run {
                task.setTaskCompleted(success: !Task.isCancelled)
                if autoReschedule {
                    // Reschedule ~1 hour later (best-effort; the system decides the actual time)
                    KWh.scheduleBackgroundRefresh(earliest: Date().addingTimeInterval(60 * 60))
                }
            }
        }
    }

    static func _handleProcessing(
        _ task: BGProcessingTask,
        autoReschedule: Bool,
        body: @escaping @Sendable () -> Void
    ) {
        var worker: Task<Void, Never>?
        task.expirationHandler = { worker?.cancel() }

        worker = Task.detached(priority: .utility) {
            await withTaskCancellationHandler {
                body()
            } onCancel: { }

            await MainActor.run {
                task.setTaskCompleted(success: !Task.isCancelled)
                if autoReschedule {
                    // Reschedule ~2 hours later
                    KWh.scheduleBackgroundProcessing(
                        earliest: Date().addingTimeInterval(2 * 60 * 60),
                        requiresNetwork: true,
                        requiresExternalPower: false
                    )
                }
            }
        }
    }
}

// MARK: - MetricKit subscriber (nonisolated)

private final class _MetricSubscriber: NSObject, MXMetricManagerSubscriber {
    static let shared = _MetricSubscriber()

    // Not @MainActor — MetricKit may call on background threads.
    func didReceive(_ payloads: [MXMetricPayload]) {
        #if DEBUG
        if !payloads.isEmpty { print("📊 MetricKit: received \(payloads.count) metric payload(s)") }
        #endif
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        #if DEBUG
        let fm = FileManager.default
        guard let docs = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            return
        }
        let ts  = ISO8601DateFormatter().string(from: Date())
        let dir = docs.appendingPathComponent("MetricKit", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        for (i, p) in payloads.enumerated() {
            let url = dir.appendingPathComponent("MXDiag-\(ts)-\(i).log")
            try? p.description.data(using: .utf8)?.write(to: url)
            print("📦 MetricKit diagnostics → \(url.path)")
        }
        #endif
    }
}

// MARK: - DEBUG helpers (non-fatal)

@MainActor
private func _warnIfIdentifiersLookUnconfigured_DEBUG() {
    #if DEBUG
    func looksPlaceholder(_ s: String) -> Bool {
        s.contains("your.bundle") || s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var warnings: [String] = []
    if looksPlaceholder(KWh.backgroundRefreshIdentifier) {
        warnings.append("backgroundRefreshIdentifier='\(KWh.backgroundRefreshIdentifier)'")
    }
    if looksPlaceholder(KWh.backgroundProcessingIdentifier) {
        warnings.append("backgroundProcessingIdentifier='\(KWh.backgroundProcessingIdentifier)'")
    }
    if !warnings.isEmpty {
        // Non-fatal so you can continue wiring; scheduling may silently fail if IDs don't match your plist.
        print("⚠️ KWh DEBUG: BGTask identifiers look unconfigured. Update Info.plist BGTaskSchedulerPermittedIdentifiers and set matching IDs. \(warnings.joined(separator: ", "))")
    }
    #endif
}

/// Attempt to read the first two identifiers from Info.plist's BGTaskSchedulerPermittedIdentifiers if present.
@MainActor
private func _loadBGIdentifiersFromPlistIfPresent_DEBUG() {
    #if DEBUG
    guard let ids = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String],
          !ids.isEmpty else { return }
    if ids.indices.contains(0) { KWh.backgroundRefreshIdentifier = ids[0] }
    if ids.indices.contains(1) { KWh.backgroundProcessingIdentifier = ids[1] }
    #endif
}

private func defaultBackgroundIdentifier(suffix: String) -> String {
    let base = Bundle.main.bundleIdentifier ?? "Me.KWh-Gas-Companion"
    return "\(base).\(suffix)"
}
