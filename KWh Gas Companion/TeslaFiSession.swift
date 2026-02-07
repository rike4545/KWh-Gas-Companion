//
//  TeslaFiSession.swift
//  KWh Gas Companion
//
//  Canonical TeslaFi session model used across:
//  - TeslaFiSessionStore / Importing
//  - Dashboard / Trip Shift views
//

import Foundation

public struct TeslaFiSession: Hashable, Identifiable, Codable, Sendable {
    public var id: UUID = UUID()

    public var startDate: Date
    public var endDate: Date

    /// kWh added during the session (TeslaFi “kWh Added”)
    public var energyAddedKWh: Double

    /// Optional cost (some sources omit cost)
    public var cost: Double?

    /// Optional location / site name
    public var location: String?

    /// Full header-driven raw column map for traceability (145-column tolerant)
    public var raw: [String: String]

    public init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        energyAddedKWh: Double,
        cost: Double? = nil,
        location: String? = nil,
        raw: [String: String] = [:]
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.energyAddedKWh = energyAddedKWh
        self.cost = cost
        self.location = location
        self.raw = raw
    }
}

public extension TeslaFiSession {

    /// Preferred display location (never empty)
    var displayLocation: String {
        let t = (location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Unknown" : t
    }

    /// Stable dedupe key used throughout the app.
    /// NOTE: Int timestamps mirror older code paths and keep hashes stable.
    var sessionHash: String {
        let kwh = String(format: "%.3f", energyAddedKWh)
        let start = String(Int(startDate.timeIntervalSince1970))
        let end = String(Int(endDate.timeIntervalSince1970))
        let loc = (location ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return [start, end, kwh, loc].joined(separator: "|")
    }

    /// Back-compat alias some older code used.
    var fingerprint: String { sessionHash }

    /// Convenience duration
    var durationSeconds: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }

    /// Back-compat alias
    var costUSD: Double? { cost }
}
