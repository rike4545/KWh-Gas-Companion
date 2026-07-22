import Foundation

enum CoreMLFeatureFlags {
    static let liveSuperchargerPricingEnabledKey = "ml.supercharger.live.enabled"
    static let semanticToolSearchEnabledKey = "ml.tools.semantic.enabled"

    static let liveSuperchargerPricingEnabledDefault = false
    static let semanticToolSearchEnabledDefault = false
}

enum MLEngineHealthState: String, Codable, Hashable, Sendable {
    case ready
    case fallback
    case unavailable
}

struct MLEngineHealthReport: Codable, Hashable, Sendable {
    let state: MLEngineHealthState
    let summary: String
    let details: String?
    let timestamp: Date

    init(
        state: MLEngineHealthState,
        summary: String,
        details: String? = nil,
        timestamp: Date = Date()
    ) {
        self.state = state
        self.summary = summary
        self.details = details
        self.timestamp = timestamp
    }
}

protocol SuperchargerLivePriceEngine: Sendable {
    var engineIdentifier: String { get }
    var healthReport: MLEngineHealthReport { get }

    func predict(
        stallsTotal: Int,
        stallsOccupied: Int,
        config: SuperchargerLivePricePredictor.Config
    ) -> SuperchargerLivePricePredictor.Prediction

    func scenarioPrices(
        stallsTotal: Int,
        config: SuperchargerLivePricePredictor.Config
    ) -> [(SuperchargerLivePricePredictor.Tier, Double, String)]
}

struct RuleBasedSuperchargerLivePriceEngine: SuperchargerLivePriceEngine {
    let engineIdentifier: String = "rule-based"
    let healthReport = MLEngineHealthReport(
        state: .ready,
        summary: "Rule-based live pricing is active.",
        details: "Core ML live pricing is disabled."
    )

    func predict(
        stallsTotal: Int,
        stallsOccupied: Int,
        config: SuperchargerLivePricePredictor.Config
    ) -> SuperchargerLivePricePredictor.Prediction {
        let predictor = SuperchargerLivePricePredictor(config: config)
        return predictor.predict(stallsTotal: stallsTotal, stallsOccupied: stallsOccupied)
    }

    func scenarioPrices(
        stallsTotal: Int,
        config: SuperchargerLivePricePredictor.Config
    ) -> [(SuperchargerLivePricePredictor.Tier, Double, String)] {
        let predictor = SuperchargerLivePricePredictor(config: config)
        return predictor.scenarioPrices(stallsTotal: stallsTotal)
    }
}

struct CoreMLSuperchargerLivePriceEnginePlaceholder: SuperchargerLivePriceEngine {
    let engineIdentifier: String = "coreml-placeholder"
    let healthReport = MLEngineHealthReport(
        state: .fallback,
        summary: "Core ML live pricing is enabled but using fallback.",
        details: "No trained Core ML live occupancy model is wired yet."
    )
    private let fallback = RuleBasedSuperchargerLivePriceEngine()

    func predict(
        stallsTotal: Int,
        stallsOccupied: Int,
        config: SuperchargerLivePricePredictor.Config
    ) -> SuperchargerLivePricePredictor.Prediction {
        // TODO: Replace with Core ML inference once live occupancy training data is available.
        fallback.predict(stallsTotal: stallsTotal, stallsOccupied: stallsOccupied, config: config)
    }

    func scenarioPrices(
        stallsTotal: Int,
        config: SuperchargerLivePricePredictor.Config
    ) -> [(SuperchargerLivePricePredictor.Tier, Double, String)] {
        fallback.scenarioPrices(stallsTotal: stallsTotal, config: config)
    }
}

protocol ToolSemanticRankingEngine: Sendable {
    var engineIdentifier: String { get }
    var healthReport: MLEngineHealthReport { get }

    /// Returns normalized semantic scores in [0, 1], keyed by candidate.
    func scores(query: String, candidates: [CalculatorKind]) -> [CalculatorKind: Double]
}

struct DisabledToolSemanticRankingEngine: ToolSemanticRankingEngine {
    let engineIdentifier: String = "disabled"
    let healthReport = MLEngineHealthReport(
        state: .ready,
        summary: "Semantic ranking is disabled.",
        details: "Lexical ranking is being used."
    )

    func scores(query: String, candidates: [CalculatorKind]) -> [CalculatorKind: Double] {
        [:]
    }
}

struct CoreMLToolSemanticRankingEnginePlaceholder: ToolSemanticRankingEngine {
    let engineIdentifier: String = "coreml-placeholder"
    let healthReport = MLEngineHealthReport(
        state: .fallback,
        summary: "Semantic ranking is enabled but using lexical fallback.",
        details: "No embedding model has been integrated yet."
    )

    func scores(query: String, candidates: [CalculatorKind]) -> [CalculatorKind: Double] {
        // TODO: Replace with on-device embedding + nearest-neighbor ranking.
        _ = query
        _ = candidates
        return [:]
    }
}
