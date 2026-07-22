//
//  CSVParse 2.swift
//  KWh Gas Companion
//
//

// ===================== CSVParsingUtils.swift =====================
import Foundation

/// Lightweight CSV helpers shared by importers
enum CSVParse {
    /// Date formats commonly seen in TeslaFi exports
    static let dateFormatters: [DateFormatter] = {
        let f1 = DateFormatter(); f1.locale = Locale(identifier: "en_US_POSIX"); f1.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let f2 = DateFormatter(); f2.locale = Locale(identifier: "en_US_POSIX"); f2.dateFormat = "M/d/yyyy H:mm"
        return [f1, f2]
    }()

    /// Split a single CSV line while respecting quotes
    static func splitLine(_ line: String) -> [String] {
        var result: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = line.makeIterator()
        while let ch = iterator.next() {
            if ch == "\"" {
                // Lookahead for escaped quote
                if inQuotes, let peek = iterator.next() {
                    if peek == "\"" { field.append("\"") }
                    else { inQuotes = false; if peek == "," { result.append(field); field.removeAll() } else { field.append(peek) } }
                } else { inQuotes.toggle() }
                continue
            }
            if ch == "," && !inQuotes { result.append(field); field.removeAll(); continue }
            field.append(ch)
        }
        result.append(field)
        return result
    }

    /// Parse a date string using several fallbacks (then ISO8601)
    static func date(_ s: String?) -> Date? {
        guard let s = s, !s.isEmpty else { return nil }
        for f in dateFormatters { if let d = f.date(from: s) { return d } }
        return ISO8601DateFormatter().date(from: s)
    }

    /// Parse a number, stripping $, quotes, commas and spaces
    static func number(_ s: String?) -> Double? {
        guard var raw = s?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        raw.removeAll { "$\" ,".contains($0) }
        return Double(raw)
    }
}
