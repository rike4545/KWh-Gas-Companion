//  ForecastSettingsView.swift
//  My KWh Companion
//
//  🔧 FIX: DecimalTextField.format(_:) allocated a new NumberFormatter on
//     every call — once per keystroke, once on appear, once per onChange.
//     Changed to a `private static let` so the formatter is built once.

import SwiftUI
import Foundation

// MARK: - Keys & Defaults

private enum ForecastPrefs {
    static let modelKey                = "forecast.model"
    static let horizonMonthsKey        = "forecast.horizonMonths"
    static let granularityKey          = "forecast.granularity"
    static let includeWeeklySeasonKey  = "forecast.includeWeeklySeason"
    static let includeYearlySeasonKey  = "forecast.includeYearlySeason"
    static let confidencePctKey        = "forecast.confidencePct"
    static let maWindowKey             = "forecast.maWindow"
    static let esAlphaKey              = "forecast.esAlpha"
    static let useWeatherKey           = "forecast.useWeather"
    static let kwhRateKey              = "forecast.kwhRate"
    static let gasPriceKey             = "forecast.gasPrice"
    static let gridCO2Key              = "forecast.gridCO2"
    static let baselineMPGKey          = "forecast.baselineMPG"
    static let showAdvancedKey         = "forecast.showAdvanced"

    struct Defaults {
        static let model: ForecastModel = .auto
        static let horizonMonths: Int = 6
        static let granularity: ForecastGranularity = .monthly
        static let includeWeeklySeason: Bool = false
        static let includeYearlySeason: Bool = true
        static let confidencePct: Double = 80
        static let maWindow: Int = 3
        static let esAlpha: Double = 0.30
        static let useWeather: Bool = false
        static let kwhRate: Double = 0.12
        static let gasPrice: Double = 3.75
        static let gridCO2: Double = 387
        static let baselineMPG: Double = 30
        static let showAdvanced: Bool = false
    }
}

// MARK: - Enums

public enum ForecastModel: String, CaseIterable, Identifiable {
    case auto, movingAverage, exponentialSmoothing, linearTrend
    public var id: String { rawValue }
    var title: String {
        switch self {
        case .auto:                  return "Auto (choose best)"
        case .movingAverage:         return "Moving Average"
        case .exponentialSmoothing:  return "Exponential Smoothing"
        case .linearTrend:           return "Linear Trend"
        }
    }
    var footnote: String {
        switch self {
        case .auto:                  return "Quick pick; balances fit & simplicity."
        case .movingAverage:         return "Smooths noise with a fixed window."
        case .exponentialSmoothing:  return "Weights recent data more."
        case .linearTrend:           return "Straight line fit over time."
        }
    }
}

public enum ForecastGranularity: String, CaseIterable, Identifiable {
    case daily, weekly, monthly
    public var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

// MARK: - View

public struct ForecastSettingsView: View {
    @AppStorage(ForecastPrefs.modelKey)               private var modelRaw: String = ForecastPrefs.Defaults.model.rawValue
    @AppStorage(ForecastPrefs.horizonMonthsKey)       private var horizonMonths: Int = ForecastPrefs.Defaults.horizonMonths
    @AppStorage(ForecastPrefs.granularityKey)         private var granularityRaw: String = ForecastPrefs.Defaults.granularity.rawValue
    @AppStorage(ForecastPrefs.includeWeeklySeasonKey) private var includeWeeklySeason: Bool = ForecastPrefs.Defaults.includeWeeklySeason
    @AppStorage(ForecastPrefs.includeYearlySeasonKey) private var includeYearlySeason: Bool = ForecastPrefs.Defaults.includeYearlySeason
    @AppStorage(ForecastPrefs.confidencePctKey)       private var confidencePct: Double = ForecastPrefs.Defaults.confidencePct
    @AppStorage(ForecastPrefs.maWindowKey)            private var maWindow: Int = ForecastPrefs.Defaults.maWindow
    @AppStorage(ForecastPrefs.esAlphaKey)             private var esAlpha: Double = ForecastPrefs.Defaults.esAlpha
    @AppStorage(ForecastPrefs.useWeatherKey)          private var useWeather: Bool = ForecastPrefs.Defaults.useWeather
    @AppStorage(ForecastPrefs.kwhRateKey)             private var kwhRate: Double = ForecastPrefs.Defaults.kwhRate
    @AppStorage(ForecastPrefs.gasPriceKey)            private var gasPrice: Double = ForecastPrefs.Defaults.gasPrice
    @AppStorage(ForecastPrefs.gridCO2Key)             private var gridCO2: Double = ForecastPrefs.Defaults.gridCO2
    @AppStorage(ForecastPrefs.baselineMPGKey)         private var baselineMPG: Double = ForecastPrefs.Defaults.baselineMPG
    @AppStorage(ForecastPrefs.showAdvancedKey)        private var showAdvanced: Bool = ForecastPrefs.Defaults.showAdvanced

    private var currentModel: ForecastModel { ForecastModel(rawValue: modelRaw) ?? .auto }
    private var currentGranularity: ForecastGranularity { ForecastGranularity(rawValue: granularityRaw) ?? .monthly }

    private var modelBinding: Binding<ForecastModel> {
        Binding(get: { ForecastModel(rawValue: modelRaw) ?? .auto }, set: { modelRaw = $0.rawValue })
    }
    private var granularityBinding: Binding<ForecastGranularity> {
        Binding(get: { ForecastGranularity(rawValue: granularityRaw) ?? .monthly }, set: { granularityRaw = $0.rawValue })
    }

    public init() {}

    public var body: some View {
        Form {
            Section("Model") {
                Picker("Forecast Model", selection: modelBinding) {
                    ForEach(ForecastModel.allCases) { m in Text(m.title).tag(m) }
                }
                .pickerStyle(.menu)

                Text(currentModel.footnote)
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Stepper(value: $horizonMonths, in: 1...36) {
                    HStack {
                        Text("Horizon")
                        Spacer()
                        Text("\(horizonMonths) month\(horizonMonths == 1 ? "" : "s")").foregroundStyle(.secondary)
                    }
                }

                Picker("Granularity", selection: granularityBinding) {
                    ForEach(ForecastGranularity.allCases) { g in Text(g.title).tag(g) }
                }
                .pickerStyle(.segmented)

                Toggle("Weekly seasonality", isOn: $includeWeeklySeason)
                Toggle("Yearly seasonality", isOn: $includeYearlySeason)

                HStack {
                    Text("Confidence band")
                    Spacer()
                    Slider(value: $confidencePct, in: 50...95, step: 1) { Text("Confidence") }
                        .frame(maxWidth: 180)
                    Text("\(Int(confidencePct))%").foregroundStyle(.secondary)
                }
            }

            if currentModel == .movingAverage {
                Section("Moving Average") {
                    Stepper(value: $maWindow, in: 2...24) {
                        HStack {
                            Text("Window")
                            Spacer()
                            Text("\(maWindow) periods").foregroundStyle(.secondary)
                        }
                    }
                    Text("Larger windows smooth more but react slower.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            if currentModel == .exponentialSmoothing {
                Section("Exponential Smoothing") {
                    HStack {
                        Text("Alpha")
                        Spacer()
                        Slider(value: $esAlpha, in: 0.05...0.95, step: 0.01) { Text("Alpha") }
                            .frame(maxWidth: 200)
                        Text(String(format: "%.2f", esAlpha))
                            .foregroundStyle(.secondary).monospacedDigit()
                    }
                    Text("Higher alpha gives more weight to recent data.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("External Factors") {
                Toggle("Adjust with weather / rates", isOn: $useWeather)
                HStack { Text("Electric rate");           Spacer(); DecimalTextField(value: $kwhRate,    suffix: " $/kWh",     step: 0.01, range: 0...3) }
                HStack { Text("Gas price");               Spacer(); DecimalTextField(value: $gasPrice,   suffix: " $/gal",     step: 0.01, range: 0...12) }
                HStack { Text("Grid intensity");          Spacer(); DecimalTextField(value: $gridCO2,    suffix: " gCO₂/kWh", step: 1,    range: 0...1200) }
                HStack { Text("Baseline ICE efficiency"); Spacer(); DecimalTextField(value: $baselineMPG, suffix: " mpg",     step: 0.5,  range: 5...120) }
            }

            Section {
                Toggle("Show advanced parameters", isOn: $showAdvanced)
                if showAdvanced {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Advanced tips").font(.subheadline.weight(.semibold))
                        Text("• Use **Monthly** granularity for most budgets.\n• Keep confidence between 70–90% for readable bands.\n• If your data is noisy, try **Moving Average** with a window of 3–6.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Button(role: .destructive) {
                    resetDefaults()
                } label: {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .navigationTitle("Forecast Settings")
    }

    private func resetDefaults() {
        modelRaw           = ForecastPrefs.Defaults.model.rawValue
        horizonMonths      = ForecastPrefs.Defaults.horizonMonths
        granularityRaw     = ForecastPrefs.Defaults.granularity.rawValue
        includeWeeklySeason = ForecastPrefs.Defaults.includeWeeklySeason
        includeYearlySeason = ForecastPrefs.Defaults.includeYearlySeason
        confidencePct      = ForecastPrefs.Defaults.confidencePct
        maWindow           = ForecastPrefs.Defaults.maWindow
        esAlpha            = ForecastPrefs.Defaults.esAlpha
        useWeather         = ForecastPrefs.Defaults.useWeather
        kwhRate            = ForecastPrefs.Defaults.kwhRate
        gasPrice           = ForecastPrefs.Defaults.gasPrice
        gridCO2            = ForecastPrefs.Defaults.gridCO2
        baselineMPG        = ForecastPrefs.Defaults.baselineMPG
        showAdvanced       = ForecastPrefs.Defaults.showAdvanced
    }
}

// MARK: - Decimal Text Field

private struct DecimalTextField: View {
    @Binding var value: Double
    var suffix: String = ""
    var step: Double = 0.1
    var range: ClosedRange<Double> = -Double.greatestFiniteMagnitude...Double.greatestFiniteMagnitude

    @State private var draft: String = ""

    init(value: Binding<Double>, suffix: String = "", step: Double = 0.1,
         range: ClosedRange<Double> = -Double.greatestFiniteMagnitude...Double.greatestFiniteMagnitude) {
        self._value = value
        self.suffix = suffix
        self.step = step
        self.range = range
        self._draft = State(initialValue: Self.format(value.wrappedValue))
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $draft)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 70, maxWidth: 100)
                .onSubmit(commit)
            Text(suffix).foregroundStyle(.secondary)
            Stepper(value: $value, in: range, step: step) { EmptyView() }
                .labelsHidden()
        }
        .onAppear { draft = Self.format(value) }
        .onChange(of: value) { _, newValue in draft = Self.format(newValue) }
    }

    private func commit() {
        let cleaned = draft.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        if let v = Double(cleaned) {
            let clamped = min(max(v, range.lowerBound), range.upperBound)
            value = clamped
            draft = Self.format(clamped)
        } else {
            draft = Self.format(value)
        }
    }

    // 🔧 FIX: `static let` — formatter created once, not on every keystroke.
    private static let formatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 3
        return nf
    }()

    private static func format(_ v: Double) -> String {
        formatter.string(from: v as NSNumber) ?? String(format: "%.3f", v)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { ForecastSettingsView() }
}
