//
//  DashboardView.swift
//  My KWh Companion
//
//  Swift 6 • iOS 17+
//
//  Regenerated (reduced top empty space + polished):
//  ✅ Uses inline nav title (removes large-title “dead air”)
//  ✅ Scroll content uses contentMargins (less top padding, cleaner)
//  ✅ Optional glass cards when uiStyle == "glass"/"teslaglass"
//  ✅ AppThemeSpec drives background/cards/separators/spacing/corners/elevation
//  ✅ Keeps your bucket logic + budget editor sheet intact
//

import SwiftUI
import Foundation

@MainActor
struct DashboardView: View {

    // MARK: - Environment

    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore
    @StateObject private var teslaFiUnlock = TeslaFiEntitlementStore.shared
    @EnvironmentObject private var appearance: AppAppearance
    @EnvironmentObject private var uiSettings: AppUISettings

    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var theme: any AppThemeSpec { themeBox.base }

    // MARK: - Settings / Storage

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String =
        (Locale.current.currency?.identifier ?? "USD")

    // Mirrors SettingsView key
    @AppStorage("uiStyle") private var uiStyleRaw: String = "teslaGlass"

    // Budget settings
    @AppStorage("budget_useCategoryBudgets") private var useCategoryBudgets: Bool = true
    @AppStorage("monthlyBudgetLimit") private var monthlyBudgetLimit: Double = 0

    @AppStorage("budget_supercharging") private var budgetSupercharging: Double = 0
    @AppStorage("budget_lease") private var budgetLease: Double = 0
    @AppStorage("budget_insurance") private var budgetInsurance: Double = 0
    @AppStorage("budget_misc") private var budgetMisc: Double = 0

    @AppStorage("dashboard.moreCardsPrompted") private var moreCardsPrompted: Bool = false

    // MARK: - UI State

    @State private var showingBudgetEditor = false
    @State private var showingLayoutEditor = false
    @State private var showMoreCardsPrompt = false
    @State private var showAllActions = false

    @StateObject private var layout = DashboardLayoutStore()
    @StateObject private var watchlistStore = PriceWatchlistStore()
    @StateObject private var adsStore = AdsEntitlementStore.shared

    // MARK: - Theme helpers

    private var isGlass: Bool {
        let v = uiStyleRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return v == "teslaglass" || v == "glass"
    }

    private var cardSurface: AnyShapeStyle {
        isGlass ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(theme.cardBackground)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let layoutSpec = dashboardLayoutSpec(for: proxy.size.width)

            ScrollView {
                VStack(spacing: theme.spacing) {
                    LazyVGrid(columns: layoutSpec.columns, spacing: theme.spacing) {
                        ForEach(layout.visibleOrder, id: \.self) { kind in
                            let spec = cardSpec(for: kind)
                            spec.view
                                .modifier(CardPolish())
                                .gridCellColumns(spec.columns)
                        }
                    }
                    .padding(.horizontal, layoutSpec.horizontalPadding)
                    .frame(maxWidth: layoutSpec.maxWidth)
                    .frame(maxWidth: .infinity)

                    if !adsStore.hasRemovedAds {
                        adBannerCard
                            .modifier(CardPolish())
                            .padding(.horizontal, layoutSpec.horizontalPadding)
                            .frame(maxWidth: layoutSpec.maxWidth)
                    }
                }
            }
        }
        // ✅ less “dead air” at top than manual .padding(.top, 12)
        .contentMargins(.top, 6, for: .scrollContent)
        .contentMargins(.bottom, 22, for: .scrollContent)
        .scrollIndicators(.hidden)
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline) // ✅ big reduction in top whitespace
        .background(dashboardBackground)
        .tint(appearance.accentColor)
        .sheet(isPresented: $showingBudgetEditor) {
            BudgetSettingsSheet(
                currencyCode: defaultCurrencyCode,
                useCategoryBudgets: $useCategoryBudgets,
                overallBudget: $monthlyBudgetLimit,
                budgetSupercharging: $budgetSupercharging,
                budgetLease: $budgetLease,
                budgetInsurance: $budgetInsurance,
                budgetMisc: $budgetMisc,
                spentSupercharging: spending.superchargingTotal,
                spentLease: spending.lease,
                spentInsurance: spending.insurance,
                spentMisc: spending.misc
            )
        }
        .sheet(isPresented: $showingLayoutEditor) {
            DashboardLayoutEditorView(layout: layout)
        }
        .onAppear {
            let any = (budgetSupercharging + budgetLease + budgetInsurance + budgetMisc) > 0
            if any { useCategoryBudgets = true }

            if !moreCardsPrompted {
                moreCardsPrompted = true
                showMoreCardsPrompt = true
            }
        }
        .task {
            await adsStore.load()
            await teslaFiUnlock.load()
        }
        .alert("More cards are available", isPresented: $showMoreCardsPrompt) {
            Button("Customize") { showingLayoutEditor = true }
            Button("Not now", role: .cancel) { }
        } message: {
            Text("We’re showing a focused set to keep scrolling fast. You can turn on more cards anytime from Customize.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingLayoutEditor = true
                } label: {
                    Label("Customize", systemImage: "slider.horizontal.3")
                }
            }
        }
    }

    private var isAccessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private struct DashboardLayoutSpec {
        let columns: [GridItem]
        let horizontalPadding: CGFloat
        let maxWidth: CGFloat
    }

    private func dashboardLayoutSpec(for width: CGFloat) -> DashboardLayoutSpec {
        let minCardWidth: CGFloat = isAccessibilitySize ? 420 : 340
        let basePadding: CGFloat = horizontalSizeClass == .regular ? 24 : 16
        let contentWidth = max(0, width - basePadding * 2)
        let possibleColumns = max(1, Int((contentWidth + theme.spacing) / (minCardWidth + theme.spacing)))
        let columnCount = min(possibleColumns, horizontalSizeClass == .regular ? 3 : 1)

        let columns = Array(
            repeating: GridItem(.flexible(minimum: minCardWidth, maximum: 560), spacing: theme.spacing, alignment: .top),
            count: columnCount
        )

        let maxWidth: CGFloat = columnCount > 1 ? 1100 : .infinity
        return DashboardLayoutSpec(columns: columns, horizontalPadding: basePadding, maxWidth: maxWidth)
    }

    private struct DashboardCardSpec {
        let view: AnyView
        let columns: Int
    }

    private struct CardPolish: ViewModifier {
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
                            .opacity(phase.isIdentity ? 1 : 0.72)
                            .scaleEffect(phase.isIdentity ? 1 : 0.985)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    private func cardSpec(for kind: DashboardCardKind) -> DashboardCardSpec {
        switch kind {
        case .greeting:
            return DashboardCardSpec(view: AnyView(greetingCard), columns: 1)
        case .actionCenter:
            return DashboardCardSpec(view: AnyView(actionCenterCard), columns: 1)
        case .insights:
            return DashboardCardSpec(view: AnyView(insightsCard), columns: 1)
        case .savingsScore:
            return DashboardCardSpec(view: AnyView(savingsScoreCard), columns: 1)
        case .weeklyForecast:
            return DashboardCardSpec(view: AnyView(weeklyForecastCard), columns: 1)
        case .weeklyHealth:
            return DashboardCardSpec(view: AnyView(weeklyHealthCard), columns: 1)
        case .schedulePlanner:
            return DashboardCardSpec(view: AnyView(schedulePlannerCard), columns: 1)
        case .priceWatchlist:
            return DashboardCardSpec(view: AnyView(priceWatchlistCard), columns: 1)
        case .spendingBreakdown:
            return DashboardCardSpec(view: AnyView(spendingBreakdownCard), columns: 1)
        case .budget:
            return DashboardCardSpec(view: AnyView(budgetCard), columns: 1)
        case .dataSources:
            return DashboardCardSpec(view: AnyView(dataSourcesCard), columns: 1)
        case .recentActivity:
            return DashboardCardSpec(view: AnyView(recentActivityCard), columns: horizontalSizeClass == .regular ? 2 : 1)
        }
    }

    private func collapseButton(for kind: DashboardCardKind) -> some View {
        Button {
            layout.toggleCollapsed(kind)
        } label: {
            Image(systemName: layout.isCollapsed(kind) ? "chevron.down" : "chevron.up")
                .font(.footnote.weight(.semibold))
                .padding(6)
                .background(Capsule().fill(theme.pillTint.opacity(0.6)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(layout.isCollapsed(kind) ? "Expand section" : "Collapse section")
    }

    private var dashboardBackground: some View {
        ZStack {
            Rectangle()
                .fill(theme.screenBackground)
                .ignoresSafeArea()

            if uiSettings.motion == .full {
                // subtle polish (theme-driven, not hardcoded colors)
                RadialGradient(
                    colors: [appearance.accentColor.opacity(scheme == .dark ? 0.16 : 0.10), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 560
                )
                .blur(radius: 28)
                .ignoresSafeArea()

                RadialGradient(
                    colors: [theme.accent.opacity(scheme == .dark ? 0.10 : 0.06), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 640
                )
                .blur(radius: 34)
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Greeting

    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    // MARK: - Time window (This month)

    private var monthWindow: ClosedRange<Date> {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let end = cal.date(byAdding: DateComponents(month: 1), to: start)?
            .addingTimeInterval(-1) ?? now
        return start...end
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f.string(from: Date())
    }

    // MARK: - Data snapshots (This month)

    private var entriesThisMonth: [ExpenseEntry] {
        entriesStore.entries
            .filter { monthWindow.contains($0.date) }
            .sorted(by: { $0.date > $1.date })
    }

    private var energyEntriesThisMonth: [ExpenseEntry] {
        entriesThisMonth.filter { $0.isEnergyEffective }
    }

    private var teslaFiThisMonth: [TeslaFiSession] {
        guard teslaFiUnlock.hasTeslaFiUnlock else { return [] }
        return teslaFiStore.sessions
            .filter { $0.startDate <= monthWindow.upperBound && $0.endDate >= monthWindow.lowerBound }
            .sorted(by: { $0.startDate > $1.startDate })
    }

    private var monthEnergyKWh: Double {
        energyEntriesThisMonth.reduce(0) { $0 + max(0, $1.energyAddedKWh ?? 0) }
    }

    private var monthEnergyCost: Double {
        energyEntriesThisMonth.reduce(0) { $0 + max(0, $1.amount) }
    }

    private var avgCostPerKWh: Double? {
        guard monthEnergyKWh > 0, monthEnergyCost > 0 else { return nil }
        return monthEnergyCost / monthEnergyKWh
    }

    private var missingCostTeslaFiCount: Int {
        teslaFiThisMonth.filter { $0.cost == nil }.count
    }

    private var missingCostEntryCount: Int {
        energyEntriesThisMonth.filter { ($0.energyAddedKWh ?? 0) > 0 && $0.amount <= 0 }.count
    }

    private var daysInMonth: Int {
        let cal = Calendar.current
        let now = Date()
        return cal.range(of: .day, in: .month, for: now)?.count ?? 30
    }

    private var daysElapsed: Int {
        let cal = Calendar.current
        let now = Date()
        let day = cal.component(.day, from: now)
        return max(1, day)
    }

    private var daysRemaining: Int {
        max(0, daysInMonth - daysElapsed)
    }

    private var projectedMonthlySpend: Double? {
        guard effectiveSpentTotal > 0 else { return nil }
        return (effectiveSpentTotal / Double(daysElapsed)) * Double(daysInMonth)
    }

    // MARK: - Classification helpers

    private func norm(_ s: String?) -> String {
        (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isSuperchargingEntry(_ e: ExpenseEntry) -> Bool {
        if e.charging?.isSupercharger == true { return true }

        let cat = norm(e.category)
        let type = norm(e.chargeType)
        let loc = norm(e.location) + " " + norm(e.charging?.siteName)
        let note = norm(e.notes)

        return type.contains("supercharg")
            || cat.contains("supercharg")
            || loc.contains("supercharg")
            || note.contains("supercharg")
            || cat.contains("dcfc")
            || cat.contains("fast")
            || type.contains("dcfc")
            || type.contains("fast")
            || loc.contains("electrify america")
            || loc.contains("evgo")
            || loc.contains("chargepoint")
    }

    private func isSuperchargerTeslaFi(_ s: TeslaFiSession) -> Bool {
        let loc = norm(s.location) + " " + norm(s.displayLocation)
        return loc.contains("supercharg")
            || loc.contains("super charger")
            || loc.contains("dcfc")
            || loc.contains("electrify america")
            || loc.contains("evgo")
            || loc.contains("chargepoint")
    }

    /// FIX: Lease/Payment must NEVER match supercharging entries,
    /// and must not trigger on generic “payment” text (common in charger transactions).
    private func isLeaseOrCarPayment(_ e: ExpenseEntry) -> Bool {
        if isSuperchargingEntry(e) { return false } // hard guard against cross-bucket bleed

        let cat = norm(e.category)
        let note = norm(e.notes)
        let loc = norm(e.location)

        let catHit =
            cat.contains("lease") ||
            cat.contains("car payment") ||
            cat.contains("auto payment") ||
            cat.contains("vehicle payment") ||
            cat.contains("auto loan") ||
            cat.contains("car loan") ||
            cat.contains("vehicle loan") ||
            cat.contains("finance") ||
            cat.contains("financing") ||
            cat.contains("lender") ||
            cat.contains("installment")

        let noteHit =
            note.contains("lease") ||
            note.contains("car payment") ||
            note.contains("auto payment") ||
            note.contains("vehicle payment") ||
            note.contains("auto loan") ||
            note.contains("car loan") ||
            note.contains("vehicle loan") ||
            note.contains("finance") ||
            note.contains("financing") ||
            note.contains("lender") ||
            note.contains("installment")

        let locHit =
            loc.contains("toyota financial") ||
            loc.contains("tesla finance") ||
            loc.contains("honda financial") ||
            loc.contains("ford credit") ||
            loc.contains("gm financial") ||
            loc.contains("capital one auto") ||
            loc.contains("ally auto") ||
            loc.contains("santander") ||
            loc.contains("chase auto") ||
            loc.contains("wells fargo auto")

        return catHit || noteHit || locHit
    }

    private func isInsurance(_ e: ExpenseEntry) -> Bool {
        let cat = norm(e.category)
        let note = norm(e.notes)
        let loc = norm(e.location)

        return cat.contains("insurance")
            || note.contains("insurance")
            || loc.contains("geico")
            || loc.contains("progressive")
            || loc.contains("state farm")
            || loc.contains("allstate")
    }

    // MARK: - Mutually exclusive bucket assignment (Entries)

    private enum EntryBucket {
        case supercharging, lease, insurance, misc
    }

    /// One entry → one bucket (prevents supercharging dollars from being counted as lease).
    private func bucket(for e: ExpenseEntry) -> EntryBucket {
        if isSuperchargingEntry(e) { return .supercharging }
        if isLeaseOrCarPayment(e) { return .lease }
        if isInsurance(e) { return .insurance }
        return .misc
    }

    // MARK: - Spending model (This month)

    private struct Spending {
        let superchargingTeslaFi: Double
        let superchargingEntries: Double
        let lease: Double
        let insurance: Double
        let misc: Double

        var superchargingTotal: Double { superchargingTeslaFi + superchargingEntries }
        var totalBuckets: Double { superchargingTotal + lease + insurance + misc }
        var hasPossibleOverlap: Bool { superchargingTeslaFi > 0 && superchargingEntries > 0 }
    }

    private var spending: Spending {
        var scEntries: Double = 0
        var lease: Double = 0
        var ins: Double = 0
        var misc: Double = 0

        for e in entriesThisMonth {
            switch bucket(for: e) {
            case .supercharging: scEntries += e.amount
            case .lease:         lease += e.amount
            case .insurance:     ins += e.amount
            case .misc:          misc += e.amount
            }
        }

        let scTeslaFi = teslaFiThisMonth
            .filter(isSuperchargerTeslaFi)
            .compactMap(\.cost)
            .reduce(0, +)

        return Spending(
            superchargingTeslaFi: scTeslaFi,
            superchargingEntries: scEntries,
            lease: lease,
            insurance: ins,
            misc: misc
        )
    }

    // MARK: - Budgets

    private var totalCategoryBudget: Double {
        max(0, budgetSupercharging) + max(0, budgetLease) + max(0, budgetInsurance) + max(0, budgetMisc)
    }

    private var effectiveBudgetTotal: Double {
        useCategoryBudgets ? totalCategoryBudget : max(0, monthlyBudgetLimit)
    }

    private var effectiveSpentTotal: Double {
        spending.totalBuckets
    }

    // MARK: - Cards

    private var greetingCard: some View {
        themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(timeOfDayGreeting)
                        .font(.title2.weight(.semibold))
                    Spacer()
                    collapseButton(for: .greeting)
                }

                if !layout.isCollapsed(.greeting) {
                    HStack {
                        Label(monthTitle, systemImage: "calendar")
                            .font(.headline)
                        Spacer()
                        pill("This month")
                    }

                    Text(formatCurrency(effectiveSpentTotal, currency: defaultCurrencyCode))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()

                    Text("Based on your Dashboard buckets: Supercharging, Lease/Payment, Insurance, and Misc.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("Updated \(dateTime(Date()))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var actionCenterCard: some View {
        themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Action Center", systemImage: "sparkles")
                        .font(.headline)
                    Spacer()
                    pill("This month")
                    collapseButton(for: .actionCenter)
                }

                if !layout.isCollapsed(.actionCenter) {
                    if actionItems.isEmpty {
                        Text("You’re all caught up. Great job keeping data clean.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        let items = showAllActions ? actionItems : Array(actionItems.prefix(4))
                        ForEach(items.indices, id: \.self) { idx in
                            items[idx]
                            if idx < items.count - 1 {
                                themedDivider(opacity: 0.18)
                            }
                        }

                        if actionItems.count > items.count {
                            themedDivider(opacity: 0.18)
                            Button(showAllActions ? "Show fewer actions" : "Show more actions") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showAllActions.toggle()
                                }
                            }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var actionItems: [AnyView] {
        var items: [AnyView] = []

        let dq = DataQualityAnalyzer.summarize(
            entries: entriesStore.energyEntries(),
            sessions: teslaFiUnlock.hasTeslaFiUnlock ? teslaFiStore.sessions : []
        )
        let dqCount = dq.costSpikes.count + dq.idleFeeRisk.count + dq.outliers.count + dq.duplicates.count

        if !teslaFiUnlock.hasTeslaFiUnlock {
            items.append(AnyView(
                TeslaFiUnlockCard(
                    title: "Unlock TeslaFi Import",
                    subtitle: "Enable TeslaFi CSV import and analytics for $0.99."
                )
            ))
        } else if teslaFiStore.sessionCount == 0 {
            items.append(AnyView(
                NavigationLink {
                    TeslaFiCSVImportView()
                        .navigationTitle("Import TeslaFi")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    actionRow(
                        title: "Import TeslaFi CSV",
                        subtitle: "Unlock session analytics and pricing trends",
                        systemImage: "square.and.arrow.down"
                    )
                }
                .buttonStyle(.plain)
            ))
        }

        if missingCostTeslaFiCount > 0 {
            items.append(AnyView(
                NavigationLink {
                    MissingCostAssistantView()
                } label: {
                    actionRow(
                        title: "Fill missing TeslaFi costs",
                        subtitle: "\(missingCostTeslaFiCount) session(s) missing cost",
                        systemImage: "dollarsign.circle"
                    )
                }
                .buttonStyle(.plain)
            ))
        }

        if missingCostEntryCount > 0 {
            items.append(AnyView(
                NavigationLink {
                    ExpenseLogView()
                        .navigationTitle("Expense Log")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    actionRow(
                        title: "Review entries with no cost",
                        subtitle: "\(missingCostEntryCount) entry(ies) have kWh but no cost",
                        systemImage: "exclamationmark.triangle"
                    )
                }
                .buttonStyle(.plain)
            ))
        }

        if dqCount > 0 {
            items.append(AnyView(
                NavigationLink {
                    DataQualityCenterView()
                } label: {
                    actionRow(
                        title: "Review data quality",
                        subtitle: "\(dqCount) potential issues found",
                        systemImage: "shield.lefthalf.filled"
                    )
                }
                .buttonStyle(.plain)
            ))
        }

        if entriesThisMonth.isEmpty {
            items.append(AnyView(
                NavigationLink {
                    ExpenseLogView()
                        .navigationTitle("Expense Log")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    actionRow(
                        title: "Log your first expense",
                        subtitle: "Start tracking charging and costs",
                        systemImage: "plus.circle"
                    )
                }
                .buttonStyle(.plain)
            ))
        }

        if !entriesStore.energyEntries().isEmpty {
            items.append(AnyView(
                NavigationLink {
                    SavingsScoreView()
                } label: {
                    actionRow(
                        title: "Review your Savings Score",
                        subtitle: "See habits that drive cost down",
                        systemImage: "gauge.high"
                    )
                }
                .buttonStyle(.plain)
            ))
        }

        items.append(AnyView(
            NavigationLink {
                ChargingSchedulePlannerView()
            } label: {
                actionRow(
                    title: "Plan your charging window",
                    subtitle: "Set off‑peak hours and rates",
                    systemImage: "clock.badge.checkmark"
                )
            }
            .buttonStyle(.plain)
        ))

        items.append(AnyView(
            NavigationLink {
                PriceWatchlistView()
            } label: {
                actionRow(
                    title: "Manage price watchlist",
                    subtitle: "Track favorite chargers manually",
                    systemImage: "tag"
                )
            }
            .buttonStyle(.plain)
        ))

        items.append(AnyView(
            NavigationLink {
                HomeVsPublicSplitView()
            } label: {
                actionRow(
                    title: "Home vs public split",
                    subtitle: "See where charging costs come from",
                    systemImage: "chart.bar"
                )
            }
            .buttonStyle(.plain)
        ))

        items.append(AnyView(
            NavigationLink {
                TripCostEstimatorView()
            } label: {
                actionRow(
                    title: "Estimate trip cost",
                    subtitle: "Distance × efficiency × rate",
                    systemImage: "map"
                )
            }
            .buttonStyle(.plain)
        ))

        items.append(AnyView(
            NavigationLink {
                AnnualCostSimulatorView()
            } label: {
                actionRow(
                    title: "Project annual cost",
                    subtitle: "Use weekly averages to forecast",
                    systemImage: "calendar"
                )
            }
            .buttonStyle(.plain)
        ))

        if effectiveBudgetTotal > 0, effectiveSpentTotal > effectiveBudgetTotal {
            items.append(AnyView(
                Button {
                    showingBudgetEditor = true
                } label: {
                    actionRow(
                        title: "Adjust your budget",
                        subtitle: "You’re over by \(formatCurrency(effectiveSpentTotal - effectiveBudgetTotal, currency: defaultCurrencyCode))",
                        systemImage: "target"
                    )
                }
                .buttonStyle(.plain)
            ))
        }

        return items
    }

    private var insightsCard: some View {
        themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Quick Insights", systemImage: "bolt.circle")
                        .font(.headline)
                    Spacer()
                    pill("This month")
                    collapseButton(for: .insights)
                }

                if !layout.isCollapsed(.insights) {
                    statsGrid([
                        ("Energy", monthEnergyKWh > 0 ? "\(formatNumber(monthEnergyKWh, digits: 1)) kWh" : "—"),
                        ("Avg $/kWh", avgCostPerKWh.map { formatCurrency($0, currency: defaultCurrencyCode) } ?? "—")
                    ])

                    statsGrid([
                        ("Entries", "\(entriesThisMonth.count)"),
                        ("TeslaFi", "\(teslaFiThisMonth.count)")
                    ])

                    if missingCostTeslaFiCount > 0 || missingCostEntryCount > 0 {
                        themedDivider(opacity: 0.20)
                        Text("Missing cost: TeslaFi \(missingCostTeslaFiCount) • Entries \(missingCostEntryCount)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
                    Label("Savings Score", systemImage: "gauge.high")
                        .font(.headline)
                    Spacer()
                    Text("\(score.totalScore)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(appearance.accentColor)
                    collapseButton(for: .savingsScore)
                }

                if !layout.isCollapsed(.savingsScore) {
                    Text(score.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let hint = score.habitNotes.first {
                        themedDivider(opacity: 0.20)
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        SavingsScoreView()
                    } label: {
                        actionRow(
                            title: "View full breakdown",
                            subtitle: "See habits and score components",
                            systemImage: "arrow.right.circle"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var weeklyForecastCard: some View {
        let summary = WeeklyForecastSummary.build(from: entriesStore.energyEntries())
        return themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Weekly Forecast", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.headline)
                    Spacer()
                    pill("Next week")
                    collapseButton(for: .weeklyForecast)
                }

                if !layout.isCollapsed(.weeklyForecast) {
                    statsGrid([
                        ("Projected cost", formatCurrency(summary.forecastCost, currency: summary.currencyCode)),
                        ("Projected kWh", "\(formatNumber(summary.forecastKWh, digits: 1)) kWh")
                    ])

                    if let confidence = summary.confidenceText {
                        Text(confidence)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        WeeklyChargingForecastView()
                    } label: {
                        actionRow(
                            title: "Open forecast",
                            subtitle: "4‑week rolling projection",
                            systemImage: "arrow.right.circle"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var weeklyHealthCard: some View {
        let report = WeeklyHealthReport.build(from: entriesStore.energyEntries())
        return themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Weekly Health Report", systemImage: "doc.text.magnifyingglass")
                        .font(.headline)
                    Spacer()
                    pill("Last 7 days")
                    collapseButton(for: .weeklyHealth)
                }

                if !layout.isCollapsed(.weeklyHealth) {
                    if report.totalSessions == 0 {
                        Text("No charging sessions logged in the last week.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        statsGrid([
                            ("Sessions", "\(report.totalSessions)"),
                            ("Cost", formatCurrency(report.totalCost, currency: report.currencyCode))
                        ])

                        statsGrid([
                            ("Energy", "\(formatNumber(report.totalKWh, digits: 1)) kWh"),
                            ("Avg $/kWh", report.avgCostPerKWh.map { formatCurrency($0, currency: report.currencyCode) } ?? "—")
                        ])

                        if let note = report.highlight {
                            themedDivider(opacity: 0.20)
                            Text(note)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        WeeklyHealthReportView()
                    } label: {
                        actionRow(
                            title: "Open report",
                            subtitle: "Best and worst sessions",
                            systemImage: "arrow.right.circle"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var schedulePlannerCard: some View {
        let window = SchedulePlannerSummary.windowText()
        let estimate = SchedulePlannerSummary.estimate(from: entriesStore.energyEntries())
        return themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Smart Charging Planner", systemImage: "clock.badge.checkmark")
                        .font(.headline)
                    Spacer()
                    collapseButton(for: .schedulePlanner)
                }

                if !layout.isCollapsed(.schedulePlanner) {
                    Text("Recommended window: \(window)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let note = estimate {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        ChargingSchedulePlannerView()
                    } label: {
                        actionRow(
                            title: "Open planner",
                            subtitle: "Tune rates and schedule",
                            systemImage: "arrow.right.circle"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var priceWatchlistCard: some View {
        themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Price Watchlist", systemImage: "tag")
                        .font(.headline)
                    Spacer()
                    Text("\(watchlistStore.items.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    collapseButton(for: .priceWatchlist)
                }

                if !layout.isCollapsed(.priceWatchlist) {
                    if watchlistStore.items.isEmpty {
                        Text("Add your favorite chargers and track price changes manually.")
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
                                    Text("—")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    NavigationLink {
                        PriceWatchlistView()
                    } label: {
                        actionRow(
                            title: "Manage watchlist",
                            subtitle: "Add and update price entries",
                            systemImage: "arrow.right.circle"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var spendingBreakdownCard: some View {
        themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Spending Breakdown", systemImage: "chart.bar.xaxis")
                        .font(.headline)
                    Spacer()
                    pill("This month")
                    collapseButton(for: .spendingBreakdown)
                }

                if !layout.isCollapsed(.spendingBreakdown) {
                    spendRow("Supercharging", spending.superchargingTotal)

                    if spending.superchargingTeslaFi > 0 || spending.superchargingEntries > 0 {
                        Text([
                            spending.superchargingTeslaFi > 0 ? "TeslaFi: \(formatCurrency(spending.superchargingTeslaFi, currency: defaultCurrencyCode))" : nil,
                            spending.superchargingEntries > 0 ? "Entries: \(formatCurrency(spending.superchargingEntries, currency: defaultCurrencyCode))" : nil
                        ].compactMap { $0 }.joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if spending.hasPossibleOverlap {
                            Text("Note: If you logged the same sessions in Entries and imported TeslaFi, totals may overlap.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    themedDivider(opacity: 0.25)

                    spendRow("Lease / Car Payment", spending.lease)
                    spendRow("Insurance", spending.insurance)
                    spendRow("Misc", spending.misc)

                    themedDivider(opacity: 0.25)

                    HStack {
                        Text("Total:")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(formatCurrency(spending.totalBuckets, currency: defaultCurrencyCode))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var weeklyEVVsGasCard: some View {
        themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Weekly EV vs Gas", systemImage: "fuelpump.and.filter")
                        .font(.headline)
                    Spacer()
                    pill("Weekly")
                }

                Text("Compare weekly operating cost using gas price, miles, MPG, and your EV kWh usage + rate.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    WeeklyEVVsGasCostView()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                        Text("Open comparison")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .padding(.top, 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Weekly EV vs Gas comparison")
            }
        }
    }

    private var adBannerCard: some View {
        AdBannerCard(adsStore: adsStore)
    }


    private var budgetCard: some View {
        let spent = effectiveSpentTotal
        let budget = effectiveBudgetTotal

        return themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Budget", systemImage: useCategoryBudgets ? "target" : "banknote")
                        .font(.headline)
                    Spacer()
                    Button("Edit") { showingBudgetEditor = true }
                        .font(.footnote.weight(.semibold))
                    collapseButton(for: .budget)
                }

                if !layout.isCollapsed(.budget) {
                    if budget <= 0 {
                        Text(useCategoryBudgets
                             ? "Set per-category budgets to track Supercharging, Lease/Payment, Insurance, and Misc."
                             : "Set an overall monthly budget to track progress."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        Button {
                            showingBudgetEditor = true
                        } label: {
                            Label("Set budgets", systemImage: "slider.horizontal.3")
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(theme.pillTint))
                        }
                        .buttonStyle(.plain)

                    } else {
                        budgetBarRow(
                            title: useCategoryBudgets ? "Total (categories)" : "Monthly total",
                            spent: spent,
                            budget: budget
                        )

                        if let projected = projectedMonthlySpend, projected > 0 {
                            Text("Projected: \(formatCurrency(projected, currency: defaultCurrencyCode)) at current pace")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if budget > 0, daysRemaining > 0 {
                            let remaining = budget - spent
                            let neededPerDay = remaining / Double(daysRemaining)
                            Text(
                                remaining >= 0
                                ? "To stay on budget: \(formatCurrency(neededPerDay, currency: defaultCurrencyCode)) /day"
                                : "Over by \(formatCurrency(abs(remaining), currency: defaultCurrencyCode)) so far"
                            )
                            .font(.footnote)
                            .foregroundColor(remaining >= 0 ? .secondary : .red)
                        }

                        if useCategoryBudgets {
                            themedDivider(opacity: 0.22)

                            categoryBudgetRow(title: "Supercharging", spent: spending.superchargingTotal, budget: budgetSupercharging)
                            categoryBudgetRow(title: "Lease / Payment", spent: spending.lease, budget: budgetLease)
                            categoryBudgetRow(title: "Insurance", spent: spending.insurance, budget: budgetInsurance)
                            categoryBudgetRow(title: "Misc", spent: spending.misc, budget: budgetMisc)
                        }
                    }
                }
            }
        }
    }

    private var dataSourcesCard: some View {
        themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Data Sources", systemImage: "tray.full")
                        .font(.headline)
                    Spacer()
                    collapseButton(for: .dataSources)
                }

                if !layout.isCollapsed(.dataSources) {
                    HStack {
                        Text("Entries (this month)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(entriesThisMonth.count)")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }

                    HStack {
                        Text("TeslaFi sessions (this month)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(teslaFiThisMonth.count)")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var recentActivityCard: some View {
        themedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Recent Activity", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                    Spacer()
                    collapseButton(for: .recentActivity)
                }

                if !layout.isCollapsed(.recentActivity) {
                    if entriesThisMonth.isEmpty && teslaFiThisMonth.isEmpty {
                        Text("No activity this month yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        if !entriesThisMonth.isEmpty {
                            Text("Latest entries")
                                .font(.subheadline.weight(.semibold))

                            ForEach(entriesThisMonth.prefix(3)) { e in
                                activityRow(
                                    title: e.location ?? e.charging?.siteName ?? e.category,
                                    subtitle: dateTime(e.date),
                                    trailing: formatCurrency(e.amount, currency: e.currencyCode ?? defaultCurrencyCode),
                                    badge: badgeForEntry(e)
                                )
                                themedDivider(opacity: 0.16)
                            }
                        }

                        if !teslaFiThisMonth.isEmpty {
                            if !entriesThisMonth.isEmpty {
                                themedDivider(opacity: 0.28)
                                    .padding(.vertical, 4)
                            }

                            Text("Latest TeslaFi sessions")
                                .font(.subheadline.weight(.semibold))

                            ForEach(teslaFiThisMonth.prefix(3), id: \.sessionHash) { s in
                                let costText = s.cost.map { formatCurrency($0, currency: defaultCurrencyCode) } ?? "—"
                                activityRow(
                                    title: s.displayLocation,
                                    subtitle: "\(dateTime(s.startDate)) • \(String(format: "%.1f", s.energyAddedKWh)) kWh",
                                    trailing: costText,
                                    badge: isSuperchargerTeslaFi(s) ? "Fast charge" : "TeslaFi"
                                )
                                themedDivider(opacity: 0.16)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Budget row helpers

    private func budgetBarRow(title: String, spent: Double, budget: Double) -> some View {
        let progress = min(max(spent / max(budget, 0.01), 0), 1)
        let remaining = budget - spent

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).foregroundStyle(.secondary)
                Spacer()
                Text("\(formatCurrency(spent, currency: defaultCurrencyCode)) / \(formatCurrency(budget, currency: defaultCurrencyCode))")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            .font(.subheadline)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.pillTint.opacity(0.55)).frame(height: 10)
                    Capsule().fill(appearance.accentColor.opacity(0.92))
                        .frame(width: geo.size.width * progress, height: 10)
                }
            }
            .frame(height: 10)

            Text(remaining >= 0
                 ? "Remaining: \(formatCurrency(remaining, currency: defaultCurrencyCode))"
                 : "Over budget: \(formatCurrency(abs(remaining), currency: defaultCurrencyCode))"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func categoryBudgetRow(title: String, spent: Double, budget: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(formatCurrency(spent, currency: defaultCurrencyCode))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            if budget > 0 {
                let progress = min(max(spent / max(budget, 0.01), 0), 1)
                let remaining = budget - spent

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.pillTint.opacity(0.55)).frame(height: 8)
                        Capsule().fill(appearance.accentColor.opacity(0.92))
                            .frame(width: geo.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)

                Text(remaining >= 0
                     ? "Budget \(formatCurrency(budget, currency: defaultCurrencyCode)) • Remaining \(formatCurrency(remaining, currency: defaultCurrencyCode))"
                     : "Budget \(formatCurrency(budget, currency: defaultCurrencyCode)) • Over \(formatCurrency(abs(remaining), currency: defaultCurrencyCode))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("No budget set for this category.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Activity helpers

    private func badgeForEntry(_ e: ExpenseEntry) -> String? {
        if isSuperchargingEntry(e) { return "Supercharging" }
        if isLeaseOrCarPayment(e) { return "Payment" }
        if isInsurance(e) { return "Insurance" }
        return nil
    }

    private func activityRow(title: String, subtitle: String, trailing: String, badge: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(appearance.accentColor.opacity(0.85))
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(theme.pillTint.opacity(0.85)))
                    }
                }

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(trailing)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Dashboard summaries (lightweight)

    private struct SchedulePlannerSummary {
        static func windowText() -> String {
            let start = UserDefaults.standard.integer(forKey: "planner.offPeakStart")
            let end = UserDefaults.standard.integer(forKey: "planner.offPeakEnd")
            return "\(hourLabel(start)) → \(hourLabel(end))"
        }

        static func estimate(from entries: [ExpenseEntry]) -> String? {
            let offPeakRate = UserDefaults.standard.double(forKey: "planner.offPeakRate")
            let peakRate = UserDefaults.standard.double(forKey: "planner.peakRate")
            guard offPeakRate > 0, peakRate > 0 else { return nil }

            let recent = entries.sorted { $0.date > $1.date }.prefix(12)
            let kwh = recent.compactMap { $0.energyAddedKWh }.filter { $0 > 0 }
            let avg = kwh.isEmpty ? nil : kwh.reduce(0, +) / Double(kwh.count)
            guard let avg else { return nil }

            let off = avg * offPeakRate
            let peak = avg * peakRate
            let savings = max(0, peak - off)
            let currency = Locale.current.currency?.identifier ?? "USD"
            return "Estimated savings per session: \(savings.formatted(.currency(code: currency)))"
        }

        private static func hourLabel(_ hour: Int) -> String {
            let h = (hour % 24 + 24) % 24
            let suffix = h < 12 ? "AM" : "PM"
            let hour12 = h % 12 == 0 ? 12 : h % 12
            return "\(hour12)\(suffix)"
        }
    }

    // MARK: - Theme primitives

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
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(theme.pillTint.opacity(0.85)))
    }

    private func spendRow(_ title: String, _ amount: Double) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(formatCurrency(amount, currency: defaultCurrencyCode))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .font(.subheadline)
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statsGrid(_ items: [(String, String)]) -> some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 10, alignment: .leading),
            count: isAccessibilitySize ? 1 : 2
        )

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                statBlock(title: item.0, value: item.1)
            }
        }
    }

    private func actionRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.pillTint.opacity(scheme == .dark ? 0.22 : 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(theme.separator.opacity(scheme == .dark ? 0.78 : 0.55), lineWidth: 1)
                    )

                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(appearance.accentColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Formatting

    private func formatCurrency(_ amount: Double, currency: String) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = currency
        nf.maximumFractionDigits = 2
        return nf.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }

    private func formatNumber(_ value: Double, digits: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = digits
        nf.minimumFractionDigits = 0
        return nf.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func dateTime(_ d: Date) -> String {
        Self.df.string(from: d)
    }

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
}

// MARK: - Budget Settings Sheet (clear labels + explanations)

@MainActor
private struct BudgetSettingsSheet: View {
    let currencyCode: String

    @Binding var useCategoryBudgets: Bool
    @Binding var overallBudget: Double

    @Binding var budgetSupercharging: Double
    @Binding var budgetLease: Double
    @Binding var budgetInsurance: Double
    @Binding var budgetMisc: Double

    let spentSupercharging: Double
    let spentLease: Double
    let spentInsurance: Double
    let spentMisc: Double

    @Environment(\.dismiss) private var dismiss

    @State private var draftUseCategories: Bool = false
    @State private var draftOverall: Double = 0

    @State private var draftSC: Double = 0
    @State private var draftLease: Double = 0
    @State private var draftIns: Double = 0
    @State private var draftMisc: Double = 0

    private var totalCats: Double {
        max(0, draftSC) + max(0, draftLease) + max(0, draftIns) + max(0, draftMisc)
    }

    private enum BudgetCat {
        case supercharging, lease, insurance, misc

        var title: String {
            switch self {
            case .supercharging: return "Supercharging"
            case .lease: return "Lease / Car Payment"
            case .insurance: return "Insurance"
            case .misc: return "Misc"
            }
        }

        var systemImage: String {
            switch self {
            case .supercharging: return "bolt.car"
            case .lease: return "creditcard"
            case .insurance: return "shield"
            case .misc: return "square.grid.2x2"
            }
        }

        var help: String {
            switch self {
            case .supercharging:
                return "Fast charging sessions. Uses TeslaFi session cost when available, plus any Entries tagged as supercharging/DCFC."
            case .lease:
                return "Entries whose category/notes mention lease, car payment, auto loan, financing, or lender keywords."
            case .insurance:
                return "Entries whose category/notes mention insurance (and common insurer names)."
            case .misc:
                return "Everything else this month that isn’t classified above."
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {

                Section(
                    header: Text("Mode"),
                    footer: Text("Per-category budgets match the Dashboard buckets so you always know what you’re editing.")
                ) {
                    Toggle("Use per-category budgets", isOn: $draftUseCategories)
                }

                if draftUseCategories {

                    Section(
                        header: Text("Total Budget (optional)"),
                        footer: Text("Used only for quick allocation (Split evenly). Your actual limits come from the category budgets below.")
                    ) {
                        LabeledContent("Total budget") {
                            TextField("0", value: $draftOverall, format: .currency(code: currencyCode))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                        }

                        Button("Split total budget evenly across categories") {
                            let total = max(0, draftOverall)
                            let each = total / 4.0
                            draftSC = each
                            draftLease = each
                            draftIns = each
                            draftMisc = each
                        }
                        .disabled(draftOverall <= 0)
                    }

                    Section(
                        header: Text("Category Budgets"),
                        footer: Text("Each row shows what the category includes and what you’ve spent this month.")
                    ) {
                        categoryRow(.supercharging, budget: $draftSC, spent: spentSupercharging)
                        categoryRow(.lease, budget: $draftLease, spent: spentLease)
                        categoryRow(.insurance, budget: $draftIns, spent: spentInsurance)
                        categoryRow(.misc, budget: $draftMisc, spent: spentMisc)

                        LabeledContent("Total (categories)") {
                            Text(formattedCurrency(totalCats))
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            draftSC = 0; draftLease = 0; draftIns = 0; draftMisc = 0
                        } label: {
                            Text("Clear category budgets")
                        }
                    }

                } else {

                    Section(
                        header: Text("Overall Monthly Budget"),
                        footer: Text("Used when per-category budgets are disabled.")
                    ) {
                        LabeledContent("Monthly budget") {
                            TextField("0", value: $draftOverall, format: .currency(code: currencyCode))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                        }

                        LabeledContent("Spent this month (Dashboard buckets)") {
                            Text(formattedCurrency(spentSupercharging + spentLease + spentInsurance + spentMisc))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            draftOverall = 0
                        } label: {
                            Text("Clear overall budget")
                        }
                    }
                }
            }
            .navigationTitle("Budgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        useCategoryBudgets = draftUseCategories
                        overallBudget = max(0, draftOverall)

                        budgetSupercharging = max(0, draftSC)
                        budgetLease = max(0, draftLease)
                        budgetInsurance = max(0, draftIns)
                        budgetMisc = max(0, draftMisc)

                        dismiss()
                    }
                }
            }
            .onAppear {
                draftUseCategories = useCategoryBudgets
                draftOverall = overallBudget

                draftSC = budgetSupercharging
                draftLease = budgetLease
                draftIns = budgetInsurance
                draftMisc = budgetMisc
            }
        }
    }

    @ViewBuilder
    private func categoryRow(_ cat: BudgetCat, budget: Binding<Double>, spent: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(cat.title, systemImage: cat.systemImage)
                    .font(.headline)

                Spacer()

                TextField("0", value: budget, format: .currency(code: currencyCode))
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(minWidth: 120)
            }

            Text(cat.help)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("Spent this month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formattedCurrency(spent))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Stepper("Adjust \(cat.title)", value: budget, in: 0...100_000, step: 25)
                .font(.footnote)
        }
        .padding(.vertical, 6)
    }

    private func formattedCurrency(_ amount: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = currencyCode
        nf.maximumFractionDigits = 2
        return nf.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
}
