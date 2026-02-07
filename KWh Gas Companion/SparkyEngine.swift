//
//  SparkyEngine.swift
//  KWh Gas Companion
//
//  Created by Bryan on 1/13/26.
//


//
//  SparkyEngine.swift
//  KWh Gas Companion
//
//  Created by Bryan on 10/27/25
//  Regenerated: actor-safe DI access, optional-bridging, cache, tunables
//

import Foundation

public actor SparkyEngine {
    public static let shared = SparkyEngine()
    private init() {}

    // MARK: - Lightweight cache

    private struct CacheKey: Hashable {
        let days: Int
        let kindKey: String
        let distanceKey: String
        let localeID: String
    }

    private struct CacheEntry {
        let result: SparkSummaryResult?
        let timestamp: Date
    }

    private var cache: [CacheKey: CacheEntry] = [:]

    /// Clear all cached summary results.
    public func clearCache() {
        cache.removeAll()
    }

    // MARK: - Public API

    /// Summarize the last N days.
    ///
    /// - Parameters:
    ///   - days: Window size in days (clamped to ≥ 1).
    ///   - kind: Optional `SparkTripKind` to pre-filter entries.
    ///   - distanceUnit: Distance aggregation unit for the summarizer.
    ///   - locale: Locale for number/date formatting.
    ///   - cacheTTL: Cache reuse window in seconds. Use `0` to disable caching.
    /// - Returns: A `SparkSummaryResult?` computed by `LocalSparkSummarizer`.
    @discardableResult
    public func summary(
        days: Int = 7,
        kind: SparkTripKind? = nil,
        distanceUnit: SparkDistanceUnit = .miles,
        locale: Locale = .current,
        cacheTTL: TimeInterval = 120
    ) async -> SparkSummaryResult? {

        let clampedDays = max(1, days)
        let kindKey = kind.map { String(describing: $0) } ?? "all"
        let distanceKey = String(describing: distanceUnit)
        let key = CacheKey(days: clampedDays, kindKey: kindKey, distanceKey: distanceKey, localeID: locale.identifier)

        // Cache hit
        if cacheTTL > 0, let hit = cache[key], Date().timeIntervalSince(hit.timestamp) <= cacheTTL {
            return hit.result
        }

        try? Task.checkCancellation()

        // --- Actor-safe DI access (MainActor) + optional → non-optional bridges ---
        let di = await MainActor.run { () -> (
            repo: any SparkEntriesRepository,
            costOf: (SparkShiftEntry) -> Double,
            pricePerKWhOf: (SparkShiftEntry) -> Double,
            tripKindOf: (SparkShiftEntry) -> SparkTripKind,
            milesOf: (SparkShiftEntry) -> Double,
            energyKWhOf: (SparkShiftEntry) -> Double,
            gridKgCO2PerKWh: () -> Double
        ) in
            let store = SparkyDI.store

            // Upcast concrete repo to existential to match summarizer initializer
            let repoAny: any SparkEntriesRepository = store.repositoryAdapter

            // Bridge optionals from the store into non-optional closures
            let cost: (SparkShiftEntry) -> Double = { entry in store.costOf(entry) ?? 0 }
            let price: (SparkShiftEntry) -> Double = { entry in store.pricePerKWhOf(entry) ?? 0 }

            // Unwrap trip kind or fail loudly (replace fatalError with a project default if desired)
            let trip: (SparkShiftEntry) -> SparkTripKind = { entry in
                if let k = store.tripKindOf(entry) ?? entry.kind {
                    return k
                }
                fatalError("SparkTripKind missing for entry \(entry)")
            }

            let miles: (SparkShiftEntry) -> Double = { entry in store.milesOf(entry) ?? 0 }
            let energy: (SparkShiftEntry) -> Double = { entry in store.energyKWhOf(entry) ?? 0 }

            // Capture a constant for grid intensity so the closure is Sendable/non-isolated
            let gridValue = store.gridKgCO2PerKWh() ?? 0
            let grid: () -> Double = { gridValue }

            return (repoAny, cost, price, trip, miles, energy, grid)
        }

        var summarizer = LocalSparkSummarizer(
            repo: di.repo,
            locale: locale,
            distanceUnit: distanceUnit,
            costOf: di.costOf,
            pricePerKWhOf: di.pricePerKWhOf,
            tripKindOf: di.tripKindOf,
            milesOf: di.milesOf,
            energyKWhOf: di.energyKWhOf,
            gridKgCO2PerKWh: di.gridKgCO2PerKWh
        )

        // Optional pre-filter by kind via a temporary repo
        if let kind {
            summarizer.repo = KindFilteringRepo(kind: kind, source: di.repo)
        }

        try? Task.checkCancellation()
        let result = await summarizer.summarize(windowDays: clampedDays)

        if cacheTTL > 0 {
            cache[key] = CacheEntry(result: result, timestamp: Date())
        }
        return result
    }

    // MARK: - Back-compat overload (keeps old call sites working)
    @available(*, deprecated, message: "Use summary(days:kind:distanceUnit:locale:cacheTTL:) instead.")
    public func summary(days: Int = 7, kind: SparkTripKind? = nil) async -> SparkSummaryResult? {
        await summary(days: days, kind: kind, distanceUnit: .miles, locale: .current, cacheTTL: 120)
    }
}

// MARK: - Filtering Repository

public struct KindFilteringRepo: SparkEntriesRepository {
    public let kind: SparkTripKind
    public let source: SparkEntriesRepository

    public init(kind: SparkTripKind, source: SparkEntriesRepository) {
        self.kind = kind
        self.source = source
    }

    public func entries(from start: Date, to end: Date) async -> [SparkShiftEntry] {
        let all = await source.entries(from: start, to: end)
        return all.filter { $0.kind == kind }
    }
}
