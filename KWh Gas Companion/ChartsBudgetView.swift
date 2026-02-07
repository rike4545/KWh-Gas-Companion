//
//  ChartsBudgetView.swift — My KWh Companion
//  Budget editor with Tesla-styled cards + compile-safe entry bridging
//
//  Fixes vs prior draft:
//  - FocusState actually attaches to the TextFields (so autosave-on-blur works)
//  - Avoids `onChange(of: entriesStore.entries)` requiring `ExpenseEntry: Equatable`
//  - Safer Mirror bridging (no generic inference failures)
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import UIKit
import Combine

// MARK: - Focus keys (file-scope so subviews can use them)

fileprivate enum BudgetField: Hashable {
    case energy
    case nonEnergy
    case category(String)
}

@MainActor
struct ChartsBudgetView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var budgetStore: BudgetStore
    @Environment(\.locale) private var locale

    // Current month to view/edit
    @State private var ym: YearMonth = YearMonth.from(Date())
    @State private var showMonthPicker = false

    // Editable numeric budgets (locale-aware via .currency)
    @State private var energyBudget: Double = 0
    @State private var nonEnergyBudget: Double = 0

    // Category budgets (edited as currency, stored as Double)
    @State private var categoryBudgetValues: [String: Double] = [:]   // category -> value

    // Toast & focus
    @State private var showSaved = false
    @FocusState private var focus: BudgetField?

    private var code: String { Locale.current.currency?.identifier ?? "USD" }

    var body: some View {
        NavigationStack {
            ZStack {
                BG().ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        header.padding(.horizontal)
                        spendSummary.padding(.horizontal)
                        budgetInsights.padding(.horizontal)
                        categoryVarianceCard.padding(.horizontal)
                        energyNonEnergyCard.padding(.horizontal)
                        categoryCard
                            .padding([.horizontal, .bottom])
                            .padding(.bottom, 24)
                    }
                    .frame(maxWidth: 1000)
                    .frame(maxWidth: .infinity)
                }

                // Floating "Saved" badge overlay
                SavedBadge(show: showSaved)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            .navigationTitle("Charts & Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(showSaved ? .green : .clear)
                        .animation(.easeInOut(duration: 0.2), value: showSaved)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focus = nil }
                }
            }
        }
        .task {
            budgetStore.createPlanIfMissing(for: ym, entries: entriesStore.entries)
            loadEditorsFromPlan()
        }
        .onChange(of: ym) { _, _ in
            budgetStore.createPlanIfMissing(for: ym, entries: entriesStore.entries)
            loadEditorsFromPlan()
        }
        // Avoid requiring ExpenseEntry: Equatable
        .onReceive(entriesStore.objectWillChange) { _ in
            // Keep category suggestions + placeholders current.
            budgetStore.createPlanIfMissing(for: ym, entries: entriesStore.entries)
            loadEditorsFromPlan()
        }
        .onChange(of: locale) { _, _ in
            loadEditorsFromPlan()
        }
        // Autosave when any field loses focus
        .onChange(of: focus) { _, newFocus in
            guard newFocus == nil else { return }
            autosaveAll()
        }
    }

    // MARK: Header

    private var header: some View {
        SettingsCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Budget Planner").font(.title3.weight(.semibold))
                    Text(monthTitle(ym)).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        ym = shift(ym, months: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        ym = shift(ym, months: +1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showMonthPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text(monthTitle(ym))
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showMonthPicker) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Pick Month").font(.headline)
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { ym.startDate() ?? Date() },
                                    set: { ym = YearMonth.from($0) }
                                ),
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                            .labelsHidden()

                            Button("Done") { showMonthPicker = false }
                                .padding(.top)
                        }
                        .padding()
                        .presentationDetents([.height(420)])
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Budget Planner for \(monthTitle(ym))")
    }

    // MARK: Spend summary

    private var spendSummary: some View {
        let energy = budgetStore.totalEnergySpend(in: ym, entries: entriesStore.entries)
        let nonEnergy = budgetStore.totalNonEnergySpend(in: ym, entries: entriesStore.entries)
        let total = energy + nonEnergy

        return SettingsCard(title: "This Month’s Spend", subtitle: monthTitle(ym)) {
            HStack(spacing: 12) {
                StatTile(icon: "bolt.fill", title: "Energy", value: currency(energy, code), tint: .green)
                    .accessibilityLabel("Energy spend \(currency(energy, code))")
                StatTile(icon: "cart.fill", title: "Non-Energy", value: currency(nonEnergy, code), tint: .pink)
                    .accessibilityLabel("Non-energy spend \(currency(nonEnergy, code))")
                StatTile(icon: "sum", title: "Total", value: currency(total, code), tint: .indigo)
                    .accessibilityLabel("Total spend \(currency(total, code))")
            }
        }
    }

    private var budgetInsights: some View {
        let plan = budgetStore.displayPlan(for: ym, entries: entriesStore.entries)
        let energy = budgetStore.totalEnergySpend(in: ym, entries: entriesStore.entries)
        let nonEnergy = budgetStore.totalNonEnergySpend(in: ym, entries: entriesStore.entries)
        let total = energy + nonEnergy
        let budgetTotal = max(0, plan.energyBudget) + max(0, plan.nonEnergyBudget)

        let calendar = Calendar.current
        let now = Date()
        let start = ym.startDate(calendar: calendar) ?? now
        let daysInMonth = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        let day = calendar.component(.day, from: now)
        let daysElapsed = max(1, min(day, daysInMonth))
        let daysRemaining = max(0, daysInMonth - daysElapsed)
        let projected = (total / Double(daysElapsed)) * Double(daysInMonth)
        let remaining = budgetTotal - total
        let neededPerDay = daysRemaining > 0 ? (remaining / Double(daysRemaining)) : 0

        return SettingsCard(title: "Budget Insights", subtitle: monthTitle(ym)) {
            VStack(spacing: 10) {
                HStack {
                    Text("Projected total")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currency(projected, code))
                        .font(.headline)
                        .foregroundStyle(projected <= budgetTotal || budgetTotal == 0 ? .green : .red)
                }

                if budgetTotal > 0 {
                    HStack {
                        Text(remaining >= 0 ? "Remaining" : "Over budget")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(currency(abs(remaining), code))
                            .font(.headline)
                            .foregroundColor(remaining >= 0 ? .green : .red)
                    }

                    HStack {
                        Text("Needed / day")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(currency(neededPerDay, code))
                            .font(.headline)
                            .foregroundColor(neededPerDay >= 0 ? .secondary : .red)
                    }
                    .font(.footnote)
                } else {
                    Text("Set budgets to see variance and pacing guidance.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
        }
    }

    // MARK: Energy / Non-Energy budgets card

    private var energyNonEnergyCard: some View {
        let plan = budgetStore.displayPlan(for: ym, entries: entriesStore.entries)
        let energySpend = budgetStore.totalEnergySpend(in: ym, entries: entriesStore.entries)
        let nonEnergySpend = budgetStore.totalNonEnergySpend(in: ym, entries: entriesStore.entries)

        return SettingsCard(title: "Budgets") {
            VStack(spacing: 14) {
                BudgetRow(
                    label: "Energy",
                    spend: energySpend,
                    budget: $energyBudget,
                    placeholder: plan.energyBudget > 0 ? currency(plan.energyBudget, code) : "0.00",
                    code: code,
                    focus: $focus,
                    focusKey: .energy
                )

                BudgetRow(
                    label: "Non-Energy",
                    spend: nonEnergySpend,
                    budget: $nonEnergyBudget,
                    placeholder: plan.nonEnergyBudget > 0 ? currency(plan.nonEnergyBudget, code) : "0.00",
                    code: code,
                    focus: $focus,
                    focusKey: .nonEnergy
                )

                HStack {
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        autosaveTopBudgets()
                        savedToast()
                    } label: {
                        Label("Save Budgets", systemImage: "checkmark")
                            .frame(minWidth: 160)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.accentColor.opacity(0.16)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            }
        }
    }

    // MARK: Category budgets

    private var categoryCard: some View {
        let cats = suggestedCategories()
        let plan = budgetStore.displayPlan(for: ym, entries: entriesStore.entries)

        return SettingsCard(title: "Category Budgets", subtitle: "Top categories adapt each month") {
            VStack(spacing: 10) {
                ForEach(cats, id: \.self) { cat in
                    HStack(spacing: 12) {
                        Text(cat)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 12)

                        GlassMoneyField(
                            value: Binding(
                                get: { categoryBudgetValues[cat] ?? 0 },
                                set: { categoryBudgetValues[cat] = max(0, $0) }
                            ),
                            placeholder: plan.categoryBudgets[cat, default: 0] > 0
                                ? currency(plan.categoryBudgets[cat, default: 0], code)
                                : "0.00",
                            code: code,
                            focus: $focus,
                            focusKey: .category(cat)
                        )
                        .frame(maxWidth: 160)
                        .overlay(alignment: .trailing) {
                            if (categoryBudgetValues[cat] ?? 0) > 0 {
                                Button {
                                    categoryBudgetValues[cat] = 0
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.trailing, 6)
                            }
                        }
                        .accessibilityLabel("\(cat) budget")
                        .accessibilityValue(currency(categoryBudgetValues[cat] ?? 0, code))
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        autosaveCategories(cats: cats)
                        savedToast()
                    } label: {
                        Label("Save Category Budgets", systemImage: "checkmark")
                            .frame(minWidth: 200)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.accentColor.opacity(0.16)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            }
        }
    }

    private var categoryVarianceCard: some View {
        let plan = budgetStore.displayPlan(for: ym, entries: entriesStore.entries)
        let cats = suggestedCategories()
        let rows: [BudgetVariance] = cats.compactMap { cat in
            let budget = plan.categoryBudgets[cat, default: 0]
            guard budget > 0 else { return nil }
            let spent = budgetStore.totalForCategory(in: ym, category: cat, entries: entriesStore.entries)
            let variance = spent - budget
            return BudgetVariance(category: cat, budget: budget, spent: spent, variance: variance)
        }

        let over = rows.filter { $0.variance > 0 }.sorted { $0.variance > $1.variance }.prefix(3)
        let under = rows.filter { $0.variance <= 0 }.sorted { $0.variance < $1.variance }.prefix(3)

        return SettingsCard(title: "Category Variance", subtitle: "Over/under budget") {
            if rows.isEmpty {
                Text("Set category budgets to see variance.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                if !over.isEmpty {
                    Text("Over budget")
                        .font(.footnote.weight(.semibold))
                    ForEach(over, id: \.category) { r in
                        varianceRow(r)
                    }
                }

                if !under.isEmpty {
                    if !over.isEmpty { Divider().padding(.vertical, 4) }
                    Text("Under budget")
                        .font(.footnote.weight(.semibold))
                    ForEach(under, id: \.category) { r in
                        varianceRow(r)
                    }
                }
            }
        }
    }

    // MARK: State sync

    private func loadEditorsFromPlan() {
        let p = budgetStore.displayPlan(for: ym, entries: entriesStore.entries)
        energyBudget    = max(0, p.energyBudget)
        nonEnergyBudget = max(0, p.nonEnergyBudget)

        var map: [String: Double] = [:]
        for cat in suggestedCategories() {
            map[cat] = max(0, p.categoryBudgets[cat] ?? 0)
        }
        categoryBudgetValues = map
    }

    // MARK: Helpers (saving, data, formatting)

    private func autosaveTopBudgets() {
        budgetStore.setEnergyBudget(for: ym, to: max(0, energyBudget))
        budgetStore.setNonEnergyBudget(for: ym, to: max(0, nonEnergyBudget))
    }

    private func autosaveCategories(cats: [String]) {
        for cat in cats {
            let v = max(0, categoryBudgetValues[cat] ?? 0)
            budgetStore.setCategoryBudget(for: ym, category: cat, to: v)
        }
    }

    private func autosaveAll() {
        autosaveTopBudgets()
        autosaveCategories(cats: suggestedCategories())
        savedToast()
    }

    private func savedToast() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { showSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.25)) { showSaved = false }
        }
    }

    private func suggestedCategories() -> [String] {
        // Union of existing plan keys + top spend categories over last 3 months; cap 5
        let p = budgetStore.displayPlan(for: ym, entries: entriesStore.entries)
        var set = Set(p.categoryBudgets.keys)

        let cal = Calendar.current
        guard let base = ym.startDate(calendar: cal) else {
            return Array(set).sorted().prefix(5).map { $0 }
        }

        var months: [YearMonth] = []
        for i in 1...3 {
            if let d = cal.date(byAdding: .month, value: -i, to: base) {
                months.append(YearMonth.from(d, calendar: cal))
            }
        }

        var spend: [String: Double] = [:]
        for m in months {
            let range = m.monthRange(cal)
            for e in entriesStore.entries where range.contains(e._date) {
                let cat = e._categoryString
                let amt = e._amount
                guard !cat.isEmpty, amt > 0 else { continue }
                spend[cat, default: 0] += amt
            }
        }

        let top = spend.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
        set.formUnion(top)
        return Array(set).sorted().prefix(5).map { $0 }
    }

    private func shift(_ ym: YearMonth, months: Int) -> YearMonth {
        let cal = Calendar.current
        let start = ym.startDate(calendar: cal) ?? Date()
        let next  = cal.date(byAdding: .month, value: months, to: start) ?? start
        return YearMonth.from(next, calendar: cal)
    }

    private func monthTitle(_ ym: YearMonth) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: ym.startDate() ?? Date())
    }

    private func currency(_ v: Double, _ code: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        return f.string(from: NSNumber(value: v)) ?? String(format: "$%.2f", v)
    }

    private func varianceRow(_ r: BudgetVariance) -> some View {
        HStack {
            Text(r.category)
                .lineLimit(1)
            Spacer()
            Text(currency(r.spent, code))
                .foregroundStyle(.secondary)
            Text(r.variance >= 0 ? "+\(currency(r.variance, code))" : currency(r.variance, code))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(r.variance > 0 ? .red : .green)
        }
        .font(.footnote)
    }
}

// MARK: - Subviews

fileprivate struct SavedBadge: View {
    let show: Bool
    var body: some View {
        Label("Saved", systemImage: "checkmark.circle.fill")
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : -12)
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: show)
    }
}

fileprivate struct StatTile: View {
    var icon: String
    var title: String
    var value: String
    var tint: Color = .red

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .shadow(color: tint.opacity(0.35), radius: 6, x: 0, y: 2)
            }
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

fileprivate struct BudgetRow: View {
    let label: String
    let spend: Double
    @Binding var budget: Double
    let placeholder: String
    let code: String

    @FocusState.Binding var focus: BudgetField?
    let focusKey: BudgetField

    private var percent: Double {
        guard budget > 0 else { return 0 }
        return spend / max(budget, 0.0001)
    }
    private var progressTint: Color {
        if percent < 0.8 { return .green }
        if percent < 1.0 { return .yellow }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(label)
                Spacer()

                GlassMoneyField(
                    value: $budget,
                    placeholder: placeholder,
                    code: code,
                    focus: $focus,
                    focusKey: focusKey
                )
                .frame(maxWidth: 160)
                .overlay(alignment: .trailing) {
                    if budget > 0 {
                        Button { budget = 0 } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.trailing, 6)
                    }
                }
            }

            let total = max(max(budget, spend), 1)
            ProgressView(value: min(spend, total), total: total)
                .tint(progressTint)

            HStack {
                Text(currency(spend, code))
                Spacer()
                Group {
                    if budget <= 0 {
                        Text("No budget set")
                    } else if percent >= 1 {
                        Label("Over budget", systemImage: "exclamationmark.triangle.fill")
                    } else {
                        Text("\(Int(percent * 100))% used")
                    }
                }
                .foregroundStyle(percent >= 1 ? .red : .secondary)
            }
            .font(.footnote)
            .padding(.top, 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) budget. Spent \(currency(spend, code)). Budget \(currency(budget, code)).")
    }

    private func currency(_ v: Double, _ code: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        return f.string(from: NSNumber(value: v)) ?? String(format: "$%.2f", v)
    }
}

fileprivate struct GlassMoneyField: View {
    @Binding var value: Double
    let placeholder: String
    let code: String

    @FocusState.Binding var focus: BudgetField?
    let focusKey: BudgetField

    var body: some View {
        TextField(placeholder, value: $value, format: .currency(code: code))
            .keyboardType(.decimalPad)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .focused($focus, equals: focusKey)
    }
}

fileprivate struct BudgetVariance {
    let category: String
    let budget: Double
    let spent: Double
    let variance: Double
}

// MARK: - Card shells / background

fileprivate struct BG: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color.black, Color(white: 0.12)]
                : [Color(white: 0.98), Color(white: 0.92)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

fileprivate struct SettingsCard<Content: View>: View {
    var title: String?
    var subtitle: String?
    @ViewBuilder var content: Content
    init(title: String? = nil, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.secondary) }
                }
                .padding(.bottom, 2)
            }
            content
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Compile-safe bridging for ExpenseEntry

fileprivate extension ExpenseEntry {
    var _date: Date {
        if let d: Date = Mirror._get(self, "date") { return d }
        if let d: Date = Mirror._get(self, "timestamp") { return d }
        if let t: TimeInterval = Mirror._get(self, "timeInterval") { return Date(timeIntervalSince1970: t) }
        if let s: String = Mirror._get(self, "dateString") {
            let iso = ISO8601DateFormatter()
            if let d = iso.date(from: s) { return d }
        }
        return Date.distantPast
    }

    var _amount: Double {
        if let v: Double = Mirror._get(self, "amount") { return v }
        if let v: Double = Mirror._get(self, "cost") { return v }
        if let v: Decimal = Mirror._get(self, "amount") { return (v as NSDecimalNumber).doubleValue }
        if let v: Int = Mirror._get(self, "amount") { return Double(v) }
        return 0
    }

    var _categoryString: String {
        if let s: String = Mirror._get(self, "category") {
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try to pull an arbitrary value and stringify it.
        if let anyVal = Mirror._getAny(self, "category") {
            if let s = anyVal as? String {
                return s.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let rep = anyVal as? any RawRepresentable {
                return String(describing: rep.rawValue)
            }
            return String(describing: anyVal)
        }

        return ""
    }
}

fileprivate extension Mirror {
    static func _get<T>(_ value: Any, _ label: String) -> T? {
        for child in Mirror(reflecting: value).children {
            if child.label?.lowercased() == label.lowercased() {
                return child.value as? T
            }
        }
        return nil
    }

    static func _getAny(_ value: Any, _ label: String) -> Any? {
        for child in Mirror(reflecting: value).children {
            if child.label?.lowercased() == label.lowercased() {
                return child.value
            }
        }
        return nil
    }
}
