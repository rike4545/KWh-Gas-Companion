//
//  CalculatorsDashboardView.swift
//  My KWh Companion
//
//  Calculators hub — router + default destinations
//  Swift 6 • iOS 17+
//
//  This revision includes:
//  ✅ "Supercharge.info Near Me" tile + routing (community dataset)
//  ✅ "Tesla Service Alerts" tile + routing (scanner/decoder view)
//  ✅ "Right to Repair" tile + routing (educational view)
//  ✅ "Tesla EPC Parts Catalog" tile + routing (embedded EPC browser + quick search helpers)
//  ✅ "Supercharger Live Price Predictor" tile + routing (occupancy tier model)
//  ✅ "Charging Etiquette" tile + routing (offline mini-guide)
//  ✅ NEW: "Weekly EV vs Gas" tile + routing (gas price + weekly EV kWh cost)
//  ✅ Removed: any TeslaMate Premium / Store references (failed idea)
//  ✅ Fixes: Switch must be exhaustive (categories now cover all cases + future-proof default)
//  ✅ Avoids SCISite naming conflicts by NOT using SCISite anywhere in this file
//  ✅ Keeps CalcDash* prefixes unchanged
//

import SwiftUI
import Foundation

// MARK: - Router Environment

public typealias CalculatorRouteFactory = () -> AnyView

private struct CalculatorRouterKey: EnvironmentKey {
    static var defaultValue: [CalculatorKind: CalculatorRouteFactory] = [:]
}

public extension EnvironmentValues {
    var calculatorRouter: [CalculatorKind: CalculatorRouteFactory] {
        get { self[CalculatorRouterKey.self] }
        set { self[CalculatorRouterKey.self] = newValue }
    }
}

public extension View {
    /// Provide mappings from `CalculatorKind` → factories that build destination views.
    func calculatorRoutes(_ routes: [CalculatorKind: CalculatorRouteFactory]) -> some View {
        environment(\.calculatorRouter, routes)
    }
}

// MARK: - Search Normalization

fileprivate extension String {
    func _calcDashSearchNormalized() -> String {
        let folded = self.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        let cleaned = String(folded.unicodeScalars.map { scalar in
            if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return Character(scalar)
            } else {
                return " "
            }
        })

        return cleaned
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func _calcDashTokens() -> [String] {
        let norm = self._calcDashSearchNormalized()
        guard !norm.isEmpty else { return [] }
        return norm.split(separator: " ").map(String.init)
    }
}

// MARK: - Highlight helper

fileprivate func CalcDashHighlighted(_ source: String, tokens: [String], accent: Color) -> AttributedString {
    var a = AttributedString(source)
    guard !tokens.isEmpty else { return a }

    let ordered = tokens
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { $0.count >= 2 }
        .sorted { $0.count > $1.count }

    for tok in ordered {
        var searchRange: Range<String.Index> = source.startIndex..<source.endIndex

        while let r = source.range(
            of: tok,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: searchRange,
            locale: .current
        ) {
            if let lb = AttributedString.Index(r.lowerBound, within: a),
               let ub = AttributedString.Index(r.upperBound, within: a) {
                let ar = lb..<ub
                a[ar].foregroundColor = accent
                a[ar].inlinePresentationIntent = .stronglyEmphasized
            }
            searchRange = r.upperBound..<source.endIndex
        }
    }

    return a
}

// MARK: - UI Style

fileprivate enum CalcDashUIStyle: String {
    case classic
    case glass
}

// MARK: - Ranking

fileprivate struct CalcDashMatch: Hashable {
    let kind: CalculatorKind
    let score: Int
}

fileprivate struct CalcDashGroup: Hashable {
    let category: CalcDashCategory
    let items: [CalculatorKind]
    let bestScore: Int
}

// MARK: - Main View

@MainActor
public struct CalculatorsDashboardView: View {

    public init() {}

    @Environment(\.calculatorRouter) private var routes
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismissSearch) private var dismissSearch
    @EnvironmentObject private var uiSettings: AppUISettings

    @StateObject private var adsStore = AdsEntitlementStore.shared

    @Environment(\.appThemeBox) private var themeBox
    @EnvironmentObject private var appearance: AppAppearance

    @AppStorage("uiStyle") private var uiStyleRaw: String = "teslaGlass"
    private var uiStyle: CalcDashUIStyle {
        if let parsed = CalcDashUIStyle(rawValue: uiStyleRaw) { return parsed }
        return uiStyleRaw.lowercased() == "teslaglass" ? .glass : .classic
    }

    @State private var query: String = ""
    @State private var selection: CalculatorKind? = nil

    private var theme: any AppThemeSpec { themeBox.base }
    private var accent: Color { appearance.accentColor }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 160), spacing: theme.spacing, alignment: .top),
            count: (hSize == .regular) ? 3 : 2
        )
    }

    private var backgroundView: some View {
        ZStack {
            Rectangle().fill(theme.screenBackground).ignoresSafeArea()

            if uiSettings.motion == .full {
                RadialGradient(
                    colors: [theme.accent.opacity(scheme == .dark ? 0.26 : 0.16), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 520
                )
                .blur(radius: 28)
                .ignoresSafeArea()

                RadialGradient(
                    colors: [theme.accent.opacity(scheme == .dark ? 0.18 : 0.10), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 620
                )
                .blur(radius: 34)
                .ignoresSafeArea()
            }
        }
    }

    // MARK: Search core

    private var tokens: [String] { query._calcDashTokens() }
    private var isSearching: Bool { !tokens.isEmpty }

    private func matches(_ kind: CalculatorKind, tokens: [String]) -> Bool {
        guard !tokens.isEmpty else { return true }

        let hay = kind._calcDashSearchBlob._calcDashSearchNormalized()
        let words = hay.split(separator: " ").map(String.init)

        return tokens.allSatisfy { tok in
            if words.contains(tok) { return true }
            if words.contains(where: { $0.hasPrefix(tok) }) { return true }
            return hay.contains(tok)
        }
    }

    private func score(_ kind: CalculatorKind, tokens: [String]) -> Int {
        guard !tokens.isEmpty else { return 0 }

        let title = kind.title._calcDashSearchNormalized()
        let subtitle = kind.subtitle._calcDashSearchNormalized()
        let blob = kind._calcDashSearchBlob._calcDashSearchNormalized()

        let tWords = title.split(separator: " ").map(String.init)
        let sWords = subtitle.split(separator: " ").map(String.init)
        let bWords = blob.split(separator: " ").map(String.init)

        var total = 0

        for tok in tokens {
            if tWords.contains(tok) { total += 18 }
            else if tWords.contains(where: { $0.hasPrefix(tok) }) { total += 14 }
            else if title.contains(tok) { total += 9 }

            if sWords.contains(tok) { total += 10 }
            else if sWords.contains(where: { $0.hasPrefix(tok) }) { total += 7 }
            else if subtitle.contains(tok) { total += 4 }

            if bWords.contains(tok) { total += 3 }
            else if bWords.contains(where: { $0.hasPrefix(tok) }) { total += 2 }
            else if blob.contains(tok) { total += 1 }
        }

        if let first = tokens.first, title.hasPrefix(first) { total += 6 }
        if tokens.count == 1, let first = tokens.first, first.count >= 3,
           tWords.contains(where: { $0 == first }) { total += 4 }

        return total
    }

    private var matchesRanked: [CalcDashMatch] {
        if tokens.isEmpty {
            return CalculatorKind.allCases.map { .init(kind: $0, score: 0) }
        }

        return CalculatorKind.allCases
            .filter { matches($0, tokens: tokens) }
            .map { .init(kind: $0, score: score($0, tokens: tokens)) }
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.kind.title < $1.kind.title
            }
    }

    private var topMatches: [CalculatorKind] {
        Array(matchesRanked.prefix(10).map(\.kind))
    }

    private var grouped: [CalcDashGroup] {
        let dict = Dictionary(grouping: matchesRanked, by: { $0.kind._calcDashCategory })
        var out: [CalcDashGroup] = []

        for cat in CalcDashCategory.allCases {
            guard let rows = dict[cat], !rows.isEmpty else { continue }

            if tokens.isEmpty {
                let kinds = rows.map(\.kind).sorted { $0.title < $1.title }
                out.append(.init(category: cat, items: kinds, bestScore: 0))
            } else {
                let sorted = rows.sorted {
                    if $0.score != $1.score { return $0.score > $1.score }
                    return $0.kind.title < $1.kind.title
                }
                let best = sorted.first?.score ?? 0
                out.append(.init(category: cat, items: sorted.map(\.kind), bestScore: best))
            }
        }

        if tokens.isEmpty { return out }

        return out.sorted {
            if $0.bestScore != $1.bestScore { return $0.bestScore > $1.bestScore }
            return $0.category.rawValue < $1.category.rawValue
        }
    }

    // MARK: Navigation

    private func open(_ kind: CalculatorKind) {
        dismissSearch()
        if selection == kind {
            selection = nil
            DispatchQueue.main.async { selection = kind }
        } else {
            selection = kind
        }
    }

    // MARK: Body

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing + 6) {

                headerCard
                    .modifier(PolishCard())

                if isSearching {
                    CalcDashSearchSummaryCard(
                        theme: theme,
                        uiStyle: uiStyle,
                        accent: accent,
                        query: query,
                        count: matchesRanked.count,
                        onClear: { query = "" }
                    )
                    .modifier(PolishCard())

                    if matchesRanked.isEmpty {
                        CalcDashEmptySearchCard(theme: theme, uiStyle: uiStyle)
                            .modifier(PolishCard())
                    } else {
                        CalcDashTopResultsSection(
                            theme: theme,
                            uiStyle: uiStyle,
                            columns: columns,
                            tokens: tokens,
                            accent: accent,
                            items: topMatches,
                            open: open
                        )
                        .modifier(PolishCard())

                        Divider()
                            .overlay(theme.separator.opacity(0.85))
                            .padding(.top, 6)
                    }
                } else {
                    CalcDashCheapestInfoView(theme: theme, uiStyle: uiStyle, open: open)
                        .modifier(PolishCard())
                    CalcDashEverydayToolsSection(theme: theme, uiStyle: uiStyle, columns: columns, open: open)
                        .modifier(PolishCard())

                    Divider()
                        .overlay(theme.separator.opacity(0.85))
                        .padding(.top, 6)
                }

                VStack(alignment: .leading, spacing: theme.spacing) {
                    ForEach(grouped, id: \.category.id) { g in
                        CalcDashSectionView(
                            theme: theme,
                            uiStyle: uiStyle,
                            title: g.category.title,
                            icon: g.category.icon,
                            items: g.items,
                            columns: columns,
                            open: open,
                            isSearching: isSearching,
                            tokens: tokens,
                            accent: accent
                        )
                        .modifier(PolishCard())
                    }
                }
                .padding(.top, 4)

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                        .modifier(PolishCard())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .contentMargins(.top, 6, for: .scrollContent)
        .contentMargins(.bottom, 24, for: .scrollContent)
        .scrollIndicators(.hidden)
        .navigationTitle("Tools")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accent)
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search tools"
        )
        .task {
            await adsStore.load()
        }
        .searchSuggestions {
            Section("Quick launch") {
                ForEach(calcDashEverydayKinds.prefix(8)) { kind in
                    Button { open(kind) } label: {
                        Label(kind.title, systemImage: kind.systemImage)
                    }
                }
            }

            if isSearching {
                if matchesRanked.isEmpty {
                    Section("Tips") {
                        Label("Try fewer words (e.g. “vin”, “rate”, “budget”, “forecast”, “repair”, “epc”, “parts”, “live price”)", systemImage: "lightbulb")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Top matches") {
                        ForEach(topMatches.prefix(8)) { kind in
                            Button { open(kind) } label: {
                                Label(kind.title, systemImage: kind.systemImage)
                            }
                        }
                    }
                }
            }
        }
        .onSubmit(of: .search) {
            if isSearching, matchesRanked.count == 1, let only = matchesRanked.first?.kind {
                open(only)
            }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .scrollDismissesKeyboard(.immediately)
        .background(backgroundView)
        .animation(.snappy(duration: 0.22), value: query)
        .animation(.snappy(duration: 0.25), value: isSearching)
        .navigationDestination(item: $selection) { kind in
            destination(for: kind)
                .tint(accent)
        }
    }

    private struct PolishCard: ViewModifier {
        @EnvironmentObject private var uiSettings: AppUISettings

        func body(content: Content) -> some View {
            switch uiSettings.motion {
            case .none:
                content
            case .reduced:
                content
                    .transition(.opacity)
            case .full:
                content
                    .scrollTransition(.animated) { view, phase in
                        view
                            .opacity(phase.isIdentity ? 1 : 0.75)
                            .scaleEffect(phase.isIdentity ? 1 : 0.985)
                    }
            }
        }
    }

    // MARK: Header

    private var headerCard: some View {
        CalcDashCard(theme: theme, uiStyle: uiStyle) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(accent.opacity(0.18))
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tools")
                        .font(.title3.weight(.semibold))
                    Text("Search, browse by category, and open any calculator.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    // MARK: Routing

    @ViewBuilder
    private func destination(for kind: CalculatorKind) -> some View {
        if let make = routes[kind] {
            make()
        } else {
            defaultDestination(for: kind)
        }
    }

    @ViewBuilder
    private func defaultDestination(for kind: CalculatorKind) -> some View {
        switch kind {

        case .accessoryTracker: AccessoryTrackerView()
        case .analyticsCharts: AnalyticsChartsView()
        case .businessDeductionReport: CalcDashBusinessDeductionReportDestination()

        case .carbonImpactDashboard: CarbonImpactDashboardView()
        case .carbonOffset: CarbonOffsetView()
        case .carsVsEVCalculator: CarsVsEVCalculatorView()
        case .chargeTime: ChargeTimeView()
        case .chargingBudgetGuard: ChargingBudgetGuardView()
        case .chargingDataStudio: ChargingDataStudioView()
        case .chargingDataIntegrity: ChargingDataIntegrityView()

        case .chargingEtiquette:
            ChargingEtiquetteHomeView()
                .navigationTitle("Charging Etiquette")
                .navigationBarTitleDisplayMode(.inline)

        case .chargingReconciliation: ChargingReconciliationView()
        case .chartsBudget: ChartsBudgetView()
        case .cheapestChargerShift: SuperchargerHelperHost()
        case .combinedChargeSession: CombinedChargeSessionView()
        case .costBreakdownDetail: CostBreakdownDetailView()
        case .costOfOwnershipAnalysis: CostOfOwnershipAnalysisView()
        case .costPerKWhTrend: CostPerKWhTrendView()
        case .costPerMileAndCO2: CostPerMileAndCO2View()
        case .csvChargingWizard: CSVChargingWizardView()
        case .csvExport: CSVExportView()

        case .deepDepthShift: DeepDepthShiftView()
        case .doGoodDonationShift: DoGoodDonationShiftView()
        case .dynamicSuperchargingExplainer: DynamicSuperchargingExplainerView()

        case .entriesAnomalies: EntriesAnomaliesView()
        case .dataQualityCenter: DataQualityCenterView()
        case .energyCoach: EnergyCoachView()
        case .discounts: DiscountsView()
        case .evContent: EVContentView()
        case .evNews: EVNewsView()
        case .evVsCarComparison: EVvsCarComparisonView()
        case .evChargingVsGasTime: EVChargingVsGasTimeCalculatorView()
        case .muscleCarShowdown: MuscleCarShowdownHost()

        case .fastVsHomeImpact: FastVsHomeImpactView()
        case .forecastChart: ForecastChartView()
        case .forecastDashboard: ForecastDashboardView()
        case .forecastWeekly: WeeklyChargingForecastView()

        case .gasTax: GasTaxView()
        case .gasToKWhConverter: CalcDashGasToKWhConverterHost()

        case .garage: GarageView()

        case .historyOfTeslaAndRivian: HistoryOfTeslaAndRivianView()
        case .homeVsPublicSplit: HomeVsPublicSplitView()

        case .incentives: IncentivesView()

        case .kWhRates: KWhRatesView()

        case .leaseMileage: LeaseMileageView()

        case .mpgeCalculator: MPGeCalculatorView()
        case .materialsShift: EVMaterialsShiftView()

        case .nearMe: NearMeView()
        case .superchargeInfoNearMe:
            MEVSuperchargeNearMeView()
                .navigationTitle("Supercharge.info Near Me")
                .navigationBarTitleDisplayMode(.inline)

        case .paymentMethod: PaymentMethodView()
        case .publicIncentiveFinder: PublicIncentiveFinderView()
        case .productPlateScannerArchive: ProductPlateScannerView()
        case .priceWatchlist: PriceWatchlistView()

        case .quarterlyTaxSummary: QuarterlyTaxSummaryView()

        case .rangeForecast: RangeForecastView()
        case .recalls: RecallsView()
        case .reimbursementGenerator: ReimbursementGeneratorView()
        case .resaleMarketplace: ResaleMarketplaceView()
        case .rivianVINDecoder: RivianVINDecoderView()

        case .rightToRepair:
            RightToRepairView()
                .navigationTitle("Right to Repair")
                .navigationBarTitleDisplayMode(.inline)

        case .savingsScore: SavingsScoreView()
        case .schedulePlanner: ChargingSchedulePlannerView()
        case .receiptOCR: ReceiptOCRView()
        case .routeCostCompare: RouteCostCompareView()
        case .tcoMonthlyTimeline: OwnershipTimelineMonthlyView()
        case .winterRangeImpactPlanner: WinterRangeImpactPlannerView()
        case .chargingSafetyChecklist: ChargingSafetyChecklistView()
        case .emergencyPackChecklist: EmergencyPackChecklistView()
        case .teslaInvoiceScan: TeslaInvoiceScanView()
        case .tripBudgetPlanner: TripBudgetPlannerView()
        case .leaseVsBuyAnalyzer: LeaseVsBuyAnalyzerView()
        case .roadTaxEstimator: RoadTaxEstimatorView()
        case .stationQualityScore: StationQualityScoreView()
        case .chargeSpeedProfiler: ChargeSpeedProfilerView()
        case .tireMaintenanceTracker: TireMaintenanceTrackerView()
        case .diyServiceVault: DIYServiceVaultView()
        case .netCostPerMile: NetCostPerMileView()
        case .monthlyHeatmap: MonthlyHeatmapView()
        case .shareableReports: ShareableReportsView()
        case .sessionConfidence: SessionConfidenceView()
        case .duplicateResolver: DuplicateResolverView()
        case .bestValueChargers: BestValueChargersView()
        case .weeklyCostRollup: WeeklyCostRollupView()
        case .batteryHealthTimeline: BatteryHealthTimelineView()
        case .homeChargerOptimizer: HomeChargerOptimizerView()
        case .monthlyBurnDown: MonthlyBurnDownView()
        case .costPerMileVsGas: CostPerMileVsGasView()
        case .insuranceFinanceTracker: InsuranceFinanceTrackerView()
        case .serviceReminders: ServiceRemindersView()
        case .serviceInvoices: ServiceInvoicesLandingView()
        case .sessionAnalytics: SessionAnalyticsView()
        case .sessionEfficiencyScatter: SessionEfficiencyScatterView()
        case .sparkPanel: CalcDashSparkPanelHost()
        case .superChargerSessionCostCalculator: SuperChargerSessionCostCalculatorView()

        case .superchargerLivePricePredictor:
            SuperchargerLivePricePredictorView()
                .navigationTitle("Live Price Predictor")
                .navigationBarTitleDisplayMode(.inline)

        case .superchargerStops: SuperchargerStopsView()

        case .tcoTimeline: TCOTimelineView()
        case .taxTreatment: TaxTreatmentView()
        case .teslaFiCSVImport: TeslaFiCSVImportView()
        case .teslaOffer: TeslaOfferView()
        case .teslaOwnersClub: TeslaOwnersClubView()
        case .teslaVINDecoder: TeslaVINDecoderView()

        case .teslaServiceAlerts:
            TeslaServiceAlertScannerView()
                .navigationTitle("Tesla Service Alerts")
                .navigationBarTitleDisplayMode(.inline)

        case .teslaEPCPartsCatalog:
            TeslaEPCPartsSearchView()
                .navigationTitle("Tesla EPC")
                .navigationBarTitleDisplayMode(.inline)

        case .tripCostEstimator: TripCostEstimatorView()
        case .tripPlanner: TripPlannerView()
        case .tripLogger: TripLoggerView()

        case .annualCostSimulator: AnnualCostSimulatorView()
        case .unitConversion: UnitConversionView()
        case .evLoanLeaseOptimizer: EVLoanLeaseOptimizerView()
        case .finance: FinanceView()
        case .weeklyHealthReport: WeeklyHealthReportView()

        case .winterDrivingTechniques: WinterDrivingTechniquesView()
        case .whatIfForecast: WhatIfForecastView()

        // ✅ NEW
        case .weeklyEVVsGasCost:
            WeeklyEVVsGasCostView()
                .navigationTitle("Weekly EV vs Gas")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Cards + Tiles (unique names)

fileprivate struct CalcDashCard<Content: View>: View {
    let theme: any AppThemeSpec
    let uiStyle: CalcDashUIStyle
    let content: Content

    @Environment(\.colorScheme) private var scheme

    init(theme: any AppThemeSpec, uiStyle: CalcDashUIStyle, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.uiStyle = uiStyle
        self.content = content()
    }

    private var backgroundStyle: AnyShapeStyle {
        switch uiStyle {
        case .classic: return AnyShapeStyle(theme.cardBackground)
        case .glass: return AnyShapeStyle(.thinMaterial)
        }
    }

    private var shadowOpacity: Double { scheme == .dark ? 0.12 : 0.18 }

    var body: some View {
        content
            .padding(theme.spacing)
            .background(backgroundStyle, in: RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                    .strokeBorder(theme.separator.opacity(0.85), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(shadowOpacity), radius: theme.elevation, x: 0, y: 2)
    }
}

fileprivate struct CalcDashPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }
}

fileprivate struct CalcDashTile: View {
    let theme: any AppThemeSpec
    let uiStyle: CalcDashUIStyle
    let kind: CalculatorKind

    let isSearching: Bool
    let tokens: [String]
    let accent: Color

    @EnvironmentObject private var appearance: AppAppearance
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        CalcDashCard(theme: theme, uiStyle: uiStyle) {
            VStack(alignment: .leading, spacing: 10) {

                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        appearance.accentColor.opacity(scheme == .dark ? 0.92 : 0.98),
                                        appearance.accentColor.opacity(scheme == .dark ? 0.52 : 0.55)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Image(systemName: kind.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(theme.onAccent)
                    }
                    .frame(width: 40, height: 40)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if isSearching {
                    Text(CalcDashHighlighted(kind.title, tokens: tokens, accent: accent))
                        .font(.headline)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(CalcDashHighlighted(kind.subtitle, tokens: tokens, accent: accent))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text(kind.title)
                        .font(.headline)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(kind.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(kind.title)
    }
}

fileprivate struct CalcDashSectionView: View {
    let theme: any AppThemeSpec
    let uiStyle: CalcDashUIStyle
    let title: String
    let icon: String
    let items: [CalculatorKind]
    let columns: [GridItem]

    let open: (CalculatorKind) -> Void

    let isSearching: Bool
    let tokens: [String]
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.headline)
                Text(title).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 2)
            .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: theme.spacing) {
                ForEach(items) { kind in
                    Button { open(kind) } label: {
                        CalcDashTile(
                            theme: theme,
                            uiStyle: uiStyle,
                            kind: kind,
                            isSearching: isSearching,
                            tokens: tokens,
                            accent: accent
                        )
                    }
                    .buttonStyle(CalcDashPressStyle())
                    .contentShape(Rectangle())
                    .accessibilityHint("Opens \(kind.title)")
                }
            }
        }
    }
}

// MARK: - Search Summary + Empty

fileprivate struct CalcDashSearchSummaryCard: View {
    let theme: any AppThemeSpec
    let uiStyle: CalcDashUIStyle
    let accent: Color
    let query: String
    let count: Int
    let onClear: () -> Void

    var body: some View {
        CalcDashCard(theme: theme, uiStyle: uiStyle) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(accent.opacity(0.18))
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Search results")
                        .font(.headline)
                    Text("“\(query)” · \(count) match\(count == 1 ? "" : "es")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button(action: onClear) {
                    Label("Clear", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
    }
}

fileprivate struct CalcDashEmptySearchCard: View {
    let theme: any AppThemeSpec
    let uiStyle: CalcDashUIStyle

    var body: some View {
        CalcDashCard(theme: theme, uiStyle: uiStyle) {
            HStack(spacing: 12) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("No matches")
                        .font(.headline)
                    Text("Try fewer words or terms like “vin”, “rate”, “budget”, “forecast”, “receipt”, “supercharger”, “live price”, “alerts”, “repair”, “etiquette”, “epc”, “parts”.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
        }
    }
}

// MARK: - Top Results

fileprivate struct CalcDashTopResultsSection: View {
    let theme: any AppThemeSpec
    let uiStyle: CalcDashUIStyle
    let columns: [GridItem]

    let tokens: [String]
    let accent: Color
    let items: [CalculatorKind]
    let open: (CalculatorKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing) {
            HStack {
                Text("Top results")
                    .font(.title3.weight(.semibold))
                Spacer()
            }

            LazyVGrid(columns: columns, spacing: theme.spacing) {
                ForEach(items) { kind in
                    Button { open(kind) } label: {
                        CalcDashTile(
                            theme: theme,
                            uiStyle: uiStyle,
                            kind: kind,
                            isSearching: true,
                            tokens: tokens,
                            accent: accent
                        )
                    }
                    .buttonStyle(CalcDashPressStyle())
                }
            }
        }
    }
}

// MARK: - Cheapest Charging Hero

@MainActor
fileprivate struct CalcDashCheapestInfoView: View {
    let theme: any AppThemeSpec
    let uiStyle: CalcDashUIStyle
    let open: (CalculatorKind) -> Void

    @StateObject private var viewModel = SuperchargerPredictionViewModel(horizonHours: 24)

    var body: some View {
        CalcDashCard(theme: theme, uiStyle: uiStyle) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Cheapest Time to Charge", systemImage: "bolt.circle")
                        .font(.headline)

                    Spacer()

                    Text("Beta")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(theme.pillTint.opacity(0.28))
                        )
                }

                if viewModel.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Analyzing the next 24 hours…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if let error = viewModel.errorMessage {
                    Text("Prediction unavailable: \(error)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else if viewModel.hasPrediction {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.bestWindowText)
                            .font(.title3.weight(.semibold))

                        Text("Best price: \(viewModel.bestPriceText)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text("Typical: \(viewModel.medianPriceText) · Range: \(viewModel.spreadText)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text("Confidence: \(viewModel.confidenceText)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Open the finder to compute the lowest-cost fast-charging window.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button { open(.cheapestChargerShift) } label: {
                    HStack(spacing: 8) {
                        Text("Open Cheapest Charger Finder")
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.pillTint.opacity(0.30), in: Capsule(style: .continuous))
                }
                .buttonStyle(CalcDashPressStyle())
                .padding(.top, 4)
            }
        }
        .onAppear {
            if !viewModel.hasPrediction && !viewModel.isLoading {
                viewModel.refreshDefaultStation()
            }
        }
    }
}

// MARK: - Everyday tools

fileprivate let calcDashEverydayKinds: [CalculatorKind] = [
    .cheapestChargerShift,
    .superchargerLivePricePredictor,
    .weeklyEVVsGasCost, // ✅ NEW
    .chargingEtiquette,
    .winterDrivingTechniques,
    .superchargeInfoNearMe,
    .teslaServiceAlerts,
    .teslaEPCPartsCatalog,
    .rightToRepair,
    .forecastDashboard,
    .chartsBudget,
    .gasToKWhConverter,
    .evChargingVsGasTime,
    .unitConversion,
    .tripPlanner,
    .tripLogger
]

fileprivate struct CalcDashEverydayToolsSection: View {
    let theme: any AppThemeSpec
    let uiStyle: CalcDashUIStyle
    let columns: [GridItem]
    let open: (CalculatorKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing) {
            HStack {
                Text("Everyday tools")
                    .font(.title2.weight(.semibold))
                Spacer()
            }

            LazyVGrid(columns: columns, spacing: theme.spacing) {
                ForEach(calcDashEverydayKinds) { kind in
                    Button { open(kind) } label: {
                        CalcDashTile(
                            theme: theme,
                            uiStyle: uiStyle,
                            kind: kind,
                            isSearching: false,
                            tokens: [],
                            accent: .clear
                        )
                    }
                    .buttonStyle(CalcDashPressStyle())
                }
            }
        }
    }
}

// MARK: - Fallback Hosts (uniquely named)

@MainActor
fileprivate struct CalcDashSparkPanelHost: View {
    @StateObject private var store = SparkShiftStore()
    var body: some View { SparkPanel(shiftStore: store) }
}

@MainActor
fileprivate struct CalcDashBusinessDeductionReportDestination: View {
    @EnvironmentObject private var entriesStore: EntriesStore

    var body: some View {
        BusinessDeductionReportView(
            items: entriesStore.entries,
            dateOf: { bestDate($0) },
            amountOf: { bestAmount($0) }
        )
        .navigationTitle("Business Report")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bestDate(_ e: ExpenseEntry) -> Date {
        if let d: Date = read(e, ["date", "timestamp"]) { return d }
        if let s: String = read(e, ["dateString", "timestampString"]) {
            let f = ISO8601DateFormatter()
            if let d = f.date(from: s) { return d }
        }
        return .distantPast
    }

    private func bestAmount(_ e: ExpenseEntry) -> Double {
        if let v: Double = read(e, ["amount", "cost", "value", "total"]) { return v }
        return 0
    }

    private func read<T>(_ e: ExpenseEntry, _ labels: [String]) -> T? {
        for child in Mirror(reflecting: e).children {
            guard let label = child.label?.lowercased() else { continue }
            if labels.contains(where: { $0.lowercased() == label }) {
                return child.value as? T
            }
        }
        return nil
    }
}

@MainActor
fileprivate struct CalcDashGasToKWhConverterHost: View {
    @EnvironmentObject private var entriesStore: EntriesStore

    var body: some View {
        GasToKWhConverterView(expensesProvider: { entriesStore.entries })
            .navigationTitle("Gas → kWh Converter")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CalculatorsDashboardView()
    }
}
#endif
