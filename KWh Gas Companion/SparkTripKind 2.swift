// =============================================================
// FILE: SparkTripKind.swift
// =============================================================

import Foundation

@frozen
public enum SparkTripKind: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    /// Used when a trip/session has no explicit classification.
    case uncategorized
    case tripA
    case tripB
    case commute
    case errands

    public var id: String { rawValue }

    // MARK: - Labels

    public var displayName: String {
        switch self {
        case .uncategorized: return "Uncategorized"
        case .tripA:         return "Trip A"
        case .tripB:         return "Trip B"
        case .commute:       return "Commute"
        case .errands:       return "Errands"
        }
    }

    public var shortTag: String {
        switch self {
        case .uncategorized: return "—"
        case .tripA:         return "A"
        case .tripB:         return "B"
        case .commute:       return "Work"
        case .errands:       return "Err"
        }
    }

    public var emoji: String {
        switch self {
        case .uncategorized: return "❓"
        case .tripA:         return "🅰️"
        case .tripB:         return "🅱️"
        case .commute:       return "🏢"
        case .errands:       return "🛒"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .uncategorized: return "questionmark.circle"
        case .tripA:         return "a.circle"
        case .tripB:         return "b.circle"
        case .commute:       return "briefcase.fill"
        case .errands:       return "cart.fill"
        }
    }

    public var tintHex: String {
        switch self {
        case .uncategorized: return "#8E8E93" // system gray
        case .tripA:         return "#4F8EF7"
        case .tripB:         return "#8A64F7"
        case .commute:       return "#34C759"
        case .errands:       return "#FF9F0A"
        }
    }

    // MARK: - Codable (future-proof unknown values)

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode(String.self)
        self = SparkTripKind(rawValue: raw) ?? .uncategorized
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}
