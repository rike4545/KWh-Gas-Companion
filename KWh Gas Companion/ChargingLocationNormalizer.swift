//  ChargingLocationNormalizer.swift
//  My KWh Companion
//
//  Makes location strings clusterable (stable siteKey).
//  Swift 6 • iOS 17+
//

import Foundation

enum ChargingLocationNormalizer {

    private static let stopwords: Set<String> = [
        "tesla", "supercharger", "superchargers", "charger", "charging", "station",
        "sc", "suc", "the", "at", "and", "of", "ny", "nj", "ct"
    ]

    static func cleanedName(_ name: String?) -> String {
        let raw = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "Unknown" : raw
    }

    static func siteKey(from name: String?) -> String {
        let s = cleanedName(name).lowercased()

        // Replace punctuation with spaces
        let replaced = s.map { ch -> Character in
            if ch.isLetter || ch.isNumber { return ch }
            return " "
        }
        let tokens = String(replaced)
            .split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
            .map { String($0) }
            .filter { !$0.isEmpty }
            .filter { !stopwords.contains($0) }

        if tokens.isEmpty {
            return "site:unknown"
        }

        // Stable: sorted token signature
        let sig = tokens.sorted().joined(separator: "-")
        return "site:\(sig)"
    }

    /// Useful display name for a cluster: prefer the longest “clean” non-unknown name.
    static func preferredDisplayName(from names: [String]) -> String {
        let cleaned = names.map { cleanedName($0) }.filter { $0.lowercased() != "unknown" }
        return cleaned.sorted(by: { $0.count > $1.count }).first ?? "Unknown"
    }
}
