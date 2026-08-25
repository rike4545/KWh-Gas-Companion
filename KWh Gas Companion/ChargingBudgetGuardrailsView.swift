//  ChargingBudgetGuardrailsView.swift
//  My KWh Companion
//
//  Local-notification guardrails for monthly charging budget.
//  Swift 6 • iOS 17+
//

import SwiftUI
import UserNotifications
import Combine

@MainActor
struct ChargingBudgetGuardrailsView: View {

    @EnvironmentObject private var entriesStore: EntriesStore

    @AppStorage("budgetGuardrailsEnabled") private var enabled: Bool = false
    @AppStorage("budgetGuardrailsMonthlyBudget") private var monthlyBudget: Double = 150.0
    @AppStorage("budgetGuardrailsThreshold") private var threshold: Double = 0.85

    @AppStorage("budgetGuardrailsLastNotifyTS") private var lastNotifyTS: Double = 0

    @State private var monthToDate: Double = 0
    @State private var authStatusText: String = "Unknown"

    private var monthStart: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    }

    private var remaining: Double { max(0, monthlyBudget - monthToDate) }
    private var triggerAt: Double { monthlyBudget * threshold }

    var body: some View {
        List {
            Section {
                Text("Get a notification when you reach a percentage of your monthly charging spend.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Guardrails") {
                Toggle("Enable budget alerts", isOn: $enabled)
                    .onChange(of: enabled) { _, newValue in
                        if newValue {
                            Task { await requestAuthAndRefreshStatus() }
                        }
                    }

                HStack {
                    Text("Monthly budget")
                    Spacer()
                    TextField("", value: $monthlyBudget, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Alert threshold")
                        Spacer()
                        Text("\(Int(threshold * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $threshold, in: 0.50...0.98, step: 0.01)
                }
            }

            Section("This month") {
                HStack {
                    Text("Month-to-date spend")
                    Spacer()
                    Text(monthToDate, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Alert triggers at")
                    Spacer()
                    Text(triggerAt, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Remaining")
                    Spacer()
                    Text(remaining, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .foregroundStyle(.secondary)
                }

                if enabled && monthlyBudget > 0 && monthToDate >= triggerAt {
                    Text("You’re past the threshold. A notification will fire once per day max.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            Section("Notifications") {
                HStack {
                    Text("Authorization")
                    Spacer()
                    Text(authStatusText)
                        .foregroundStyle(.secondary)
                }

                Button("Check now") {
                    recalcAndMaybeNotify()
                }

                Button("Send a test notification") {
                    Task { await sendTestNotification() }
                }
            }
        }
        .navigationTitle("Budget Guardrails")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await refreshAuthStatus() }
            recalcAndMaybeNotify()
        }
        .onReceive(entriesStore.$entries) { _ in
            recalcAndMaybeNotify()
        }
    }

    private func recalcAndMaybeNotify() {
        // MTD spend from energy-effective entries
        monthToDate = entriesStore.entries
            .filter { $0.isEnergyEffective && $0.date >= monthStart }
            .map(\.amount)
            .reduce(0, +)

        guard enabled else { return }
        guard monthlyBudget > 0 else { return }
        guard monthToDate >= (monthlyBudget * threshold) else { return }

        // Once per day max
        let last = Date(timeIntervalSince1970: lastNotifyTS)
        if Calendar.current.isDate(last, inSameDayAs: Date()) { return }

        Task { await scheduleBudgetNotification(spent: monthToDate, budget: monthlyBudget) }
    }

    private func requestAuthAndRefreshStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized:
            authStatusText = "Authorized"
        case .denied:
            authStatusText = "Denied"
        case .notDetermined:
            authStatusText = "Not determined"
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            let s2 = await center.notificationSettings()
            authStatusText = (s2.authorizationStatus == .authorized) ? "Authorized" : "Not authorized"
        case .provisional:
            authStatusText = "Provisional"
        case .ephemeral:
            authStatusText = "Ephemeral"
        @unknown default:
            authStatusText = "Unknown"
        }
    }

    private func refreshAuthStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized:
            authStatusText = "Authorized"
        case .denied:
            authStatusText = "Denied"
        case .notDetermined:
            authStatusText = "Not determined"
        case .provisional:
            authStatusText = "Provisional"
        case .ephemeral:
            authStatusText = "Ephemeral"
        @unknown default:
            authStatusText = "Unknown"
        }
    }

    private func scheduleBudgetNotification(spent: Double, budget: Double) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "Charging budget alert"
        content.body = String(format: "You’ve spent $%.2f of your $%.2f charging budget this month.", spent, budget)
        content.sound = .default

        // Replace existing
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(identifier: "chargingBudgetGuardrails", content: content, trigger: trigger)
        try? await center.add(req)

        lastNotifyTS = Date().timeIntervalSince1970
    }

    private func sendTestNotification() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "Test alert"
        content.body = "Budget guardrails are working."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(identifier: "chargingBudgetGuardrails.test", content: content, trigger: trigger)
        try? await center.add(req)
    }
}
