import Foundation

struct ToolSearchBenchmarkCase: Hashable, Sendable {
    let query: String
    let expectedTopRaw: [String]

    var expectedTopKinds: [CalculatorKind] {
        expectedTopRaw.compactMap(CalculatorKind.init(rawValue:))
    }
}

struct ToolSearchCaseResult: Codable, Hashable, Sendable {
    let query: String
    let expectedTopRaw: [String]
    let top5Raw: [String]
    let reciprocalRank: Double
    let hitAt3: Bool
    let hitAt5: Bool
}

struct ToolSearchEvaluationSnapshot: Codable, Hashable, Sendable {
    let createdAt: Date
    let semanticEnabled: Bool
    let rankingEngine: String
    let queryCount: Int
    let meanReciprocalRank: Double
    let hitRateAt3: Double
    let hitRateAt5: Double
    let cases: [ToolSearchCaseResult]
}

struct SuperchargerHistoryStationSnapshot: Codable, Hashable, Sendable {
    let stationId: String
    let sampleCount: Int
    let averagePricePerKWh: Double
    let stdDevPricePerKWh: Double
    let mostRecentTimestamp: Date?
}

struct SuperchargerHistoryEvaluationSnapshot: Codable, Hashable, Sendable {
    let createdAt: Date
    let totalSamples: Int
    let stationCount: Int
    let medianSamplesPerStation: Double
    let p90SamplesPerStation: Double
    let averagePricePerKWh: Double?
    let topStationsBySampleCount: [SuperchargerHistoryStationSnapshot]
}

enum CoreMLEvaluationHarness {
    static let defaultToolSearchCases: [ToolSearchBenchmarkCase] = [
        .init(query: "vin decoder", expectedTopRaw: ["teslaVINDecoder", "rivianVINDecoder"]),
        .init(query: "receipt scan", expectedTopRaw: ["receiptOCR", "teslaInvoiceScan"]),
        .init(query: "invoice pdf", expectedTopRaw: ["teslaInvoiceScan", "serviceInvoices"]),
        .init(query: "live price occupancy", expectedTopRaw: ["superchargerLivePricePredictor"]),
        .init(query: "cheapest charger time", expectedTopRaw: ["cheapestChargerShift"]),
        .init(query: "trip planner", expectedTopRaw: ["tripPlanner", "tripCostEstimator"]),
        .init(query: "budget", expectedTopRaw: ["tripBudgetPlanner", "chargingBudgetGuard"]),
        .init(query: "battery health", expectedTopRaw: ["batteryHealthTimeline"]),
        .init(query: "cost per mile", expectedTopRaw: ["evVsCarComparison", "costPerMileAndCO2"]),
        .init(query: "weekly health", expectedTopRaw: ["weeklyHealthReport"]),
        .init(query: "station quality", expectedTopRaw: ["stationQualityScore"]),
        .init(query: "route compare", expectedTopRaw: ["routeCostCompare"])
    ]

    static func evaluateToolSearch(
        semanticEnabled: Bool,
        rankingEngine: any ToolSemanticRankingEngine
    ) -> ToolSearchEvaluationSnapshot {
        let results = defaultToolSearchCases.map { testCase in
            let ranked = rankedTools(
                for: testCase.query,
                semanticEnabled: semanticEnabled,
                rankingEngine: rankingEngine
            )
            let top5 = Array(ranked.prefix(5))
            let reciprocalRank = reciprocalRank(
                ranked: ranked,
                expected: testCase.expectedTopKinds
            )
            return ToolSearchCaseResult(
                query: testCase.query,
                expectedTopRaw: testCase.expectedTopRaw,
                top5Raw: top5.map(\.rawValue),
                reciprocalRank: reciprocalRank,
                hitAt3: hitAtK(ranked: ranked, expected: testCase.expectedTopKinds, k: 3),
                hitAt5: hitAtK(ranked: ranked, expected: testCase.expectedTopKinds, k: 5)
            )
        }

        let mrr = mean(results.map(\.reciprocalRank))
        let hit3 = mean(results.map { $0.hitAt3 ? 1.0 : 0.0 })
        let hit5 = mean(results.map { $0.hitAt5 ? 1.0 : 0.0 })

        return ToolSearchEvaluationSnapshot(
            createdAt: Date(),
            semanticEnabled: semanticEnabled,
            rankingEngine: rankingEngine.engineIdentifier,
            queryCount: results.count,
            meanReciprocalRank: mrr,
            hitRateAt3: hit3,
            hitRateAt5: hit5,
            cases: results
        )
    }

    static func evaluateSuperchargerHistory(
        samples: [SuperchargerPriceSample],
        maxStations: Int = 15
    ) -> SuperchargerHistoryEvaluationSnapshot {
        let grouped = Dictionary(grouping: samples, by: { $0.stationId })
        let stationCounts = grouped.values.map(\.count).sorted()
        let prices = samples.map(\.pricePerKwh).filter { $0 > 0 }

        let topStations = grouped.map { stationId, bucket -> SuperchargerHistoryStationSnapshot in
            let validPrices = bucket.map(\.pricePerKwh).filter { $0 > 0 }
            let average = validPrices.isEmpty ? 0.0 : validPrices.reduce(0, +) / Double(validPrices.count)
            let stdDev = standardDeviation(validPrices)
            let mostRecent = bucket.max(by: { $0.timestamp < $1.timestamp })?.timestamp
            return SuperchargerHistoryStationSnapshot(
                stationId: stationId,
                sampleCount: bucket.count,
                averagePricePerKWh: average,
                stdDevPricePerKWh: stdDev,
                mostRecentTimestamp: mostRecent
            )
        }
        .sorted {
            if $0.sampleCount != $1.sampleCount { return $0.sampleCount > $1.sampleCount }
            return $0.stationId < $1.stationId
        }
        .prefix(maxStations)

        return SuperchargerHistoryEvaluationSnapshot(
            createdAt: Date(),
            totalSamples: samples.count,
            stationCount: grouped.count,
            medianSamplesPerStation: percentile(stationCounts.map(Double.init), p: 0.50) ?? 0.0,
            p90SamplesPerStation: percentile(stationCounts.map(Double.init), p: 0.90) ?? 0.0,
            averagePricePerKWh: prices.isEmpty ? nil : prices.reduce(0, +) / Double(prices.count),
            topStationsBySampleCount: Array(topStations)
        )
    }

    @discardableResult
    static func writeSnapshot<T: Encodable>(
        _ payload: T,
        prefix: String
    ) throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent("CoreMLDiagnostics", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let file = dir.appendingPathComponent("\(prefix)_\(timestampLabel()).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        try data.write(to: file, options: [.atomic])
        return file
    }

    private static func rankedTools(
        for query: String,
        semanticEnabled: Bool,
        rankingEngine: any ToolSemanticRankingEngine
    ) -> [CalculatorKind] {
        let tokens = normalizedTokens(query)
        var ranked: [(kind: CalculatorKind, lexical: Int)] = CalculatorKind.allCases.map {
            ($0, lexicalScore(kind: $0, tokens: tokens))
        }

        if !tokens.isEmpty {
            ranked = ranked
                .filter { $0.lexical > 0 }
                .sorted {
                    if $0.lexical != $1.lexical { return $0.lexical > $1.lexical }
                    return $0.kind.title < $1.kind.title
                }
        } else {
            ranked = ranked.sorted { $0.kind.title < $1.kind.title }
        }

        if semanticEnabled, !ranked.isEmpty {
            let semantic = rankingEngine.scores(query: query, candidates: ranked.map(\.kind))
            if !semantic.isEmpty {
                ranked.sort { lhs, rhs in
                    let left = blendedScore(lexical: lhs.lexical, semantic: semantic[lhs.kind])
                    let right = blendedScore(lexical: rhs.lexical, semantic: semantic[rhs.kind])
                    if left != right { return left > right }
                    if lhs.lexical != rhs.lexical { return lhs.lexical > rhs.lexical }
                    return lhs.kind.title < rhs.kind.title
                }
            }
        }

        return ranked.map(\.kind)
    }

    private static func normalizedTokens(_ text: String) -> [String] {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let cleaned = String(folded.unicodeScalars.map { scalar in
            if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return Character(scalar)
            } else {
                return " "
            }
        })
        return cleaned
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    private static func lexicalScore(kind: CalculatorKind, tokens: [String]) -> Int {
        guard !tokens.isEmpty else { return 0 }
        let title = kind.title.lowercased()
        let subtitle = kind.subtitle.lowercased()
        let blob = kind._calcDashSearchBlob.lowercased()

        var total = 0
        for tok in tokens {
            if title.contains(tok) { total += 12 }
            if subtitle.contains(tok) { total += 7 }
            if blob.contains(tok) { total += 2 }
        }
        if let first = tokens.first, title.hasPrefix(first) { total += 6 }
        return total
    }

    private static func blendedScore(lexical: Int, semantic: Double?) -> Int {
        guard let semantic else { return lexical }
        return lexical + Int((max(0, min(1, semantic)) * 40).rounded())
    }

    private static func reciprocalRank(ranked: [CalculatorKind], expected: [CalculatorKind]) -> Double {
        guard !expected.isEmpty else { return 0 }
        for (idx, item) in ranked.enumerated() where expected.contains(item) {
            return 1.0 / Double(idx + 1)
        }
        return 0
    }

    private static func hitAtK(ranked: [CalculatorKind], expected: [CalculatorKind], k: Int) -> Bool {
        guard k > 0, !expected.isEmpty else { return false }
        return Array(ranked.prefix(k)).contains(where: { expected.contains($0) })
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let avg = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - avg, 2) } / Double(values.count)
        return sqrt(variance)
    }

    private static func percentile(_ sortedValues: [Double], p: Double) -> Double? {
        guard !sortedValues.isEmpty else { return nil }
        let clamped = max(0.0, min(1.0, p))
        let idx = Int((Double(sortedValues.count - 1) * clamped).rounded())
        return sortedValues[idx]
    }

    private static func timestampLabel() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: Date())
    }
}
