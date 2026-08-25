//
//  TeslaDeliveryOrder.swift
//  KWh Gas Companion
//
//  Tesla delivery tracking — the order model, the delivery stage ladder, and
//  the change journal that records every field that moved between checks.
//
//  Swift 6 • iOS 17+
//

import Foundation

// MARK: - Stage ladder

/// The stages a Tesla order walks through between deposit and handover.
///
/// Tesla does not publish a stage machine — the community infers it from which
/// fields have appeared on the order. `TeslaDeliveryOrder.inferredStage` does
/// that inference; this enum is the vocabulary it uses.
public enum DeliveryStage: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case orderPlaced
    case orderConfirmed
    case buildScheduled
    case inProduction
    case built
    case inTransit
    case atDeliveryCenter
    case readyForDelivery
    case delivered

    public var id: String { rawValue }

    /// Position on the ladder, 0-based.
    public var step: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    public var title: String {
        switch self {
        case .orderPlaced:      return "Order Placed"
        case .orderConfirmed:   return "Order Confirmed"
        case .buildScheduled:   return "Build Scheduled"
        case .inProduction:     return "In Production"
        case .built:            return "Built · VIN Assigned"
        case .inTransit:        return "In Transit"
        case .atDeliveryCenter: return "At Delivery Center"
        case .readyForDelivery: return "Ready for Delivery"
        case .delivered:        return "Delivered"
        }
    }

    public var systemImage: String {
        switch self {
        case .orderPlaced:      return "doc.badge.plus"
        case .orderConfirmed:   return "checkmark.seal"
        case .buildScheduled:   return "calendar.badge.clock"
        case .inProduction:     return "gearshape.2"
        case .built:            return "number.square"
        case .inTransit:        return "truck.box"
        case .atDeliveryCenter: return "building.2"
        case .readyForDelivery: return "key.horizontal"
        case .delivered:        return "party.popper"
        }
    }

    /// What this stage actually means for the person waiting.
    public var blurb: String {
        switch self {
        case .orderPlaced:
            return "Deposit taken. The configuration is locked in but nothing is scheduled yet."
        case .orderConfirmed:
            return "Order booked and in the queue. Payment method and trade-in tasks usually open here."
        case .buildScheduled:
            return "A delivery window has appeared. Your build slot is being matched to it."
        case .inProduction:
            return "The car is being built. VIN assignment typically lands a few days to a few weeks out."
        case .built:
            return "A VIN is on the order — the physical car exists and is tied to you."
        case .inTransit:
            return "The car has left the factory and is moving toward your delivery center."
        case .atDeliveryCenter:
            return "The car has arrived locally and is going through prep and inspection."
        case .readyForDelivery:
            return "Appointment scheduled. Final payment and paperwork come next."
        case .delivered:
            return "Handed over. Anything after this is service, not delivery."
        }
    }

    /// The one field that most reliably signals this stage has been reached.
    public var signal: String {
        switch self {
        case .orderPlaced:      return "Reservation date present"
        case .orderConfirmed:   return "Order booked date present"
        case .buildScheduled:   return "Delivery window shown"
        case .inProduction:     return "Window narrowed, no VIN yet"
        case .built:            return "VIN assigned"
        case .inTransit:        return "ETA to delivery center present"
        case .atDeliveryCenter: return "Odometer reading present"
        case .readyForDelivery: return "Delivery appointment scheduled"
        case .delivered:        return "Order status DELIVERED"
        }
    }
}

// MARK: - Change journal

/// One field that moved between two checks of the same order.
public struct DeliveryChangeLogEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var field: String
    public var oldValue: String
    public var newValue: String

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        field: String,
        oldValue: String,
        newValue: String
    ) {
        self.id = id
        self.date = date
        self.field = field
        self.oldValue = oldValue
        self.newValue = newValue
    }

    /// Blank values read as "—" rather than an empty gap in the log.
    public var oldDisplay: String { oldValue.isEmpty ? "—" : oldValue }
    public var newDisplay: String { newValue.isEmpty ? "—" : newValue }

    /// A first appearance reads differently from a change.
    public var isFirstAppearance: Bool { oldValue.isEmpty && !newValue.isEmpty }
}

// MARK: - Order

public struct TeslaDeliveryOrder: Identifiable, Codable, Hashable, Sendable {

    public var id: UUID
    public var createdAt: Date

    /// What the owner calls it. Falls back to the model name in the UI.
    public var nickname: String

    // Identity
    public var referenceNumber: String
    public var modelCode: String
    public var trim: String
    public var vin: String
    public var optionCodes: [String]

    // Dates
    public var reservationDate: Date?
    public var orderBookedDate: Date?

    // Delivery window — kept both as Tesla's own string and as parsed bounds,
    // because the string is what people compare against on the forums.
    public var deliveryWindowDisplay: String
    public var windowStart: Date?
    public var windowEnd: Date?

    // Logistics
    public var orderStatusCode: String
    public var etaToDeliveryCenter: String
    public var routingLocation: String
    public var deliveryAppointment: Date?
    public var deliveryAppointmentText: String
    public var odometer: Double?
    public var odometerUnit: String

    // Owner state
    public var stageOverride: DeliveryStage?
    public var notes: String
    public var changeLog: [DeliveryChangeLogEntry]
    public var lastCheckedAt: Date?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        nickname: String = "",
        referenceNumber: String = "",
        modelCode: String = "",
        trim: String = "",
        vin: String = "",
        optionCodes: [String] = [],
        reservationDate: Date? = nil,
        orderBookedDate: Date? = nil,
        deliveryWindowDisplay: String = "",
        windowStart: Date? = nil,
        windowEnd: Date? = nil,
        orderStatusCode: String = "",
        etaToDeliveryCenter: String = "",
        routingLocation: String = "",
        deliveryAppointment: Date? = nil,
        deliveryAppointmentText: String = "",
        odometer: Double? = nil,
        odometerUnit: String = "",
        stageOverride: DeliveryStage? = nil,
        notes: String = "",
        changeLog: [DeliveryChangeLogEntry] = [],
        lastCheckedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.nickname = nickname
        self.referenceNumber = referenceNumber
        self.modelCode = modelCode
        self.trim = trim
        self.vin = vin
        self.optionCodes = optionCodes
        self.reservationDate = reservationDate
        self.orderBookedDate = orderBookedDate
        self.deliveryWindowDisplay = deliveryWindowDisplay
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.orderStatusCode = orderStatusCode
        self.etaToDeliveryCenter = etaToDeliveryCenter
        self.routingLocation = routingLocation
        self.deliveryAppointment = deliveryAppointment
        self.deliveryAppointmentText = deliveryAppointmentText
        self.odometer = odometer
        self.odometerUnit = odometerUnit
        self.stageOverride = stageOverride
        self.notes = notes
        self.changeLog = changeLog
        self.lastCheckedAt = lastCheckedAt
    }
}

// MARK: - Derived

public extension TeslaDeliveryOrder {

    var modelName: String { TeslaModelCatalog.name(forCode: modelCode) }

    var displayName: String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let model = modelName
        let t = trim.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return "\(model) \(t)" }
        return model
    }

    var hasVIN: Bool { vin.trimmingCharacters(in: .whitespacesAndNewlines).count == 17 }

    /// Decoded VIN, when there is a valid one. Reuses the app's existing decoder.
    var decodedVIN: TeslaVINInfo? {
        guard hasVIN else { return nil }
        return TeslaVINDecoderLogic.decode(vin.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var spec: TeslaOptionSpec { TeslaOptionCodeDecoder.decode(optionCodes) }

    var statusDescription: TeslaOrderStatusCode { TeslaOrderStatusCode(raw: orderStatusCode) }

    /// The stage the order data implies. An explicit override always wins —
    /// owners often know something the fields have not caught up to yet.
    var stage: DeliveryStage {
        if let stageOverride { return stageOverride }
        return inferredStage
    }

    /// Walks the ladder from the top down, returning the highest stage whose
    /// signal is present. Deliberately conservative: a missing field never
    /// pushes the order forward.
    var inferredStage: DeliveryStage {
        if statusDescription.isDelivered { return .delivered }
        if deliveryAppointment != nil || !deliveryAppointmentText.isEmpty { return .readyForDelivery }
        if let odometer, odometer > 0 { return .atDeliveryCenter }
        if !etaToDeliveryCenter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .inTransit }
        if hasVIN { return .built }
        if !deliveryWindowDisplay.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .buildScheduled }
        if orderBookedDate != nil { return .orderConfirmed }
        return .orderPlaced
    }

    var progressFraction: Double {
        let total = Double(DeliveryStage.allCases.count - 1)
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(stage.step) / total))
    }

    var isComplete: Bool { stage == .delivered }

    /// Days since the deposit went down.
    var daysSinceOrder: Int? {
        let start = reservationDate ?? orderBookedDate
        guard let start else { return nil }
        return Calendar.current.dateComponents([.day], from: start, to: Date()).day
    }

    /// Negative once the window has opened.
    var daysUntilWindowStart: Int? {
        guard let windowStart else { return nil }
        return Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: windowStart)
        ).day
    }

    var daysUntilWindowEnd: Int? {
        guard let windowEnd else { return nil }
        return Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: windowEnd)
        ).day
    }

    /// The single line the tracker leads with.
    var countdownText: String {
        if isComplete { return "Delivered" }

        if let appt = deliveryAppointment {
            let days = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: appt)
            ).day ?? 0
            if days > 1  { return "Delivery in \(days) days" }
            if days == 1 { return "Delivery tomorrow" }
            if days == 0 { return "Delivery today" }
            return "Appointment has passed"
        }

        if let start = daysUntilWindowStart, start > 0 {
            return start == 1 ? "Window opens tomorrow" : "Window opens in \(start) days"
        }

        if let end = daysUntilWindowEnd {
            if end > 1  { return "Window closes in \(end) days" }
            if end == 1 { return "Window closes tomorrow" }
            if end == 0 { return "Last day of the window" }
            return "Window has passed — expect a new one"
        }

        if !deliveryWindowDisplay.isEmpty { return deliveryWindowDisplay }
        if let days = daysSinceOrder { return "Day \(days) since order" }
        return "Waiting on a delivery window"
    }

    /// True once the window has come and gone with no car. Worth surfacing —
    /// it is the point at which most owners start chasing their advisor.
    var isWindowOverdue: Bool {
        guard !isComplete, let end = daysUntilWindowEnd else { return false }
        return end < 0
    }
}

// MARK: - Change detection

public extension TeslaDeliveryOrder {

    /// Fields worth journaling, in the order they read best in a log.
    private var trackedFields: [(String, String)] {
        [
            ("Order status", statusDescription.label),
            ("VIN", vin),
            ("Delivery window", deliveryWindowDisplay),
            ("ETA to delivery center", etaToDeliveryCenter),
            ("Delivery appointment", deliveryAppointmentText),
            ("Routing location", routingLocation),
            ("Odometer", odometer.map { "\(Self.trimmedNumber($0)) \(odometerUnit)".trimmingCharacters(in: .whitespaces) } ?? ""),
            ("Trim", trim),
            ("Option codes", optionCodes.joined(separator: ", ")),
            ("Reference number", referenceNumber)
        ]
    }

    /// What moved between `old` and `self`. Values are compared as displayed,
    /// so a formatting-only difference never shows up as a change.
    func changes(comparedTo old: TeslaDeliveryOrder, at date: Date = Date()) -> [DeliveryChangeLogEntry] {
        let before = Dictionary(uniqueKeysWithValues: old.trackedFields)
        return trackedFields.compactMap { field, newValue in
            let oldValue = before[field] ?? ""
            guard oldValue != newValue else { return nil }
            return DeliveryChangeLogEntry(date: date, field: field, oldValue: oldValue, newValue: newValue)
        }
    }

    static func trimmedNumber(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}

// MARK: - Sharing

public extension TeslaDeliveryOrder {

    /// A plain-text block sized for a forum post or a text to a friend.
    /// The reference number is deliberately left out — it is the one field
    /// that identifies the order to anyone who has it.
    func forumSummary(includeVIN: Bool = false) -> String {
        var lines: [String] = []
        lines.append("\(modelName)\(trim.isEmpty ? "" : " \(trim)") — \(stage.title)")

        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none

        if let reservationDate { lines.append("Ordered: \(df.string(from: reservationDate))") }
        if let orderBookedDate { lines.append("Booked: \(df.string(from: orderBookedDate))") }
        if !deliveryWindowDisplay.isEmpty { lines.append("Window: \(deliveryWindowDisplay)") }
        if !etaToDeliveryCenter.isEmpty { lines.append("ETA to delivery center: \(etaToDeliveryCenter)") }
        if !routingLocation.isEmpty { lines.append("Routing: \(routingLocation)") }

        if includeVIN, hasVIN {
            lines.append("VIN: \(vin)")
        } else if hasVIN, let decoded = decodedVIN {
            // Plant and year are the parts people actually compare, and they
            // give nothing away on their own.
            lines.append("Built: \(decoded.plant)\(decoded.modelYear.map { " · \($0)" } ?? "")")
        }

        let spec = self.spec
        if !spec.isEmpty { lines.append("Config: \(spec.oneLine)") }
        if let days = daysSinceOrder { lines.append("Day \(days) since order") }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Model catalog

public enum TeslaModelCatalog {

    /// Tesla's own `modelCode` values, plus the spellings people type by hand.
    private static let names: [String: String] = [
        "m3": "Model 3",
        "my": "Model Y",
        "ms": "Model S",
        "mx": "Model X",
        "ct": "Cybertruck",
        "mdl3": "Model 3",
        "mdly": "Model Y",
        "mdls": "Model S",
        "mdlx": "Model X",
        "tt":  "Semi",
        "rd":  "Roadster"
    ]

    public static let pickerOptions: [(code: String, name: String)] = [
        ("m3", "Model 3"),
        ("my", "Model Y"),
        ("ms", "Model S"),
        ("mx", "Model X"),
        ("ct", "Cybertruck")
    ]

    public static func name(forCode code: String) -> String {
        let key = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if key.isEmpty { return "Tesla" }
        return names[key] ?? code.uppercased()
    }
}

// MARK: - Order status codes

/// Tesla returns a short uppercase token in `orderStatus`. This maps the values
/// that show up in practice and degrades gracefully on anything new.
public struct TeslaOrderStatusCode: Hashable, Sendable {

    public let raw: String

    public init(raw: String) {
        self.raw = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    public var isKnown: Bool { Self.table[raw] != nil }

    public var label: String {
        if raw.isEmpty { return "" }
        return Self.table[raw]?.label ?? raw
    }

    public var explanation: String {
        if raw.isEmpty { return "No order status recorded yet." }
        return Self.table[raw]?.detail
            ?? "Tesla returned “\(raw)”, which isn't a status this app recognizes. Treat the delivery window and VIN as the reliable signals."
    }

    public var isDelivered: Bool { raw == "DELIVERED" || raw == "COMPLETE" || raw == "COMPLETED" }
    public var isCancelled: Bool { raw == "CANCELLED" || raw == "CANCELED" || raw == "VOID" }

    private static let table: [String: (label: String, detail: String)] = [
        "BOOKED": (
            "Booked",
            "The order is confirmed and in Tesla's queue. This is where most orders sit for the longest stretch — it does not change when the car enters production."
        ),
        "PENDING": (
            "Pending",
            "The order exists but has not been fully booked. Usually a payment method, trade-in, or financing task is still open."
        ),
        "RESERVATION": (
            "Reservation",
            "A reservation rather than a configured order. No build slot is assigned until the configuration is locked."
        ),
        "PREORDER": (
            "Pre-order",
            "A pre-order placed before the configurator opened for this model."
        ),
        "SUBMITTED": (
            "Submitted",
            "The configuration has been submitted and is being validated before booking."
        ),
        "IN_PRODUCTION": (
            "In Production",
            "The build has started. VIN assignment usually follows within days to a few weeks."
        ),
        "PRODUCTION": (
            "In Production",
            "The build has started. VIN assignment usually follows within days to a few weeks."
        ),
        "READY_FOR_DELIVERY": (
            "Ready for Delivery",
            "The car is prepped at the delivery center. Final payment and paperwork are the remaining steps."
        ),
        "DELIVERED": (
            "Delivered",
            "The handover is complete."
        ),
        "COMPLETE": (
            "Complete",
            "The order is closed out."
        ),
        "COMPLETED": (
            "Complete",
            "The order is closed out."
        ),
        "CANCELLED": (
            "Cancelled",
            "The order was cancelled. Deposits and refund handling depend on when it was cancelled."
        ),
        "CANCELED": (
            "Cancelled",
            "The order was cancelled. Deposits and refund handling depend on when it was cancelled."
        )
    ]
}
