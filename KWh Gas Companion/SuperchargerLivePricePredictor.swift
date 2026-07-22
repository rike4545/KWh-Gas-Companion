//
//  SuperchargerLivePricePredictor.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import Foundation

// MARK: - Settings hooks (currency + optional home rate)

public struct PreferredCurrencyCodeKey: EnvironmentKey {
    public static let defaultValue: String? = nil
}

public struct HomeRatePerKWhKey: EnvironmentKey {
    public static let defaultValue: Double? = nil
}

public extension EnvironmentValues {
    var preferredCurrencyCode: String? {
        get { self[PreferredCurrencyCodeKey.self] }
        set { self[PreferredCurrencyCodeKey.self] = newValue }
    }

    var homeRatePerKWh: Double? {
        get { self[HomeRatePerKWhKey.self] }
        set { self[HomeRatePerKWhKey.self] = newValue }
    }
}

// MARK: - Predictor

public struct SuperchargerLivePricePredictor: Sendable {

    public enum Tier: String, CaseIterable, Identifiable, Sendable {
        case low
        case normal
        case high

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .low:    return "Low occupancy"
            case .normal: return "Normal"
            case .high:   return "Near capacity"
            }
        }

        public var subtitle: String {
            switch self {
            case .low:    return "≤ 1 stall occupied"
            case .normal: return "2+ occupied"
            case .high:   return "Site close to full"
            }
        }

        public var systemImage: String {
            switch self {
            case .low:    return "leaf"
            case .normal: return "bolt"
            case .high:   return "exclamationmark.triangle"
            }
        }
    }

    public struct Config: Sendable, Hashable {
        public var basePricePerKWh: Double
        public var lowMaxOccupied: Int
        public var nearCapacityThreshold: Double
        public var lowMultiplier: Double
        public var normalMultiplier: Double
        public var highMultiplier: Double

        public init(
            basePricePerKWh: Double = 0.40,
            lowMaxOccupied: Int = 1,
            nearCapacityThreshold: Double = 0.80,
            lowMultiplier: Double = 0.85,
            normalMultiplier: Double = 1.00,
            highMultiplier: Double = 1.25
        ) {
            self.basePricePerKWh = basePricePerKWh
            self.lowMaxOccupied = lowMaxOccupied
            self.nearCapacityThreshold = nearCapacityThreshold
            self.lowMultiplier = lowMultiplier
            self.normalMultiplier = normalMultiplier
            self.highMultiplier = highMultiplier
        }
    }

    public struct Prediction: Sendable, Hashable {
        public var tier: Tier
        public var pricePerKWh: Double
        public var rationale: String
    }

    public var config: Config

    public init(config: Config = .init()) {
        self.config = config
    }

    public func tier(stallsTotal: Int, stallsOccupied: Int) -> Tier {
        let total = max(1, stallsTotal)
        let occ   = min(max(0, stallsOccupied), total)

        if occ <= config.lowMaxOccupied { return .low }

        let frac = Double(occ) / Double(total)
        if frac >= max(0.0, min(1.0, config.nearCapacityThreshold)) { return .high }

        return .normal
    }

    public func predict(stallsTotal: Int, stallsOccupied: Int) -> Prediction {
        let t    = tier(stallsTotal: stallsTotal, stallsOccupied: stallsOccupied)
        let base = max(0, config.basePricePerKWh)

        let (mult, why): (Double, String) = {
            switch t {
            case .low:
                return (max(0, config.lowMultiplier),
                        "Occupancy is low (≤ \(config.lowMaxOccupied)).")
            case .normal:
                return (max(0, config.normalMultiplier),
                        "Occupancy is moderate (2+ stalls occupied) and not near capacity.")
            case .high:
                let pct = Int((config.nearCapacityThreshold * 100).rounded())
                return (max(0, config.highMultiplier),
                        "Occupancy is near capacity (≥ \(pct)% of stalls).")
            }
        }()

        return .init(tier: t, pricePerKWh: base * mult, rationale: why)
    }

    public func scenarioPrices(stallsTotal: Int) -> [(Tier, Double, String)] {
        let total   = max(1, stallsTotal)
        let lowOcc  = min(config.lowMaxOccupied, total)
        let normalOcc = min(max(config.lowMaxOccupied + 1, 2), total)
        let highOcc = min(Int(ceil(Double(total) * config.nearCapacityThreshold)), total)

        let low    = predict(stallsTotal: total, stallsOccupied: lowOcc)
        let normal = predict(stallsTotal: total, stallsOccupied: normalOcc)
        let high   = predict(stallsTotal: total, stallsOccupied: highOcc)

        return [
            (.low,    low.pricePerKWh,    "Example: \(lowOcc)/\(total) occupied"),
            (.normal, normal.pricePerKWh, "Example: \(normalOcc)/\(total) occupied"),
            (.high,   high.pricePerKWh,   "Example: \(highOcc)/\(total) occupied")
        ]
    }
}

// MARK: - Scenario row wrapper (fixes ForEach tuple inference errors)

/// Wraps the raw tuple from `scenarioPrices` so ForEach can resolve
/// the Identifiable conformance without ambiguous key-path inference.
private struct SCLiveScenarioRow: Identifiable {
    let id: String
    let tier: SuperchargerLivePricePredictor.Tier
    let price: Double
    let note: String

    init(tier: SuperchargerLivePricePredictor.Tier, price: Double, note: String) {
        self.id    = tier.id
        self.tier  = tier
        self.price = price
        self.note  = note
    }
}

// MARK: - View

@MainActor
public struct SuperchargerLivePricePredictorView: View {

    public init() {}

    // Theme
    @Environment(\.appThemeBox) private var themeBox
    @EnvironmentObject private var appearance: AppAppearance
    @Environment(\.preferredCurrencyCode) private var preferredCurrencyCode
    @Environment(\.homeRatePerKWh) private var homeRateEnv
    @StateObject private var priceStore = SuperchargerPriceStore.shared
    @EnvironmentObject private var teslaPricingStore: TeslaOfficialSuperchargerPricingStore

    // FIX 3: `accent` is typed as Color, so .foregroundStyle(accent) always
    // resolves correctly — no more "ShapeStyle has no member 'accentColor'".
    private var theme: any AppThemeSpec { themeBox.base }
    private var accent: Color { appearance.accentColor }

    // Inputs
    @State private var stallsTotal: Int    = 12
    @State private var stallsOccupied: Int = 1

    @State private var basePriceText: String = "0.40"
    @State private var kWhText: String       = "25.0000"

    @State private var showAdvanced: Bool          = false
    @State private var lowMultiplierText: String   = "0.85"
    @State private var normalMultiplierText: String = "1.00"
    @State private var highMultiplierText: String  = "1.25"
    @State private var nearCapacityPct: Double     = 80
    @State private var lowMaxOccupied: Int         = 1

    @State private var idleFeePerMinText: String = ""
    @State private var idleMinutesText: String   = ""

    @AppStorage("supercharger.predictor.stationId")
    private var stationIdText: String = ""
    @AppStorage(CoreMLFeatureFlags.liveSuperchargerPricingEnabledKey)
    private var useCoreMLLivePricing: Bool = CoreMLFeatureFlags.liveSuperchargerPricingEnabledDefault
    @AppStorage("ml.supercharger.live.health.lastSummary")
    private var lastHealthSummary: String = ""
    @AppStorage("ml.supercharger.live.health.lastTimestamp")
    private var lastHealthTimestamp: Double = 0
    @State private var logStatusText: String? = nil

    // MARK: Derived

    private var resolvedCurrencyCode: String {
        if let c = preferredCurrencyCode, !c.isEmpty { return c }
        let keys = ["preferredCurrencyCode", "currencyCode", "settings.currencyCode"]
        for k in keys {
            if let v = UserDefaults.standard.string(forKey: k), !v.isEmpty { return v }
        }
        return Locale.current.currency?.identifier ?? "USD"
    }

    private var numberLocale: Locale { Locale.current }

    private var trimmedStationId: String {
        stationIdText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var historyCount: Int {
        guard !trimmedStationId.isEmpty else { return 0 }
        return priceStore.history(for: trimmedStationId).count
    }

    private var lastLoggedText: String? {
        guard !trimmedStationId.isEmpty else { return nil }
        guard let last = priceStore.mostRecent(for: trimmedStationId) else { return nil }
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: last.timestamp)
    }

    private var officialRecord: TeslaSCOfficialPriceRecord? {
        guard !trimmedStationId.isEmpty else { return nil }
        return teslaPricingStore.record(for: trimmedStationId)
    }

    private func parseDouble(_ s: String, fallback: Double) -> Double {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return fallback }
        if let v = Double(trimmed) { return v }
        let sep = numberLocale.decimalSeparator ?? "."
        if sep != "." {
            let swapped = trimmed.replacingOccurrences(of: sep, with: ".")
            if let v = Double(swapped) { return v }
        }
        return fallback
    }

    private var predictorConfig: SuperchargerLivePricePredictor.Config {
        let base  = parseDouble(basePriceText,       fallback: 0.40)
        let lowM  = parseDouble(lowMultiplierText,   fallback: 0.85)
        let norM  = parseDouble(normalMultiplierText, fallback: 1.00)
        let highM = parseDouble(highMultiplierText,  fallback: 1.25)
        let near  = max(0.50, min(0.95, nearCapacityPct / 100.0))

        return SuperchargerLivePricePredictor.Config(
            basePricePerKWh: max(0, base),
            lowMaxOccupied: max(0, lowMaxOccupied),
            nearCapacityThreshold: near,
            lowMultiplier: max(0, lowM),
            normalMultiplier: max(0, norM),
            highMultiplier: max(0, highM)
        )
    }

    private var livePricingEngine: any SuperchargerLivePriceEngine {
        if useCoreMLLivePricing {
            return CoreMLSuperchargerLivePriceEnginePlaceholder()
        }
        return RuleBasedSuperchargerLivePriceEngine()
    }

    private var prediction: SuperchargerLivePricePredictor.Prediction {
        livePricingEngine.predict(
            stallsTotal: stallsTotal,
            stallsOccupied: stallsOccupied,
            config: predictorConfig
        )
    }

    private var scenarioRows: [(SuperchargerLivePricePredictor.Tier, Double, String)] {
        livePricingEngine.scenarioPrices(
            stallsTotal: stallsTotal,
            config: predictorConfig
        )
    }

    private var engineHealth: MLEngineHealthReport {
        livePricingEngine.healthReport
    }

    private var engineHealthColor: Color {
        switch engineHealth.state {
        case .ready:       return .green
        case .fallback:    return .orange
        case .unavailable: return .red
        }
    }

    private var kWhToAdd: Double {
        max(0, parseDouble(kWhText, fallback: 25.0))
    }

    private var sessionCost: Double {
        kWhToAdd * prediction.pricePerKWh
    }

    private var idleFeeCost: Double? {
        let fee  = parseDouble(idleFeePerMinText, fallback: 0)
        let mins = parseDouble(idleMinutesText,   fallback: 0)
        guard fee > 0, mins > 0 else { return nil }
        return fee * mins
    }

    private var homeRate: Double? {
        if let env = homeRateEnv { return env }
        let keys = ["homeRatePerKWh", "localRatePerKWh", "settings.homeRatePerKWh"]
        for k in keys {
            if let v = UserDefaults.standard.object(forKey: k) as? Double, v > 0 { return v }
        }
        return nil
    }

    private func money(_ value: Double, maxFractionDigits: Int = 2) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = resolvedCurrencyCode
        nf.maximumFractionDigits = maxFractionDigits
        nf.minimumFractionDigits = min(2, maxFractionDigits)
        return nf.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func rateText(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = resolvedCurrencyCode
        nf.maximumFractionDigits = 4
        nf.minimumFractionDigits = 4
        let s = nf.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(s)/kWh"
    }

    private func logCurrentPriceSample() {
        guard !trimmedStationId.isEmpty else {
            logStatusText = "Add a station ID to log prices."
            return
        }
        SuperchargerPriceStore.shared.addSampleIfChanged(
            stationId: trimmedStationId,
            pricePerKwh: prediction.pricePerKWh,
            timestamp: Date()
        )
        logStatusText = "Logged \(rateText(prediction.pricePerKWh)) to \(trimmedStationId)"
    }

    private func persistHealthReport() {
        lastHealthSummary   = "\(engineHealth.state.rawValue): \(engineHealth.summary)"
        lastHealthTimestamp = Date().timeIntervalSince1970
    }

    // MARK: Body

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing + 8) {
                header
                modelStatusCard
                inputsCard
                scenarioTilesCard
                currentPredictionCard
                sessionCard
                feesCard
                disclaimerCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .navigationTitle("Live Price Predictor")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accent)
        .background(
            Rectangle()
                .fill(theme.screenBackground)
                .ignoresSafeArea()
        )
        .onAppear { persistHealthReport() }
        .onChange(of: useCoreMLLivePricing) { _, _ in persistHealthReport() }
    }

    // MARK: Header

    private var header: some View {
        card {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(accent.opacity(0.18))
                    Image(systemName: "bolt.badge.clock")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)  // FIX 3: accent is Color — no ambiguity
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Supercharger Live Price Predictor")
                        .font(.title3.weight(.semibold))
                    Text("Estimate price tiers from stall occupancy, and see the price you'd likely lock in at plug-in.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: Inputs Card

    private var inputsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {

                Text("Inputs").font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Station ID (for logging)")
                        .font(.footnote).foregroundStyle(.secondary)
                    TextField("e.g. supercharger_lake_grove_ny", text: $stationIdText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(10)
                        .background(theme.cardBackground.opacity(0.65),
                                    in: RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                                .strokeBorder(theme.separator.opacity(0.75), lineWidth: 1)
                        )
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Stalls total")
                            .font(.footnote).foregroundStyle(.secondary)
                        Stepper(value: $stallsTotal, in: 1...64) {
                            Text("\(stallsTotal)").font(.body.weight(.semibold))
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Occupied now")
                            .font(.footnote).foregroundStyle(.secondary)
                        Stepper(value: $stallsOccupied, in: 0...stallsTotal) {
                            Text("\(stallsOccupied)").font(.body.weight(.semibold))
                        }
                        .onChange(of: stallsTotal) { _, newTotal in
                            stallsOccupied = min(stallsOccupied, newTotal)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Base price for this location (\(resolvedCurrencyCode))")
                        .font(.footnote).foregroundStyle(.secondary)
                    TextField("e.g. 0.40", text: $basePriceText)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(10)
                        .background(theme.cardBackground.opacity(0.65),
                                    in: RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                                .strokeBorder(theme.separator.opacity(0.75), lineWidth: 1)
                        )
                }

                DisclosureGroup(isExpanded: $showAdvanced) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            ForEach(
                                [("Low multiplier", $lowMultiplierText, "0.85"),
                                 ("Normal multiplier", $normalMultiplierText, "1.00"),
                                 ("High multiplier", $highMultiplierText, "1.25")],
                                id: \.0
                            ) { label, binding, placeholder in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(label)
                                        .font(.footnote).foregroundStyle(.secondary)
                                    TextField(placeholder, text: binding)
                                        .keyboardType(.decimalPad)
                                        .padding(10)
                                        .background(theme.cardBackground.opacity(0.65),
                                                    in: RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Low tier max occupied")
                                    .font(.footnote).foregroundStyle(.secondary)
                                Stepper(value: $lowMaxOccupied, in: 0...min(3, stallsTotal)) {
                                    Text("\(lowMaxOccupied)").font(.body.weight(.semibold))
                                }
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Near-capacity threshold")
                                    .font(.footnote).foregroundStyle(.secondary)
                                HStack {
                                    Slider(value: $nearCapacityPct, in: 50...95, step: 1)
                                    Text("\(Int(nearCapacityPct))%")
                                        .font(.body.weight(.semibold))
                                        .frame(width: 54, alignment: .trailing)
                                }
                            }
                        }
                    }
                    .padding(.top, 10)
                } label: {
                    Text("Advanced tuning").font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    // MARK: Model Status Card

    private var modelStatusCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Model status").font(.headline)
                    Spacer()
                    Text(engineHealth.state.rawValue.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(engineHealthColor)
                }

                HStack(spacing: 8) {
                    Image(systemName: "cpu").foregroundStyle(engineHealthColor)
                    Text("Engine: \(livePricingEngine.engineIdentifier)")
                        .font(.footnote.weight(.semibold))
                }

                Text(engineHealth.summary)
                    .font(.footnote).foregroundStyle(.secondary)

                if let details = engineHealth.details, !details.isEmpty {
                    Text(details).font(.caption).foregroundStyle(.secondary)
                }

                if !lastHealthSummary.isEmpty, lastHealthTimestamp > 0 {
                    let last = Date(timeIntervalSince1970: lastHealthTimestamp)
                    Text("Last recorded: \(last.formatted(date: .abbreviated, time: .shortened)) · \(lastHealthSummary)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Scenario Tiles Card
    // FIX 1 & 2: map tuples → SCLiveScenarioRow so ForEach gets a proper
    // Identifiable type; eliminates both "No exact matches" / key-path errors.

    private var scenarioTilesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Scenarios").font(.headline)
                    Spacer()
                    Text("3-tier model").font(.caption).foregroundStyle(.secondary)
                }

                let rows = scenarioRows.map {
                    SCLiveScenarioRow(tier: $0.0, price: $0.1, note: $0.2)
                }

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(rows) { row in
                        scenarioTile(tier: row.tier, price: row.price, note: row.note)
                    }
                }
            }
        }
    }

    private func scenarioTile(
        tier: SuperchargerLivePricePredictor.Tier,
        price: Double,
        note: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: tier.systemImage)
                    .foregroundStyle(accent)  // FIX 3: accent is Color
                Text(tier.title).font(.subheadline.weight(.semibold))
                Spacer()
            }
            Text(rateText(price)).font(.headline.weight(.semibold))
            Text("\(tier.subtitle) · \(note)")
                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(12)
        .background(theme.cardBackground.opacity(0.65),
                    in: RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                .strokeBorder(theme.separator.opacity(0.75), lineWidth: 1)
        )
    }

    // MARK: Current Prediction Card

    private var currentPredictionCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Current prediction").font(.headline)

                HStack {
                    Label(prediction.tier.title, systemImage: prediction.tier.systemImage)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(rateText(prediction.pricePerKWh))
                        .font(.subheadline.weight(.semibold))
                }

                Text(prediction.rationale).font(.footnote).foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button {
                        logCurrentPriceSample()
                    } label: {
                        Label("Log current price", systemImage: "plus.circle")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(theme.pillTint))
                    }
                    .buttonStyle(.plain)
                    .disabled(stationIdText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let logStatusText {
                        Text(logStatusText)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }

                if historyCount > 0 {
                    HStack(spacing: 8) {
                        Text("History: \(historyCount)")
                        if let lastLoggedText {
                            Text("Last: \(lastLoggedText)")
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }

                if let officialRecord {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Official pricing (Tesla FindUs)")
                            .font(.footnote.weight(.semibold))
                        if officialRecord.pricingTeslaPrices.isEmpty {
                            Text("Pricing text found, but no explicit $/kWh values detected.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Detected $/kWh: " +
                                 officialRecord.pricingTeslaPrices
                                    .map { String(format: "$%.2f", $0) }
                                    .joined(separator: ", "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Last checked: \(officialRecord.lastFetched.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    NavigationLink {
                        TeslaOfficialSuperchargerPricingShiftView()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Check Tesla official pricing")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(theme.pillTint.opacity(0.65)))
                    }
                    .buttonStyle(.plain)
                }

                if let home = homeRate {
                    let diff = prediction.pricePerKWh - home
                    let pct  = home > 0 ? (diff / home) * 100.0 : 0
                    Text("Compared to home: \(rateText(home)) · Δ \(money(diff, maxFractionDigits: 4))/kWh (\(pct >= 0 ? "+" : "")\(pct, specifier: "%.0f")%)")
                        .font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                }
            }
        }
    }

    // MARK: Session Card

    private var sessionCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Session estimate").font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Energy to add (kWh)")
                        .font(.footnote).foregroundStyle(.secondary)
                    TextField("25.0000", text: $kWhText)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(10)
                        .background(theme.cardBackground.opacity(0.65),
                                    in: RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                                .strokeBorder(theme.separator.opacity(0.75), lineWidth: 1)
                        )
                }

                HStack {
                    Text("\(kWhToAdd, specifier: "%.4f") kWh @ \(rateText(prediction.pricePerKWh))")
                        .font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Text(money(sessionCost))
                        .font(.title3.weight(.semibold))
                }
            }
        }
    }

    // MARK: Fees Card

    private var feesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Optional fees").font(.headline)

                Text("Idle fees (if applicable) are often charged per minute when the station is busy and you remain plugged in after charging completes.")
                    .font(.footnote).foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Idle fee / min")
                            .font(.footnote).foregroundStyle(.secondary)
                        TextField("e.g. 1.00", text: $idleFeePerMinText)
                            .keyboardType(.decimalPad)
                            .padding(10)
                            .background(theme.cardBackground.opacity(0.65),
                                        in: RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Idle minutes")
                            .font(.footnote).foregroundStyle(.secondary)
                        TextField("e.g. 10", text: $idleMinutesText)
                            .keyboardType(.numberPad)
                            .padding(10)
                            .background(theme.cardBackground.opacity(0.65),
                                        in: RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
                    }
                }

                if let idle = idleFeeCost {
                    HStack {
                        Text("Idle fee estimate")
                            .font(.footnote).foregroundStyle(.secondary)
                        Spacer()
                        Text(money(idle)).font(.subheadline.weight(.semibold))
                    }
                    HStack {
                        Text("Total (energy + idle)")
                            .font(.footnote).foregroundStyle(.secondary)
                        Spacer()
                        Text(money(sessionCost + idle)).font(.headline.weight(.semibold))
                    }
                }
            }
        }
    }

    // MARK: Disclaimer Card

    private var disclaimerCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes").font(.headline)
                Text("This is a heuristic model. Tesla pricing varies by location/time and the displayed price is typically locked in when you plug in. Use this as a planning aid, not a guarantee.")
                    .font(.footnote).foregroundStyle(.secondary)

                Divider()

                Link(destination: URL(string: "https://www.hansshow.com?bg_ref=ptYAKqt7kF")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.car")
                            .font(.footnote)
                        Text("Tesla accessories by HansShow")
                            .font(.footnote.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(accent)
                }
            }
        }
    }

    // MARK: Card shell

    @ViewBuilder
    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .padding(theme.spacing)
            .background(theme.cardBackground.opacity(0.55),
                        in: RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                    .strokeBorder(theme.separator.opacity(0.85), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        SuperchargerLivePricePredictorView()
    }
}
#endif
