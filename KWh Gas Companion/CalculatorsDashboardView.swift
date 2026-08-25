//
//  CalculatorsDashboardView.swift
//  My KWh Companion
//
//  Calculators hub -- router + default destinations
//  Swift 6 / iOS 17+
//
//  Performance revision 2 -- all compiler errors fixed:
//  CalculatorKind.lemonLaw added to everyday tools + routing
//

import SwiftUI
import Foundation

// MARK: - Router Environment

public typealias CalculatorRouteFactory = @MainActor () -> AnyView

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

// MARK: - Highlight cache + builder

fileprivate final class CalcDashHighlightCache: @unchecked Sendable {
    private var store: [String: AttributedString] = [:]
    private let maxSize = 256

    func get(key: String) -> AttributedString? { store[key] }
    func set(key: String, value: AttributedString) {
        if store.count >= maxSize { store.removeAll(keepingCapacity: true) }
        store[key] = value
    }
}

fileprivate let _highlightCache = CalcDashHighlightCache()

fileprivate func CalcDashHighlighted(_ source: String, tokens: [String], accent: Color) -> AttributedString {
    guard !tokens.isEmpty else { return AttributedString(source) }
    let cacheKey = "\(source)|\(tokens.joined(separator: ","))"
    if let cached = _highlightCache.get(key: cacheKey) { return cached }

    var a = AttributedString(source)
    let ordered = tokens
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { $0.count >= 2 }
        .sorted { $0.count > $1.count }

    for tok in ordered {
        var searchRange: Range<String.Index> = source.startIndex..<source.endIndex
        while let r = source.range(of: tok, options: [.caseInsensitive, .diacriticInsensitive],
                                   range: searchRange, locale: .current) {
            if let lb = AttributedString.Index(r.lowerBound, within: a),
               let ub = AttributedString.Index(r.upperBound, within: a) {
                a[lb..<ub].foregroundColor = accent
                a[lb..<ub].inlinePresentationIntent = .stronglyEmphasized
            }
            searchRange = r.upperBound..<source.endIndex
        }
    }
    _highlightCache.set(key: cacheKey, value: a)
    return a
}

// MARK: - UI Style / Shadow

fileprivate enum CalcDashUIStyle: String {
    case classic
    case glass
}

fileprivate enum CalcDashShadowLevel {
    case none, soft, normal
}

// MARK: - Ranking models

fileprivate struct CalcDashMatch: Hashable {
    let kind: CalculatorKind
    let score: Int
}

fileprivate struct CalcDashGroup: Hashable {
    let category: CalcDashCategory
    let items: [CalculatorKind]
    let bestScore: Int
    let categoryID: String
}

// MARK: - Pure scoring

fileprivate func calcDashMatches(_ kind: CalculatorKind, tokens: [String]) -> Bool {
    guard !tokens.isEmpty else { return true }
    let hay = kind._calcDashSearchBlob._calcDashSearchNormalized()
    let words = hay.split(separator: " ").map(String.init)
    return tokens.allSatisfy { tok in
        words.contains(tok) || words.contains(where: { $0.hasPrefix(tok) }) || hay.contains(tok)
    }
}

fileprivate func calcDashScore(_ kind: CalculatorKind, tokens: [String]) -> Int {
    guard !tokens.isEmpty else { return 0 }
    let title    = kind.title._calcDashSearchNormalized()
    let subtitle = kind.subtitle._calcDashSearchNormalized()
    let blob     = kind._calcDashSearchBlob._calcDashSearchNormalized()
    let tWords = title.split(separator: " ").map(String.init)
    let sWords = subtitle.split(separator: " ").map(String.init)
    let bWords = blob.split(separator: " ").map(String.init)
    var total = 0
    for tok in tokens {
        if tWords.contains(tok)                                { total += 18 }
        else if tWords.contains(where: { $0.hasPrefix(tok) }) { total += 14 }
        else if title.contains(tok)                            { total += 9  }
        if sWords.contains(tok)                                { total += 10 }
        else if sWords.contains(where: { $0.hasPrefix(tok) }) { total += 7  }
        else if subtitle.contains(tok)                         { total += 4  }
        if bWords.contains(tok)                                { total += 3  }
        else if bWords.contains(where: { $0.hasPrefix(tok) }) { total += 2  }
        else if blob.contains(tok)                             { total += 1  }
    }
    if let first = tokens.first, title.hasPrefix(first) { total += 6 }
    if tokens.count == 1, let first = tokens.first, first.count >= 3,
       tWords.contains(where: { $0 == first }) { total += 4 }
    return total
}

fileprivate func calcDashBlendedScore(lexical: Int, semantic: Double?) -> Int {
    guard let semantic else { return lexical }
    let semanticClamped = max(0.0, min(1.0, semantic))
    let semanticBonus = Int((semanticClamped * 40.0).rounded())
    return lexical + semanticBonus
}

// MARK: - Background

fileprivate struct CalcDashBackground: View {
    let screenBackground: AnyShapeStyle
    let accent: Color
    let showGradients: Bool
    let scheme: ColorScheme

    var body: some View {
        ZStack {
            Rectangle().fill(screenBackground).ignoresSafeArea()
            if showGradients {
                RadialGradient(
                    colors: [accent.opacity(scheme == .dark ? 0.26 : 0.16), .clear],
                    center: .topLeading, startRadius: 0, endRadius: 520
                )
                .blur(radius: 28).ignoresSafeArea()
                RadialGradient(
                    colors: [accent.opacity(scheme == .dark ? 0.18 : 0.10), .clear],
                    center: .bottomTrailing, startRadius: 0, endRadius: 620
                )
                .blur(radius: 34).ignoresSafeArea()
            }
        }
    }
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
    @AppStorage(CoreMLFeatureFlags.semanticToolSearchEnabledKey)
    private var useSemanticToolSearch: Bool = CoreMLFeatureFlags.semanticToolSearchEnabledDefault
    private var uiStyle: CalcDashUIStyle {
        switch uiStyleRaw.lowercased() {
        case "glass", "teslaglass": return .glass
        default:
            if let parsed = CalcDashUIStyle(rawValue: uiStyleRaw) { return parsed }
            return .classic
        }
    }

    @State private var query: String = ""
    @State private var selection: CalculatorKind? = nil
    @State private var showAgentPanel: Bool = false

    @State private var tokens: [String] = []
    @State private var matchesRanked: [CalcDashMatch] = calcDashVisibleKinds.map { .init(kind: $0, score: 0) }
    @State private var grouped: [CalcDashGroup] = []
    @State private var topMatches: [CalculatorKind] = []
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var searchRevision: Int = 0

    private var theme: any AppThemeSpec { themeBox.base }
    private var accent: Color { appearance.accentColor }
    private var isSearching: Bool { !tokens.isEmpty }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 160), spacing: theme.spacing, alignment: .top),
            count: (hSize == .regular) ? 3 : 2
        )
    }

    // MARK: Search update

    private func updateSearch(newQuery: String) {
        searchTask?.cancel()
        searchRevision &+= 1

        let currentRevision = searchRevision
        let newTokens = newQuery._calcDashTokens()
        tokens = newTokens
        let semanticEnabled = useSemanticToolSearch
        let semanticQuery = newQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        searchTask = Task.detached(priority: .userInitiated) {
            var ranked: [CalcDashMatch]
            if newTokens.isEmpty {
                ranked = calcDashVisibleKinds.map { .init(kind: $0, score: 0) }
            } else {
                ranked = calcDashVisibleKinds
                    .filter { calcDashMatches($0, tokens: newTokens) }
                    .map    { .init(kind: $0, score: calcDashScore($0, tokens: newTokens)) }
                    .sorted {
                        if $0.score != $1.score { return $0.score > $1.score }
                        return $0.kind.title < $1.kind.title
                    }
            }

            if semanticEnabled, !semanticQuery.isEmpty, !ranked.isEmpty {
                let ranker: any ToolSemanticRankingEngine = CoreMLToolSemanticRankingEnginePlaceholder()
                let semanticScores = ranker.scores(
                    query: semanticQuery,
                    candidates: ranked.map(\.kind)
                )
                if !semanticScores.isEmpty {
                    ranked.sort { lhs, rhs in
                        let left  = calcDashBlendedScore(lexical: lhs.score, semantic: semanticScores[lhs.kind])
                        let right = calcDashBlendedScore(lexical: rhs.score, semantic: semanticScores[rhs.kind])
                        if left != right { return left > right }
                        if lhs.score != rhs.score { return lhs.score > rhs.score }
                        return lhs.kind.title < rhs.kind.title
                    }
                }
            }

            guard !Task.isCancelled else { return }
            let top = Array(ranked.prefix(10).map(\.kind))

            let dict = Dictionary(grouping: ranked, by: { $0.kind._calcDashCategory })
            var mutableGroups: [CalcDashGroup] = []
            for cat in CalcDashCategory.allCases {
                guard let rows = dict[cat], !rows.isEmpty else { continue }
                let catID = String(describing: cat)
                if newTokens.isEmpty {
                    let kinds = rows.map(\.kind).sorted { $0.title < $1.title }
                    mutableGroups.append(.init(category: cat, items: kinds, bestScore: 0, categoryID: catID))
                } else {
                    let sorted = rows.sorted {
                        if $0.score != $1.score { return $0.score > $1.score }
                        return $0.kind.title < $1.kind.title
                    }
                    let best = sorted.first?.score ?? 0
                    mutableGroups.append(.init(category: cat, items: sorted.map(\.kind), bestScore: best, categoryID: catID))
                }
            }
            if !newTokens.isEmpty {
                mutableGroups.sort {
                    if $0.bestScore != $1.bestScore { return $0.bestScore > $1.bestScore }
                    return $0.categoryID < $1.categoryID
                }
            }
            let finalGroups  = mutableGroups
            let finalRanked  = ranked

            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard currentRevision == self.searchRevision else { return }
                self.matchesRanked = finalRanked
                self.topMatches    = top
                self.grouped       = finalGroups
            }
        }
    }

    // MARK: Navigation

    private func open(_ kind: CalculatorKind) {
        dismissSearch()
        if selection == kind {
            selection = nil
            Task { @MainActor in selection = kind }
        } else {
            selection = kind
        }
    }

    // MARK: Body helpers

    private var searchingContent: some View {
        Group {
            CalcDashSearchSummaryCard(
                theme: theme, uiStyle: uiStyle, accent: accent,
                query: query, count: matchesRanked.count,
                onClear: {
                    withAnimation(uiSettings.motion == .none ? nil : .snappy(duration: 0.18)) {
                        query = ""
                    }
                }
            )
            .modifier(CalcDashHeroPolish())

            if matchesRanked.isEmpty {
                CalcDashEmptySearchCard(theme: theme, uiStyle: uiStyle)
                    .modifier(CalcDashHeroPolish())
            } else {
                CalcDashTopResultsSection(
                    theme: theme, uiStyle: uiStyle, columns: columns,
                    tokens: tokens, accent: accent, items: topMatches, open: open
                )
                .equatable()

                Divider()
                    .overlay(theme.separator.opacity(0.85))
                    .padding(.top, 6)
            }
        }
    }

    private var browsingContent: some View {
        Group {
            CalcDashAgentCopilotCard(theme: theme, uiStyle: uiStyle) {
                showAgentPanel = true
            }
            .modifier(CalcDashHeroPolish())

            CalcDashCheapestInfoView(theme: theme, uiStyle: uiStyle, open: open)
                .modifier(CalcDashHeroPolish())

            CalcDashEverydayToolsSection(
                theme: theme, uiStyle: uiStyle, columns: columns, open: open
            )

            Divider()
                .overlay(theme.separator.opacity(0.85))
                .padding(.top, 6)
        }
    }

    // MARK: Body

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing + 6) {

                headerCard.modifier(CalcDashHeroPolish())

                if isSearching {
                    searchingContent
                } else {
                    browsingContent
                }

                VStack(alignment: .leading, spacing: theme.spacing) {
                    ForEach(grouped, id: \.categoryID) { g in
                        CalcDashSectionView(
                            theme: theme, uiStyle: uiStyle,
                            title: g.category.title, icon: g.category.icon,
                            items: g.items, columns: columns, open: open,
                            isSearching: isSearching, tokens: tokens, accent: accent
                        )
                    }
                }
                .padding(.top, 4)

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore).modifier(CalcDashHeroPolish())
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
        .onChange(of: query) { _, newValue in updateSearch(newQuery: newValue) }
        .onAppear { if grouped.isEmpty { updateSearch(newQuery: "") } }
        .onDisappear { searchTask?.cancel(); searchTask = nil }
        .task { await adsStore.load() }
        .searchSuggestions {
            Section("Quick launch") {
                ForEach(calcDashEverydayKinds.prefix(8), id: \.self) { kind in
                    Button { open(kind) } label: {
                        Label(kind.title, systemImage: kind.systemImage)
                    }
                }
            }
            if isSearching {
                if matchesRanked.isEmpty {
                    Section("Tips") {
                        Label(
                            "Try fewer words (e.g. \"vin\", \"rate\", \"budget\", \"lemon\", \"repair\", \"forecast\", \"epc\", \"parts\", \"live price\")",
                            systemImage: "lightbulb"
                        )
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Top matches") {
                        ForEach(topMatches.prefix(8), id: \.self) { kind in
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
        .background(
            CalcDashBackground(
                screenBackground: AnyShapeStyle(theme.screenBackground),
                accent: accent,
                showGradients: uiSettings.motion == .full,
                scheme: scheme
            )
        )
        .navigationDestination(item: $selection) { kind in
            destination(for: kind).tint(accent)
        }
        .sheet(isPresented: $showAgentPanel) {
            AgentPanelView()
        }
    }

    // MARK: Hero polish modifier

    private struct CalcDashHeroPolish: ViewModifier {
        @EnvironmentObject private var uiSettings: AppUISettings
        func body(content: Content) -> some View {
            switch uiSettings.motion {
            case .none:    content
            case .reduced: content.transition(.opacity)
            case .full:    content.transition(.opacity)
            }
        }
    }

    // MARK: Header

    private var headerCard: some View {
        CalcDashCard(theme: theme, uiStyle: uiStyle, shadow: .normal) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(accent.opacity(0.18))
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tools").font(.title3.weight(.semibold))
                    Text("Search, browse by category, and open any calculator.")
                        .font(.subheadline).foregroundStyle(.secondary)
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
        case .carsVsEVCalculator, .costPerMileAndCO2, .evVsCarComparison, .costPerMileVsGas, .weeklyEVVsGasCost:
            EVGasComparisonHubView()
        case .chargeTime: ChargeTimeView()
        case .chargingBudgetGuard: ChargingBudgetGuardView()
        case .chargingDataStudio: ChargingDataStudioView()
        case .chargingDataIntegrity: ChargingDataIntegrityView()
        case .chargingEtiquette:
            ChargingEtiquetteHomeView()
                .navigationTitle("Charging Etiquette")
                .navigationBarTitleDisplayMode(.inline)
        case .chargingReconciliation: ChargingReconciliationView()
        case .caughtaKWH: CaughtaKWHView()
        case .chartsBudget: ChartsBudgetView()
        case .cheapestChargerShift: SuperchargerHelperHost()
        case .combinedChargeSession: CombinedChargeSessionView()
        case .costBreakdownDetail: CostBreakdownDetailView()
        case .costOfOwnershipAnalysis: CostOfOwnershipAnalysisView()
        case .costPerKWhTrend: CostPerKWhTrendView()

        case .csvChargingWizard: CSVChargingWizardView()
        case .csvExport: CSVExportView()
        case .deliveryTracker: TeslaDeliveryTrackerView()
        case .deliveryChecklist: DeliveryChecklistView()
        case .deepDepthShift: DeepDepthShiftView()
        case .doGoodDonationShift: DoGoodDonationShiftView()
        case .dynamicSuperchargingExplainer: DynamicSuperchargingExplainerView()
        case .entriesAnomalies: EntriesAnomaliesView()
        case .dataQualityCenter: DataQualityCenterView()
        case .energyCoach: EnergyCoachView()
        case .discounts: DiscountsView()
        case .evContent: EVContentView()
        case .evNews: EVNewsView()

        case .evChargingVsGasTime: EVChargingVsGasTimeCalculatorView()
        case .muscleCarShowdown: MuscleCarShowdownHost()
        case .fastVsHomeImpact: FastVsHomeImpactView()
        case .forecastChart: ForecastChartView()
        case .forecastDashboard: ForecastDashboardView()
        case .forecastWeekly: WeeklyChargingForecastView()
        case .gridEmissionsForecast: GridEmissionsForecastView()
        case .gasTax: GasTaxView()
        case .gasToKWhConverter: CalcDashGasToKWhConverterHost()
        case .garage: GarageView()
        case .historyOfTeslaAndRivian: HistoryOfTeslaAndRivianView()
        case .homeVsPublicSplit: HomeVsPublicSplitView()
        case .incentives: IncentivesView()
        case .kWhRates: KWhRatesView()
        case .libreNav: LibreNavView()
        case .routeDiscovery: RouteDiscoveryView()
        case .leaseMileage: LeaseMileageView()
        case .mpgeCalculator: MPGeCalculatorView()
        case .materialsShift: EVMaterialsShiftView()
        case .nearMe: NearMeView()
        case .nhtsaCrashReporting: NHTSACrashReportingView()
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
        case .lemonLawGuide:
            LemonLawGuideView()
                .navigationTitle("Lemon Law Guide")
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
        case .maintenanceGuides: MaintenanceGuidesView()
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
        case .altitudeCockpit: AltitudeCockpitView()
        case .weatherCockpit: WeatherCockpitView()
        case .tripCockpit: TripCockpitView()
        case .ticTacToe: TicTacToeView()
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

        }
    }
}

// MARK: - Card container

fileprivate struct CalcDashCard<Content: View>: View {
    let theme: any AppThemeSpec
    let uiStyle: CalcDashUIStyle
    let shadow: CalcDashShadowLevel
    let content: Content

    @Environment(\.colorScheme) private var scheme

    init(
        theme: any AppThemeSpec,
        uiStyle: CalcDashUIStyle,
        shadow: CalcDashShadowLevel = .normal,
        @ViewBuilder content: () -> Content
    ) {
        self.theme = theme; self.uiStyle = uiStyle
        self.shadow = shadow; self.content = content()
    }

    private var backgroundStyle: AnyShapeStyle {
        switch uiStyle {
        case .classic: return AnyShapeStyle(theme.cardBackground)
        case .glass:   return AnyShapeStyle(.thinMaterial)
        }
    }
    private var shadowOpacity: Double { scheme == .dark ? 0.10 : 0.14 }
    private var shadowRadius: CGFloat {
        switch shadow {
        case .none:   return 0
        case .soft:   return max(1, theme.elevation * 0.55)
        case .normal: return theme.elevation
        }
    }

    var body: some View {
        content
            .padding(theme.spacing)
            .background(backgroundStyle, in: RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                .strokeBorder(theme.separator.opacity(0.85), lineWidth: 1))
            .shadow(color: Color.black.opacity(shadowOpacity),
                    radius: shadowRadius, x: 0, y: shadowRadius == 0 ? 0 : 2)
    }
}

fileprivate struct CalcDashPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Tile (Equatable)

fileprivate struct CalcDashTile: View, Equatable {
    let theme: any AppThemeSpec
    let uiStyle: CalcDashUIStyle
    let kind: CalculatorKind
    let isSearching: Bool
    let tokens: [String]
    let accent: Color

    @EnvironmentObject private var appearance: AppAppearance
    @Environment(\.colorScheme) private var scheme

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.kind == rhs.kind &&
        lhs.isSearching == rhs.isSearching &&
        lhs.tokens == rhs.tokens &&
        lhs.uiStyle == rhs.uiStyle
    }

    var body: some View {
        CalcDashCard(theme: theme, uiStyle: .classic, shadow: .soft) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle().fill(appearance.accentColor.opacity(scheme == .dark ? 0.82 : 0.90))
                        Image(systemName: kind.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(theme.onAccent)
                    }
                    .frame(width: 40, height: 40)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }

                if isSearching {
                    Text(CalcDashHighlighted(kind.title, tokens: tokens, accent: accent))
                        .font(.headline).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    Text(CalcDashHighlighted(kind.subtitle, tokens: tokens, accent: accent))
                        .font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                } else {
                    Text(kind.title)
                        .font(.headline).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    Text(kind.subtitle)
                        .font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(kind.title)
    }
}

// MARK: - Section (Equatable)

fileprivate struct CalcDashSectionView: View, Equatable {
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

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title &&
        lhs.items == rhs.items &&
        lhs.isSearching == rhs.isSearching &&
        lhs.tokens == rhs.tokens &&
        lhs.uiStyle == rhs.uiStyle
    }

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
                ForEach(items, id: \.self) { kind in
                    Button { open(kind) } label: {
                        CalcDashTile(
                            theme: theme, uiStyle: uiStyle, kind: kind,
                            isSearching: isSearching, tokens: tokens, accent: accent
                        )
                        .equatable()
                    }
                    .buttonStyle(CalcDashPressStyle())
                    .contentShape(Rectangle())
                    .accessibilityHint("Opens \(kind.title)")
                }
            }
        }
    }
}

// MARK: - Search summary card

fileprivate struct CalcDashSearchSummaryCard: View {
    let theme: any AppThemeSpec
    let uiStyle: CalcDashUIStyle
    let accent: Color
    let query: String
    let count: Int
    let onClear: () -> Void

    var body: some View {
        CalcDashCard(theme: theme, uiStyle: uiStyle, shadow: .normal) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(accent.opacity(0.18))
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(accent)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Search results").font(.headline)
                    Text("\"\(query)\" \u{00B7} \(count) match\(count == 1 ? "" : "es")")
                        .font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Button(action: onClear) {
                    Label("Clear", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly).foregroundStyle(.secondary)
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
        CalcDashCard(theme: theme, uiStyle: uiStyle, shadow: .normal) {
            HStack(spacing: 12) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("No matches").font(.headline)
                    Text("Try fewer words or terms like \"vin\", \"rate\", \"budget\", \"lemon\", \"repair\", \"receipt\", \"supercharger\", \"live price\", \"alerts\", \"etiquette\", \"epc\", \"parts\".")
                        .font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Top Results (Equatable)

fileprivate struct CalcDashTopResultsSection: View, Equatable {
    let theme: any AppThemeSpec
    let uiStyle: CalcDashUIStyle
    let columns: [GridItem]
    let tokens: [String]
    let accent: Color
    let items: [CalculatorKind]
    let open: (CalculatorKind) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.items == rhs.items &&
        lhs.tokens == rhs.tokens &&
        lhs.uiStyle == rhs.uiStyle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing) {
            HStack { Text("Top results").font(.title3.weight(.semibold)); Spacer() }
            LazyVGrid(columns: columns, spacing: theme.spacing) {
                ForEach(items, id: \.self) { kind in
                    Button { open(kind) } label: {
                        CalcDashTile(
                            theme: theme, uiStyle: uiStyle, kind: kind,
                            isSearching: true, tokens: tokens, accent: accent
                        )
                        .equatable()
                    }
                    .buttonStyle(CalcDashPressStyle())
                }
            }
        }
    }
}

// MARK: - Cheapest charging hero

@MainActor
fileprivate struct CalcDashCheapestInfoView: View {
    let theme: any AppThemeSpec
    let uiStyle: CalcDashUIStyle
    let open: (CalculatorKind) -> Void

    @StateObject private var viewModel = SuperchargerPredictionViewModel(horizonHours: 24)

    var body: some View {
        CalcDashCard(theme: theme, uiStyle: uiStyle, shadow: .normal) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Cheapest Time to Charge", systemImage: "bolt.circle").font(.headline)
                    Spacer()
                    Text("Beta")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule(style: .continuous).fill(theme.pillTint.opacity(0.28)))
                }

                if viewModel.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Analyzing the next 24 hours...").font(.footnote).foregroundStyle(.secondary)
                    }
                } else if let error = viewModel.errorMessage {
                    Text("Prediction unavailable: \(error)").font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                } else if viewModel.hasPrediction {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.bestWindowText).font(.title3.weight(.semibold))
                        Text("Best price: \(viewModel.bestPriceText)").font(.footnote).foregroundStyle(.secondary)
                        Text("Typical: \(viewModel.medianPriceText) / Range: \(viewModel.spreadText)").font(.footnote).foregroundStyle(.secondary)
                        Text("Confidence: \(viewModel.confidenceText)").font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Open the finder to compute the lowest-cost fast-charging window.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Button { open(.cheapestChargerShift) } label: {
                    HStack(spacing: 8) {
                        Text("Open Cheapest Charger Finder")
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(theme.pillTint.opacity(0.30), in: Capsule(style: .continuous))
                }
                .buttonStyle(CalcDashPressStyle())
                .padding(.top, 4)
            }
        }
        .onAppear {
            if !viewModel.hasPrediction && !viewModel.isLoading { viewModel.refreshDefaultStation() }
        }
    }
}

// MARK: - Everyday tools

fileprivate let calcDashConsolidatedKinds: Set<CalculatorKind> = [
    .carsVsEVCalculator, .costPerMileAndCO2, .costPerMileVsGas, .weeklyEVVsGasCost
]

fileprivate let calcDashVisibleKinds: [CalculatorKind] = CalculatorKind.allCases.filter {
    !calcDashConsolidatedKinds.contains($0)
}

fileprivate let calcDashEverydayKinds: [CalculatorKind] = [
    .cheapestChargerShift, .superchargerLivePricePredictor, .evVsCarComparison,
    .chargingEtiquette, .maintenanceGuides, .winterDrivingTechniques, .superchargeInfoNearMe,
    .teslaServiceAlerts, .teslaEPCPartsCatalog, .rightToRepair, .lemonLawGuide,
    .deliveryTracker, .deliveryChecklist,
    .forecastDashboard, .gridEmissionsForecast, .chartsBudget, .gasToKWhConverter,
    .evChargingVsGasTime, .unitConversion, .tripPlanner, .tripLogger
]

fileprivate struct CalcDashEverydayToolsSection: View {
    let theme: any AppThemeSpec
    let uiStyle: CalcDashUIStyle
    let columns: [GridItem]
    let open: (CalculatorKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing) {
            HStack { Text("Everyday tools").font(.title2.weight(.semibold)); Spacer() }
            LazyVGrid(columns: columns, spacing: theme.spacing) {
                ForEach(calcDashEverydayKinds, id: \.self) { kind in
                    Button { open(kind) } label: {
                        CalcDashTile(
                            theme: theme, uiStyle: uiStyle, kind: kind,
                            isSearching: false, tokens: [], accent: .clear
                        )
                        .equatable()
                    }
                    .buttonStyle(CalcDashPressStyle())
                }
            }
        }
    }
}

fileprivate struct CalcDashAgentCopilotCard: View {
    let theme: any AppThemeSpec
    let uiStyle: CalcDashUIStyle
    let open: () -> Void

    var body: some View {
        CalcDashCard(theme: theme, uiStyle: uiStyle, shadow: .normal) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("AI Copilot", systemImage: "sparkles").font(.headline)
                    Spacer()
                    Text("V1")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule(style: .continuous).fill(theme.pillTint.opacity(0.28)))
                }
                Text("Ask for summaries, spike detection, charging window suggestions, and draft expense actions.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button { open() } label: {
                    HStack(spacing: 8) {
                        Text("Open AI Copilot")
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(theme.pillTint.opacity(0.30), in: Capsule(style: .continuous))
                }
                .buttonStyle(CalcDashPressStyle())
                .padding(.top, 2)
            }
        }
    }
}

// MARK: - Fallback hosts

@MainActor
fileprivate struct CalcDashSparkPanelHost: View {
    @StateObject private var store = SparkShiftStore()
    var body: some View { SparkPanel(shiftStore: store) }
}

@MainActor
fileprivate struct CalcDashBusinessDeductionReportDestination: View {
    @EnvironmentObject private var entriesStore: EntriesStore

    // PERF: `dateOf` / `amountOf` used to resolve their values through
    // `Mirror(reflecting:)`, walking every stored property of `ExpenseEntry`
    // and lowercasing each label. `BusinessDeductionReportView.filteredSorted`
    // calls `dateOf` twice per *sort comparison*, so a report over N entries
    // performed O(N log N) reflections — ~44,000 Mirror walks for 2,000
    // entries, each allocating ~25 lowercased strings. And `filteredSorted` is
    // a computed property re-evaluated by the total, the eligible total and the
    // list section on every body pass. That is a hard freeze on open and on
    // every filter/sort toggle.
    //
    // `ExpenseEntry` has concrete `date` and `amount` properties — the same
    // ones the rest of the app reads — so these are direct accesses now.
    // (Same class of bug as FIX 2 in GasToKWhConverterView.swift.)
    var body: some View {
        BusinessDeductionReportView(
            items: entriesStore.entries,
            dateOf: { $0.date },
            amountOf: { $0.amount }
        )
        .navigationTitle("Business Report")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
fileprivate struct CalcDashGasToKWhConverterHost: View {
    @EnvironmentObject private var entriesStore: EntriesStore

    var body: some View {
        GasToKWhConverterView(expensesProvider: { entriesStore.entries })
            .navigationTitle("Gas to kWh Converter")
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
