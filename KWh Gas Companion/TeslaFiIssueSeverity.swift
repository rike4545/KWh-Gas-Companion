//
//  TeslaFiIssueSeverity.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/17/25.
//


//
//  TeslaFiSessionIntegrityModels.swift
//  KWh Gas Companion
//
//  Bucket 1: Session cleanup + integrity diagnostics
//  Swift 6 • iOS 17+
//

import Foundation

public enum TeslaFiIssueSeverity: String, Codable, CaseIterable {
    case info, warning, critical

    public var sortRank: Int {
        switch self {
        case .critical: return 0
        case .warning: return 1
        case .info: return 2
        }
    }
}

public enum TeslaFiIssueKind: String, Codable, CaseIterable {
    case endBeforeStart
    case missingLocation
    case nonPositiveEnergy
    case negativeCost
    case implausiblePower
    case suspiciousDuplicate
}

public struct TeslaFiSessionIssue: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var sessionID: UUID
    public var severity: TeslaFiIssueSeverity
    public var kind: TeslaFiIssueKind
    public var message: String

    public init(sessionID: UUID, severity: TeslaFiIssueSeverity, kind: TeslaFiIssueKind, message: String) {
        self.sessionID = sessionID
        self.severity = severity
        self.kind = kind
        self.message = message
    }
}

public struct TeslaFiNormalizationSettings: Codable, Hashable {
    /// If two sessions are same location and the gap between end→start is <= this threshold, merge.
    public var gapThresholdSeconds: TimeInterval = 6 * 60

    /// If sessions overlap in time, they are considered merge candidates.
    public var mergeOverlaps: Bool = true

    /// Flag sessions whose implied kW exceeds this threshold.
    public var maxReasonableKW: Double = 350

    /// Pair fingerprints the user has marked “do not merge”.
    public var doNotMergePairFingerprints: Set<String> = []

    public init() {}
}

/// Output of normalization:
/// - canonical: merged, cleaned sessions to use in UI/analytics
/// - mergeMap: canonicalID -> list of raw IDs that contributed
/// - issues: anomaly flags on canonical sessions
public struct TeslaFiNormalizationResult: Codable, Hashable {
    public var canonical: [TeslaFiSession]
    public var mergeMap: [UUID: [UUID]]
    public var issues: [TeslaFiSessionIssue]
}
