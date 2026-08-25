//  SuperchargeInfoJSON.swift
//  KWh Gas Companion / My EV Companion
//
//  Supercharge.info JSON helpers
//  Swift 6 • iOS 17+
//
//  IMPORTANT:
//  - Ensure you have ONLY ONE definition of `SuperchargeInfoJSON` in your project.
//    If you previously defined it inside SuperchargeInfoStore.swift, delete that old enum
//    to avoid “Invalid redeclaration” errors.
//

import Foundation

public enum SuperchargeInfoJSON {

    /// Used when the dataset contains an empty/invalid date string but the field is typed as `Date` / `Date?`.
    /// A JSONDecoder date strategy cannot return nil, so we use a stable placeholder.
    public static let placeholderDate = Date(timeIntervalSince1970: 0)

    // MARK: - Decoder / Encoder

    public static func makeDecoder() -> JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()

            // null → placeholder
            if c.decodeNil() { return placeholderDate }

            // number → seconds or milliseconds
            if let n = try? c.decode(Double.self) {
                return dateFromTimestamp(n) ?? placeholderDate
            }
            if let n = try? c.decode(Int64.self) {
                return dateFromTimestamp(Double(n)) ?? placeholderDate
            }

            // string → various formats
            if let s = try? c.decode(String.self) {
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return placeholderDate }

                if let d = parseDateString(trimmed) { return d }

                // Sometimes numeric timestamps are encoded as strings
                if let asDouble = Double(trimmed), let d = dateFromTimestamp(asDouble) {
                    return d
                }

                // Keep decoding resilient
                return placeholderDate
            }

            return placeholderDate
        }
        return dec
    }

    public static func makeEncoder(pretty: Bool = false) -> JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]

        // Encode dates as ISO8601 with fractional seconds (best round-trip for APIs/logs)
        enc.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            // Don’t emit placeholder as a “real” date; emit null-ish string instead.
            if isPlaceholderDate(date) {
                try c.encode("")
                return
            }
            try c.encode(iso8601String(date))
        }

        return enc
    }

    // MARK: - Placeholder handling

    public static func isPlaceholderDate(_ d: Date) -> Bool {
        abs(d.timeIntervalSince1970 - placeholderDate.timeIntervalSince1970) < 0.000_001
    }

    public static func sanitizeOptionalDate(_ d: Date?) -> Date? {
        guard let d else { return nil }
        return isPlaceholderDate(d) ? nil : d
    }

    // MARK: - Date parsing

    /// Accepts:
    /// - ISO8601/RFC3339 (with/without fractional seconds)
    /// - yyyy-MM-dd
    /// - yyyy-MM-dd HH:mm:ss
    /// - MM/dd/yyyy (rare fallback)
    public static func parseDateString(_ s: String) -> Date? {
        // ISO8601 (fractional)
        do {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f.date(from: s) { return d }
        }

        // ISO8601 (no fractional)
        do {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            if let d = f.date(from: s) { return d }
        }

        // yyyy-MM-dd
        do {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = "yyyy-MM-dd"
            if let d = f.date(from: s) { return d }
        }

        // yyyy-MM-dd HH:mm:ss
        do {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = "yyyy-MM-dd HH:mm:ss"
            if let d = f.date(from: s) { return d }
        }

        // MM/dd/yyyy (fallback)
        do {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = "MM/dd/yyyy"
            if let d = f.date(from: s) { return d }
        }

        return nil
    }

    /// If `t` looks like milliseconds (>= 1e12), converts to seconds.
    public static func dateFromTimestamp(_ t: Double) -> Date? {
        guard t.isFinite else { return nil }
        let seconds: Double
        if t >= 1_000_000_000_000 { // ms since epoch
            seconds = t / 1000.0
        } else {
            seconds = t
        }
        // Basic sanity window: 2000–2100 (keeps junk from becoming “valid”)
        let d = Date(timeIntervalSince1970: seconds)
        let y2000 = Date(timeIntervalSince1970: 946684800)  // 2000-01-01
        let y2100 = Date(timeIntervalSince1970: 4102444800) // 2100-01-01
        guard d >= y2000 && d <= y2100 else { return nil }
        return d
    }

    // MARK: - String helpers

    public static func normalizedString(_ s: String?) -> String? {
        guard let s else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    public static func iso8601String(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }
}
