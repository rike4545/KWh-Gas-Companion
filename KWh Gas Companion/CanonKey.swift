//  CanonKey.swift
//  KWh Gas Companion
//
//  Canonical header mapping for CSV imports (simple & fast).
//  Fixes:
//  • No public/internal mismatch — everything is module-internal by default.
//  • No misuse of String(decoding:as:) — this file operates on Strings only.
//
//  Supported canonical keys (your reduced 6-field set):
//  - cost            ("UnitCostBase", "Cost")
//  - location        ("SiteLocationName", "Location")
//  - quantity        ("QuantityBase", "Quantity" or kWh)
//  - total           ("Total Inc. VAT", "Total Cost")
//  - invoice         ("Invoice or Notes", "Invoice")
//  - startDateTime   ("ChargeStartDateTime", "Charge Start / Date and Time")
//
//  Usage:
//      let map = autoMap(headers: csvHeaders)
//      // map[.cost] -> Int?  (index in the header array)
//
//  If you need this across modules later, mark the types/functions `public` *together*.

import Foundation

// MARK: - Canonical keys

enum CanonKey: String, CaseIterable, Codable, Hashable, Identifiable {
    case cost
    case location
    case quantity
    case total
    case invoice
    case startDateTime

    var id: String { rawValue }

    /// Friendly title for UI
    var title: String {
        switch self {
        case .cost:          return "Cost"
        case .location:      return "Location"
        case .quantity:      return "Quantity"
        case .total:         return "Total Cost"
        case .invoice:       return "Invoice / Notes"
        case .startDateTime: return "Charge Start (Date & Time)"
        }
    }
}

// MARK: - HeaderMap (index lookup)

/// Maps each canonical key to the index in the CSV header array.
struct HeaderMap: Codable, Hashable {
    private var storage: [CanonKey: Int] = [:]

    subscript(key: CanonKey) -> Int? {
        get { storage[key] }
        set { storage[key] = newValue }
    }

    var isEmpty: Bool { storage.isEmpty }
    var keys: [CanonKey] { Array(storage.keys) }
}

// MARK: - Auto-map

/// Create a best-effort mapping from raw header names.
/// - Parameter headers: The header row as `[String]`.
/// - Returns: `HeaderMap` with any fields we could confidently match.
func autoMap(headers: [String]) -> HeaderMap {
    var map = HeaderMap()

    // Build a normalized lookup of header -> index
    let normalized: [(raw: String, norm: String, idx: Int)] = headers.enumerated().map { (i, h) in
        (h, normalize(h), i)
    }

    // A simple helper to claim the first matching header for a key if available.
    func claim(_ key: CanonKey, by predicates: [(String) -> Bool]) {
        guard map[key] == nil else { return }
        if let hit = normalized.first(where: { triple in predicates.contains(where: { $0(triple.norm) }) }) {
            map[key] = hit.idx
        }
    }

    // Cost
    claim(.cost, by: [
        equals("unitcostbase"), equals("cost"), equals("unitcost"), contains("unitcost"),
        equals("rate"), contains("price")
    ])

    // Location
    claim(.location, by: [
        equals("sitelocationname"), equals("location"), contains("site"), contains("station"), contains("address")
    ])

    // Quantity (kWh)
    claim(.quantity, by: [
        equals("quantitybase"), equals("quantity"), equals("kwh"), contains("kwh"), contains("energy")
    ])

    // Total cost
    claim(.total, by: [
        equals("totalincvat"), equals("totalcost"), equals("total"), contains("total"), contains("amountpaid"), contains("amount")
    ])

    // Invoice / Notes
    claim(.invoice, by: [
        equals("invoiceornotes"), equals("invoice"), equals("notes"), contains("invoice"), contains("receipt"), contains("ref")
    ])

    // Start date & time
    claim(.startDateTime, by: [
        equals("chargestartdatetime"), contains("charge start"), contains("startdatetime"),
        contains("starttime"), contains("timestamp"), equals("dateandtime"), contains("dateandtime")
    ])

    return map
}

// MARK: - Normalization & predicate helpers

/// Lowercase + strip all non-alphanumerics (and collapse whitespace) so we can match robustly.
/// Examples:
///   "Total Inc. VAT" -> "totalincvat"
///   "Charge Start, Date and Time" -> "chargestartdateandtime"
func normalize(_ s: String) -> String {
    let lowered = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    // Remove diacritics
    let noMarks = lowered.folding(options: .diacriticInsensitive, locale: .current)
    // Keep only [a-z0-9]
    let allowed = noMarks.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
    return String(String.UnicodeScalarView(allowed))
}

/// Exact match predicate against a normalized token.
func equals(_ token: String) -> (String) -> Bool {
    { $0 == token }
}

/// Contains substring predicate against normalized token.
func contains(_ token: String) -> (String) -> Bool {
    { $0.contains(token) }
}

// MARK: - Convenience helpers

extension HeaderMap {
    /// Return a dictionary for debugging or UI display.
    var dictionary: [String: Int] {
        var out: [String: Int] = [:]
        for (k, v) in CanonKey.allCases.compactMap({ key in self[key].map { (key, $0) } }) {
            out[k.title] = v
        }
        return out
    }

    /// Whether the map has at least the core fields typically needed to import.
    /// Adjust this depending on your importer rules.
    var hasMinimumForImport: Bool {
        // Cost and date/time are usually essential; others optional depending on your parser.
        return self[.startDateTime] != nil && (self[.total] != nil || self[.cost] != nil)
    }
}

#if DEBUG
// Quick, local sanity checks in Debug builds
struct _CanonKey_Previews {
    static func demo() {
        let headers = [
            "UnitCostBase",
            "SiteLocationName",
            "QuantityBase",
            "Total Inc. VAT",
            "Invoice or Notes",
            "ChargeStartDateTime"
        ]
        let map = autoMap(headers: headers)
        assert(map[.cost] != nil)
        assert(map[.location] != nil)
        assert(map[.quantity] != nil)
        assert(map[.total] != nil)
        assert(map[.invoice] != nil)
        assert(map[.startDateTime] != nil)
        print("CanonKey demo map:", map.dictionary)
    }
}
#endif
