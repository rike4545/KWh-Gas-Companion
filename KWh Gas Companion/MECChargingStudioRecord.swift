//
//  ChargingDataStudioView.swift
//  KWh Gas Companion / My KWh Companion
//
//  Charging Data Studio
//  - Device-backed by default (TeslaFiSessionStore + EntriesStore)
//  - Also supports external injected sessions (generic Sequence initializer)
//  - No placeholder/sample data
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import Foundation
import Combine
import CryptoKit

// MARK: - Internal record used by the Studio UI (type-agnostic)

private struct MECChargingStudioRecord: Identifiable, Hashable {

    enum Source: String, CaseIterable, Identifiable {
        case all
        case teslaFi
        case energyEntry
        case external

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "All"
            case .teslaFi: return "Imported"
            case .energyEntry: return "Entries"
            case .external: return "External"
            }
        }
    }

    let id: String
    let source: Source
    let startDate: Date
    let kWh: Double
    let cost: Double
    let location: String
    let providerName: String
    let providerSymbol: String
    let tags: [String]

    var pricePerKWh: Double {
        guard kWh > 0 else { return 0 }
        return cost / kWh
    }
}

// MARK: - ViewModel

@MainActor
private final class ChargingDataStudioViewModel: ObservableObject {

    enum Mode {
        case device
        case external(items: [Any])
    }

    // Inputs
    private let mode: Mode

    // Filters
    @Published var sourceFilter: MECChargingStudioRecord.Source = .all { didSet { recompute() } }
    @Published var providerFilter: String? = nil { didSet { recompute() } }
    @Published var timeRange: MECChargingTimeRange = .last90 { didSet { recompute() } }
    @Published var sortKey: MECChargingSortKey = .dateDesc { didSet { recompute() } }
    @Published var searchText: String = "" { didSet { scheduleRecomputeForSearch() } }

    // Data
    @Published private(set) var allRecords: [MECChargingStudioRecord] = []
    @Published private(set) var visibleRecords: [MECChargingStudioRecord] = []

    struct Summary: Equatable {
        var count: Int
        var totalKWh: Double
        var totalCost: Double
        var avgPricePerKWh: Double
        static let zero = Summary(count: 0, totalKWh: 0, totalCost: 0, avgPricePerKWh: 0)
    }

    @Published private(set) var summary: Summary = .zero

    private var searchTask: Task<Void, Never>?
    private var reloadTask: Task<Void, Never>?

    init(mode: Mode) {
        self.mode = mode
    }

    func reset() {
        sourceFilter = .all
        providerFilter = nil
        timeRange = .last90
        sortKey = .dateDesc
        searchText = ""
    }

    func reloadDeviceData(teslaFiStore: TeslaFiSessionStore, entriesStore: EntriesStore) {
        guard case .device = mode else { return }

        reloadTask?.cancel()
        reloadTask = Task { @MainActor [weak self] in
            // small debounce to avoid storms during imports/merges
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard let self else { return }
            self.allRecords = Self.buildRecordsFromDevice(teslaFiStore: teslaFiStore, entriesStore: entriesStore)
            self.recompute()
        }
    }

    func loadExternalIfNeeded() {
        guard case .external(let items) = mode else { return }
        allRecords = Self.buildRecordsFromExternal(items: items)
        recompute()
    }

    private func scheduleRecomputeForSearch() {
        searchTask?.cancel()
        searchTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            self?.recompute()
        }
    }

    private func recompute() {
        let now = Date()
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var records = allRecords

        // Source filter
        switch sourceFilter {
        case .all:
            break
        case .teslaFi:
            records = records.filter { $0.source == .teslaFi }
        case .energyEntry:
            records = records.filter { $0.source == .energyEntry }
        case .external:
            records = records.filter { $0.source == .external }
        }

        // Time range
        records = records.filter { timeRange.contains($0.startDate, now: now) }

        // Provider filter
        if let providerFilter, !providerFilter.isEmpty {
            records = records.filter { $0.providerName == providerFilter }
        }

        // Search
        if !q.isEmpty {
            records = records.filter { r in
                if r.location.lowercased().contains(q) { return true }
                if r.providerName.lowercased().contains(q) { return true }
                if r.tags.contains(where: { $0.lowercased().contains(q) }) { return true }
                return false
            }
        }

        // Sort
        records.sort { a, b in
            switch sortKey {
            case .dateDesc:        return a.startDate > b.startDate
            case .costDesc:        return a.cost > b.cost
            case .kWhDesc:         return a.kWh > b.kWh
            case .pricePerKWhDesc: return a.pricePerKWh > b.pricePerKWh
            }
        }

        // Summary
        let totalKWh = records.reduce(0) { $0 + $1.kWh }
        let totalCost = records.reduce(0) { $0 + $1.cost }
        let avg = totalKWh > 0 ? (totalCost / totalKWh) : 0

        visibleRecords = records
        summary = Summary(count: records.count, totalKWh: totalKWh, totalCost: totalCost, avgPricePerKWh: avg)
    }

    // MARK: - Build records

    private static func buildRecordsFromDevice(
        teslaFiStore: TeslaFiSessionStore,
        entriesStore: EntriesStore
    ) -> [MECChargingStudioRecord] {

        var out: [MECChargingStudioRecord] = []

        // TeslaFi: prefer canonical if available
        let teslaFiItems: [Any] = {
            let canon = teslaFiStore.canonicalSessions
            if !canon.isEmpty { return canon.map { $0 as Any } }
            return teslaFiStore.sessions.map { $0 as Any }
        }()

        out.append(contentsOf: teslaFiItems.compactMap { buildTeslaFiRecord(from: $0) })

        // Entries: energy-only entries
        let energyEntries = entriesStore.energyEntries()
        out.append(contentsOf: energyEntries.map { $0 as Any }.compactMap { buildEnergyEntryRecord(from: $0) })

        return out
    }

    private static func buildRecordsFromExternal(items: [Any]) -> [MECChargingStudioRecord] {
        items.compactMap { item in
            // Treat external items as “sessions” and read common fields reflectively
            let startDate = extractDate(item, names: ["startDate", "date", "start", "timestamp", "createdAt"]) ?? Date.distantPast
            let location  = extractString(item, names: ["location", "siteName", "name", "stationName", "title"]) ?? "Unknown location"
            let kWh       = extractDouble(item, names: ["kWh", "kwh", "energyAdded", "energy", "energyKWh", "energyAddedKWh"]) ?? 0
            let cost      = extractDouble(item, names: ["cost", "amount", "totalCost", "total", "price", "value"]) ?? 0
            let provider  = extractString(item, names: ["provider", "providerName", "network", "chargerNetwork"]) ?? "External"

            var tags = extractStringArray(item, names: ["tags", "tagList"]) ?? []
            tags.append("External")

            let id = stableID("ext|\(startDate.timeIntervalSince1970)|\(location)|\(kWh)|\(cost)|\(provider)")

            return MECChargingStudioRecord(
                id: id,
                source: .external,
                startDate: startDate,
                kWh: kWh,
                cost: cost,
                location: location,
                providerName: provider,
                providerSymbol: symbolForProvider(provider),
                tags: Array(Set(tags)).sorted()
            )
        }
    }

    private static func buildTeslaFiRecord(from item: Any) -> MECChargingStudioRecord? {
        let startDate = extractDate(item, names: ["startDate", "start", "date", "timestamp", "createdAt"]) ?? Date.distantPast
        let location  = extractString(item, names: ["location", "siteName", "name", "stationName"]) ?? "Unknown location"
        let kWh       = extractDouble(item, names: ["energyAdded", "energyAddedKWh", "kWh", "kwh", "energy", "energyKWh"]) ?? 0
        let cost      = extractDouble(item, names: ["cost", "totalCost", "amount", "price", "sessionCost"]) ?? 0
        let provider  = extractString(item, names: ["providerName", "provider", "network", "chargerNetwork"]) ?? "Imported Session"

        var tags = extractStringArray(item, names: ["tags", "tagList"]) ?? []
        tags.append("Imported")

        let id = stableID("tfi|\(startDate.timeIntervalSince1970)|\(location)|\(kWh)|\(cost)|\(provider)")

        return MECChargingStudioRecord(
            id: id,
            source: .teslaFi,
            startDate: startDate,
            kWh: kWh,
            cost: cost,
            location: location,
            providerName: provider,
            providerSymbol: symbolForProvider(provider),
            tags: Array(Set(tags)).sorted()
        )
    }

    private static func buildEnergyEntryRecord(from item: Any) -> MECChargingStudioRecord? {
        let startDate = extractDate(item, names: ["date", "startDate", "timestamp", "createdAt"]) ?? Date.distantPast
        let location  =
            extractString(item, names: ["location", "merchant", "vendor", "title", "name", "notes", "note"]) ??
            "Energy entry"

        let kWh       = extractDouble(item, names: ["kWh", "kwh", "energyKWh", "energy", "quantity"]) ?? 0
        let cost      = extractDouble(item, names: ["cost", "amount", "total", "value", "price"]) ?? 0
        let provider  =
            extractString(item, names: ["providerName", "provider", "network", "category", "subCategory"]) ??
            "Entries"

        // Skip truly empty rows
        if startDate == Date.distantPast && location == "Energy entry" && kWh == 0 && cost == 0 { return nil }

        var tags = extractStringArray(item, names: ["tags", "tagList"]) ?? []
        tags.append("Entry")

        let id = stableID("ent|\(startDate.timeIntervalSince1970)|\(location)|\(kWh)|\(cost)|\(provider)")

        return MECChargingStudioRecord(
            id: id,
            source: .energyEntry,
            startDate: startDate,
            kWh: kWh,
            cost: cost,
            location: location,
            providerName: provider,
            providerSymbol: symbolForProvider(provider),
            tags: Array(Set(tags)).sorted()
        )
    }

    // MARK: - Reflection helpers

    private static func extractAny(_ item: Any, names: [String]) -> Any? {
        let mirror = Mirror(reflecting: item)
        for name in names {
            if let v = mirror.children.first(where: { $0.label == name })?.value { return v }
        }
        return nil
    }

    private static func extractString(_ item: Any, names: [String]) -> String? {
        guard let v = extractAny(item, names: names) else { return nil }
        if let s = v as? String { return s }
        return (v as? CustomStringConvertible)?.description
    }

    private static func extractStringArray(_ item: Any, names: [String]) -> [String]? {
        guard let v = extractAny(item, names: names) else { return nil }
        if let arr = v as? [String] { return arr }
        if let arr = v as? [Any] { return arr.compactMap { ($0 as? CustomStringConvertible)?.description } }
        return nil
    }

    private static func extractDouble(_ item: Any, names: [String]) -> Double? {
        guard let v = extractAny(item, names: names) else { return nil }
        if let d = v as? Double { return d }
        if let f = v as? Float { return Double(f) }
        if let i = v as? Int { return Double(i) }
        if let s = v as? String {
            let cleaned = s.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(cleaned)
        }
        return nil
    }

    private static func extractDate(_ item: Any, names: [String]) -> Date? {
        guard let v = extractAny(item, names: names) else { return nil }
        if let d = v as? Date { return d }
        if let t = v as? TimeInterval { return Date(timeIntervalSince1970: t) }
        return nil
    }

    private static func stableID(_ seed: String) -> String {
        let digest = SHA256.hash(data: Data(seed.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func symbolForProvider(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("tesla") || n.contains("supercharger") { return "bolt.car" }
        if n.contains("home") { return "house.and.bolt" }
        if n.contains("chargepoint") { return "c.circle" }
        if n.contains("evgo") { return "e.circle" }
        if n.contains("electrify") { return "bolt.circle" }
        if n.contains("teslafi") { return "tray.and.arrow.down" }
        if n.contains("entries") || n.contains("entry") { return "pencil.and.list.clipboard" }
        return "bolt"
    }
}

// MARK: - View

@MainActor
struct ChargingDataStudioView: View {

    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var appearance: AppAppearance

    @StateObject private var vm: ChargingDataStudioViewModel

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    private var providerOptions: [String] {
        Array(Set(vm.allRecords.map { $0.providerName }.filter { !$0.isEmpty })).sorted()
    }

    // ✅ Default: device-backed (real data)
    init() {
        _vm = StateObject(wrappedValue: ChargingDataStudioViewModel(mode: .device))
    }

    // ✅ Compatibility: allow any `sessions:` call site without knowing the element type.
    //    (Use ONLY with real device data; do not pass sample arrays.)
    init<S: Sequence>(sessions: S) {
        let items = sessions.map { $0 as Any }
        _vm = StateObject(wrappedValue: ChargingDataStudioViewModel(mode: .external(items: items)))
    }

    var body: some View {
        List {
            filtersSection
            summarySection
            sessionsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Charging Data Studio")
        .searchable(text: $vm.searchText, prompt: "Search location, provider, or tag")
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") { vm.reset() }
            }
        }
        .background(backgroundView.ignoresSafeArea())
        .task {
            // Load once
            vm.loadExternalIfNeeded()
            vm.reloadDeviceData(teslaFiStore: teslaFiStore, entriesStore: entriesStore)
        }
        .onReceive(teslaFiStore.objectWillChange) { _ in
            vm.reloadDeviceData(teslaFiStore: teslaFiStore, entriesStore: entriesStore)
        }
        .onReceive(entriesStore.objectWillChange) { _ in
            vm.reloadDeviceData(teslaFiStore: teslaFiStore, entriesStore: entriesStore)
        }
    }

    // MARK: Sections (broken up to avoid type-check explosions)

    private var filtersSection: some View {
        Section("Filters") {
            Picker("Source", selection: $vm.sourceFilter) {
                ForEach(MECChargingStudioRecord.Source.allCases) { s in
                    Text(s.title).tag(s)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Menu {
                    Button("All Providers") { vm.providerFilter = nil }
                    ForEach(providerOptions, id: \.self) { p in
                        Button(p) { vm.providerFilter = p }
                    }
                } label: {
                    Label(vm.providerFilter ?? "All Providers", systemImage: "slider.horizontal.3")
                }

                Picker("Range", selection: $vm.timeRange) {
                    ForEach(MECChargingTimeRange.allCases) { r in
                        Text(r.title).tag(r)
                    }
                }
                .pickerStyle(.segmented)
            }

            Menu {
                ForEach(MECChargingSortKey.allCases) { key in
                    Button(key.title) { vm.sortKey = key }
                }
            } label: {
                Label("Sort: \(vm.sortKey.title)", systemImage: "arrow.up.arrow.down")
            }
        }
    }

    private var summarySection: some View {
        Section("Summary") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    metricCard("Sessions", "\(vm.summary.count)", "In range")
                    metricCard("Energy", String(format: "%.1f kWh", vm.summary.totalKWh), "Filtered")
                    metricCard("Cost", vm.summary.totalCost.formatted(.currency(code: currencyCode)), "Filtered")
                    metricCard(
                        "Avg price",
                        "\(vm.summary.avgPricePerKWh.formatted(.currency(code: currencyCode)))/kWh",
                        "Filtered"
                    )
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var sessionsSection: some View {
        Section("Sessions") {
            if vm.visibleRecords.isEmpty {
                ContentUnavailableView(
                    "No sessions",
                    systemImage: "bolt.slash",
                    description: Text("Adjust filters or import more charging history.")
                )
            } else {
                ForEach(vm.visibleRecords) { record in
                    ChargingStudioRow(record: record, currencyCode: currencyCode)
                }
            }
        }
    }

    // MARK: UI

    private var backgroundView: some View {
        let accent = appearance.accentColor
        return LinearGradient(
            colors: [
                accent.opacity(0.12),
                Color(.systemBackground),
                Color(.secondarySystemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func metricCard(_ title: String, _ value: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).lineLimit(1).minimumScaleFactor(0.85)
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
        )
    }
}

// MARK: - Row

private struct ChargingStudioRow: View {
    let record: MECChargingStudioRecord
    let currencyCode: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            left
            Spacer(minLength: 8)
            right
        }
        .padding(.vertical, 6)
    }

    private var left: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.location)
                .font(.headline)

            HStack(spacing: 6) {
                Text(record.startDate, style: .date)
                Text("·").foregroundStyle(.secondary)
                Text(record.startDate, style: .time)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Image(systemName: record.providerSymbol)
                Text(record.providerName)
                Text("·").foregroundStyle(.secondary)
                Text(sourceLabel)
                    .foregroundStyle(.secondary)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if !record.tags.isEmpty {
                Text(record.tags.joined(separator: " • "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var right: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(record.cost, format: .currency(code: currencyCode))
                .font(.headline)

            Text(String(format: "%.1f kWh", record.kWh))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(record.pricePerKWh.formatted(.currency(code: currencyCode)))/kWh")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var sourceLabel: String {
        switch record.source {
        case .teslaFi: return "Imported"
        case .energyEntry: return "Entry"
        case .external: return "External"
        case .all: return ""
        }
    }
}
