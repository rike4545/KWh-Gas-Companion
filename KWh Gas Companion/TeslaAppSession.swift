//
//  TeslaAppSession.swift
//  My KWh Companion
//
//  Swift 6 / iOS 17+
//  - Public-facing models for sessions parsed from Tesla app "session summaries"
//  - Safe parser that can ingest freeform text and best-effort extract charge sessions
//  - All types used by any `public` symbol are also `public` to avoid access control errors
//

import Foundation

// MARK: - Public Models

/// Kind of Tesla app session we recognize.
public enum TeslaSessionKind: String, Codable, Hashable, Sendable {
    case charging
    case driving
    case service
    case unknown
}

/// A single session item parsed from Tesla app summaries.
public struct TeslaAppSession: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var kind: TeslaSessionKind
    public var vehicleVIN: String?
    public var location: String?
    public var energyKWh: Double?     // For charging: energy added
    public var cost: Double?          // Session cost in USD (or your app currency later)
    public var notes: String?         // Raw tail text we couldn't classify

    public init(
        id: UUID = UUID(),
        date: Date,
        kind: TeslaSessionKind,
        vehicleVIN: String? = nil,
        location: String? = nil,
        energyKWh: Double? = nil,
        cost: Double? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.vehicleVIN = vehicleVIN
        self.location = location
        self.energyKWh = energyKWh
        self.cost = cost
        self.notes = notes
    }
}

// MARK: - Parser (Public)

/// Parses pasted Tesla app session summaries (freeform text) into `TeslaAppSession`s.
public enum TeslaAppSessionParser {

    /// Parse a block of text (e.g., copied from Tesla app activity) into sessions.
    ///
    /// Access control notes:
    /// - Method is `public`, returns `public` type `TeslaAppSession` to avoid "result uses an internal type".
    ///
    /// - Parameters:
    ///   - text: Freeform text containing multiple lines; each line may describe a session.
    ///   - defaultVIN: Optional fallback VIN to attach when none is found in the text.
    ///   - locale: Optional locale to influence number/date parsing (defaults to current).
    /// - Returns: Array of parsed `TeslaAppSession`.
    public static func parseSummaries(
        _ text: String,
        defaultVIN: String? = nil,
        locale: Locale = .current
    ) -> [TeslaAppSession] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var out: [TeslaAppSession] = []
        out.reserveCapacity(lines.count)

        let df = makeDateFormatter(locale: locale)

        for line in lines {
            // Try structured parse, otherwise fallback into a best-effort bucket.
            if let s = parseLine(line, df: df, defaultVIN: defaultVIN, locale: locale) {
                out.append(s)
            } else {
                // Unknown / unparsed line — preserve as note so user can see what failed
                out.append(
                    TeslaAppSession(
                        date: Date(),
                        kind: .unknown,
                        vehicleVIN: defaultVIN,
                        notes: line
                    )
                )
            }
        }
        return out
    }
}

// MARK: - Internal helpers (fileprivate)

fileprivate func makeDateFormatter(locale: Locale) -> DateFormatter {
    // Tesla app often shows short human dates; we support a few common patterns.
    let df = DateFormatter()
    df.locale = locale
    df.timeZone = .current

    // We'll try multiple formats manually when parsing.
    return df
}

fileprivate func parseLine(
    _ line: String,
    df: DateFormatter,
    defaultVIN: String?,
    locale: Locale
) -> TeslaAppSession? {

    // Examples we try to catch (these vary by region/app version):
    // "10/29/2025 14:32 • Charging at Lake Grove Supercharger • +26.0 kWh • $7.80"
    // "2025-10-29 14:32 — Supercharging Central Islip — 21.4 kWh — $5.92 — VIN 5YJ..."
    // "Service • Tesla Smithtown • $0.00 • Warranty"
    // "Drive • 18.3 mi • 290 Wh/mi"
    //
    // Strategy:
    // 1) Tokenize by separators we commonly see: "•", "—", "|", " - "
    // 2) Identify a date prefix (multiple patterns)
    // 3) Classify kind by keywords: "charge/supercharge", "service", "drive"
    // 4) Extract energy (kWh) and cost ($)
    // 5) Extract a location-ish token, remainder goes to notes

    let tokens = tokenize(line)
    if tokens.isEmpty { return nil }

    // 1) Date detection
    let (when, restAfterDate) = extractDatePrefix(tokens: tokens, df: df, locale: locale)

    // 2) Kind by keywords
    let kind = classifyKind(in: restAfterDate)

    // 3) Energy & cost
    let energy = extractFirstDouble(from: restAfterDate, matching: [
        #"([0-9]*\.?[0-9]+)\s*kwh"#, // "26.0 kWh"
        #"kwh\s*([0-9]*\.?[0-9]+)"#
    ])

    let cost = extractFirstCurrency(from: restAfterDate, locale: locale)

    // 4) VIN
    let vin = extractVIN(from: restAfterDate) ?? defaultVIN

    // 5) Location heuristic: pick the first token that contains "supercharger" or looks like a place
    let location = restAfterDate.first(where: { token in
        let t = token.lowercased()
        return t.contains("supercharger") || t.contains("service") || t.contains("tesla") || t.contains("station") || t.contains("plaza")
    })

    // Notes = everything not parsed already (keep short)
    let notes: String? = {
        let joined = restAfterDate.joined(separator: " • ")
        // Avoid duplicating energy/cost artifacts in notes if we already parsed them
        if joined.isEmpty { return nil }
        return joined
    }()

    return TeslaAppSession(
        date: when ?? Date(),
        kind: kind,
        vehicleVIN: vin,
        location: location,
        energyKWh: energy,
        cost: cost,
        notes: notes
    )
}

fileprivate func tokenize(_ s: String) -> [String] {
    if s.contains("•") {
        return s.split(separator: "•").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    } else if s.contains("—") {
        return s.split(separator: "—").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    } else if s.contains("|") {
        return s.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    } else if s.contains(" - ") {
        return s.components(separatedBy: " - ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    } else {
        return [s.trimmingCharacters(in: .whitespacesAndNewlines)]
    }
}

fileprivate func extractDatePrefix(
    tokens: [String],
    df: DateFormatter,
    locale: Locale
) -> (Date?, [String]) {

    // Try several date formats commonly seen in shares:
    let formats = [
        "yyyy-MM-dd HH:mm",     // 2025-10-29 14:32
        "M/d/yyyy h:mm a",      // 10/29/2025 2:32 PM
        "M/d/yy h:mm a",        // 10/29/25 2:32 PM
        "M/d/yyyy HH:mm",       // 10/29/2025 14:32
        "M/d/yy HH:mm",         // 10/29/25 14:32
        "MMM d, yyyy h:mm a",   // Oct 29, 2025 2:32 PM
        "MMM d h:mm a"          // Oct 29 2:32 PM (yearless; fallback to current year)
    ]

    for i in 0..<min(tokens.count, 2) { // date usually in first or second token
        let t = tokens[i]
        for f in formats {
            df.dateFormat = f
            if let d = df.date(from: t) {
                // Remove date token from list
                var rest = tokens
                rest.remove(at: i)
                return (d, rest)
            }
        }
    }

    // If none detected, return nil date and original tokens
    return (nil, tokens)
}

fileprivate func classifyKind(in tokens: [String]) -> TeslaSessionKind {
    let joined = tokens.joined(separator: " ").lowercased()
    if joined.contains("supercharge") || joined.contains("charging") || joined.contains("charge") {
        return TeslaSessionKind.charging   // fully qualified to avoid inference error
    }
    if joined.contains("service") || joined.contains("warranty") || joined.contains("invoice") {
        return TeslaSessionKind.service
    }
    if joined.contains("drive") || joined.contains("driving") {
        return TeslaSessionKind.driving
    }
    return TeslaSessionKind.unknown
}

fileprivate func extractFirstDouble(from tokens: [String], matching patterns: [String]) -> Double? {
    let s = tokens.joined(separator: " ")
    for p in patterns {
        if let v = firstCapturedDouble(p, in: s) { return v }
    }
    return nil
}

fileprivate func extractFirstCurrency(from tokens: [String], locale: Locale) -> Double? {
    // Very permissive: $7.80, 7.80 USD, USD 7.80, etc.
    let s = tokens.joined(separator: " ").lowercased()
    // Prefer $ amounts
    if let v = firstCapturedDouble(#"\$([0-9]*\.?[0-9]+)"#, in: s) { return v }
    // Fallback: bare number followed by "usd"
    if let v = firstCapturedDouble(#"([0-9]*\.?[0-9]+)\s*usd"#, in: s) { return v }
    // Fallback: "cost 7.80"
    if let v = firstCapturedDouble(#"cost\s*([0-9]*\.?[0-9]+)"#, in: s) { return v }
    return nil
}

fileprivate func extractVIN(from tokens: [String]) -> String? {
    // Simple VIN heuristic: 17 chars alnum excluding I,O,Q
    let s = tokens.joined(separator: " ")
    let pattern = #"\b([A-HJ-NPR-Z0-9]{17})\b"#
    do {
        let re = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        if let m = re.firstMatch(in: s, options: [], range: range), m.numberOfRanges >= 2,
           let r = Range(m.range(at: 1), in: s) {
            return String(s[r]).uppercased()
        }
    } catch { }
    return nil
}

fileprivate func firstCapturedDouble(_ pattern: String, in s: String) -> Double? {
    do {
        let re = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        if let m = re.firstMatch(in: s, options: [], range: range), m.numberOfRanges >= 2,
           let r = Range(m.range(at: 1), in: s) {
            let raw = String(s[r]).replacingOccurrences(of: ",", with: "")
            return Double(raw)
        }
    } catch { }
    return nil
}
