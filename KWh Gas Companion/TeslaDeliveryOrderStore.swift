//
//  TeslaDeliveryOrderStore.swift
//  KWh Gas Companion
//
//  Persistence and change journaling for tracked Tesla orders, plus the local
//  reminders that fire around a delivery window.
//
//  Everything here is on-device. No order data leaves the phone.
//
//  Swift 6 • iOS 17+
//

import Foundation
import Combine
import UserNotifications

@MainActor
final class TeslaDeliveryOrderStore: ObservableObject {

    @Published private(set) var orders: [TeslaDeliveryOrder] = [] {
        didSet { persist() }
    }

    private let filename: String
    private var isHydrating = true

    init(filename: String = "tesla_delivery_orders.json") {
        self.filename = filename
        hydrate()
        isHydrating = false
    }

    // MARK: - Derived

    /// Active orders first, each group newest-first.
    var sortedOrders: [TeslaDeliveryOrder] {
        orders.sorted { lhs, rhs in
            if lhs.isComplete != rhs.isComplete { return !lhs.isComplete }
            return lhs.createdAt > rhs.createdAt
        }
    }

    var activeOrders: [TeslaDeliveryOrder] { orders.filter { !$0.isComplete } }

    /// Every journal entry across every order, newest first — the "what changed"
    /// feed on the hub.
    var combinedChangeLog: [(order: TeslaDeliveryOrder, entry: DeliveryChangeLogEntry)] {
        orders
            .flatMap { order in order.changeLog.map { (order: order, entry: $0) } }
            .sorted { $0.entry.date > $1.entry.date }
    }

    func order(id: UUID) -> TeslaDeliveryOrder? {
        orders.first { $0.id == id }
    }

    // MARK: - Mutation

    func add(_ order: TeslaDeliveryOrder) {
        var new = order
        // Seed the journal so the timeline has a starting point.
        new.changeLog.append(
            DeliveryChangeLogEntry(
                date: new.createdAt,
                field: "Tracking started",
                oldValue: "",
                newValue: new.displayName
            )
        )
        orders.append(new)
        refreshReminders(for: new)
    }

    /// Replaces an order, journaling every tracked field that moved.
    /// Journaling is what makes the change log worth having, so it happens here
    /// rather than at each call site.
    func update(_ updated: TeslaDeliveryOrder, journal: Bool = true) {
        guard let index = orders.firstIndex(where: { $0.id == updated.id }) else { return }
        let previous = orders[index]

        var next = updated
        if journal {
            let changes = updated.changes(comparedTo: previous)
            if !changes.isEmpty {
                next.changeLog.append(contentsOf: changes)
            }
        }
        next.changeLog = Array(next.changeLog.suffix(Self.maxJournalEntries))

        orders[index] = next
        refreshReminders(for: next)
    }

    func delete(id: UUID) {
        cancelReminders(for: id)
        orders.removeAll { $0.id == id }
    }

    func markChecked(id: UUID) {
        guard let index = orders.firstIndex(where: { $0.id == id }) else { return }
        orders[index].lastCheckedAt = Date()
    }

    func clearChangeLog(id: UUID) {
        guard let index = orders.firstIndex(where: { $0.id == id }) else { return }
        orders[index].changeLog.removeAll()
    }

    private static let maxJournalEntries = 400

    // MARK: - Persistence

    private var saveURL: URL {
        let base = (try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(filename)
    }

    private func hydrate() {
        guard let data = try? Data(contentsOf: saveURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([TeslaDeliveryOrder].self, from: data) else { return }
        orders = decoded
    }

    private func persist() {
        guard !isHydrating else { return }
        let snapshot = orders
        let url = saveURL
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}

// MARK: - Reminders

extension TeslaDeliveryOrderStore {

    /// Asked for from a button, never on launch — an unprompted permission
    /// sheet is the fastest way to get told no.
    static func requestNotificationAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }

    static func notificationsEnabled() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    private static func identifiers(for orderID: UUID) -> [String] {
        ["windowOpen", "windowSoon", "appointment", "overdue"].map { "teslaDelivery.\(orderID.uuidString).\($0)" }
    }

    func cancelReminders(for orderID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: Self.identifiers(for: orderID))
    }

    /// Rebuilds every reminder for one order. Cheap enough to run on any edit,
    /// which keeps the schedule honest when a window moves.
    func refreshReminders(for order: TeslaDeliveryOrder) {
        cancelReminders(for: order.id)
        guard !order.isComplete else { return }

        let center = UNUserNotificationCenter.current()
        let name = order.displayName

        func schedule(_ suffix: String, title: String, body: String, at date: Date) {
            guard date > Date() else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            components.hour = 9
            components.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "teslaDelivery.\(order.id.uuidString).\(suffix)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }

        let calendar = Calendar.current

        if let appointment = order.deliveryAppointment {
            if let dayBefore = calendar.date(byAdding: .day, value: -1, to: appointment) {
                schedule(
                    "appointment",
                    title: "Delivery tomorrow",
                    body: "\(name) — run the Delivery Day Checklist tonight so you're not doing it in the lot.",
                    at: dayBefore
                )
            }
        } else if let windowStart = order.windowStart {
            if let week = calendar.date(byAdding: .day, value: -7, to: windowStart) {
                schedule(
                    "windowSoon",
                    title: "Delivery window opens in a week",
                    body: "\(name) — \(order.deliveryWindowDisplay). Good time to line up insurance and payment.",
                    at: week
                )
            }
            schedule(
                "windowOpen",
                title: "Delivery window is open",
                body: "\(name) — check your order for a VIN or an appointment.",
                at: windowStart
            )
        }

        if let windowEnd = order.windowEnd,
           let dayAfter = calendar.date(byAdding: .day, value: 1, to: windowEnd) {
            schedule(
                "overdue",
                title: "Delivery window has passed",
                body: "\(name) — no delivery yet. Worth a message to your advisor about a new window.",
                at: dayAfter
            )
        }
    }

    /// Re-arms everything, e.g. after the user grants permission.
    func refreshAllReminders() {
        for order in orders { refreshReminders(for: order) }
    }
}
