//
//  AskSparkyIntent.swift
//  KWh Gas Companion — Spark
//
//  Regenerated: Oct 27, 2025
//

#if canImport(AppIntents)
import AppIntents
import Foundation

@available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
struct AskSparkyIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Sparky"
    static var description = IntentDescription("Ask about recent driving, costs, or efficiency.")

    // MARK: Parameters

    @Parameter(
        title: "Question",
        requestValueDialog: IntentDialog("What do you want to ask?")
    )
    var question: String

    // Keep this as String so we don't require SparkTripKind to conform to AppEnum.
    @Parameter(
        title: "Trip Kind",
        requestValueDialog: IntentDialog("Which kind? (Trip A, Trip B, Commute, Errands)")
    )
    var kindName: String?

    // NOTE: In AppIntents, 'default:' must come before 'requestValueDialog:' to satisfy the compiler.
    @Parameter(
        title: "Window (days)",
        default: 7,
        requestValueDialog: IntentDialog("For how many days?")
    )
    var windowDays: Int

    // Parameter summary syntax that compiles on older SDKs:
    static var parameterSummary: some ParameterSummary {
        Summary("Ask Sparky about \(\.$question)") {
            \.$windowDays
            \.$kindName
        }
    }

    // MARK: Perform

    // Return the text directly as the result value (avoids IntentDialog literal constraints).
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let enumKind = Self.parseKind(kindName)
        let days = max(1, windowDays)

        let unit: SparkDistanceUnit = (DistanceUnit.defaultForDevice == .kilometers) ? .kilometers : .miles
        let result = await SparkyEngine.shared.summary(
            days: days,
            kind: enumKind,
            distanceUnit: unit,
            locale: .current,
            cacheTTL: 120
        )
        let line = result?.dialogLine ?? "I couldn't find any matching recent driving."

        return .result(value: line)
    }

    // MARK: Helpers

    /// Tolerant mapping from user-entered kind name to SparkTripKind.
    private static func parseKind(_ s: String?) -> SparkTripKind? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        let norm = s.lowercased().replacingOccurrences(of: #"[^\w]+"#, with: "", options: .regularExpression)

        switch norm {
        // Trip A
        case "tripa", "a", "trip1", "trip": return .tripA
        // Trip B
        case "tripb", "b", "trip2": return .tripB
        // Commute
        case "commute", "work", "office", "towork", "fromwork": return .commute
        // Errands
        case "errands", "err", "shopping", "grocery", "groceries", "store": return .errands
        default:
            return nil
        }
    }
}

#endif
