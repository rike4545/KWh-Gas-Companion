import SwiftUI
#if canImport(Charts)
import Charts
#endif

/// Summarizes fast DCFC ("supercharger") expense entries with filters, charts, and export.
struct CombinedChargeSessionView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var profileStore: ProfileStore

    /// If nil, includes all vehicles. Pass a vehicle ID to scope results.
    let vehicleID: UUID?

    // MARK: - Filters
    @State private var quickRange: QuickRange = .last12mo
    @State private var dateRange: ClosedRange<Date>? = nil   // custom
    @State private var showingDateSheet = false
    @State private var scope: ScopeFilter = .all             // all / personal / business

    // MARK: - Derived

    private var currencyCode: String { profileStore.currencyCode }

    private var activeRange: ClosedRange<Date>? {
        switch quickRange {
        case .custom: return dateRange
        default: return quickRange.computeRange(reference: Date())
        }
    }

    /// Only include fast DCFC sessions; apply vehicle, scope, and date filters.
    private var filteredSessions: [ExpenseEntry] {
        entriesStore
            .entries
            .filter { $0.category == ExpenseCategory.fastDCFC.rawValue }
            .filter { vehicleID == nil || $0.vehicleID == vehicleID }
            .filter { scope.predicate($0) }
            .filter { r in
                guard let ar = activeRange else { return true }
                return ar.contains(r.date)
            }
            .sorted(by: { $0.date > $1.date })
    }

    // MARK: - Stats

    private var totalCost: Double {
        filteredSessions.reduce(0) { $0 + $1.amount }
    }

    private var totalKWh: Double {
        filteredSessions.reduce(0) { $0 + max(0, $1.energyKWh ?? 0) }
    }

    private var avgPricePerKWh: Double? {
        let kWh = totalKWh
        guard kWh > 0 else { return nil }
        return totalCost / kWh
    }

    private var avgCostPerSession: Double? {
        guard !filteredSessions.isEmpty else { return nil }
        return totalCost / Double(filteredSessions.count)
    }

    // MARK: - Init

    init(vehicleID: UUID? = nil) {
        self.vehicleID = vehicleID
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                summaryStrip
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        filterChips

                        if filteredSessions.isEmpty {
                            ContentUnavailableView(
                                "No DC Fast Charging",
                                systemImage: "bolt.fill",
                                description: Text("Add fast-charging entries or adjust filters.")
                            )
                            .padding(.horizontal)
                            Spacer(minLength: 32)
                        } else {
                            chartsSection
                            sessionsList
                            Spacer(minLength: 32)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Supercharger Sessions")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Scope", selection: $scope) {
                            ForEach(ScopeFilter.allCases, id: \.self) { s in
                                Label(s.title, systemImage: s.icon).tag(s)
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
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: exportCSVFile(),
                              preview: .init("DCFC Sessions CSV"))
                }
            }
            .sheet(isPresented: $showingDateSheet) {
                DCFCDateRangeSheet(dateRange: $dateRange)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Sticky Summary

    private var summaryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(title: "\(filteredSessions.count) sessions", icon: "bolt.car")
                chip(title: totalCost.formattedCurrency(code: currencyCode), icon: "sum")
                if totalKWh > 0 {
                    chip(title: String(format: "%.0f kWh", totalKWh), icon: "bolt.fill")
                }
                if let p = avgPricePerKWh {
                    chip(title: "\(p.formattedCurrency(code: currencyCode))/kWh", icon: "dollarsign")
                }
                if let a = avgCostPerSession {
                    chip(title: "\(a.formattedCurrency(code: currencyCode))/session", icon: "dollarsign.arrow.circlepath")
                }
                if let ar = activeRange {
                    chip(title: dateLabel(ar), icon: "calendar")
                } else {
                    chip(title: quickRange.title, icon: "calendar")
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
        .accessibilityElement(children: .contain)
    }

    private func chip(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).imageScale(.small)
            Text(title).font(.footnote).monospacedDigit()
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .accessibilityLabel(title)
    }

    // MARK: - Header + Chips

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Fast DC Charging")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text(vehicleID == nil ? "All Vehicles" : "Selected Vehicle")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(QuickRange.allCases, id: \.self) { q in
                    Button {
                        if q == .custom {
                            quickRange = .custom
                            showingDateSheet = true
                        } else {
                            quickRange = q
                            if dateRange != nil { dateRange = nil }
                        }
                    } label: {
                        Text(q.title)
                            .font(.footnote.weight(q == quickRange ? .semibold : .regular))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(q == quickRange ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(q.title)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, -6)
    }

    // MARK: - Charts

    @ViewBuilder
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            #if canImport(Charts)
            // Monthly spend
            let cal = Calendar.current
            let monthlySpend = Dictionary(grouping: filteredSessions, by: {
                cal.dateInterval(of: .month, for: $0.date)?.start ?? $0.date
            })
            .map { (month: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.month < $1.month }

            if !monthlySpend.isEmpty {
                Text("Monthly Spend").font(.title3.bold()).padding(.horizontal)
                Chart(monthlySpend, id: \.month) { item in
                    LineMark(
                        x: .value("Month", item.month),
                        y: .value("Total", item.total)
                    )
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("Month", item.month),
                        y: .value("Total", item.total)
                    )
                    .accessibilityLabel(monthShort(item.month))
                    .accessibilityValue(item.total.formattedCurrency(code: currencyCode))
                }
                .frame(height: 220)
                .padding(.horizontal)
                .chartYAxis { AxisMarks(position: .leading) }
            }

            // Price per kWh trend (if kWh present)
            let perKWh = filteredSessions.compactMap { e -> (Date, Double)? in
                guard let k = e.energyKWh, k > 0 else { return nil }
                return (e.date, e.amount / k)
            }
            .sorted { $0.0 < $1.0 }

            if !perKWh.isEmpty {
                Text("Price per kWh").font(.title3.bold()).padding(.horizontal)
                Chart(perKWh, id: \.0) { item in
                    LineMark(
                        x: .value("Date", item.0),
                        y: .value("$/kWh", item.1)
                    )
                    PointMark(
                        x: .value("Date", item.0),
                        y: .value("$/kWh", item.1)
                    )
                    .accessibilityLabel(item.0.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityValue((item.1).formattedCurrency(code: currencyCode))
                }
                .frame(height: 220)
                .padding(.horizontal)
                .chartYAxis { AxisMarks(position: .leading) }
            }
            #else
            // Fallback if Charts isn’t available
            HStack {
                Image(systemName: "chart.xyaxis.line")
                Text("Charts unavailable on this platform.")
                Spacer()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            #endif
        }
    }

    // MARK: - Sessions List (grouped by month)

    @ViewBuilder
    private var sessionsList: some View {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filteredSessions, by: {
            cal.dateInterval(of: .month, for: $0.date)?.start ?? $0.date
        })
        let sections = grouped
            .map { (month: $0.key, rows: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.month > $1.month } // newest month first

        VStack(alignment: .leading, spacing: 8) {
            ForEach(sections, id: \.month) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(monthShort(section.month))
                        .font(.headline)
                        .padding(.horizontal)
                    ForEach(section.rows) { entry in
                        SessionRow(entry: entry, currencyCode: currencyCode)
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                            .background(.thinMaterial, in: .rect(cornerRadius: 10))
                            .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - CSV Export

    private func exportCSV() -> String {
        var lines: [String] = []
        lines.append("Date,Amount,Currency,kWh,Location,VehicleID,Category,Notes")
        let df = ISO8601DateFormatter()
        df.timeZone = .current
        for e in filteredSessions {
            let date = df.string(from: e.date)
            let amount = String(format: "%.2f", e.amount)
            let kWh = e.energyKWh.map { String(format: "%.3f", max(0,$0)) } ?? ""
            let loc = "" // `ExpenseEntry` has no `locationName`; keep column for compatibility
            let vehicleCol = e.vehicleID?.uuidString ?? ""   // FIX: optional vehicleID
            let notes = (e.notes ?? "").csvEscaped
            lines.append("\(date),\(amount),\(currencyCode),\(kWh),\(loc),\(vehicleCol),\(e.category.csvEscaped),\(notes)")
        }
        return lines.joined(separator: "\n")
    }

    /// Write CSV to a temp file and return the URL so ShareLink can export it reliably.
    private func exportCSVFile() -> URL {
        let csv = exportCSV()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DCFC_Sessions_\(Int(Date().timeIntervalSince1970)).csv")
        do {
            try csv.data(using: .utf8)?.write(to: url)
        } catch {
            // best-effort: still return URL; ShareSheet will fail gracefully if unreadable
        }
        return url
    }
}

// MARK: - Row

private struct SessionRow: View {
    let entry: ExpenseEntry
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date, style: .date)
                    .font(.subheadline.bold())
                HStack(spacing: 8) {
                    if let k = entry.energyKWh, k > 0 {
                        Text(String(format: "%.1f kWh", k))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    // Show category (since `locationName` doesn't exist)
                    if !entry.category.isEmpty {
                        Text("• \(entry.category)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if entry.isBusiness {
                        Text("• Business")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.amount, format: .currency(code: currencyCode))
                    .font(.headline).monospacedDigit()
                if let k = entry.energyKWh, k > 0 {
                    let unit = entry.amount / max(0.0001, k)
                    Text("\(unit.formattedCurrency(code: currencyCode))/kWh")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(entry.date.formatted(date: .abbreviated, time: .omitted)) " +
            "\(entry.amount.formattedCurrency(code: currencyCode))"
        )
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

    func computeRange(reference: Date) -> ClosedRange<Date>? {
        let cal = Calendar.current
        switch self {
        case .allTime, .custom:
            return nil
        case .last12mo:
            let end = reference
            guard let start = cal.date(byAdding: .month, value: -12, to: end) else { return nil }
            return start...end
        case .ytd:
            let comps = cal.dateComponents([.year], from: reference)
            guard let start = cal.date(from: DateComponents(year: comps.year, month: 1, day: 1)) else { return nil }
            return start...reference
        case .last90d:
            let end = reference
            guard let start = cal.date(byAdding: .day, value: -90, to: end) else { return nil }
            return start...end
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

// MARK: - Date Range Sheet  (renamed to avoid clashes)

fileprivate struct DCFCDateRangeSheet: View {
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
                    Text("Pick a start and end date to filter sessions.")
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

fileprivate enum _FmtCacheSC {
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

fileprivate func monthShort(_ d: Date) -> String {
    _FmtCacheSC.month.string(from: d)
}

fileprivate func dateLabel(_ r: ClosedRange<Date>) -> String {
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .none
    return "\(df.string(from: r.lowerBound)) – \(df.string(from: r.upperBound))"
}

fileprivate extension String {
    var csvEscaped: String {
        guard self.contains(",") || self.contains("\"") || self.contains("\n") else { return self }
        return "\"\(self.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

fileprivate extension Double {
    func formattedCurrency(code: String) -> String {
        let nf = _FmtCacheSC.currency
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

#if DEBUG
struct CombinedChargeSessionView_Previews: PreviewProvider {
    static var previews: some View {
        CombinedChargeSessionView(vehicleID: nil)
            .environmentObject(EntriesStore())
            .environmentObject(ProfileStore())
    }
}
#endif
