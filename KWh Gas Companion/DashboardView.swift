//
//  DashboardView.swift
//  My KWh Companion
//
//  Swift 6 · iOS 17+
//
//  Revision history
//  ─────────────────────────────────────────────────────────────
//  • Tesla-inspired redesign: hero card, SOC ring, alert banner,
//    stat tiles, quick-action grid, section labels.
//  • Performance: snapshots promoted to @State, recomputed only
//    on explicit recomputeSnapshots() calls (not every render).
//  • Formatters: static cached NumberFormatter / DateFormatter.
//  • CardPolish: scrollTransition gated behind .full motion pref.
//

import SwiftUI
import Foundation

// MARK: - DashboardView

@MainActor
struct DashboardView: View {

    // MARK: Environment

    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore
    @EnvironmentObject private var profileStore: ProfileStore
    @StateObject  private var teslaFiUnlock = TeslaFiEntitlementStore.shared
    @EnvironmentObject private var appearance: AppAppearance
    @EnvironmentObject private var uiSettings: AppUISettings

    @Environment(\.appThemeBox)        private var themeBox
    @Environment(\.brandTheme)         private var brandTheme
    @Environment(\.colorScheme)        private var scheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize)    private var dynamicTypeSize

    private var theme: any AppThemeSpec { themeBox.base }

    // MARK: Persistent storage

    @AppStorage("defaultCurrencyCode")       private var defaultCurrencyCode =
        Locale.current.currency?.identifier ?? "USD"
    @AppStorage("uiStyle")                   private var uiStyleRaw = "teslaGlass"
    @AppStorage("budget_useCategoryBudgets") private var useCategoryBudgets = true
    @AppStorage("monthlyBudgetLimit")        private var monthlyBudgetLimit: Double = 0
    @AppStorage("budget_supercharging")      private var budgetSupercharging: Double = 0
    @AppStorage("budget_lease")              private var budgetLease: Double = 0
    @AppStorage("budget_insurance")          private var budgetInsurance: Double = 0
    @AppStorage("budget_misc")              private var budgetMisc: Double = 0

    // Shared with GasToKWhConverterView so the dashboard card reflects the
    // user's last-entered gas price / MPG.
    @AppStorage("gasToKwh.lastGasPrice")     private var persistedGasPrice: Double = 0
    @AppStorage("gasToKwh.lastMPG")          private var persistedMPG: Double = 30

    // MARK: UI state

    @State private var showingBudgetEditor = false
    @State private var showingLayoutEditor = false
    @State private var showAllActions      = false

    @StateObject private var layout       = DashboardLayoutStore()
    @StateObject private var watchlistStore = PriceWatchlistStore()
    @StateObject private var adsStore     = AdsEntitlementStore.shared

    // MARK: Cached snapshots
    //
    // All expensive derivations live here and are refreshed only
    // via recomputeSnapshots(), never on every SwiftUI render pass.

    @State private var cachedSnapshot    = DashboardSnapshot.empty
    @State private var cachedActionItems: [ActionItem] = []

    // Convenience accessors – zero-cost computed vars over the snapshot.
    private var snapshot: DashboardSnapshot { cachedSnapshot }

    private var cachedEntriesThisMonth:       [ExpenseEntry]  { snapshot.entriesThisMonth }
    private var cachedTeslaFiThisMonth:       [TeslaFiSession] { snapshot.importedSessionsThisMonth }
    private var cachedSpending:               DashboardSpending { snapshot.spending }
    private var cachedMonthEnergyKWh:         Double           { snapshot.monthEnergyKWh }
    private var cachedAvgCostPerKWh:          Double?          { snapshot.averageCostPerKWh }
    private var cachedMissingCostTeslaFiCount: Int             { snapshot.missingImportedCostCount }
    private var cachedMissingCostEntryCount:  Int             { snapshot.missingEntryCostCount }
    private var cachedDataQualityIssueCount:  Int             { snapshot.dataQualityIssueCount }
    private var cachedTrackedEnergyMonths:    Int             { snapshot.trackedEnergyMonths }
    private var cachedLatestCharge:           DashboardLatestChargeSnapshot? { snapshot.latestCharge }
    private var cachedTripInsights:           TripInsightsSnapshot { snapshot.tripInsights }
    private var cachedPrevMonthSpent:         Double           { snapshot.previousMonthSpentTotal }
    private var cachedPrevMonthEnergyKWh:     Double           { snapshot.previousMonthEnergyKWh }
    private var cachedMonthEnergyCost:        Double           { snapshot.monthEnergyCost }

    // MARK: Theme helpers

    private var isGlass: Bool {
        let v = uiStyleRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return v == "teslaglass" || v == "glass"
    }

    private var cardSurface: AnyShapeStyle {
        isGlass
            ? AnyShapeStyle(.thinMaterial)
            : AnyShapeStyle(theme.cardBackground)
    }

    /// True-black / true-white surface used by the vehicle hero card.
    private var teslaDarkSurface: AnyShapeStyle {
        scheme == .dark
            ? AnyShapeStyle(Color(hex: "#111111"))
            : AnyShapeStyle(Color(hex: "#FFFFFF"))
    }

    private var dashboardCardStyle: DashboardCardStyle {
        DashboardCardStyle(
            surface:   cardSurface,
            spacing:   theme.spacing,
            corner:    theme.corner,
            pillTint:  theme.pillTint,
            separator: theme.separator,
            accent:    appearance.accentColor
        )
    }

    // MARK: Formatters  (static – rebuilt only when currency changes)

    private static func makeCurrencyFormatter(_ code: String) -> NumberFormatter {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = code
        nf.maximumFractionDigits = 2
        return nf
    }

    private static var _lastCurrencyCode = ""
    private static var _currencyFormatter = makeCurrencyFormatter("USD")

    private func currencyFormatter() -> NumberFormatter {
        guard Self._lastCurrencyCode != defaultCurrencyCode else {
            return Self._currencyFormatter
        }
        Self._lastCurrencyCode = defaultCurrencyCode
        Self._currencyFormatter = Self.makeCurrencyFormatter(defaultCurrencyCode)
        return Self._currencyFormatter
    }

    private static let decimalFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 1
        nf.minimumFractionDigits = 0
        return nf
    }()

    // MARK: - body

    var body: some View {
        GeometryReader { proxy in
            let spec = dashboardLayoutSpec(for: proxy.size.width)

            ScrollView {
                VStack(spacing: 10) {
                    // 1 · Vehicle hero – always first, full-width.
                    vehicleHeroCard
                        .modifier(CardPolish())
                        .padding(.horizontal, spec.horizontalPadding)

                    // 2 · Alert banner – shown only when actionable issues exist.
                    if totalAlertCount > 0 {
                        alertBannerCard
                            .modifier(CardPolish())
                            .padding(.horizontal, spec.horizontalPadding)
                    }

                    if hasAnyData {
                        // 3 · Month-at-a-glance stat tiles.
                        sectionLabel("This month")
                            .padding(.horizontal, spec.horizontalPadding)
                        monthStatTiles
                            .padding(.horizontal, spec.horizontalPadding)

                        // 4 · User-ordered card grid.
                        LazyVGrid(columns: spec.columns, spacing: 10) {
                            ForEach(layout.visibleOrder, id: \.self) { kind in
                                let cardSpec = cardSpec(for: kind)
                                cardSpec.view
                                    .modifier(CardPolish())
                                    .gridCellColumns(cardSpec.columns)
                            }
                        }
                        .padding(.horizontal, spec.horizontalPadding)
                        .frame(maxWidth: spec.maxWidth)
                        .frame(maxWidth: .infinity)
                    } else {
                        // 3′ · First-run onboarding replaces the empty grid.
                        onboardingCard
                            .modifier(CardPolish())
                            .padding(.horizontal, spec.horizontalPadding)
                    }

                    // 5 · Quick-action grid – always visible at the bottom.
                    sectionLabel("Quick actions")
                        .padding(.horizontal, spec.horizontalPadding)
                    quickActionGrid
                        .padding(.horizontal, spec.horizontalPadding)

                    if !adsStore.hasRemovedAds {
                        AdBannerCard(adsStore: adsStore)
                            .modifier(CardPolish())
                            .padding(.horizontal, spec.horizontalPadding)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .contentMargins(.top, 6, for: .scrollContent)
        .scrollIndicators(.hidden)
        .refreshable { recomputeSnapshots() }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .background(dashboardBackground)
        .tint(appearance.accentColor)
        .sheet(isPresented: $showingBudgetEditor) { budgetSheet }
        .sheet(isPresented: $showingLayoutEditor) {
            DashboardLayoutEditorView(layout: layout)
        }
        .onAppear(perform: handleAppear)
        .onChange(of: entriesStore.entries.count)       { _, _ in recomputeSnapshots() }
        .onChange(of: teslaFiStore.sessionCount)        { _, _ in recomputeSnapshots() }
        .onChange(of: teslaFiUnlock.hasTeslaFiUnlock)   { _, _ in recomputeSnapshots() }
        .onChange(of: profileStore.selectedVehicleID)   { _, _ in recomputeSnapshots() }
        .task {
            await adsStore.load()
            await teslaFiUnlock.load()
            recomputeSnapshots()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingLayoutEditor = true } label: {
                    Label("Customize", systemImage: "slider.horizontal.3")
                }
            }
        }
    }

    // MARK: Lifecycle

    private func handleAppear() {
        let hasAnyCategoryBudget =
            (budgetSupercharging + budgetLease + budgetInsurance + budgetMisc) > 0
        if hasAnyCategoryBudget {
            useCategoryBudgets = true
        }
        recomputeSnapshots()
    }

    private func recomputeSnapshots() {
        cachedSnapshot = DashboardSnapshotCalculator.make(
            entries: entriesStore.entries,
            energyEntries: entriesStore.energyEntries(),
            importedSessions: teslaFiStore.sessions,
            selectedVehicle: profileStore.selectedVehicle,
            includeImportedSessions: teslaFiUnlock.hasTeslaFiUnlock
        )
        cachedActionItems = buildActionItems()

        if showAllActions && cachedActionItems.count <= 4 {
            showAllActions = false
        }
    }

    // MARK: Derived values

    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    private var totalAlertCount: Int {
        cachedMissingCostTeslaFiCount
            + cachedMissingCostEntryCount
            + cachedDataQualityIssueCount
    }

    /// True once the user has any logged entry or imported session. Drives the
    /// first-run onboarding card versus the full dashboard.
    private var hasAnyData: Bool {
        !entriesStore.entries.isEmpty || !teslaFiStore.sessions.isEmpty
    }

    // MARK: Budget helpers

    private var totalCategoryBudget: Double {
        max(0, budgetSupercharging)
            + max(0, budgetLease)
            + max(0, budgetInsurance)
            + max(0, budgetMisc)
    }

    private var effectiveBudgetTotal: Double {
        useCategoryBudgets ? totalCategoryBudget : max(0, monthlyBudgetLimit)
    }

    private var effectiveSpentTotal: Double { cachedSpending.totalBuckets }

    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
    }

    private var daysElapsed: Int {
        max(1, Calendar.current.component(.day, from: Date()))
    }

    private var daysRemaining: Int { max(0, daysInMonth - daysElapsed) }

    private var projectedMonthlySpend: Double? {
        guard effectiveSpentTotal > 0 else { return nil }
        return (effectiveSpentTotal / Double(daysElapsed)) * Double(daysInMonth)
    }

    // MARK: - Layout spec

    private struct DashboardLayoutSpec {
        let columns: [GridItem]
        let horizontalPadding: CGFloat
        let maxWidth: CGFloat
    }

    private func dashboardLayoutSpec(for width: CGFloat) -> DashboardLayoutSpec {
        let minCardWidth: CGFloat = isAccessibilitySize ? 300 : 280
        let basePadding: CGFloat  = horizontalSizeClass == .regular ? 24 : 16
        let contentWidth          = max(0, width - basePadding * 2)
        let possibleColumns       = max(1, Int((contentWidth + theme.spacing) / (minCardWidth + theme.spacing)))
        let columnCount           = min(possibleColumns, horizontalSizeClass == .regular ? 3 : 1)

        let columns = Array(
            repeating: GridItem(
                .flexible(minimum: minCardWidth, maximum: 560),
                spacing: 10,
                alignment: .top
            ),
            count: columnCount
        )

        return DashboardLayoutSpec(
            columns: columns,
            horizontalPadding: basePadding,
            maxWidth: columnCount > 1 ? 1100 : .infinity
        )
    }

    // MARK: - CardPolish modifier

    private struct CardPolish: ViewModifier {
        @EnvironmentObject private var uiSettings: AppUISettings

        func body(content: Content) -> some View {
            switch uiSettings.motion {
            case .none:
                content

            case .reduced:
                content.transition(.opacity)

            case .full:
                content
                    .scrollTransition(.animated) { view, phase in
                        view
                            .opacity(phase.isIdentity ? 1 : 0.72)
                            .scaleEffect(phase.isIdentity ? 1 : 0.985)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    // MARK: - Background

    private var dashboardBackground: some View {
        DashboardBackground(
            screenBackground: AnyShapeStyle(theme.screenBackground),
            accent: appearance.accentColor,
            themeAccent: theme.accent,
            showGradients: uiSettings.motion == .full,
            scheme: scheme
        )
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }

    // MARK: - Collapse button

    private func collapseButton(for kind: DashboardCardKind) -> some View {
        let isCollapsed = layout.isCollapsed(kind)
        return Button { layout.toggleCollapsed(kind) } label: {
            Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                .font(.footnote.weight(.semibold))
                .padding(6)
                .background(Capsule().fill(theme.pillTint.opacity(0.6)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCollapsed ? "Expand section" : "Collapse section")
    }

    // MARK: - Vehicle hero card

    private var vehicleHeroCard: some View {
        let vehicle     = profileStore.selectedVehicle
        let latestCharge = cachedLatestCharge

        return VStack(spacing: 0) {
            heroHeader(vehicle: vehicle, latestCharge: latestCharge)
                .padding(.bottom, layout.isCollapsed(.greeting) ? 0 : 6)

            if !layout.isCollapsed(.greeting) {
                heroVehicleImage(vehicle: vehicle)
                    .padding(.top, 6)
                    .padding(.bottom, 16)

                heroSocRow(vehicle: vehicle, latestCharge: latestCharge)
                    .padding(.bottom, 20)

                // Tesla-app signature: row of round controls beneath the car.
                teslaControlBar
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing)
        .background(heroSurfaceBackground)
    }

    /// Dark mode (default Tesla look): the car floats directly on the black
    /// canvas with no card chrome. Light mode: a clean flat card.
    @ViewBuilder
    private var heroSurfaceBackground: some View {
        if scheme == .dark {
            Color.clear
        } else {
            RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                        .strokeBorder(theme.separator.opacity(0.55), lineWidth: 0.75)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        }
    }

    // MARK: - Tesla control bar

    private var teslaControlBar: some View {
        HStack(alignment: .top, spacing: 4) {
            controlButton("Charge",   "bolt.fill")                 { ChargingSchedulePlannerView() }
            controlButton("Forecast", "chart.line.uptrend.xyaxis") { WeeklyChargingForecastView() }
            controlButton("Locate",   "location.fill")             { NearMeView() }
            controlButton("Garage",   "car.2.fill")                { VehicleProfileListView() }
            controlButton("Import",   "square.and.arrow.down")     { ChargingImportHubView() }
        }
    }

    private func controlButton<Destination: View>(
        _ title: String,
        _ systemImage: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            TeslaControlButtonLabel(systemImage: systemImage, title: title)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens \(title)")
    }

    private func heroHeader(
        vehicle: VehicleProfile?,
        latestCharge: DashboardLatestChargeSnapshot?
    ) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(vehicle?.displayName ?? "My EV Companion")
                    .font(.title2.weight(.semibold))

                Text(vehicle == nil
                     ? "Add a vehicle to get started"
                     : heroSubtitle(latestCharge: latestCharge))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            vehicleStatusBadge(latestCharge: latestCharge)
            collapseButton(for: .greeting)
        }
    }

    private func heroVehicleImage(vehicle: VehicleProfile?) -> some View {
        teslaVehicleImage(selectedVehicle: vehicle)
            .frame(maxWidth: .infinity)
            .frame(height: horizontalSizeClass == .regular ? 170 : 130)
    }

    private func heroSocRow(
        vehicle: VehicleProfile?,
        latestCharge: DashboardLatestChargeSnapshot?
    ) -> some View {
        HStack(alignment: .center, spacing: 20) {
            socRing(latestCharge: latestCharge)
            heroRangeInfo(vehicle: vehicle, latestCharge: latestCharge)
            Spacer()
        }
    }

    @ViewBuilder
    private func heroRangeInfo(
        vehicle: VehicleProfile?,
        latestCharge: DashboardLatestChargeSnapshot?
    ) -> some View {
        if let soc = latestCharge?.endSOC, soc > 0 {
            let range = estimatedAvailableRangeMiles(vehicle: vehicle, soc: soc)
            VStack(alignment: .leading, spacing: 6) {
                Text(range.map { "\($0) mi" } ?? "—")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("Estimated range")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if latestCharge?.isFastCharge == true {
                    Label("Fast charging", systemImage: "bolt.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.green)
                }
            }
        } else if let cost = latestCharge?.cost {
            VStack(alignment: .leading, spacing: 6) {
                Text(formatCurrency(cost, currency: defaultCurrencyCode))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("Last session cost")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("No data")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("Import or log a session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func heroSubtitle(latestCharge: DashboardLatestChargeSnapshot?) -> String {
        guard let charge = latestCharge else { return "No recent sessions" }
        let hours = Calendar.current.dateComponents([.hour], from: charge.date, to: Date()).hour ?? 0
        switch hours {
        case ..<1:   return "Just charged"
        case ..<24:  return "Last charged \(hours)h ago"
        default:     return "Last charged \(hours / 24)d ago"
        }
    }

    private func vehicleStatusBadge(latestCharge: DashboardLatestChargeSnapshot?) -> some View {
        let (label, color): (String, Color) = {
            guard let charge = latestCharge else {
                return profileStore.selectedVehicle != nil
                    ? ("Needs setup", .orange)
                    : ("Add vehicle", .secondary)
            }
            let hours = Calendar.current.dateComponents([.hour], from: charge.date, to: Date()).hour ?? 0
            if charge.isFastCharge && hours < 2 { return ("Charging", .green) }
            if hours < 72                        { return ("Active",   appearance.accentColor) }
            return ("Idle", .orange)
        }()

        return Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(scheme == .dark ? 0.20 : 0.13)))
            .foregroundStyle(color)
    }

    private func socRing(latestCharge: DashboardLatestChargeSnapshot?) -> some View {
        let soc      = latestCharge?.endSOC ?? 0
        let progress = min(max(soc / 100, 0), 1)
        let ringColor: Color = {
            if soc > 50 { return .green }
            if soc > 20 { return .orange }
            return .red
        }()

        return ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
            VStack(spacing: 0) {
                Text(soc > 0 ? "\(Int(soc.rounded()))%" : "—")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(soc > 0 ? "LAST SOC" : "SOC")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.4)
            }
        }
        .frame(width: 80, height: 80)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            soc > 0
                ? "\(Int(soc.rounded())) percent state of charge at last session"
                : "No state of charge data"
        )
    }

    // MARK: - Alert banner

    private var alertBannerCard: some View {
        let summary = alertSummaryParts.joined(separator: " · ")

        return NavigationLink(destination: DataQualityCenterView()) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.red)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Action needed")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.red)
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(Color.red.opacity(0.75))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.red.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(alertBannerBackground)
        }
        .buttonStyle(.plain)
    }

    private var alertSummaryParts: [String] {
        var parts: [String] = []
        if cachedMissingCostTeslaFiCount > 0 {
            let n = cachedMissingCostTeslaFiCount
            parts.append("\(n) imported session\(n == 1 ? "" : "s") missing cost")
        }
        if cachedMissingCostEntryCount > 0 {
            let n = cachedMissingCostEntryCount
            parts.append("\(n) entr\(n == 1 ? "y" : "ies") missing cost")
        }
        if cachedDataQualityIssueCount > 0 {
            let n = cachedDataQualityIssueCount
            parts.append("\(n) data quality issue\(n == 1 ? "" : "s")")
        }
        return parts
    }

    private var alertBannerBackground: some View {
        RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
            .fill(Color.red.opacity(scheme == .dark ? 0.10 : 0.06))
            .overlay(
                RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                    .strokeBorder(Color.red.opacity(0.25), lineWidth: 0.5)
            )
    }

    // MARK: - Month-over-month trends

    /// Neutral (gray) energy delta vs the previous calendar month.
    private var energyMoMTrend: TrendInfo? {
        guard cachedPrevMonthEnergyKWh > 0, cachedMonthEnergyKWh > 0 else { return nil }
        let delta = cachedMonthEnergyKWh - cachedPrevMonthEnergyKWh
        let pct   = delta / cachedPrevMonthEnergyKWh * 100
        guard abs(pct) >= 1 else {
            return TrendInfo(text: "About the same as last month", color: .gray, icon: "equal")
        }
        let up = delta >= 0
        return TrendInfo(
            text:  "\(up ? "+" : "")\(formatNumber(pct, digits: 0))% vs last month",
            color: .gray,
            icon:  up ? "arrow.up.right" : "arrow.down.right"
        )
    }

    /// Spend delta vs the previous month — up is bad (red), down is good (green).
    /// Shown on the Total-spent tile only when no budget context is available.
    private var spentMoMTrend: TrendInfo? {
        guard cachedPrevMonthSpent > 0, effectiveSpentTotal > 0 else { return nil }
        let delta = effectiveSpentTotal - cachedPrevMonthSpent
        let pct   = delta / cachedPrevMonthSpent * 100
        let up    = delta >= 0
        return TrendInfo(
            text:  "\(up ? "+" : "")\(formatNumber(pct, digits: 0))% vs last month",
            color: up ? .red : .green,
            icon:  up ? "arrow.up.right" : "arrow.down.right"
        )
    }

    // MARK: - Month stat tiles

    private var monthStatTiles: some View {
        let budget    = effectiveBudgetTotal
        let spent     = effectiveSpentTotal
        let remaining = budget > 0 ? budget - spent : nil as Double?

        return LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 130), spacing: 8),
                GridItem(.flexible(minimum: 130), spacing: 8)
            ],
            spacing: 8
        ) {
            statTileLink(destination: expenseLogView) {
                statTile(
                    label: "Total spent",
                    value: formatCurrency(spent, currency: defaultCurrencyCode),
                    sub:   budget > 0
                        ? "of \(formatCurrency(budget, currency: defaultCurrencyCode)) budget"
                        : "No budget set",
                    trend: remaining.map { r in
                        r >= 0
                            ? TrendInfo(
                                text:  "\(formatCurrency(r, currency: defaultCurrencyCode)) left",
                                color: .green,
                                icon:  "checkmark.circle.fill")
                            : TrendInfo(
                                text:  "Over by \(formatCurrency(abs(r), currency: defaultCurrencyCode))",
                                color: .red,
                                icon:  "exclamationmark.circle.fill")
                    } ?? spentMoMTrend
                )
            }

            statTileLink(destination: HomeVsPublicSplitView()) {
                statTile(
                    label: "Supercharging",
                    value: formatCurrency(cachedSpending.superchargingTotal, currency: defaultCurrencyCode),
                    sub:   budgetSupercharging > 0
                        ? "of \(formatCurrency(budgetSupercharging, currency: defaultCurrencyCode)) budget"
                        : "\(cachedEntriesThisMonth.count) entries",
                    trend: nil
                )
            }

            statTileLink(destination: WeeklyChargingForecastView()) {
                statTile(
                    label: "Energy charged",
                    value: cachedMonthEnergyKWh > 0
                        ? "\(formatNumber(cachedMonthEnergyKWh, digits: 1)) kWh"
                        : "—",
                    sub: cachedAvgCostPerKWh
                        .map { "avg \(formatCurrency($0, currency: defaultCurrencyCode))/kWh" }
                        ?? "No cost data",
                    trend: energyMoMTrend
                )
            }

            statTileLink(
                destination: ForecastDashboardView(months: min(max(cachedTrackedEnergyMonths, 3), 12))
            ) {
                statTile(
                    label: "Tracked months",
                    value: "\(cachedTrackedEnergyMonths)",
                    sub: cachedTrackedEnergyMonths >= 3
                        ? "Forecast ready"
                        : "\(max(0, 3 - cachedTrackedEnergyMonths)) more to forecast",
                    trend: cachedTrackedEnergyMonths >= 3
                        ? TrendInfo(
                            text:  "Forecast ready",
                            color: .green,
                            icon:  "chart.line.uptrend.xyaxis")
                        : nil
                )
            }
        }
    }

    /// Wraps a stat tile in a navigation link while keeping the tile's flat
    /// appearance (no chevron, no button chrome).
    private func statTileLink<Destination: View, Label: View>(
        destination: Destination,
        @ViewBuilder label: () -> Label
    ) -> some View {
        NavigationLink(destination: destination) {
            label()
        }
        .buttonStyle(.plain)
    }

    private struct TrendInfo {
        let text:  String
        let color: Color
        let icon:  String
    }

    private func statTile(
        label: String,
        value: String,
        sub:   String,
        trend: TrendInfo?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            Text(sub)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let trend {
                Label(trend.text, systemImage: trend.icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(trend.color)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                .fill(cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                .strokeBorder(theme.separator.opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: - Quick-action grid

    private var quickActionGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ],
            spacing: 8
        ) {
            quickActionTile("Garage",   "car.2.fill",                tint: appearance.accentColor) { VehicleProfileListView() }
            quickActionTile("Planner",  "clock.badge.checkmark",     tint: .teal)                  { ChargingSchedulePlannerView() }
            quickActionTile("Import",   "square.and.arrow.down",     tint: .purple)                { ChargingImportHubView() }
            quickActionTile("Forecast", "chart.line.uptrend.xyaxis", tint: .orange)                { WeeklyChargingForecastView() }
        }
    }

    private func quickActionTile<Destination: View>(
        _ title: String,
        _ systemImage: String,
        tint: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(scheme == .dark ? 0.18 : 0.10))
                        .frame(width: 32, height: 32)
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                    .fill(cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                    .strokeBorder(theme.separator.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens \(title)")
    }

    // MARK: - Card dispatch

    private struct DashboardCardSpec {
        let view:    AnyView
        let columns: Int
    }

    private func makeCardSpec<V: View>(_ view: V, columns: Int) -> DashboardCardSpec {
        DashboardCardSpec(view: AnyView(view), columns: columns)
    }

    private func cardSpec(for kind: DashboardCardKind) -> DashboardCardSpec {
        let wideIfRegular = horizontalSizeClass == .regular ? 2 : 1
        switch kind {
        case .greeting:          return makeCardSpec(EmptyView(),            columns: 1) // rendered separately
        case .actionCenter:      return makeCardSpec(actionCenterCard,       columns: 1)
        case .costOfCharging:    return makeCardSpec(costOfChargingCard,     columns: 1)
        case .gasComparison:     return makeCardSpec(gasComparisonCard,      columns: 1)
        case .insights:          return makeCardSpec(insightsCard,           columns: 1)
        case .savingsScore:      return makeCardSpec(savingsScoreCard,       columns: 1)
        case .weeklyForecast:    return makeCardSpec(weeklyForecastCard,     columns: 1)
        case .gridEmissions:     return makeCardSpec(gridEmissionsCard,      columns: 1)
        case .weeklyHealth:      return makeCardSpec(weeklyHealthCard,       columns: 1)
        case .schedulePlanner:   return makeCardSpec(schedulePlannerCard,    columns: 1)
        case .priceWatchlist:    return makeCardSpec(priceWatchlistCard,     columns: 1)
        case .spendingBreakdown: return makeCardSpec(spendingBreakdownCard,  columns: 1)
        case .budget:            return makeCardSpec(budgetCard,             columns: 1)
        case .dataSources:       return makeCardSpec(dataSourcesCard,        columns: 1)
        case .recentActivity:    return makeCardSpec(recentActivityCard,     columns: wideIfRegular)
        }
    }

    // MARK: - DashboardDefaultCards wrappers

    private var spendingBreakdownCard: some View {
        DashboardSpendingBreakdownCard(
            spending:    cachedSpending,
            currencyCode: defaultCurrencyCode,
            style:       dashboardCardStyle,
            isCollapsed: layout.isCollapsed(.spendingBreakdown)
        ) {
            collapseButton(for: .spendingBreakdown)
        }
    }

    private var budgetCard: some View {
        DashboardBudgetCard(
            spending:            cachedSpending,
            currencyCode:        defaultCurrencyCode,
            style:               dashboardCardStyle,
            isCollapsed:         layout.isCollapsed(.budget),
            useCategoryBudgets:  useCategoryBudgets,
            totalBudget:         effectiveBudgetTotal,
            superchargingBudget: budgetSupercharging,
            leaseBudget:         budgetLease,
            insuranceBudget:     budgetInsurance,
            miscBudget:          budgetMisc,
            projectedMonthlySpend: projectedMonthlySpend,
            daysRemaining:       daysRemaining,
            onEdit:              { showingBudgetEditor = true }
        ) {
            collapseButton(for: .budget)
        }
    }

    private var dataSourcesCard: some View {
        DashboardDataSourcesCard(
            entryCount:               cachedEntriesThisMonth.count,
            importedSessionCount:     cachedTeslaFiThisMonth.count,
            missingImportedCostCount: cachedMissingCostTeslaFiCount,
            missingEntryCostCount:    cachedMissingCostEntryCount,
            style:                    dashboardCardStyle,
            isCollapsed:              layout.isCollapsed(.dataSources)
        ) {
            collapseButton(for: .dataSources)
        }
    }

    private var recentActivityCard: some View {
        DashboardRecentActivityCard(
            entries:          cachedEntriesThisMonth,
            importedSessions: cachedTeslaFiThisMonth,
            currencyCode:     defaultCurrencyCode,
            style:            dashboardCardStyle,
            isCollapsed:      layout.isCollapsed(.recentActivity)
        ) {
            collapseButton(for: .recentActivity)
        }
    }

    // MARK: - Onboarding (first run)

    private var onboardingCard: some View {
        themedCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Welcome to My EV Companion", systemImage: "sparkles")
                    .font(.headline)
                Text("Set up your dashboard in a few quick steps — you'll start seeing costs, energy, and forecasts right away.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                actionLink(destination: VehicleProfileListView()) {
                    actionRow(
                        title:      "Add your vehicle",
                        subtitle:   "Personalize range, SOC, and stats",
                        systemImage: "car.2.fill"
                    )
                }
                themedDivider(opacity: 0.16)
                actionLink(destination: ChargingImportHubView()) {
                    actionRow(
                        title:      "Import charging history",
                        subtitle:   "Bring in Tesla or CSV sessions",
                        systemImage: "square.and.arrow.down"
                    )
                }
                themedDivider(opacity: 0.16)
                actionLink(destination: expenseLogView) {
                    actionRow(
                        title:      "Log your first session",
                        subtitle:   "Track energy and cost by hand",
                        systemImage: "plus.circle"
                    )
                }
            }
        }
    }

    // MARK: - Action Center

    private enum ActionItem: Identifiable {
        case fillMissingCosts(Int)
        case reviewEntries(Int)
        case dataQuality(Int)
        case importHistory
        case logFirst
        case savingsScore
        case forecast(Int)
        case planCharging
        case watchlist
        case homeVsPublic
        case tripCost
        case annualCost
        case adjustBudget(String)

        var id: String {
            switch self {
            case .fillMissingCosts(let n): return "fillMissing-\(n)"
            case .reviewEntries(let n):    return "reviewEntries-\(n)"
            case .dataQuality(let n):      return "dataQuality-\(n)"
            case .importHistory:           return "importHistory"
            case .logFirst:                return "logFirst"
            case .savingsScore:            return "savingsScore"
            case .forecast(let m):         return "forecast-\(m)"
            case .planCharging:            return "planCharging"
            case .watchlist:               return "watchlist"
            case .homeVsPublic:            return "homeVsPublic"
            case .tripCost:                return "tripCost"
            case .annualCost:              return "annualCost"
            case .adjustBudget(let s):     return "adjustBudget-\(s)"
            }
        }
    }

    private func buildActionItems() -> [ActionItem] {
        var items: [ActionItem] = []

        if cachedMissingCostTeslaFiCount > 0 {
            items.append(.fillMissingCosts(cachedMissingCostTeslaFiCount))
        }
        if cachedMissingCostEntryCount > 0 {
            items.append(.reviewEntries(cachedMissingCostEntryCount))
        }
        if cachedDataQualityIssueCount > 0 {
            items.append(.dataQuality(cachedDataQualityIssueCount))
        }
        if entriesStore.energyEntries().isEmpty && cachedTeslaFiThisMonth.isEmpty {
            items.append(.importHistory)
        }
        if cachedEntriesThisMonth.isEmpty {
            items.append(.logFirst)
        }
        if cachedTrackedEnergyMonths >= 3 {
            items.append(.forecast(min(max(cachedTrackedEnergyMonths, 3), 12)))
        }
        if cachedTrackedEnergyMonths > 0 {
            items.append(.savingsScore)
        }
        items.append(contentsOf: [.planCharging, .watchlist, .homeVsPublic, .tripCost, .annualCost])
        if effectiveBudgetTotal > 0 && effectiveSpentTotal > effectiveBudgetTotal {
            let overBy = formatCurrency(effectiveSpentTotal - effectiveBudgetTotal, currency: defaultCurrencyCode)
            items.append(.adjustBudget(overBy))
        }
        return items
    }

    private var actionCenterCard: some View {
        themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Action Center", systemImage: "sparkles").font(.headline)
                    Spacer()
                    pill("This month")
                    collapseButton(for: .actionCenter)
                }

                if !layout.isCollapsed(.actionCenter) {
                    if cachedActionItems.isEmpty {
                        Label("All caught up — great data hygiene.", systemImage: "checkmark.seal.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        actionCenterItemList
                    }
                }
            }
        }
    }

    private var actionCenterItemList: some View {
        let displayed = showAllActions
            ? cachedActionItems
            : Array(cachedActionItems.prefix(4))

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(displayed) { item in
                actionItemView(item)
                if item.id != displayed.last?.id {
                    themedDivider(opacity: 0.16)
                }
            }

            if cachedActionItems.count > 4 {
                themedDivider(opacity: 0.16)
                Button(showAllActions
                       ? "Show fewer"
                       : "Show \(cachedActionItems.count - 4) more") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllActions.toggle()
                    }
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
    }

    @ViewBuilder
    private func actionItemView(_ item: ActionItem) -> some View {
        switch item {
        case .fillMissingCosts(let n):
            actionLink(destination: MissingCostAssistantView()) {
                actionRow(
                    title:      "Fill missing session costs",
                    subtitle:   "\(n) session\(n == 1 ? "" : "s") need a cost",
                    systemImage: "dollarsign.circle"
                )
            }

        case .reviewEntries(let n):
            actionLink(destination: expenseLogView) {
                actionRow(
                    title:      "Review entries with no cost",
                    subtitle:   "\(n) entr\(n == 1 ? "y" : "ies") have kWh but no cost",
                    systemImage: "exclamationmark.triangle"
                )
            }

        case .dataQuality(let n):
            actionLink(destination: DataQualityCenterView()) {
                actionRow(
                    title:      "Review data quality",
                    subtitle:   "\(n) potential issue\(n == 1 ? "" : "s") found",
                    systemImage: "shield.lefthalf.filled"
                )
            }

        case .importHistory:
            actionLink(destination: CSVChargingWizardView()) {
                actionRow(
                    title:      "Import charging history",
                    subtitle:   "Bring in Tesla CSV sessions to start",
                    systemImage: "square.and.arrow.down"
                )
            }

        case .logFirst:
            actionLink(destination: expenseLogView) {
                actionRow(
                    title:      "Log your first expense",
                    subtitle:   "Start tracking charging and costs",
                    systemImage: "plus.circle"
                )
            }

        case .savingsScore:
            actionLink(destination: SavingsScoreView()) {
                actionRow(
                    title:      "Review your Savings Score",
                    subtitle:   "See habits that drive cost down",
                    systemImage: "gauge.high"
                )
            }

        case .forecast(let months):
            actionLink(destination: ForecastDashboardView(months: months)) {
                actionRow(
                    title:      "Open forecast dashboard",
                    subtitle:   "\(months)-month trend window ready",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
            }

        case .planCharging:
            actionLink(destination: ChargingSchedulePlannerView()) {
                actionRow(
                    title:      "Plan your charging window",
                    subtitle:   "Set off-peak hours and rates",
                    systemImage: "clock.badge.checkmark"
                )
            }

        case .watchlist:
            actionLink(destination: PriceWatchlistView()) {
                actionRow(
                    title:      "Manage price watchlist",
                    subtitle:   "Track favourite chargers manually",
                    systemImage: "tag"
                )
            }

        case .homeVsPublic:
            actionLink(destination: HomeVsPublicSplitView()) {
                actionRow(
                    title:      "Home vs public split",
                    subtitle:   "See where charging costs come from",
                    systemImage: "chart.bar"
                )
            }

        case .tripCost:
            actionLink(destination: TripCostEstimatorView()) {
                actionRow(
                    title:      "Estimate trip cost",
                    subtitle:   "Distance × efficiency × rate",
                    systemImage: "map"
                )
            }

        case .annualCost:
            actionLink(destination: AnnualCostSimulatorView()) {
                actionRow(
                    title:      "Project annual cost",
                    subtitle:   "Use weekly averages to forecast",
                    systemImage: "calendar"
                )
            }

        case .adjustBudget(let overBy):
            Button { showingBudgetEditor = true } label: {
                actionRow(
                    title:      "Adjust your budget",
                    subtitle:   "You're over by \(overBy)",
                    systemImage: "target"
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// Convenience wrapper so each action case stays one statement.
    private func actionLink<D: View, L: View>(
        destination: D,
        @ViewBuilder label: () -> L
    ) -> some View {
        NavigationLink(destination: destination, label: label)
            .buttonStyle(.plain)
    }

    /// Reusable destination so ExpenseLogView isn't duplicated twice.
    private var expenseLogView: some View {
        ExpenseLogView()
            .navigationTitle("Expense Log")
            .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Content cards

    /// Weekly + monthly charging cost at a glance, with a week-over-week delta
    /// and a link to the full weekly rollup.
    private var costOfChargingCard: some View {
        let weekly = WeeklyCostRollup.compute(
            entries:  entriesStore.energyEntries(),
            sessions: teslaFiStore.sessions
        )
        let wowDelta = weekly.thisWeekCost - weekly.lastWeekCost
        return themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Cost of Charging", systemImage: "creditcard.circle").font(.headline)
                    Spacer()
                    collapseButton(for: .costOfCharging)
                }

                if !layout.isCollapsed(.costOfCharging) {
                    twoStatRow(
                        title1: "This week",
                        value1: formatCurrency(weekly.thisWeekCost, currency: defaultCurrencyCode),
                        title2: "This month",
                        value2: formatCurrency(cachedMonthEnergyCost, currency: defaultCurrencyCode)
                    )
                    twoStatRow(
                        title1: "Week energy",
                        value1: "\(formatNumber(weekly.thisWeekKWh, digits: 1)) kWh",
                        title2: "Month energy",
                        value2: cachedMonthEnergyKWh > 0
                            ? "\(formatNumber(cachedMonthEnergyKWh, digits: 1)) kWh"
                            : "—"
                    )

                    if weekly.lastWeekCost > 0 {
                        let up = wowDelta >= 0
                        Label(
                            "\(up ? "+" : "")\(formatCurrency(wowDelta, currency: defaultCurrencyCode)) vs last week",
                            systemImage: up ? "arrow.up.right" : "arrow.down.right"
                        )
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(up ? .red : .green)
                    }

                    actionLink(destination: WeeklyCostRollupView()) {
                        actionRow(
                            title:      "Weekly cost rollup",
                            subtitle:   "Week-over-week trend and alerts",
                            systemImage: "arrow.right.circle"
                        )
                    }
                }
            }
        }
    }

    /// Compares a gallon of gasoline (as energy) against the user's average
    /// charging $/kWh. Uses the gas price shared with the Gas → kWh converter.
    private var gasComparisonCard: some View {
        let kWhPerGallon = 33.7
        let gasPerKWh: Double? = persistedGasPrice > 0 ? persistedGasPrice / kWhPerGallon : nil
        let evPerKWh = cachedAvgCostPerKWh
        return themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Gas vs Electric", systemImage: "fuelpump").font(.headline)
                    Spacer()
                    collapseButton(for: .gasComparison)
                }

                if !layout.isCollapsed(.gasComparison) {
                    if let gasPerKWh {
                        twoStatRow(
                            title1: "Gas energy",
                            value1: "\(formatCurrency(gasPerKWh, currency: defaultCurrencyCode))/kWh",
                            title2: "Your EV avg",
                            value2: evPerKWh.map { "\(formatCurrency($0, currency: defaultCurrencyCode))/kWh" } ?? "—"
                        )
                        Text("Based on \(formatCurrency(persistedGasPrice, currency: defaultCurrencyCode))/gal ÷ \(formatNumber(kWhPerGallon, digits: 1)) kWh.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if let evPerKWh, evPerKWh > 0, gasPerKWh > 0 {
                            let diff  = gasPerKWh - evPerKWh
                            let pct   = abs(diff / evPerKWh * 100)
                            let evCheaper = diff > 0
                            Label(
                                evCheaper
                                    ? "Charging is \(formatNumber(pct, digits: 0))% cheaper than gas energy"
                                    : "Charging is \(formatNumber(pct, digits: 0))% pricier than gas energy",
                                systemImage: evCheaper ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                            )
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(evCheaper ? .green : .orange)
                        }
                    } else {
                        Text("Add a gas price to compare a gallon of gas against your charging cost per kWh.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    actionLink(destination: DashboardGasToKWhConverterHost()) {
                        actionRow(
                            title:      persistedGasPrice > 0 ? "Open Gas → kWh converter" : "Set your gas price",
                            subtitle:   "Compare a gallon of gas to your $/kWh",
                            systemImage: "arrow.right.circle"
                        )
                    }
                }
            }
        }
    }

    private var insightsCard: some View {
        themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Quick Insights", systemImage: "bolt.circle").font(.headline)
                    Spacer()
                    pill("This month")
                    collapseButton(for: .insights)
                }

                if !layout.isCollapsed(.insights) {
                    HStack(spacing: 10) {
                        spotlightStat(
                            title:  "Energy",
                            value:  cachedMonthEnergyKWh > 0
                                ? "\(formatNumber(cachedMonthEnergyKWh, digits: 1)) kWh"
                                : "—",
                            symbol: "bolt.fill"
                        )
                        spotlightStat(
                            title:  "Avg $/kWh",
                            value:  cachedAvgCostPerKWh
                                .map { formatCurrency($0, currency: defaultCurrencyCode) } ?? "—",
                            symbol: "dollarsign.circle.fill"
                        )
                    }
                    HStack(spacing: 10) {
                        spotlightStat(title: "Entries",  value: "\(cachedEntriesThisMonth.count)",  symbol: "doc.text.fill")
                        spotlightStat(title: "Imported", value: "\(cachedTeslaFiThisMonth.count)",  symbol: "waveform.path.ecg")
                    }
                    if let tripWindow = cachedTripInsights.selectedWindow {
                        themedDivider(opacity: 0.20)
                        HStack(spacing: 10) {
                            spotlightStat(title: "Trips",         value: "\(tripWindow.tripCount) recent", symbol: "road.lanes")
                            spotlightStat(
                                title:  "Avg trip cost",
                                value:  tripWindow.averageKnownCost
                                    .map { formatCurrency($0, currency: defaultCurrencyCode) } ?? "—",
                                symbol: "car.rear.and.tire.marks"
                            )
                        }
                        Text(cachedTripInsights.trendDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        actionLink(destination: TripInsightsView(
                            sessions:     cachedTeslaFiThisMonth,
                            currencyCode: defaultCurrencyCode
                        )) {
                            actionRow(
                                title:      "Open Trip Insights",
                                subtitle:   "Rollups, trends, and price extremes",
                                systemImage: "arrow.right.circle"
                            )
                        }
                    }
                }
            }
        }
    }

    private var savingsScoreCard: some View {
        let score = SavingsScoreSummary.compute(from: entriesStore.energyEntries())
        return themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Savings Score", systemImage: "gauge.high").font(.headline)
                    Spacer()
                    Text("\(score.totalScore)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(appearance.accentColor)
                    collapseButton(for: .savingsScore)
                }

                if !layout.isCollapsed(.savingsScore) {
                    Text(score.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let hint = score.habitNotes.first {
                        themedDivider(opacity: 0.20)
                        Text(hint).font(.footnote).foregroundStyle(.secondary)
                    }
                    actionLink(destination: SavingsScoreView()) {
                        actionRow(
                            title:      "View full breakdown",
                            subtitle:   "See habits and score components",
                            systemImage: "arrow.right.circle"
                        )
                    }
                }
            }
        }
    }

    private var weeklyForecastCard: some View {
        let summary = WeeklyForecastSummary.build(from: entriesStore.energyEntries())
        return themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Weekly Forecast", systemImage: "chart.line.uptrend.xyaxis").font(.headline)
                    Spacer()
                    pill("Next week")
                    collapseButton(for: .weeklyForecast)
                }

                if !layout.isCollapsed(.weeklyForecast) {
                    twoStatRow(
                        title1: "Projected cost",
                        value1: formatCurrency(summary.forecastCost, currency: summary.currencyCode),
                        title2: "Projected kWh",
                        value2: "\(formatNumber(summary.forecastKWh, digits: 1)) kWh"
                    )
                    if let confidence = summary.confidenceText {
                        Text(confidence).font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let model = summary.modelSummary {
                        Text(model).font(.footnote).foregroundStyle(.secondary)
                    }
                    if let reinforcement = summary.reinforcementSummary {
                        Label(reinforcement, systemImage: "scope")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    actionLink(destination: WeeklyChargingForecastView()) {
                        actionRow(
                            title:      "Open forecast",
                            subtitle:   "4-week neural projection",
                            systemImage: "arrow.right.circle"
                        )
                    }
                }
            }
        }
    }

    private var gridEmissionsCard: some View {
        themedCard { GridEmissionDashboardTile() }
    }

    private var weeklyHealthCard: some View {
        let report = WeeklyHealthReport.build(from: entriesStore.energyEntries())
        return themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Weekly Health", systemImage: "doc.text.magnifyingglass").font(.headline)
                    Spacer()
                    pill("Last 7 days")
                    collapseButton(for: .weeklyHealth)
                }

                if !layout.isCollapsed(.weeklyHealth) {
                    if report.totalSessions == 0 {
                        Text("No sessions logged in the last week.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        twoStatRow(
                            title1: "Sessions",
                            value1: "\(report.totalSessions)",
                            title2: "Cost",
                            value2: formatCurrency(report.totalCost, currency: report.currencyCode)
                        )
                        twoStatRow(
                            title1: "Energy",
                            value1: "\(formatNumber(report.totalKWh, digits: 1)) kWh",
                            title2: "Avg $/kWh",
                            value2: report.avgCostPerKWh
                                .map { formatCurrency($0, currency: report.currencyCode) } ?? "—"
                        )
                        if let note = report.highlight {
                            themedDivider(opacity: 0.20)
                            Text(note).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    actionLink(destination: WeeklyHealthReportView()) {
                        actionRow(
                            title:      "Open report",
                            subtitle:   "Best and worst sessions",
                            systemImage: "arrow.right.circle"
                        )
                    }
                }
            }
        }
    }

    private var schedulePlannerCard: some View {
        let window   = SchedulePlannerSummary.windowText()
        let estimate = SchedulePlannerSummary.estimate(from: entriesStore.energyEntries())
        return themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Smart Charging Planner", systemImage: "clock.badge.checkmark").font(.headline)
                    Spacer()
                    collapseButton(for: .schedulePlanner)
                }

                if !layout.isCollapsed(.schedulePlanner) {
                    Text("Recommended window: \(window)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let note = estimate {
                        Text(note).font(.footnote).foregroundStyle(.secondary)
                    }
                    actionLink(destination: ChargingSchedulePlannerView()) {
                        actionRow(
                            title:      "Open planner",
                            subtitle:   "Tune rates and schedule",
                            systemImage: "arrow.right.circle"
                        )
                    }
                }
            }
        }
    }

    private var priceWatchlistCard: some View {
        themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Price Watchlist", systemImage: "tag").font(.headline)
                    Spacer()
                    Text("\(watchlistStore.items.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    collapseButton(for: .priceWatchlist)
                }

                if !layout.isCollapsed(.priceWatchlist) {
                    if watchlistStore.items.isEmpty {
                        Text("Add your favourite chargers and track price changes.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(watchlistStore.items.prefix(3)) { item in
                            HStack {
                                Text(item.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Spacer()
                                if let price = item.lastPricePerKWh {
                                    Text(price, format: .currency(code: defaultCurrencyCode))
                                        .font(.footnote.weight(.semibold))
                                        .monospacedDigit()
                                } else {
                                    Text("—").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    actionLink(destination: PriceWatchlistView()) {
                        actionRow(
                            title:      "Manage watchlist",
                            subtitle:   "Add and update price entries",
                            systemImage: "arrow.right.circle"
                        )
                    }
                }
            }
        }
    }

    // MARK: - Vehicle image helpers

    @ViewBuilder
    private func teslaVehicleImage(selectedVehicle: VehicleProfile?) -> some View {
        if let assetName = selectedVehicle.flatMap(teslaAssetName) {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .shadow(
                    color:  Color.black.opacity(scheme == .dark ? 0.55 : 0.18),
                    radius: 20,
                    y:      12
                )
                .accessibilityLabel(selectedVehicle?.displayName ?? "Vehicle")
        } else {
            Image(systemName: "car.side.fill")
                .font(.system(size: 84, weight: .light))
                .foregroundStyle(Color.primary.opacity(0.55))
                .accessibilityLabel("Vehicle")
        }
    }

    private func teslaAssetName(for vehicle: VehicleProfile) -> String? {
        guard vehicle.detectedBrand == .tesla else { return nil }
        let raw = [vehicle.model, vehicle.name, vehicle.trim ?? ""]
            .joined(separator: " ")
            .lowercased()
        if raw.contains("roadster")                              { return "roadster" }
        if raw.contains("cyber")                                 { return "cybertruck" }
        if raw.contains("model 3") || raw.contains("model3")    { return "model 3" }
        if raw.contains("model y") || raw.contains("modely")    { return "model y" }
        if raw.contains("model x") || raw.contains("modelx")    { return "model x" }
        if raw.contains("model s") || raw.contains("models")    { return "model s" }
        return "model 3"
    }

    private func estimatedAvailableRangeMiles(vehicle: VehicleProfile?, soc: Double) -> Int? {
        guard let vehicle else { return nil }
        let fullRange = vehicle.estimatedRangeMiles ?? vehicle.maxRangeMiles
        guard let fullRange, fullRange > 0 else { return nil }
        return Int((fullRange * max(0, min(100, soc)) / 100).rounded())
    }

    // MARK: - Schedule Planner Summary

    private struct SchedulePlannerSummary {
        static func windowText() -> String {
            let start = UserDefaults.standard.integer(forKey: "planner.offPeakStart")
            let end   = UserDefaults.standard.integer(forKey: "planner.offPeakEnd")
            return "\(hourLabel(start)) → \(hourLabel(end))"
        }

        static func estimate(from entries: [ExpenseEntry]) -> String? {
            let offPeakRate = UserDefaults.standard.double(forKey: "planner.offPeakRate")
            let peakRate    = UserDefaults.standard.double(forKey: "planner.peakRate")
            guard offPeakRate > 0, peakRate > 0 else { return nil }

            let recentKWh = entries
                .sorted { $0.date > $1.date }
                .prefix(12)
                .compactMap { $0.energyAddedKWh }
                .filter { $0 > 0 }
            guard !recentKWh.isEmpty else { return nil }

            let avgKWh   = recentKWh.reduce(0, +) / Double(recentKWh.count)
            let savings  = max(0, avgKWh * peakRate - avgKWh * offPeakRate)
            let currency = Locale.current.currency?.identifier ?? "USD"
            return "Est. savings per session: \(savings.formatted(.currency(code: currency)))"
        }

        private static func hourLabel(_ hour: Int) -> String {
            let h   = (hour % 24 + 24) % 24
            let h12 = h % 12 == 0 ? 12 : h % 12
            return "\(h12)\(h < 12 ? "AM" : "PM")"
        }
    }

    // MARK: - Primitive view helpers

    private func themedCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard(padding: theme.spacing, corner: theme.corner, surface: cardSurface)
    }

    private func themedDivider(opacity: Double = 0.35) -> some View {
        Rectangle()
            .fill(theme.separator.opacity(opacity))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(theme.pillTint.opacity(0.85)))
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.footnote).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func twoStatRow(
        title1: String, value1: String,
        title2: String, value2: String
    ) -> some View {
        HStack(spacing: 10) {
            statBlock(title: title1, value: value1)
            statBlock(title: title2, value: value2)
        }
    }

    private func actionRow(
        title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(appearance.accentColor.opacity(scheme == .dark ? 0.18 : 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(theme.separator.opacity(0.5), lineWidth: 0.5)
                    )
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(appearance.accentColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func spotlightStat(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(appearance.accentColor)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .minimumScaleFactor(0.8)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.pillTint.opacity(scheme == .dark ? 0.18 : 0.52))
        )
    }

    // MARK: - Formatting helpers

    private func formatCurrency(_ amount: Double, currency: String) -> String {
        let nf = currencyFormatter()
        // If a one-off currency is requested, create a temporary formatter.
        if nf.currencyCode != currency {
            let temp = Self.makeCurrencyFormatter(currency)
            return temp.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
        }
        return nf.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }

    private func formatNumber(_ value: Double, digits: Int) -> String {
        let nf = Self.decimalFormatter
        nf.maximumFractionDigits = digits
        return nf.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // MARK: - Budget sheet

    private var budgetSheet: some View {
        BudgetSettingsSheet(
            currencyCode:       defaultCurrencyCode,
            useCategoryBudgets: $useCategoryBudgets,
            overallBudget:      $monthlyBudgetLimit,
            budgetSupercharging: $budgetSupercharging,
            budgetLease:         $budgetLease,
            budgetInsurance:     $budgetInsurance,
            budgetMisc:          $budgetMisc,
            spentSupercharging:  cachedSpending.superchargingTotal,
            spentLease:          cachedSpending.lease,
            spentInsurance:      cachedSpending.insurance,
            spentMisc:           cachedSpending.misc
        )
    }
}

// MARK: - DashboardBackground

private struct DashboardBackground: View {
    let screenBackground: AnyShapeStyle
    let accent:           Color
    let themeAccent:      Color
    let showGradients:    Bool
    let scheme:           ColorScheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(screenBackground)
                .ignoresSafeArea()

            if showGradients {
                RadialGradient(
                    colors:      [accent.opacity(scheme == .dark ? 0.14 : 0.08), .clear],
                    center:      .topLeading,
                    startRadius: 0,
                    endRadius:   520
                )
                .blur(radius: 28)
                .ignoresSafeArea()

                RadialGradient(
                    colors:      [themeAccent.opacity(scheme == .dark ? 0.08 : 0.05), .clear],
                    center:      .bottomTrailing,
                    startRadius: 0,
                    endRadius:   600
                )
                .blur(radius: 34)
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - BudgetSettingsSheet

@MainActor
private struct BudgetSettingsSheet: View {
    let currencyCode: String

    @Binding var useCategoryBudgets: Bool
    @Binding var overallBudget:      Double
    @Binding var budgetSupercharging: Double
    @Binding var budgetLease:        Double
    @Binding var budgetInsurance:    Double
    @Binding var budgetMisc:         Double

    let spentSupercharging: Double
    let spentLease:         Double
    let spentInsurance:     Double
    let spentMisc:          Double

    @Environment(\.dismiss) private var dismiss

    // Draft values – committed only when the user taps Save.
    @State private var draftUseCategories = false
    @State private var draftOverall:       Double = 0
    @State private var draftSC:            Double = 0
    @State private var draftLease:         Double = 0
    @State private var draftIns:           Double = 0
    @State private var draftMisc:          Double = 0

    private var totalCategoryDraft: Double {
        max(0, draftSC) + max(0, draftLease) + max(0, draftIns) + max(0, draftMisc)
    }

    // Static cached formatter – rebuilt only when currency changes.
    private static var _lastCurrency = ""
    private static var _formatter    = NumberFormatter()

    private func fmt(_ amount: Double) -> String {
        if Self._lastCurrency != currencyCode {
            Self._lastCurrency = currencyCode
            let nf = NumberFormatter()
            nf.numberStyle = .currency
            nf.currencyCode = currencyCode
            nf.maximumFractionDigits = 2
            Self._formatter = nf
        }
        return Self._formatter.string(from: NSNumber(value: amount))
            ?? String(format: "%.2f", amount)
    }

    // MARK: Budget category model

    private enum BudgetCat {
        case supercharging, lease, insurance, misc

        var title: String {
            switch self {
            case .supercharging: return "Supercharging"
            case .lease:         return "Lease / Car Payment"
            case .insurance:     return "Insurance"
            case .misc:          return "Misc"
            }
        }

        var systemImage: String {
            switch self {
            case .supercharging: return "bolt.car"
            case .lease:         return "creditcard"
            case .insurance:     return "shield"
            case .misc:          return "square.grid.2x2"
            }
        }

        var help: String {
            switch self {
            case .supercharging:
                return "Fast charging sessions. Uses imported-session cost when available, plus Entries tagged as supercharging/DCFC."
            case .lease:
                return "Entries whose category or notes mention lease, car payment, auto loan, financing, or lender."
            case .insurance:
                return "Entries whose category or notes mention insurance (and common insurer names)."
            case .misc:
                return "Everything else this month not classified above."
            }
        }
    }

    // MARK: body

    var body: some View {
        NavigationStack {
            Form {
                modeSection
                if draftUseCategories {
                    totalBudgetSection
                    categoryBudgetsSection
                    clearCategoriesSection
                } else {
                    overallBudgetSection
                    clearOverallSection
                }
            }
            .navigationTitle("Budgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .onAppear(perform: loadDrafts)
        }
    }

    // MARK: Form sections

    private var modeSection: some View {
        Section(
            header: Text("Mode"),
            footer: Text("Per-category budgets match the Dashboard spending buckets.")
        ) {
            Toggle("Use per-category budgets", isOn: $draftUseCategories)
        }
    }

    private var totalBudgetSection: some View {
        Section(
            header: Text("Total budget (optional)"),
            footer: Text("Used only for Split evenly. Your actual limits come from the category budgets below.")
        ) {
            LabeledContent("Total budget") {
                TextField("0", value: $draftOverall, format: .currency(code: currencyCode))
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
            }
            Button("Split evenly across categories") {
                let each = max(0, draftOverall) / 4.0
                draftSC = each
                draftLease = each
                draftIns = each
                draftMisc = each
            }
            .disabled(draftOverall <= 0)
        }
    }

    private var categoryBudgetsSection: some View {
        Section(
            header: Text("Category budgets"),
            footer: Text("Each row shows this month's spend against your target.")
        ) {
            categoryRow(.supercharging, budget: $draftSC,    spent: spentSupercharging)
            categoryRow(.lease,         budget: $draftLease, spent: spentLease)
            categoryRow(.insurance,     budget: $draftIns,   spent: spentInsurance)
            categoryRow(.misc,          budget: $draftMisc,  spent: spentMisc)
            LabeledContent("Total (categories)") {
                Text(fmt(totalCategoryDraft))
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var clearCategoriesSection: some View {
        Section {
            Button(role: .destructive) {
                draftSC = 0
                draftLease = 0
                draftIns = 0
                draftMisc = 0
            } label: {
                Text("Clear category budgets")
            }
        }
    }

    private var overallBudgetSection: some View {
        Section(
            header: Text("Overall monthly budget"),
            footer: Text("Used when per-category budgets are disabled.")
        ) {
            LabeledContent("Monthly budget") {
                TextField("0", value: $draftOverall, format: .currency(code: currencyCode))
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
            }
            LabeledContent("Spent this month") {
                Text(fmt(spentSupercharging + spentLease + spentInsurance + spentMisc))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var clearOverallSection: some View {
        Section {
            Button(role: .destructive) {
                draftOverall = 0
            } label: {
                Text("Clear overall budget")
            }
        }
    }

    // MARK: Actions

    private func save() {
        useCategoryBudgets  = draftUseCategories
        overallBudget       = max(0, draftOverall)
        budgetSupercharging = max(0, draftSC)
        budgetLease         = max(0, draftLease)
        budgetInsurance     = max(0, draftIns)
        budgetMisc          = max(0, draftMisc)
        dismiss()
    }

    private func loadDrafts() {
        draftUseCategories = useCategoryBudgets
        draftOverall       = overallBudget
        draftSC            = budgetSupercharging
        draftLease         = budgetLease
        draftIns           = budgetInsurance
        draftMisc          = budgetMisc
    }

    // MARK: Category row

    @ViewBuilder
    private func categoryRow(
        _ cat: BudgetCat,
        budget: Binding<Double>,
        spent: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(cat.title, systemImage: cat.systemImage).font(.headline)
                Spacer()
                TextField("0", value: budget, format: .currency(code: currencyCode))
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(minWidth: 120)
            }
            Text(cat.help)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Spent this month").font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Text(fmt(spent)).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            }
            Stepper("Adjust \(cat.title)", value: budget, in: 0...100_000, step: 25)
                .font(.subheadline)
        }
        .padding(.vertical, 6)
    }
}
