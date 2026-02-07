//
//  SuperchargePricingMode.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//
//  Pricing “mode” selection for Supercharger-related tools.
//  IMPORTANT: This file intentionally contains NO store types.
//

import Foundation

public enum SuperchargePricingMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    /// Use best available data automatically (official snapshot if present, otherwise fallbacks).
    case automatic

    /// Use official Tesla “Find Us” page pricing snapshot (when available).
    case officialTesla

    /// Use community / inferred pricing (if your tool provides it).
    case community

    /// Use user/session history derived pricing (if your tool provides it).
    case sessionHistory

    /// User-entered manual override.
    case manualOverride

    /// Unknown / legacy.
    case unknown

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .officialTesla: return "Official Tesla Pricing"
        case .community: return "Community Estimate"
        case .sessionHistory: return "Session History"
        case .manualOverride: return "Manual Override"
        case .unknown: return "Unknown"
        }
    }

    public var subtitle: String {
        switch self {
        case .automatic: return "Use the best available source"
        case .officialTesla: return "From Tesla location pages"
        case .community: return "Community/inferred pricing"
        case .sessionHistory: return "Derived from your past sessions"
        case .manualOverride: return "You provide a price"
        case .unknown: return "Legacy/unsupported"
        }
    }
}
