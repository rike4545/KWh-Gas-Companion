//
//  ChargingBudgetGuardrailsEngine.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/17/25.
//


//
//  ChargingBudgetGuardrailsEngine.swift
//  My KWh Companion
//
//  Local notification guardrails for charging budget.
//  Swift 6 • iOS 17+
//

import Foundation
import UserNotifications

@MainActor
final class ChargingBudgetGuardrailsEngine {

    static func monthStart(for date: Date = Date()) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }

    static func monthToDateChargingCost(entries: EntriesStore) -> Double {
        let start = monthStart()
        return entries.energyEntries()
            .filter { $0.date >= start }
            .map(\.amount)
            .reduce(0, +)
    }

    static func requestNotificationAuthIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func scheduleIfNeeded(
        entries: EntriesStore,
        monthlyBudget: Double,
        threshold: Double = 0.85
    ) async {
        guard monthlyBudget > 0 else { return }
        let spent = monthToDateChargingCost(entries: entries)
        guard spent >= monthlyBudget * threshold else { return }

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Charging budget alert"
        content.body = String(format: "You’ve spent $%.2f of your $%.2f charging budget this month.", spent, monthlyBudget)
        content.sound = .default

        // fire once per day max: use a fixed identifier and replace it
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let req = UNNotificationRequest(identifier: "chargingBudgetGuardrails", content: content, trigger: trigger)
        try? await center.add(req)
    }
}
