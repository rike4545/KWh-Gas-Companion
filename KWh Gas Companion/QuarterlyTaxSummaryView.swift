//  QuarterlyTaxSummaryView.swift — My KWh Companion
//  Aug 2025 (rev: year field fix, horizontal tiles, VAT label, count tile, persistence)
//
//  • Works with either init(entries:) or @EnvironmentObject EntriesStore
//  • Groups by Year + Quarter (Q1–Q4)
//  • Shows YTD totals and per-quarter: Business total, Energy (biz), Non-Energy (biz), VAT, Entries
//  • Copy-to-Clipboard CSV per quarter
//  • Glass cards; local card shells avoid cross-file deps

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct QuarterlyTaxSummaryView: View {
    // Optional direct data feed
    private let providedEntries: [ExpenseEntry]?

    // Or pull from the store
    @EnvironmentObject private var entriesStore: EntriesStore

    // UI
    @AppStorage("QTS_SelectedYear") private var persistedYear: Int = 0
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var yearText: String = ""
    @State private var copiedToast: String? = nil

    init(entries: [ExpenseEntry]? = nil) {
        self.providedEntries = entries
    }

    // MARK: Derived data

    private var allEntries: [ExpenseEntry] {
        providedEntries ?? entriesStore.entries
    }

    private var availableYears: [Int] {
        let years = allEntries.map { Calendar.current.component(.year, from: $0.date) }
        // Always include current year so UI has a sensible default even without entries
        let current = Calendar.current.component(.year, from: Date())
        return Array(Set(years + [current])).sorted(by: >)
    }

    /// Entries only for the selected year
    private var yearEntries: [ExpenseEntry] {
        allEntries.filter { Calendar.current.component(.year, from: $0.date) == selectedYear }
    }

    private var ytd: QuarterAgg {
        aggregate(entries: yearEntries)
    }

    private var quarters: [(key: QuarterKey, agg: QuarterAgg)] {
        (1...4).map { q in
            let k = QuarterKey(year: selectedYear, quarter: q)
            let es = yearEntries.filter { Calendar.current.component(.quarter, from: $0.date) == q }
            return (k, aggregate(entries: es))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QTSBackground().ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        header.padding(.horizontal)
                        yearPickerCard.padding(.horizontal)
                        ytdCard.padding(.horizontal)
                        ForEach(quarters, id: \.key) { item in
                            quarterCard(for: item.key, agg: item.agg)
                                .padding(.horizontal)
                        }
                        Spacer(minLength: 16)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Quarterly Tax Summary")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Restore persisted year or pick a sensible one on first load
            if persistedYear > 0 {
                selectedYear = persistedYear
            } else if !availableYears.contains(selectedYear) {
                selectedYear = availableYears.first ?? selectedYear
            }
            yearText = String(selectedYear)
        }
        .onChange(of: selectedYear) { _, newValue in
            yearText = String(newValue)
            persistedYear = newValue
        }
        .overlay(alignment: .top) {
            if let msg = copiedToast {
                QTS_Toast(text: msg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                            withAnimation { copiedToast = nil }
                        }
                    }
            }
        }
    }

    // MARK: UI Sections

    private var header: some View {
        QTSCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial).frame(width: 54, height: 54)
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 24, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quarterly Tax Summary").font(.title3.weight(.semibold))
                    Text("Business vs personal • Energy vs non-energy • VAT")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var yearPickerCard: some View {
        QTSCard(title: "Year") {
            // 1) Chip picker from known years
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableYears, id: \.self) { y in
                        Button {
                            withAnimation(.easeInOut) { selectedYear = y }
                        } label: {
                            Text("\(y)")
                                .font(.callout.weight(.semibold)).monospacedDigit()
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(selectedYear == y ? .thinMaterial : .ultraThinMaterial,
                                            in: Capsule())
                                .overlay(Capsule().strokeBorder(.white.opacity(selectedYear == y ? 0.3 : 0.15), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 8)

            // 2) Manual year entry (digits only; no grouping separators)
            TextField("YYYY", text: $yearText)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.title3.monospacedDigit().weight(.semibold))
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
                .onChange(of: yearText) { _, newValue in
                    // keep only digits, limit to 4
                    let filtered = newValue.filter { $0.isNumber }.prefix(4)
                    if filtered != newValue { yearText = String(filtered) }
                    if let y = Int(filtered), (1900...2200).contains(y) {
                        selectedYear = y
                    }
                }
        }
    }

    private var ytdCard: some View {
        QTSCard(title: "Year-to-Date (\(selectedYear))") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    MetricTileQTS(systemImage: "briefcase.fill", title: "Business Total", valueText: currency(ytd.businessTotal))
                    MetricTileQTS(systemImage: "bolt.fill", title: "Energy (Biz)", valueText: currency(ytd.energyBusiness))
                    MetricTileQTS(systemImage: "wrench.fill", title: "Non-Energy (Biz)", valueText: currency(ytd.nonEnergyBusiness))
                    MetricTileQTS(systemImage: "percent", title: "VAT", valueText: currency(ytd.vatTotal))
                    MetricTileQTS(systemImage: "list.number", title: "Entries", valueText: "\(ytd.sessions)")
                }
            }
        }
    }

    private func quarterCard(for key: QuarterKey, agg: QuarterAgg) -> some View {
        QTSCard(title: "Q\(key.quarter) \(key.year)", subtitle: agg.sessions > 0 ? "\(agg.sessions) entries" : "No entries") {
            VStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        MetricTileQTS(systemImage: "briefcase.fill", title: "Business Total", valueText: currency(agg.businessTotal))
                        MetricTileQTS(systemImage: "bolt.fill", title: "Energy (Biz)", valueText: currency(agg.energyBusiness))
                        MetricTileQTS(systemImage: "wrench.fill", title: "Non-Energy (Biz)", valueText: currency(agg.nonEnergyBusiness))
                        MetricTileQTS(systemImage: "percent", title: "VAT", valueText: currency(agg.vatTotal))
                        MetricTileQTS(systemImage: "list.number", title: "Entries", valueText: "\(agg.sessions)")
                    }
                }

                if agg.sessions > 0 {
                    Divider().opacity(0.12)
                    // Top categories (business only), descending by spend
                    let top = topBusinessCategories(for: key, limit: 5)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Categories").font(.subheadline.weight(.semibold))
                        ForEach(top, id: \.name) { row in
                            HStack {
                                Text(row.name).lineLimit(1)
                                Spacer()
                                Text(currency(row.amount)).font(.callout.weight(.semibold))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        let csv = csvForQuarter(key)
                        copyToClipboard(csv)
                        withAnimation { copiedToast = "CSV copied for Q\(key.quarter) \(key.year)" }
                    } label: {
                        Label("Copy CSV", systemImage: "doc.on.doc")
                            .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Aggregation

    private struct QuarterKey: Hashable {
        let year: Int
        let quarter: Int
    }

    private struct QuarterAgg {
        var businessTotal: Double = 0
        var energyBusiness: Double = 0
        var nonEnergyBusiness: Double = 0
        var vatTotal: Double = 0
        var sessions: Int = 0
    }

    private func aggregate(entries: [ExpenseEntry]) -> QuarterAgg {
        var agg = QuarterAgg()
        for e in entries {
            if e.isBusiness {
                agg.businessTotal += e.amount
                if e.isEnergyEffective {
                    agg.energyBusiness += e.amount
                } else {
                    agg.nonEnergyBusiness += e.amount
                }
                if let v = e.vatAmount { agg.vatTotal += v }
            }
            agg.sessions += 1
        }
        return agg
    }

    private func topBusinessCategories(for key: QuarterKey, limit: Int) -> [(name: String, amount: Double)] {
        let es = yearEntries.filter {
            Calendar.current.component(.quarter, from: $0.date) == key.quarter && $0.isBusiness
        }
        var map: [String: Double] = [:]
        for e in es {
            let k = e.category
            map[k, default: 0] += e.amount
        }
        return map.sorted { $0.value > $1.value }.prefix(limit).map { ($0.key, $0.value) }
    }

    // MARK: - CSV

    private func csvForQuarter(_ key: QuarterKey) -> String {
        let header = [
            "Date", "Category", "Amount", "Business", "Energy", "VAT", "Location", "Invoice"
        ].joined(separator: ",")

        let rows = yearEntries
            .filter { Calendar.current.component(.quarter, from: $0.date) == key.quarter }
            .map { e -> String in
                let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm"
                let cols: [String] = [
                    df.string(from: e.date),
                    e.category.replacingOccurrences(of: ",", with: " "),
                    String(format: "%.2f", e.amount),
                    e.isBusiness ? "Y" : "N",
                    e.isEnergyEffective ? "Y" : "N",
                    String(format: "%.2f", e.vatAmount ?? 0),
                    (e.location ?? "").replacingOccurrences(of: ",", with: " "),
                    (e.invoiceNumber ?? "").replacingOccurrences(of: ",", with: " ")
                ]
                return cols.joined(separator: ",")
            }

        return ([header] + rows).joined(separator: "\n")
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }

    // MARK: - Format

    private func currency(_ value: Double) -> String {
        let code = Locale.current.currency?.identifier ?? "USD"
        return value.formatted(.currency(code: code))
    }
}

// MARK: - Local shells (avoid cross-file deps)

fileprivate struct QTSBackground: View {
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

fileprivate struct QTSCard<Content: View>: View {
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)
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

fileprivate struct MetricTileQTS: View {
    let systemImage: String
    let title: String
    let valueText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.caption).opacity(0.7)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Text(valueText).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

fileprivate struct QTS_Toast: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview {
    QuarterlyTaxSummaryView()
        .environmentObject(EntriesStore())
}
