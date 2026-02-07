import SwiftUI
#if canImport(Charts)
import Charts
#endif

/// Consolidated view displaying total cost of ownership and breakdowns by category,
/// with quick date filters and personal/business scope.
struct CombinedOwnershipView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var profileStore: ProfileStore

    /// If nil, shows all vehicles; otherwise filters by this vehicle.
    let vehicleID: UUID?

    // MARK: - Filters

    @State private var quickRange: QuickRange = .last12mo
    @State private var dateRange: ClosedRange<Date>? = nil  // custom
    @State private var showingDateSheet = false
    @State private var scope: ScopeFilter = .all            // all / personal / business

    // MARK: - Derived

    private var vehicleProfile: VehicleProfile? {
        guard let id = vehicleID else { return nil }
        return profileStore.vehicles.first(where: { $0.id == id })
    }
    private var vehicleName: String { vehicleProfile?.name ?? "All Vehicles" }
    private var currencyCode: String { profileStore.currencyCode }

    /// Effective date range from quick filter or custom.
    private var activeRange: ClosedRange<Date>? {
        switch quickRange {
        case .custom: return dateRange
        default: return quickRange.computeRange(reference: Date())
        }
    }

    /// Entries filtered by vehicle, date, and scope.
    private var filteredEntries: [ExpenseEntry] {
        entriesStore.entries.filter { e in
            // vehicle filter
            (vehicleID == nil || e.vehicleID == vehicleID) &&
            // date filter
            (activeRange == nil || activeRange!.contains(e.date)) &&
            // scope filter
            scope.predicate(e)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                summaryStrip
                ScrollView {
                    VStack(spacing: 24) {
                        header
                        quickFilters
                        // If no data, show empty state and skip heavy sections
                        if filteredEntries.isEmpty {
                            ContentUnavailableView(
                                "No entries",
                                systemImage: "tray",
                                description: Text("Add expenses or adjust filters to see ownership stats.")
                            )
                            .padding(.horizontal)
                            Spacer(minLength: 32)
                        } else {
                            overviewCards
                            categoryBreakdown
                            monthlyTrend
                            topCategoriesList
                            Spacer(minLength: 32)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Ownership")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Scope", selection: $scope) {
                            ForEach(ScopeFilter.allCases, id: \.self) { s in
                                Label(s.title, systemImage: s.icon)
                                    .tag(s)
                            }
                        }
                    } label: {
                        Label(scope.title, systemImage: scope.icon)
                    }
                    .accessibilityLabel("Scope")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        quickRange = .custom
                        showingDateSheet = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("Choose date range")
                }
            }
            .sheet(isPresented: $showingDateSheet) {
                OwnershipDateRangeSheet(dateRange: $dateRange)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Sticky Summary

    private var summaryStrip: some View {
        // Compute aggregate KPIs once here; reused in view tree
        let energyCost = filteredEntries
            .filter { $0.isEnergy || (($0.energyKWh ?? 0) > 0) }
            .reduce(0) { $0 + $1.amount }

        let nonEnergyCost = filteredEntries
            .filter { !($0.isEnergy || (($0.energyKWh ?? 0) > 0)) }
            .reduce(0) { $0 + $1.amount }

        let totalCost = energyCost + nonEnergyCost

        let milesDriven: Double? = milesAcrossVehicles(filteredEntries)
        let costPerMile: Double? = {
            guard let miles = milesDriven, miles > 0 else { return nil }
            return totalCost / miles
        }()

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                chip(title: vehicleName, icon: "car.fill")
                if let range = activeRange {
                    chip(title: dateLabel(range), icon: "calendar")
                } else {
                    chip(title: quickRange.title, icon: "calendar")
                }
                chip(title: totalCost.formattedCurrency(code: currencyCode), icon: "sum")
                if let cpm = costPerMile {
                    chip(title: "\(cpm.formattedCurrency(code: currencyCode))/mi", icon: "dollarsign.arrow.circlepath")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
        .accessibilityElement(children: .contain)
    }

    private func chip(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).imageScale(.small)
            Text(title).font(.footnote).monospacedDigit()
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .accessibilityLabel("\(title)")
    }

    // MARK: - Header / Quick Filters

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ownership")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text(vehicleName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var quickFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(QuickRange.allCases, id: \.self) { q in
                    Button {
                        if q == .custom {
                            quickRange = .custom
                            showingDateSheet = true
                        } else {
                            quickRange = q
                            // clear custom if leaving custom
                            if dateRange != nil { dateRange = nil }
                        }
                    } label: {
                        Text(q.title)
                            .font(.footnote.weight(q == quickRange ? .semibold : .regular))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(q == quickRange ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(q.accessibilityLabel)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, -6)
    }

    // MARK: - Overview Cards

    @ViewBuilder
    private var overviewCards: some View {
        // Compute once for this section
        let energyCost = filteredEntries
            .filter { $0.isEnergy || (($0.energyKWh ?? 0) > 0) }
            .reduce(0) { $0 + $1.amount }

        let nonEnergyCost = filteredEntries
            .filter { !($0.isEnergy || (($0.energyKWh ?? 0) > 0)) }
            .reduce(0) { $0 + $1.amount }

        let totalCost = energyCost + nonEnergyCost
        let milesDriven: Double? = milesAcrossVehicles(filteredEntries)
        let costPerMile: Double? = {
            guard let miles = milesDriven, miles > 0 else { return nil }
            return totalCost / miles
        }()

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                statCard(title: "Total",
                         value: totalCost.formattedCurrency(code: currencyCode),
                         symbol: "sum")
                statCard(title: "Energy",
                         value: energyCost.formattedCurrency(code: currencyCode),
                         symbol: "bolt.fill")
                statCard(title: "Non-Energy",
                         value: nonEnergyCost.formattedCurrency(code: currencyCode),
                         symbol: "wrench.and.screwdriver")
                if let miles = milesDriven {
                    statCard(title: "Miles",
                             value: String(format: "%.0f mi", miles),
                             symbol: "gauge.with.dots.needle.67percent")
                }
                if let cpm = costPerMile {
                    statCard(title: "$/mi",
                             value: cpm.formattedCurrency(code: currencyCode),
                             symbol: "dollarsign.arrow.circlepath")
                }
            }
            .padding(.horizontal)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func statCard(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .imageScale(.large)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.title3.bold()).monospacedDigit()
            }
            Spacer()
        }
        .frame(width: 160, height: 80)
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }

    // MARK: - Category Breakdown

    @ViewBuilder
    private var categoryBreakdown: some View {
        let byCategory = Dictionary(grouping: filteredEntries, by: {
            let trimmed = $0.category.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Uncategorized" : trimmed
        })
        .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
        .sorted { $0.total > $1.total }

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Category Breakdown")
                    .font(.title3.bold())
                Spacer()
                if !byCategory.isEmpty {
                    Text("Top \(min(5, byCategory.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            if byCategory.isEmpty {
                Text("No category data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                #if canImport(Charts)
                let annotated = Set(byCategory.prefix(5).map(\.category))
                Chart(byCategory.prefix(12), id: \.category) { item in
                    BarMark(
                        x: .value("Category", item.category),
                        y: .value("Total", item.total)
                    )
                    .annotation(position: .top, alignment: .center) {
                        if annotated.contains(item.category) {
                            Text(item.total.formattedCurrency(code: currencyCode))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: 240)
                .padding(.horizontal)
                .chartYAxis { AxisMarks(position: .leading) }
                #else
                VStack(spacing: 8) {
                    ForEach(byCategory.prefix(12), id: \.category) { item in
                        HStack {
                            Text(item.category)
                            Spacer()
                            Text(item.total.formattedCurrency(code: currencyCode))
                                .monospacedDigit()
                        }
                        .padding(.horizontal)
                    }
                }
                #endif
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Monthly Trend

    @ViewBuilder
    private var monthlyTrend: some View {
        let cal = Calendar.current
        let monthly = Dictionary(grouping: filteredEntries, by: {
            cal.dateInterval(of: .month, for: $0.date)?.start ?? $0.date
        })
        .map { (month: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
        .sorted { $0.month < $1.month }

        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly Trend")
                .font(.title3.bold())
                .padding(.horizontal)

            if monthly.isEmpty {
                Text("No monthly data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                #if canImport(Charts)
                Chart(monthly, id: \.month) { item in
                    LineMark(
                        x: .value("Month", item.month),
                        y: .value("Total", item.total)
                    )
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("Month", item.month),
                        y: .value("Total", item.total)
                    )
                    .accessibilityLabel("\(monthShort(item.month))")
                    .accessibilityValue(item.total.formattedCurrency(code: currencyCode))
                }
                .frame(height: 220)
                .padding(.horizontal)
                .chartYAxis { AxisMarks(position: .leading) }
                #else
                VStack(spacing: 8) {
                    ForEach(monthly, id: \.month) { item in
                        HStack {
                            Text(monthShort(item.month))
                            Spacer()
                            Text(item.total.formattedCurrency(code: currencyCode))
                                .monospacedDigit()
                        }
                        .padding(.horizontal)
                    }
                }
                #endif
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Top Categories (compact list)

    @ViewBuilder
    private var topCategoriesList: some View {
        let byCategory = Dictionary(grouping: filteredEntries, by: {
            let trimmed = $0.category.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Uncategorized" : trimmed
        })
        .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
        .sorted { $0.total > $1.total }

        if !byCategory.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Top Categories")
                    .font(.title3.bold())
                    .padding(.horizontal)

                ForEach(byCategory.prefix(5), id: \.category) { item in
                    HStack {
                        Text(item.category)
                        Spacer()
                        Text(item.total.formattedCurrency(code: currencyCode))
                            .monospacedDigit()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: .rect(cornerRadius: 10))
                    .padding(.horizontal)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.category) \(item.total.formattedCurrency(code: currencyCode))")
                }
            }
        }
    }
}

// MARK: - Quick Range + Scope

fileprivate enum QuickRange: CaseIterable {
    case allTime, last12mo, ytd, last90d, custom

    static var allCases: [QuickRange] { [.allTime, .last12mo, .ytd, .last90d, .custom] }

    var title: String {
        switch self {
        case .allTime: "All Time"
        case .last12mo: "Last 12 Mo"
        case .ytd: "YTD"
        case .last90d: "Last 90d"
        case .custom: "Custom"
        }
    }

    var accessibilityLabel: String { title }

    func computeRange(reference: Date) -> ClosedRange<Date>? {
        let cal = Calendar.current
        switch self {
        case .allTime:
            return nil
        case .last12mo:
            let end = reference
            guard let start = cal.date(byAdding: .month, value: -12, to: end) else { return nil }
            return start...end
        case .ytd:
            let comps = cal.dateComponents([.year], from: reference)
            guard let startOfYear = cal.date(from: DateComponents(year: comps.year, month: 1, day: 1)) else { return nil }
            return startOfYear...reference
        case .last90d:
            let end = reference
            guard let start = cal.date(byAdding: .day, value: -90, to: end) else { return nil }
            return start...end
        case .custom:
            return nil
        }
    }
}

fileprivate enum ScopeFilter: CaseIterable {
    case all, personal, business

    var title: String {
        switch self {
        case .all: "All"
        case .personal: "Personal"
        case .business: "Business"
        }
    }

    var icon: String {
        switch self {
        case .all: "line.3.horizontal.decrease.circle"
        case .personal: "person"
        case .business: "briefcase"
        }
    }

    func predicate(_ e: ExpenseEntry) -> Bool {
        switch self {
        case .all: true
        case .personal: e.isBusiness == false
        case .business: e.isBusiness == true
        }
    }
}

// MARK: - Date Range Sheet (self-contained, unique name)

fileprivate struct OwnershipDateRangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var dateRange: ClosedRange<Date>?

    @State private var localStart: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var localEnd: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Start", selection: $localStart, displayedComponents: .date)
                    DatePicker("End", selection: $localEnd, in: localStart..., displayedComponents: .date)
                } footer: {
                    Text("Pick a start and end date to filter entries.")
                }

                if let r = dateRange {
                    Section("Current Range") {
                        Text("\(r.lowerBound.formatted(date: .abbreviated, time: .omitted)) – \(r.upperBound.formatted(date: .abbreviated, time: .omitted))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Date Range")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear") { dateRange = nil; dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        dateRange = min(localStart, localEnd)...max(localStart, localEnd)
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let r = dateRange {
                    localStart = r.lowerBound
                    localEnd = r.upperBound
                }
            }
        }
    }
}

// MARK: - Helpers

private enum _FmtCache {
    static let currency: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.maximumFractionDigits = 2
        nf.minimumFractionDigits = 0
        return nf
    }()
    static let month: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM yyyy"
        return df
    }()
}

fileprivate func dateLabel(_ r: ClosedRange<Date>) -> String {
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .none
    return "\(df.string(from: r.lowerBound)) – \(df.string(from: r.upperBound))"
}

fileprivate func monthShort(_ d: Date) -> String {
    _FmtCache.month.string(from: d)
}

fileprivate extension Double {
    func formattedCurrency(code: String) -> String {
        let nf = _FmtCache.currency
        if code.isEmpty {
            if #available(iOS 16.0, *) {
                nf.currencyCode = Locale.current.currency?.identifier ?? "USD"
            } else {
                nf.currencyCode = Locale.current.currencyCode ?? "USD"
            }
        } else {
            nf.currencyCode = code
        }
        return nf.string(from: NSNumber(value: self)) ?? String(format: "$%.2f", self)
    }
}

/// Accurate miles when multiple vehicles are present:
/// compute delta per-vehicle and sum positives (ignores missing/unsorted odometers).
fileprivate func milesAcrossVehicles(_ entries: [ExpenseEntry]) -> Double? {
    let groups = Dictionary(grouping: entries, by: { $0.vehicleID })
    var sum: Double = 0
    var any = false
    for (_, group) in groups {
        let odos = group.compactMap { $0.odometer }.sorted()
        if let first = odos.first, let last = odos.last, last > first {
            sum += (last - first)
            any = true
        }
    }
    return any ? sum : nil
}

#if DEBUG
struct CombinedOwnershipView_Previews: PreviewProvider {
    static var previews: some View {
        CombinedOwnershipView(vehicleID: nil)
            .environmentObject(ProfileStore())
            .environmentObject(EntriesStore())
    }
}
#endif
