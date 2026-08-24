//
//  TeslaOrderJSONImporter.swift
//  KWh Gas Companion
//
//  Parses a Tesla order payload the owner obtained themselves and folds it into
//  a `TeslaDeliveryOrder`.
//
//  WHY A PASTE BOX AND NOT A LOGIN
//  ───────────────────────────────
//  Order data lives on Tesla's private first-party endpoints
//  (`owner-api.teslamotors.com/api/1/users/orders` and the `/tasks` gateway).
//  Reaching them requires the official Tesla app's client ID and TLS
//  fingerprint. Tesla's public Fleet API — the one this app authenticates
//  against — has no order surface at all. So this app never touches those
//  endpoints; it accepts the JSON the owner already pulled with a community
//  tool and does the decoding locally.
//
//  Shape-agnostic on purpose: the payload can be the raw `/tasks` response, a
//  single element from `/users/orders`, an array of either, or the merged
//  `{ "order": …, "details": … }` blob the community scripts save. The parser
//  walks the whole tree looking for known keys rather than assuming a layout.
//
//  Swift 6 • iOS 17+
//

import Foundation

public struct TeslaOrderImportResult: Sendable {
    /// Fields the payload actually supplied, for the confirmation screen.
    public var matchedFields: [String]
    public var order: TeslaDeliveryOrder

    public var isEmpty: Bool { matchedFields.isEmpty }
}

public enum TeslaOrderImportError: LocalizedError {
    case notJSON
    case noRecognizedFields

    public var errorDescription: String? {
        switch self {
        case .notJSON:
            return "That doesn't parse as JSON. Copy the whole response, including the outermost { } or [ ]."
        case .noRecognizedFields:
            return "The JSON parsed, but none of Tesla's order fields were in it. Make sure you copied the order or /tasks response rather than a different endpoint."
        }
    }
}

public enum TeslaOrderJSONImporter {

    /// Merges a pasted payload into `base`, leaving any field the payload
    /// doesn't mention untouched.
    public static func apply(json: String, to base: TeslaDeliveryOrder) throws -> TeslaOrderImportResult {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data)
        else { throw TeslaOrderImportError.notJSON }

        let index = KeyIndex(root: root)
        var order = base
        var matched: [String] = []

        func take(_ label: String, _ keys: [String], _ assign: (String) -> Bool) {
            for key in keys {
                guard let value = index.string(forKey: key), !value.isEmpty else { continue }
                if assign(value) { matched.append(label) }
                return
            }
        }

        take("Reference number", ["referenceNumber", "reservationNumber", "orderId"]) {
            order.referenceNumber = $0; return true
        }
        take("Order status", ["orderStatus", "status"]) {
            order.orderStatusCode = $0; return true
        }
        take("Model", ["modelCode", "model"]) {
            order.modelCode = $0; return true
        }
        take("VIN", ["vin"]) {
            let candidate = $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard candidate.count == 17 else { return false }
            order.vin = candidate
            return true
        }
        take("Trim", ["trimCode", "trimName", "vehicleTrim"]) {
            order.trim = $0; return true
        }
        take("Option codes", ["mktOptions", "optionCodes", "optionCodeList", "options"]) {
            let codes = TeslaOptionCodeDecoder.split($0)
            guard !codes.isEmpty else { return false }
            order.optionCodes = codes
            return true
        }
        take("Reservation date", ["reservationDate"]) {
            guard let date = Self.parseDate($0) else { return false }
            order.reservationDate = date
            return true
        }
        take("Order booked date", ["orderBookedDate", "bookedDate"]) {
            guard let date = Self.parseDate($0) else { return false }
            order.orderBookedDate = date
            return true
        }
        take("Delivery window", ["deliveryWindowDisplay", "deliveryWindow"]) {
            order.deliveryWindowDisplay = $0
            let bounds = TeslaDeliveryWindowParser.parse($0)
            order.windowStart = bounds.start
            order.windowEnd = bounds.end
            return true
        }
        take("ETA to delivery center", ["etaToDeliveryCenter", "eta"]) {
            order.etaToDeliveryCenter = $0; return true
        }
        take("Delivery appointment", ["apptDateTimeAddressStr", "deliveryAppointmentDate", "apptDateTime"]) {
            order.deliveryAppointmentText = $0
            if let date = Self.parseDate($0) { order.deliveryAppointment = date }
            return true
        }
        take("Routing location", ["vehicleRoutingLocation", "routingLocation", "deliveryLocation"]) {
            order.routingLocation = $0; return true
        }
        take("Odometer", ["vehicleOdometer", "odometer"]) {
            guard let value = Double($0) else { return false }
            order.odometer = value
            return true
        }
        take("Odometer unit", ["vehicleOdometerType", "odometerType"]) {
            order.odometerUnit = $0.capitalized
            return false   // a unit alone isn't worth reporting as a match
        }

        guard !matched.isEmpty else { throw TeslaOrderImportError.noRecognizedFields }

        order.lastCheckedAt = Date()
        return TeslaOrderImportResult(matchedFields: matched, order: order)
    }

    // MARK: Dates

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let fallbackFormats = [
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd",
        "MM/dd/yyyy",
        "MMM d, yyyy",
        "MMMM d, yyyy"
    ]

    /// Tesla mixes ISO timestamps, bare dates, and human strings across fields.
    static func parseDate(_ raw: String) -> Date? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let date = isoFractional.date(from: value) { return date }
        if let date = iso.date(from: value) { return date }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in fallbackFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }

        // Appointment strings bury the date in prose — pull the first date-like
        // run out of it rather than failing the whole field.
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(value.startIndex..., in: value)
            if let match = detector.firstMatch(in: value, range: range)?.date { return match }
        }
        return nil
    }
}

// MARK: - Recursive key lookup

/// Flattens an arbitrary JSON tree into first-seen values per key. Tesla nests
/// the same field at different depths depending on which endpoint produced the
/// payload, so a breadth-first walk beats hard-coded key paths.
private struct KeyIndex {

    private var values: [String: String] = [:]

    init(root: Any) {
        var queue: [Any] = [root]
        var guardCounter = 0

        while !queue.isEmpty, guardCounter < 20_000 {
            let node = queue.removeFirst()
            guardCounter += 1

            switch node {
            case let dict as [String: Any]:
                for (key, value) in dict {
                    switch value {
                    case is [String: Any], is [Any]:
                        queue.append(value)
                    default:
                        let lowered = key.lowercased()
                        if values[lowered] == nil, let scalar = Self.scalar(value) {
                            values[lowered] = scalar
                        }
                    }
                }
            case let array as [Any]:
                queue.append(contentsOf: array)
            default:
                break
            }
        }
    }

    func string(forKey key: String) -> String? {
        values[key.lowercased()]
    }

    private static func scalar(_ value: Any) -> String? {
        switch value {
        case let s as String:
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let n as NSNumber:
            // Bools arrive as NSNumber too and are never useful here.
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return nil }
            return n.doubleValue == n.doubleValue.rounded()
                ? String(n.intValue)
                : n.stringValue
        default:
            return nil
        }
    }
}

// MARK: - Delivery window parsing

/// Turns Tesla's `deliveryWindowDisplay` into real dates so the tracker can
/// count down. The string has no fixed format — "Sep 15 – Sep 30",
/// "October 2025", and "Oct 1, 2025 - Oct 21, 2025" all show up.
public enum TeslaDeliveryWindowParser {

    public struct Bounds: Sendable {
        public var start: Date?
        public var end: Date?
    }

    public static func parse(_ raw: String, referenceDate: Date = Date()) -> Bounds {
        let value = raw
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: " to ", with: " - ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else { return Bounds() }

        let calendar = Calendar.current
        let halves = value.split(separator: "-", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // "October 2025" / "Oct 2025" — the whole month is the window.
        if halves.count == 1, let month = monthOnly(value) {
            let start = month
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: month)
            return Bounds(start: start, end: end)
        }

        guard halves.count == 2 else {
            return Bounds(start: dayValue(value, referenceDate: referenceDate), end: nil)
        }

        // A trailing year usually applies to both halves: "Oct 1 - Oct 21, 2025".
        let trailingYear = year(in: halves[1])
        let startText = year(in: halves[0]) == nil && trailingYear != nil
            ? "\(halves[0]), \(trailingYear!)"
            : halves[0]

        let start = dayValue(startText, referenceDate: referenceDate)
        // "Oct 1 - 21" leaves the month off the second half.
        let endText = containsMonth(halves[1]) ? halves[1] : "\(monthWord(in: halves[0]) ?? "") \(halves[1])"
        var end = dayValue(endText, referenceDate: referenceDate)

        // A window that ends before it starts crossed a year boundary.
        if let s = start, let e = end, e < s {
            end = calendar.date(byAdding: .year, value: 1, to: e)
        }

        return Bounds(start: start, end: end)
    }

    private static let monthNames = [
        "january", "february", "march", "april", "may", "june",
        "july", "august", "september", "october", "november", "december"
    ]

    private static func containsMonth(_ text: String) -> Bool { monthWord(in: text) != nil }

    private static func monthWord(in text: String) -> String? {
        let lowered = text.lowercased()
        for name in monthNames where lowered.contains(name) || lowered.contains(name.prefix(3)) {
            return name.capitalized
        }
        return nil
    }

    private static func year(in text: String) -> Int? {
        guard let match = text.range(of: "\\b20\\d{2}\\b", options: .regularExpression) else { return nil }
        return Int(text[match])
    }

    /// "October 2025" with no day component.
    private static func monthOnly(_ text: String) -> Date? {
        guard year(in: text) != nil, monthWord(in: text) != nil else { return nil }
        guard text.range(of: "\\b\\d{1,2}\\b", options: .regularExpression) == nil else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["MMMM yyyy", "MMM yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    /// A single day, filling in the year from `referenceDate` when it's absent.
    private static func dayValue(_ text: String, referenceDate: Date) -> Date? {
        let cleaned = text
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in ["MMMM d yyyy", "MMM d yyyy", "yyyy-MM-dd", "MM/dd/yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: cleaned) { return date }
        }

        // No year given — assume the nearest one, rolling forward if the date
        // has already passed by more than a month.
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: referenceDate)
        for format in ["MMMM d", "MMM d"] {
            formatter.dateFormat = "\(format) yyyy"
            guard let date = formatter.date(from: "\(cleaned) \(currentYear)") else { continue }
            let staleCutoff = calendar.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
            if date < staleCutoff {
                return calendar.date(byAdding: .year, value: 1, to: date) ?? date
            }
            return date
        }
        return nil
    }
}
