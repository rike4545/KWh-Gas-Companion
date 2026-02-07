//
//  DeepDepthCore.swift
//  KWh Gas Companion
//
//  Single source of truth for DeepDepth types + environment injection.
//  Swift 6 • iOS 17+
//
//  Notes:
//  - Environment keeps the provider OPTIONAL so features can gracefully no-op.
//  - Includes a built-in .empty provider and a convenience view modifier.
//

import SwiftUI
import Foundation

// MARK: - Core Session Model

public struct DeepDepthSession: Sendable, Hashable {
    public let start: Date
    public let end: Date
    public let energyKWh: Double
    public let cost: Double?
    public let miles: Double
    public let isSupercharging: Bool

    public init(
        start: Date,
        end: Date,
        energyKWh: Double,
        cost: Double?,
        miles: Double,
        isSupercharging: Bool
    ) {
        self.start = start
        self.end = end
        self.energyKWh = energyKWh
        self.cost = cost
        self.miles = miles
        self.isSupercharging = isSupercharging
    }

    // MARK: Convenience Metrics

    public var durationSeconds: TimeInterval {
        max(0, end.timeIntervalSince(start))
    }

    public var kWhPerMile: Double? {
        guard miles > 0 else { return nil }
        return energyKWh / miles
    }

    public var milesPerKWh: Double? {
        guard energyKWh > 0 else { return nil }
        return miles / energyKWh
    }

    public var costPerKWh: Double? {
        guard let cost, energyKWh > 0 else { return nil }
        return cost / energyKWh
    }

    public var costPerMile: Double? {
        guard let cost, miles > 0 else { return nil }
        return cost / miles
    }
}

// MARK: - Provider

public struct DeepDepthDataProvider: Sendable {
    public var fetch: @Sendable (_ start: Date, _ end: Date) async -> [DeepDepthSession]

    public init(fetch: @escaping @Sendable (_ start: Date, _ end: Date) async -> [DeepDepthSession]) {
        self.fetch = fetch
    }

    /// A safe no-op provider. Useful as a fallback (or for previews/tests).
    public static var empty: DeepDepthDataProvider {
        .init { _, _ in [] }
    }
}

// MARK: - Environment

private struct DeepDepthProviderKey: EnvironmentKey {
    static let defaultValue: DeepDepthDataProvider? = nil
}

public extension EnvironmentValues {
    /// Optional provider. If nil, DeepDepth features should no-op gracefully.
    var deepDepthProvider: DeepDepthDataProvider? {
        get { self[DeepDepthProviderKey.self] }
        set { self[DeepDepthProviderKey.self] = newValue }
    }

    /// Convenience: always returns a provider (falls back to `.empty`).
    var deepDepthProviderOrEmpty: DeepDepthDataProvider {
        deepDepthProvider ?? .empty
    }
}

// MARK: - Injection helper

public extension View {
    /// Convenience injection.
    func deepDepthProvider(_ provider: DeepDepthDataProvider?) -> some View {
        environment(\.deepDepthProvider, provider)
    }
}
