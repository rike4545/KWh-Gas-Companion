//
//  SystemHealthView.swift
//  My KWh Companion
//
//  Swift 6 / iOS 17+
//
//  Self-contained system health & utilities screen.
//  - No theme/token dependencies
//  - Uses NotificationIntegration shim (async calls wrapped with Task)
//  - Shows basic app/runtime info and quick actions
//

import SwiftUI
import UserNotifications

@MainActor
struct SystemHealthView: View {
    // Optional app model if you want to surface import/merge states, etc.
    @EnvironmentObject private var app: KWhGasCompanionAppModel

    // Local UI state
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var pendingCount: Int = 0
    @State private var deliveredCount: Int = 0
    @State private var lastRefresh: Date = Date()
    @State private var isRefreshing: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                HeaderCard()

                // Notifications summary
                NotificationsStatusCard(
                    authStatus: authStatus,
                    pendingCount: pendingCount,
                    deliveredCount: deliveredCount,
                    lastRefresh: lastRefresh,
                    isRefreshing: isRefreshing,
                    onRefresh: refreshAll
                )

                // Quick actions for notifications
                NotificationActionsCard(
                    requestAuth: {
                        Task {
                            let ok = await NotificationIntegration.requestAuthorization()
                            await MainActor.run {
                                if !ok { errorMessage = "User denied notifications or an error occurred." }
                                refreshAll()
                            }
                        }
                    },
                    registerCategories: {
                        NotificationIntegration.registerCategories()
                        refreshAll()
                    },
                    scheduleDemo: {
                        Task { await NotificationIntegration.scheduleDemo() }
                    },
                    ensureRepeating: {
                        Task { await NotificationIntegration.ensureRepeatingSchedules() }
                    },
                    clearAll: {
                        Task { await NotificationIntegration.clearAll(); refreshAll() }
                    }
                )

                // App / runtime quick info (safe fallbacks)
                RuntimeInfoCard()

                // Errors, if any
                if let msg = errorMessage {
                    MessageCard(systemImage: "exclamationmark.triangle.fill",
                                title: "Notice",
                                message: msg)
                }
            }
            .padding(16)
        }
        .navigationTitle("System Health")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Configure categories silently, then refresh snapshot
            Task {
                await NotificationIntegration.configureOnLaunch(requestAuthorizationIfNeeded: false)
                refreshAll()
            }
        }
    }

    // MARK: - Snapshot Refresh

    private func refreshAll() {
        isRefreshing = true
        errorMessage = nil
        Task {
            let center = UNUserNotificationCenter.current()

            // Authorization status
            let settings = await center.notificationSettings()
            let status = settings.authorizationStatus

            // Pending requests
            let pending = await withCheckedContinuation { cont in
                center.getPendingNotificationRequests { reqs in
                    cont.resume(returning: reqs)
                }
            }

            // Delivered notifications
            let delivered = await withCheckedContinuation { cont in
                center.getDeliveredNotifications { notes in
                    cont.resume(returning: notes)
                }
            }

            await MainActor.run {
                self.authStatus = status
                self.pendingCount = pending.count
                self.deliveredCount = delivered.count
                self.lastRefresh = Date()
                self.isRefreshing = false
            }
        }
    }
}

// MARK: - Subviews

fileprivate struct HeaderCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "heart.text.square")
                    .font(.title3.weight(.semibold))
                Text("System Health")
                    .font(.title3.weight(.semibold))
            }
            Text("Check notification readiness, review queued alerts, and run common maintenance actions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.secondary.opacity(0.08)))
    }
}

fileprivate struct NotificationsStatusCard: View {
    let authStatus: UNAuthorizationStatus
    let pendingCount: Int
    let deliveredCount: Int
    let lastRefresh: Date
    let isRefreshing: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge")
                    .font(.headline)
                Text("Notifications Status")
                    .font(.headline)
                Spacer()
                if isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        onRefresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Refresh status")
                }
            }

            Grid(horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    statusRow(label: "Authorization", value: statusText(authStatus))
                    statusRow(label: "Pending", value: "\(pendingCount)")
                }
                GridRow {
                    statusRow(label: "Delivered", value: "\(deliveredCount)")
                    statusRow(label: "Updated", value: relativeDate(lastRefresh))
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.secondary.opacity(0.08)))
    }

    @ViewBuilder
    private func statusRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline)
        }
    }

    private func statusText(_ s: UNAuthorizationStatus) -> String {
        switch s {
        case .notDetermined: return "Not Determined"
        case .denied:        return "Denied"
        case .authorized:    return "Authorized"
        case .provisional:   return "Provisional"
        case .ephemeral:     return "Ephemeral"
        @unknown default:    return "Unknown"
        }
    }

    private func relativeDate(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: Date())
    }
}

fileprivate struct NotificationActionsCard: View {
    let requestAuth: () -> Void
    let registerCategories: () -> Void
    let scheduleDemo: () -> Void
    let ensureRepeating: () -> Void
    let clearAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.headline)
                Text("Notification Actions")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 10) {
                HStack {
                    Button {
                        requestAuth()
                    } label: { Label("Request Authorization", systemImage: "bell.and.waves.left.and.right") }
                    .buttonStyle(.borderedProminent)

                    Button {
                        registerCategories()
                    } label: { Label("Register Categories", systemImage: "list.bullet.rectangle") }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Button {
                        scheduleDemo()
                    } label: { Label("Schedule Demo", systemImage: "sparkles") }
                    .buttonStyle(.bordered)

                    Button {
                        ensureRepeating()
                    } label: { Label("Ensure Repeating", systemImage: "calendar.badge.clock") }
                    .buttonStyle(.bordered)
                }

                Button(role: .destructive) {
                    clearAll()
                } label: { Label("Clear All Notifications", systemImage: "trash") }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.secondary.opacity(0.08)))
    }
}

fileprivate struct RuntimeInfoCard: View {
    var body: some View {
        let device = UIDevice.current
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.headline)
                Text("Runtime Info")
                    .font(.headline)
                Spacer()
            }
            Grid(horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    infoRow(label: "App Version", value: bundleValue("CFBundleShortVersionString"))
                    infoRow(label: "Build", value: bundleValue("CFBundleVersion"))
                }
                GridRow {
                    infoRow(label: "Device", value: device.model)
                    infoRow(label: "iOS", value: device.systemVersion)
                }
                GridRow {
                    infoRow(label: "Locale", value: Locale.current.identifier)
                    infoRow(label: "Time Zone", value: TimeZone.current.identifier)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.secondary.opacity(0.08)))
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline)
        }
    }

    private func bundleValue(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "—"
    }
}

fileprivate struct MessageCard: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.orange)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let entries  = EntriesStore()
    let profile  = ProfileStore()
    let teslaFi  = TeslaFiSessionStore()
    let appModel = KWhGasCompanionAppModel(
        teslaFiStore: teslaFi,
        profileStore: profile,
        entriesStore: entries
    )

    return NavigationStack {
        SystemHealthView()
            .environmentObject(appModel)
            .environmentObject(entries)
            .environmentObject(profile)
            // Optional: include if any subviews reference the store directly
            .environmentObject(teslaFi)
    }
}
#endif
