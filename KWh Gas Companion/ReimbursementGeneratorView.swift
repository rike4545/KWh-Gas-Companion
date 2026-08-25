//  ReimbursementGeneratorView.swift — My KWh Companion
//  Aug 2025 (fixed: RGToast + RGMetricTile + explicit transition)

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct ReimbursementGeneratorView: View {
    // Optional direct data feed
    private let providedEntries: [ExpenseEntry]?
    @EnvironmentObject private var entriesStore: EntriesStore

    // MARK: Policy & Range
    enum Policy: String, CaseIterable, Identifiable { case perMile = "Per-Mile", perKWh = "Per-kWh"; var id: String { rawValue } }
    enum RangeMode: String, CaseIterable, Identifiable { case month = "Month", quarter = "Quarter", custom = "Custom"; var id: String { rawValue } }

    @State private var policy: Policy = .perMile
    @State private var perMileRate: Double = 0.67
    @State private var perKWhRate: Double = 0.20

    @State private var rangeMode: RangeMode = .quarter
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedQuarter: Int = Calendar.current.component(.quarter, from: Date())

    @State private var customStart: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var customEnd: Date = Date()

    // Scope
    @State private var businessOnly: Bool = true
    @State private var energyOnly: Bool = false

    // UI
    @State private var toast: String? = nil

    init(entries: [ExpenseEntry]? = nil) {
        self.providedEntries = entries
    }

    // MARK: Derived
    private var allEntries: [ExpenseEntry] { providedEntries ?? entriesStore.entries }

    private var availableYears: [Int] {
        let years = allEntries.map { Calendar.current.component(.year, from: $0.date) }
        return Array(Set(years)).sorted(by: >)
    }

    private var dateRange: (start: Date, end: Date) {
        switch rangeMode {
        case .month:
            if let (s, e) = Calendar.current.monthRange(year: selectedYear, month: selectedMonth) { return (s, e) }
        case .quarter:
            if let (s, e) = Calendar.current.quarterRange(year: selectedYear, quarter: selectedQuarter) { return (s, e) }
        case .custom:
            return (min(customStart, customEnd), max(customStart, customEnd))
        }
        let now = Date()
        let comps = Calendar.current.dateComponents([.year, .month], from: now)
        let y = comps.year ?? selectedYear
        let m = comps.month ?? selectedMonth
        return Calendar.current.monthRange(year: y, month: m) ?? (now, now)
    }

    private var scopedEntries: [ExpenseEntry] {
        let (s, e) = dateRange
        return allEntries
            .filter { $0.date >= s && $0.date <= e }
            .filter { businessOnly ? $0.isBusiness : true }
            .filter { energyOnly ? $0.isEnergyEffective : true }
    }

    private var totalBusinessKWh: Double {
        scopedEntries.reduce(0) { $0 + ($1.energyAddedKWh ?? 0) }
    }

    private var totalBusinessMiles: Double {
        scopedEntries.reduce(0) { partial, e in
            guard let s = e.charging?.odometerStart, let t = e.charging?.odometerEnd, t > s else { return partial }
            return partial + (t - s)
        }
    }

    private var reimbursementTotal: Double {
        switch policy {
        case .perMile: return totalBusinessMiles * perMileRate
        case .perKWh:  return totalBusinessKWh * perKWhRate
        }
    }

    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    var body: some View {
        NavigationStack {
            ZStack {
                RGBackground().ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        headerCard.padding(.horizontal)
                        rangeCard.padding(.horizontal)
                        policyCard.padding(.horizontal)
                        metricsCard.padding(.horizontal)
                        detailCard.padding([.horizontal, .bottom]).padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Reimbursement")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if !availableYears.contains(selectedYear), let firstYear = availableYears.first {
                selectedYear = firstYear
            }
        }
        .overlay(alignment: .top) {
            if let msg = toast {
                RGToast(text: msg)
                    .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                            withAnimation { toast = nil }
                        }
                    }
            }
        }
    }

    // MARK: Cards
    private var headerCard: some View {
        RGCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial).frame(width: 54, height: 54)
                    Image(systemName: "dollarsign.circle.fill").font(.system(size: 24, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reimbursement Generator").font(.title3.weight(.semibold))
                    Text("Per-mile or per-kWh · pick a range · copy CSV")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var rangeCard: some View {
        RGCard(title: "Range & Scope") {
            VStack(spacing: 12) {
                Picker("Mode", selection: $rangeMode) {
                    ForEach(RangeMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch rangeMode {
                case .month:
                    HStack {
                        Picker("Year", selection: $selectedYear) {
                            ForEach(yearChoices(), id: \.self) { Text("\($0)").tag($0) }
                        }.pickerStyle(.menu)
                        Spacer()
                        Picker("Month", selection: $selectedMonth) {
                            ForEach(1...12, id: \.self) { m in Text(Calendar.current.monthSymbols[m-1]).tag(m) }
                        }.pickerStyle(.menu)
                    }

                case .quarter:
                    HStack {
                        Picker("Year", selection: $selectedYear) {
                            ForEach(yearChoices(), id: \.self) { Text("\($0)").tag($0) }
                        }.pickerStyle(.menu)
                        Spacer()
                        Picker("Quarter", selection: $selectedQuarter) {
                            ForEach(1...4, id: \.self) { q in Text("Q\(q)").tag(q) }
                        }.pickerStyle(.menu)
                    }

                case .custom:
                    VStack(spacing: 8) {
                        DatePicker("Start", selection: $customStart, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("End", selection: $customEnd, displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Divider().opacity(0.12)
                Toggle("Business entries only", isOn: $businessOnly)
                Toggle("Energy entries only", isOn: $energyOnly)
            }
        }
    }

    private var policyCard: some View {
        RGCard(title: "Policy & Rates") {
            VStack(spacing: 12) {
                Picker("Policy", selection: $policy) {
                    ForEach(Policy.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch policy {
                case .perMile:
                    HStack {
                        Text("Rate ($/mi)")
                        Spacer()
                        TextField("$/mi", value: $perMileRate, format: .currency(code: currencyCode))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 160)
                    }
                case .perKWh:
                    HStack {
                        Text("Rate ($/kWh)")
                        Spacer()
                        TextField("$/kWh", value: $perKWhRate, format: .currency(code: currencyCode))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 160)
                    }
                }
            }
        }
    }

    private var metricsCard: some View {
        RGCard(title: "Totals") {
            HStack(spacing: 16) {
                RGMetricTile(title: "Business kWh",
                             valueText: totalBusinessKWh.formatted(.number.precision(.fractionLength(1))),
                             systemImage: "bolt.fill")
                RGMetricTile(title: "Business mi",
                             valueText: totalBusinessMiles.formatted(.number.precision(.fractionLength(1))),
                             systemImage: "gauge")
                RGMetricTile(title: "Reimbursement",
                             valueText: reimbursementTotal.formatted(.currency(code: currencyCode)),
                             systemImage: "dollarsign.circle")
            }
        }
    }

    private var detailCard: some View {
        RGCard(title: "Entries in Range", subtitle: scopedEntries.isEmpty ? "No entries" : "\(scopedEntries.count) item(s)") {
            if scopedEntries.isEmpty {
                Text("No entries match your filters. Adjust range or scope.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(scopedEntries) { e in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.category).font(.subheadline.weight(.semibold))
                                Text(lineSubtitle(e))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(e.amount.formatted(.currency(code: currencyCode)))
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.vertical, 6)
                        if e.id != scopedEntries.last?.id { Divider().opacity(0.08) }
                    }
                }
            }

            HStack {
                Spacer()
                Button {
                    let csv = csvForCurrentSelection()
                    copyToClipboard(csv)
                    withAnimation { toast = "CSV copied" }
                } label: { Label("Copy CSV", systemImage: "doc.on.doc") }
                .buttonStyle(.plain)

                Button {
                    let summary = summaryText()
                    copyToClipboard(summary)
                    withAnimation { toast = "Summary copied" }
                } label: { Label("Copy Summary", systemImage: "doc.plaintext") }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
    }

    // MARK: Helpers
    private func yearChoices() -> [Int] {
        if availableYears.isEmpty {
            let y = Calendar.current.component(.year, from: Date())
            return [y]
        }
        return availableYears
    }

    private func lineSubtitle(_ e: ExpenseEntry) -> String {
        var parts: [String] = []
        parts.append(DateFormatter.shortDateTime.string(from: e.date))
        if let loc = e.location, !loc.isEmpty { parts.append(loc) }
        if let k = e.energyAddedKWh, k > 0 { parts.append(String(format: "%.1f kWh", k)) }
        if let s = e.charging?.odometerStart, let t = e.charging?.odometerEnd, t > s {
            parts.append(String(format: "%.1f mi", t - s))
        }
        if e.isBusiness { parts.append("Business") }
        return parts.joined(separator: " • ")
    }

    private func csvForCurrentSelection() -> String {
        let (s, e) = dateRange
        let header = "Date,Category,Amount,Business,Energy,kWh,Miles,Location,Invoice"
        let rows = scopedEntries.map { en -> String in
            let kwh = en.energyAddedKWh ?? 0
            let miles = ((en.charging?.odometerEnd ?? 0) - (en.charging?.odometerStart ?? 0))
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm"
            let cols: [String] = [
                df.string(from: en.date),
                en.category,
                String(format: "%.2f", en.amount),
                en.isBusiness ? "Y" : "N",
                en.isEnergyEffective ? "Y" : "N",
                String(format: "%.3f", kwh),
                miles > 0 ? String(format: "%.1f", miles) : "",
                (en.location ?? "").replacingOccurrences(of: ",", with: " "),
                (en.invoiceNumber ?? "").replacingOccurrences(of: ",", with: " ")
            ]
            return cols.joined(separator: ",")
        }
        let title = "# Range: \(DateFormatter.shortDate.string(from: s)) to \(DateFormatter.shortDate.string(from: e))"
        let policyLine: String = {
            switch policy {
            case .perMile: return "# Policy: Per-Mile @ \(perMileRate.formatted(.currency(code: currencyCode)))/mi"
            case .perKWh:  return "# Policy: Per-kWh @ \(perKWhRate.formatted(.currency(code: currencyCode)))/kWh"
            }
        }()
        return ([title, policyLine, header] + rows).joined(separator: "\n")
    }

    private func summaryText() -> String {
        let (s, e) = dateRange
        let base = """
        Reimbursement Summary
        Range: \(DateFormatter.shortDate.string(from: s)) → \(DateFormatter.shortDate.string(from: e))
        Entries: \(scopedEntries.count)
        Business kWh: \(totalBusinessKWh.formatted(.number.precision(.fractionLength(1))))
        Business mi: \(totalBusinessMiles.formatted(.number.precision(.fractionLength(1))))
        """
        let tail: String = {
            switch policy {
            case .perMile:
                return "Policy: Per-Mile @ \(perMileRate.formatted(.currency(code: currencyCode)))/mi\nTotal: \(reimbursementTotal.formatted(.currency(code: currencyCode)))"
            case .perKWh:
                return "Policy: Per-kWh @ \(perKWhRate.formatted(.currency(code: currencyCode)))/kWh\nTotal: \(reimbursementTotal.formatted(.currency(code: currencyCode)))"
            }
        }()
        return base + "\n" + tail
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

// MARK: - Local shells
fileprivate struct RGBackground: View {
    @Environment(\.colorScheme) private var cs
    var body: some View {
        LinearGradient(
            colors: cs == .dark ? [Color.black, Color(white: 0.12)]
                                : [Color(white: 0.98), Color(white: 0.92)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

fileprivate struct RGCard<Content: View>: View {
    var title: String?
    var subtitle: String?
    @ViewBuilder var content: Content
    init(title: String? = nil, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title; self.subtitle = subtitle; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.secondary) }
                }
                .padding(.bottom, 4)
            }
            content
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}

fileprivate struct RGMetricTile: View {
    let title: String
    let valueText: String
    let systemImage: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.caption).opacity(0.7)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Text(valueText).font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .contentShape(Rectangle())
    }
}

fileprivate struct RGToast: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            .padding(.top, 10)
    }
}

// MARK: - Calendar helpers & formatters
fileprivate extension Calendar {
    func monthRange(year: Int, month: Int) -> (Date, Date)? {
        let comps = DateComponents(year: year, month: month, day: 1)
        guard let start = date(from: comps) else { return nil }
        guard let lastDay = range(of: .day, in: .month, for: start)?.count else { return nil }
        let endComps = DateComponents(year: year, month: month, day: lastDay, hour: 23, minute: 59, second: 59)
        guard let end = date(from: endComps) else { return nil }
        return (start, end)
    }

    func quarterRange(year: Int, quarter: Int) -> (Date, Date)? {
        let mStart = (quarter - 1) * 3 + 1
        guard let (s, _) = monthRange(year: year, month: mStart),
              let (_, e) = monthRange(year: year, month: mStart + 2) else { return nil }
        return (s, e)
    }
}

fileprivate extension DateFormatter {
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()
    static let shortDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
}

// MARK: - Preview
#Preview {
    ReimbursementGeneratorView()
        .environmentObject(EntriesStore())
}
