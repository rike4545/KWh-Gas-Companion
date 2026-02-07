//
//  SparkReport.swift
//  My EV Companion — Spark
//
//  Structured, model-friendly report produced from SparkPanel merged entries.
//  This is intentionally compact + stable so you can feed it to an LLM or
//  store it as a JSON artifact for regression testing.
//
//  Swift 6 • iOS 17+
//

import Foundation

public struct SparkReport: Codable, Hashable, Sendable {

    public struct Coverage: Codable, Hashable, Sendable {
        public var costKnownCount: Int
        public var kWhKnownCount: Int
        public var milesKnownCount: Int
        public var siteKnownCount: Int
        public var kindKnownCount: Int

        public init(costKnownCount: Int, kWhKnownCount: Int, milesKnownCount: Int, siteKnownCount: Int, kindKnownCount: Int) {
            self.costKnownCount = costKnownCount
            self.kWhKnownCount = kWhKnownCount
            self.milesKnownCount = milesKnownCount
            self.siteKnownCount = siteKnownCount
            self.kindKnownCount = kindKnownCount
        }
    }

    public struct WindowSummary: Codable, Hashable, Sendable {
        public var days: Int
        public var start: Date
        public var end: Date
        public var entryCount: Int
        public var totalCost: Double?
        public var totalKWh: Double?
        public var totalMiles: Double?
        public var avgWhPerMile: Double?
        public var avgCostPerKWh: Double?
        public var coverage: Coverage
        public var notes: [String]

        public init(
            days: Int,
            start: Date,
            end: Date,
            entryCount: Int,
            totalCost: Double?,
            totalKWh: Double?,
            totalMiles: Double?,
            avgWhPerMile: Double?,
            avgCostPerKWh: Double?,
            coverage: Coverage,
            notes: [String]
        ) {
            self.days = days
            self.start = start
            self.end = end
            self.entryCount = entryCount
            self.totalCost = totalCost
            self.totalKWh = totalKWh
            self.totalMiles = totalMiles
            self.avgWhPerMile = avgWhPerMile
            self.avgCostPerKWh = avgCostPerKWh
            self.coverage = coverage
            self.notes = notes
        }
    }

    public struct SiteSummary: Codable, Hashable, Sendable, Identifiable {
        public var id: String { name }

        public var name: String
        public var visits: Int
        public var totalCost: Double
        public var totalKWh: Double
        public var avgCostPerKWh: Double?

        public init(name: String, visits: Int, totalCost: Double, totalKWh: Double, avgCostPerKWh: Double?) {
            self.name = name
            self.visits = visits
            self.totalCost = totalCost
            self.totalKWh = totalKWh
            self.avgCostPerKWh = avgCostPerKWh
        }
    }

    public enum AnomalyKind: String, Codable, Hashable, Sendable {
        case pricePerKWhSpike
        case costPerMileOutlier
    }

    public struct AnomalySummary: Codable, Hashable, Sendable, Identifiable {
        public var id: String { entryId + "-" + kind.rawValue }

        public var kind: AnomalyKind
        public var date: Date
        public var entryId: String
        public var site: String
        public var metric: String
        public var value: Double
        public var zScore: Double

        public init(kind: AnomalyKind, date: Date, entryId: String, site: String, metric: String, value: Double, zScore: Double) {
            self.kind = kind
            self.date = date
            self.entryId = entryId
            self.site = site
            self.metric = metric
            self.value = value
            self.zScore = zScore
        }
    }

    public var generatedAt: Date
    public var sourceCounts: [String: Int]

    public var window7: WindowSummary?
    public var window31: WindowSummary?

    public var topSitesBySpend: [SiteSummary]
    public var anomalies: [AnomalySummary]

    public init(
        generatedAt: Date,
        sourceCounts: [String: Int],
        window7: WindowSummary?,
        window31: WindowSummary?,
        topSitesBySpend: [SiteSummary],
        anomalies: [AnomalySummary]
    ) {
        self.generatedAt = generatedAt
        self.sourceCounts = sourceCounts
        self.window7 = window7
        self.window31 = window31
        self.topSitesBySpend = topSitesBySpend
        self.anomalies = anomalies
    }
}
