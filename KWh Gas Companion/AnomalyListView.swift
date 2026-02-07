//
//  AnomalyListView.swift
//  My KWh Companion
//
//  Full utility + inline fix actions (store-agnostic) + ignore + configurable MAD-z threshold.
//  iOS 17+ / Swift 6
//

import SwiftUI
import Foundation

// MARK: - Public Observation (required)

public struct ALVObservation: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let date: Date
    public let energyKWh: Double
    public let cost: Double
    public let miles: Double? // optional

    public init(id: UUID = UUID(), date: Date, energyKWh: Double, cost: Double, miles: Double? = nil) {
        self.id = id
        self.date = date
        self.energyKWh = energyKWh
        self.cost = cost
        self.miles = miles
    }
}

// MARK: - Optional Editing Bridge (store-agnostic)

public struct ALVEditableEntryModel: Sendable {
    public var id: UUID
    public var date: Date
    public var category: String
    public var energyKWh: Double?
    public var amount: Double
    public var miles: Double?
    public var notes: String?

    public init(id: UUID, date: Date, category: String, energyKWh: Double?, amount: Double, miles: Double?, notes: String?) {
        self.id = id
        self.date = date
        self.category = category
        self.energyKWh = energyKWh
        self.amount = amount
        self.miles = miles
        self.notes = notes
    }
}

public struct ALVEditBridge: Sendable {
    public var fetchByID: @Sendable (UUID) -> ALVEditableEntryModel?
    public var update:    @Sendable (ALVEditableEntryModel) -> Void
    public var delete:    @Sendable (UUID) -> Void
    public var context:   @Sendable () -> [ALVEditableEntryModel]
    public var refresh:   @Sendable () -> Void

    public init(
        fetchByID: @escaping @Sendable (UUID) -> ALVEditableEntryModel?,
        update:    @escaping @Sendable (ALVEditableEntryModel) -> Void,
        delete:    @escaping @Sendable (UUID) -> Void,
        context:   @escaping @Sendable () -> [ALVEditableEntryModel] = { [] },
        refresh:   @escaping @Sendable () -> Void = {}
    ) {
        self.fetchByID = fetchByID
        self.update = update
        self.delete = delete
        self.context = context
        self.refresh = refresh
    }
}

// MARK: - Severity & Anomaly

private enum ALVSeverity: String, CaseIterable, Identifiable {
    case critical, warning, info
    var id: String { rawValue }
    var label: String { switch self { case .critical: "Critical"; case .warning: "Warning"; case .info: "Info" } }
    var tint: Color { switch self { case .critical: .red; case .warning: .orange; case .info: .yellow } }
    var icon: String {
        switch self {
        case .critical: "exclamationmark.octagon.fill"
        case .warning:  "exclamationmark.triangle.fill"
        case .info:     "exclamationmark.circle.fill"
        }
    }
}

private enum ALVIssueKind: String, Sendable {
    case cpkHigh, cpkLow, kwhHigh, kwhLow, cpmOutlier, invalidNumber, negativeValue, costWithZero, duplicateDate
}

private struct ALVAnomaly: Identifiable, Hashable, Sendable {
    let id = UUID()
    let observationID: UUID
    let date: Date
    let title: String
    let detail: String
    let severity: ALVSeverity
    let metricLabel: String
    let metricValue: String
    let zScore: Double?
    let kind: ALVIssueKind
}

// MARK: - Fix Suggestions

private enum FixSuggestion: Identifiable, Sendable, Hashable {
    case recategorizeToFee
    case divideCostBy100
    case convertPerMinuteToPerKWh(assumedKW: Double)
    case setEnergy(Double)          // prompts; value is a hint/default
    case clampNegatives
    case ignoreTinyTopoff(minKWh: Double)
    case mergeWith(UUID)

    var id: String { String(describing: self) }

    var label: String {
        switch self {
        case .recategorizeToFee:
            return "Re-categorize to Fee"
        case .divideCostBy100:
            return "Convert cents → dollars"
        case .convertPerMinuteToPerKWh(let kw):
            return "Interpret $/min (≈ $/kWh @ \(Int(kw)) kW)"
        case .setEnergy:
            return "Set energy (kWh)…"
        case .clampNegatives:
            return "Clamp negatives to 0"
        case .ignoreTinyTopoff(let min):
            return "Mark tiny top-off (< \(String(format: "%.1f", min)) kWh) ignored"
        case .mergeWith:
            return "Merge with duplicate on this day"
        }
    }

    var systemImage: String {
        switch self {
        case .recategorizeToFee: return "arrowshape.turn.up.right"
        case .divideCostBy100:   return "percent"
        case .convertPerMinuteToPerKWh: return "timer"
        case .setEnergy:         return "bolt.fill"
        case .clampNegatives:    return "minus.circle"
        case .ignoreTinyTopoff:  return "drop.triangle"
        case .mergeWith:         return "arrow.triangle.merge"
        }
    }
}

// MARK: - Main View

public struct AnomalyListView: View {
    // Inputs
    private let observations: [ALVObservation]
    private let editBridge: ALVEditBridge?

    // UI State
    @State private var selectedSeverity: ALVSeverity? = nil
    @State private var query: String = ""
    @State private var sortNewestFirst = true
    @State private var zCutoff: Double = 3.5

    // Ignore (local-only)
    @State private var ignoredIDs: Set<UUID> = []

    // Fix sheet
    @State private var fixing: ALVAnomaly? = nil
    @State private var showSetEnergyPrompt = false
    @State private var energyText: String = ""
    @State private var energyDefault: Double = 0
    @StateObject private var adsStore = AdsEntitlementStore.shared

    // Init
    public init(observations: [ALVObservation]) {
        self.observations = observations
        self.editBridge = nil
    }
    public init(observations: [ALVObservation], editBridge: ALVEditBridge) {
        self.observations = observations
        self.editBridge = editBridge
    }

    public var body: some View {
        let all = detectAnomalies(in: observations)
        let filtered = anomaliesFiltered(all)
        let sorted = filtered.sorted(by: sortNewestFirst ? { $0.date > $1.date } : { $0.date < $1.date })

        return List {
            if all.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No anomalies detected",
                        systemImage: "checkmark.seal",
                        description: Text("Everything looks normal based on the current thresholds.")
                    )
                }
            } else {
                header(allCount: all.count, shownCount: sorted.count)

                ForEach(sorted) { anomaly in
                    row(for: anomaly)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if editBridge != nil {
                                Button {
                                    fixing = anomaly
                                } label: { Label("Fix…", systemImage: "wrench.and.screwdriver") }
                                .tint(.blue)
                            }
                            Button {
                                ignoredIDs.insert(anomaly.observationID)
                            } label: { Label("Ignore", systemImage: "eye.slash") }
                            .tint(.gray)
                        }
                }

                if !ignoredIDs.isEmpty {
                    Section {
                        Button {
                            ignoredIDs.removeAll()
                        } label: {
                            Label("Clear ignored (\(ignoredIDs.count))", systemImage: "eye")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if !adsStore.hasRemovedAds {
                Section {
                    AdBannerCard(adsStore: adsStore)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Anomalies")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { severityMenu }
            ToolbarItem(placement: .topBarTrailing) { sortToggle }
            ToolbarItem(placement: .topBarTrailing) { thresholdMenu }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search issues or metrics")
        .sheet(item: $fixing) { anomaly in
            fixSheet(for: anomaly)
                .presentationDetents([.medium, .large])
        }
        .alert("Set Energy (kWh)", isPresented: $showSetEnergyPrompt) {
            TextField("e.g. \(energyDefault.roundedString(2))", text: $energyText)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { energyText = "" }
            Button("Apply") { applySetEnergy() }
        } message: {
            Text("Enter the actual energy for this session.")
        }
        .task { await adsStore.load() }
    }

    // MARK: Header

    @ViewBuilder
    private func header(allCount: Int, shownCount: Int) -> some View {
        if !query.isEmpty || selectedSeverity != nil || !ignoredIDs.isEmpty || zCutoff != 3.5 {
            Section {
                HStack {
                    Text("\(shownCount) of \(allCount) flagged")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !ignoredIDs.isEmpty {
                        Text("Ignored: \(ignoredIDs.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.secondary.opacity(0.12)))
                    }
                }
            }
        }
    }

    // MARK: Toolbar

    private var severityMenu: some View {
        Menu {
            Button(role: selectedSeverity == nil ? .destructive : .none) {
                selectedSeverity = nil
            } label: {
                Label("All severities", systemImage: "line.3.horizontal.decrease.circle")
            }
            Divider()
            ForEach(ALVSeverity.allCases) { sev in
                Button { selectedSeverity = sev } label: {
                    Label(sev.label, systemImage: sev.icon)
                }
            }
        } label: {
            if let sev = selectedSeverity {
                Label(sev.label, systemImage: sev.icon).foregroundStyle(sev.tint)
            } else {
                Label("Severity", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
    }

    private var sortToggle: some View {
        Button {
            sortNewestFirst.toggle()
        } label: {
            Label(sortNewestFirst ? "Newest first" : "Oldest first",
                  systemImage: sortNewestFirst ? "arrow.down.to.line" : "arrow.up.to.line")
        }
        .help("Toggle sort order")
    }

    private var thresholdMenu: some View {
        Menu {
            ForEach([2.5, 3.0, 3.5, 4.0, 4.5], id: \.self) { v in
                Button {
                    zCutoff = v
                } label: {
                    if v == zCutoff {
                        Label("z ≥ \(v) (selected)", systemImage: "checkmark")
                    } else {
                        Text("z ≥ \(v)")
                    }
                }
            }
            Divider()
            Button(role: .destructive) {
                zCutoff = 3.5
            } label: {
                Label("Reset threshold", systemImage: "arrow.counterclockwise")
            }
        } label: {
            Label("Threshold", systemImage: "dial.medium")
        }
    }

    // MARK: Row

    private func row(for anomaly: ALVAnomaly) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: anomaly.severity.icon)
                .foregroundStyle(anomaly.severity.tint)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(anomaly.title).font(.headline)
                    Spacer()
                    Text(anomaly.date, style: .date)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                Text(anomaly.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    tag(anomaly.metricLabel)
                    Text(anomaly.metricValue).font(.subheadline).bold()
                    if let z = anomaly.zScore {
                        tag("z: \(z.roundedString(2))", color: .blue.opacity(0.15), border: .blue.opacity(0.3))
                    }
                }
                .padding(.top, 2)

                HStack(spacing: 8) {
                    if editBridge != nil {
                        Button {
                            fixing = anomaly
                        } label: {
                            Label("Fix…", systemImage: "wrench.and.screwdriver")
                        }
                        .buttonStyle(.bordered)
                    }
                    Button {
                        ignoredIDs.insert(anomaly.observationID)
                    } label: {
                        Label("Ignore", systemImage: "eye.slash")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
        .contextMenu {
            if editBridge != nil {
                Button { fixing = anomaly } label: {
                    Label("Fix…", systemImage: "wrench.and.screwdriver")
                }
            }
            Button {
                ignoredIDs.insert(anomaly.observationID)
            } label: {
                Label("Ignore", systemImage: "eye.slash")
            }
        }
    }

    private func tag(_ text: String, color: Color = .secondary.opacity(0.12), border: Color = .secondary.opacity(0.25)) -> some View {
        Text(text)
            .font(.caption)
            .padding(.vertical, 4).padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(color))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 0.5))
    }

    // MARK: Fix Sheet

    @ViewBuilder
    private func fixSheet(for anomaly: ALVAnomaly) -> some View {
        if let bridge = editBridge, let entry = bridge.fetchByID(anomaly.observationID) {
            let suggestions = EntryFixer.suggestions(
                for: entry,
                issueKind: anomaly.kind,
                context: bridge.context()
            )

            NavigationStack {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entrySummary(entry))
                                .font(.subheadline)
                            Text(anomaly.title).font(.headline)
                            Text(anomaly.detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    if suggestions.isEmpty {
                        Section {
                            ContentUnavailableView("No automatic fixes available",
                                                   systemImage: "checkmark.seal",
                                                   description: Text("You can edit this entry manually in your editor."))
                        }
                    } else {
                        Section("Suggestions") {
                            ForEach(suggestions) { s in
                                Button {
                                    apply(suggestion: s, to: entry, using: bridge)
                                } label: {
                                    Label(s.label, systemImage: s.systemImage)
                                }
                            }
                        }
                    }

                    Section("Danger Zone") {
                        Button(role: .destructive) {
                            bridge.delete(entry.id)
                            bridge.refresh()
                            fixing = nil
                        } label: {
                            Label("Delete entry", systemImage: "trash")
                        }
                    }
                }
                .navigationTitle("Fix Entry")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { fixing = nil }
                    }
                }
            }
        } else {
            ContentUnavailableView("Entry not available",
                                   systemImage: "exclamationmark.triangle",
                                   description: Text("This anomaly can’t be edited here."))
                .padding()
        }
    }

    private func entrySummary(_ e: ALVEditableEntryModel) -> String {
        let d = e.date.formatted(date: .abbreviated, time: .shortened)
        let cost = e.amount.formattedCurrency()
        let k = (e.energyKWh ?? 0).roundedString(2)
        let cat = e.category
        return "\(d) • \(cat) • \(cost) • \(k) kWh"
    }

    // MARK: - Apply Fix

    private func apply(suggestion s: FixSuggestion, to entry: ALVEditableEntryModel, using bridge: ALVEditBridge) {
        var x = entry
        switch s {
        case .recategorizeToFee:
            x.category = "Fee"
            x.notes = EntryFixer.append(x.notes, "Fix: re-categorized to Fee (0 kWh).")
            x = EntrySanitizer.sanitize(x)

        case .divideCostBy100:
            x.amount = (x.amount / 100.0).rounded(to: 2)
            x.notes = EntryFixer.append(x.notes, "Fix: cost divided by 100 (cents→dollars).")
            x = EntrySanitizer.sanitize(x)

        case .convertPerMinuteToPerKWh(let kw):
            let perMin = max(0, x.amount)
            let perKWh = (perMin * 60.0) / max(kw, 1)
            x.notes = EntryFixer.append(x.notes,
                String(format: "Fix: interpreted $/min %.2f as ≈ $%.2f/kWh @ %.0f kW.", perMin, perKWh, kw)
            )
            x = EntrySanitizer.sanitize(x)

        case .setEnergy(let hint):
            energyDefault = hint
            energyText = hint == 0 ? "" : String(hint)
            showSetEnergyPrompt = true
            return

        case .clampNegatives:
            if x.amount < 0 { x.amount = 0 }
            if (x.energyKWh ?? 0) < 0 { x.energyKWh = 0 }
            x.notes = EntryFixer.append(x.notes, "Fix: clamped negatives to zero.")
            x = EntrySanitizer.sanitize(x)

        case .ignoreTinyTopoff(let minKWh):
            if (x.energyKWh ?? 0) < minKWh {
                x.category = "Top-off (ignored)"
                x.notes = EntryFixer.append(x.notes, "Fix: tiny session < \(minKWh) kWh marked ignored.")
            }
            x = EntrySanitizer.sanitize(x)

        case .mergeWith(let otherID):
            if let other = bridge.fetchByID(otherID) {
                let keepNewest = max(x.date, other.date)
                x.energyKWh = (x.energyKWh ?? 0) + (other.energyKWh ?? 0)
                x.amount += other.amount
                x.date = keepNewest
                x.notes = EntryFixer.append(x.notes, "Fix: merged with \(otherID.uuidString.prefix(8)).")
                bridge.delete(otherID)
                x = EntrySanitizer.sanitize(x)
            }
        }

        bridge.update(x)
        bridge.refresh()
        fixing = nil
    }

    private func applySetEnergy() {
        guard let anomaly = fixing, let bridge = editBridge, var e = bridge.fetchByID(anomaly.observationID) else {
            showSetEnergyPrompt = false
            return
        }
        let normalized = energyText.replacingOccurrences(of: ",", with: ".")
        if let val = Double(normalized), val.isFinite, val >= 0 {
            e.energyKWh = val
            e.category = "Energy"
            e.notes = EntryFixer.append(e.notes, "Fix: set energy to \(val) kWh.")
            e = EntrySanitizer.sanitize(e)
            bridge.update(e)
            bridge.refresh()
        }
        showSetEnergyPrompt = false
        fixing = nil
    }

    // MARK: Filtering

    private func anomaliesFiltered(_ anomalies: [ALVAnomaly]) -> [ALVAnomaly] {
        anomalies.filter { a in
            guard !ignoredIDs.contains(a.observationID) else { return false }
            let sevOK = selectedSeverity == nil || a.severity == selectedSeverity
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty else { return sevOK }
            return sevOK && (
                a.title.localizedCaseInsensitiveContains(q) ||
                a.detail.localizedCaseInsensitiveContains(q) ||
                a.metricLabel.localizedCaseInsensitiveContains(q) ||
                a.metricValue.localizedCaseInsensitiveContains(q)
            )
        }
    }

    // MARK: Detection

    private func detectAnomalies(in obs: [ALVObservation]) -> [ALVAnomaly] {
        guard !obs.isEmpty else { return [] }

        var result: [ALVAnomaly] = []

        // Valid energy-only slice
        let validEnergy = obs.filter { $0.energyKWh.isFinite && $0.energyKWh > 0 }
        let costPerKWhPairs: [(ALVObservation, Double)] = validEnergy.map { ($0, $0.cost / max($0.energyKWh, .leastNonzeroMagnitude)) }
        let energyVals = validEnergy.map { $0.energyKWh }
        let cpkVals = costPerKWhPairs.map { $0.1 }

        let energyStats = RobustStats(values: energyVals)
        let cpkStats = RobustStats(values: cpkVals)

        // 1) $/kWh outliers
        for (o, value) in costPerKWhPairs {
            let z = cpkStats.zScore(value)
            if abs(z) >= zCutoff {
                let high = z > 0
                result.append(ALVAnomaly(
                    observationID: o.id,
                    date: o.date,
                    title: high ? "Unusually high cost per kWh" : "Unusually low cost per kWh",
                    detail: "z ≈ \(z.roundedString(2)) vs median \(cpkStats.median.formattedCurrency())/kWh",
                    severity: high ? .critical : .warning,
                    metricLabel: "$/kWh",
                    metricValue: value.formattedCurrency() + "/kWh",
                    zScore: z,
                    kind: high ? .cpkHigh : .cpkLow
                ))
            }
        }

        // 2) kWh outliers
        for o in validEnergy {
            let z = energyStats.zScore(o.energyKWh)
            if abs(z) >= zCutoff {
                result.append(ALVAnomaly(
                    observationID: o.id,
                    date: o.date,
                    title: "Energy unusually \(z > 0 ? "high" : "low")",
                    detail: "z ≈ \(z.roundedString(2)); median \(energyStats.median.roundedString(1)) kWh",
                    severity: .warning,
                    metricLabel: "kWh",
                    metricValue: o.energyKWh.roundedString(2) + " kWh",
                    zScore: z,
                    kind: z > 0 ? .kwhHigh : .kwhLow
                ))
            }
        }

        // 3) $/mi outliers if miles present
        let withMiles = obs.compactMap { o -> (ALVObservation, Double)? in
            guard let m = o.miles, m.isFinite, m > 0 else { return nil }
            return (o, o.cost / m)
        }
        if !withMiles.isEmpty {
            let vals = withMiles.map { $0.1 }
            let stats = RobustStats(values: vals)
            for (o, v) in withMiles {
                let z = stats.zScore(v)
                if abs(z) >= zCutoff {
                    result.append(ALVAnomaly(
                        observationID: o.id,
                        date: o.date,
                        title: "Cost per mile outlier",
                        detail: "z ≈ \(z.roundedString(2)) vs median \(stats.median.formattedCurrency())/mi",
                        severity: z > 0 ? .warning : .info,
                        metricLabel: "$/mi",
                        metricValue: v.formattedCurrency() + "/mi",
                        zScore: z,
                        kind: .cpmOutlier
                    ))
                }
            }
        }

        // 4) Data quality checks
        for o in obs {
            if !o.energyKWh.isFinite || !o.cost.isFinite || !(o.miles ?? 0).isFinite {
                result.append(ALVAnomaly(
                    observationID: o.id, date: o.date,
                    title: "Invalid numeric value",
                    detail: "Non-finite number detected (NaN/∞).",
                    severity: .critical,
                    metricLabel: "Data", metricValue: "Invalid",
                    zScore: nil, kind: .invalidNumber
                ))
            } else if o.energyKWh < 0 || o.cost < 0 || (o.miles ?? 0) < 0 {
                result.append(ALVAnomaly(
                    observationID: o.id, date: o.date,
                    title: "Negative value",
                    detail: "One or more fields are negative.",
                    severity: .critical,
                    metricLabel: "Data", metricValue: "Negative",
                    zScore: nil, kind: .negativeValue
                ))
            } else if o.energyKWh == 0 && o.cost > 0 {
                result.append(ALVAnomaly(
                    observationID: o.id, date: o.date,
                    title: "Cost with zero energy",
                    detail: "Cost \(o.cost.formattedCurrency()) recorded with 0 kWh.",
                    severity: .warning,
                    metricLabel: "kWh", metricValue: "0",
                    zScore: nil, kind: .costWithZero
                ))
            }
        }

        // 5) Duplicate dates (same day)
        let byDay = Dictionary(grouping: obs) { Calendar.current.startOfDay(for: $0.date) }
        for (day, items) in byDay where items.count > 1 {
            let list = items.map { $0.id.uuidString.prefix(8) }.joined(separator: ", ")
            for o in items {
                result.append(ALVAnomaly(
                    observationID: o.id, date: o.date,
                    title: "Duplicate date",
                    detail: "Multiple entries on \(day.formatted(date: .abbreviated, time: .omitted)) [\(list)]",
                    severity: .info,
                    metricLabel: "Count", metricValue: "\(items.count)",
                    zScore: nil, kind: .duplicateDate
                ))
            }
        }

        return result
    }
}

// MARK: - Fix Engine (Sanitizer + Suggestions)

private enum EntrySanitizer {
    static func sanitize(_ e: ALVEditableEntryModel) -> ALVEditableEntryModel {
        var x = e
        if !x.amount.isFinite || x.amount < 0 { x.amount = 0 }
        if let k = x.energyKWh, (!k.isFinite || k < 0) { x.energyKWh = 0 }

        if (x.energyKWh ?? 0) == 0, x.amount > 0, x.category.lowercased() == "energy" {
            x.category = "Fee"
            x.notes = EntryFixer.append(x.notes, "Auto-fix: moved to Fee (0 kWh with cost).")
        }
        return x
    }
}

private enum EntryFixer {
    static func suggestions(for entry: ALVEditableEntryModel,
                            issueKind: ALVIssueKind,
                            context: [ALVEditableEntryModel]) -> [FixSuggestion] {
        var fixes: [FixSuggestion] = []

        switch issueKind {
        case .cpkHigh:
            fixes.append(.divideCostBy100)
            fixes.append(.convertPerMinuteToPerKWh(assumedKW: guessKW(from: entry)))
        case .cpkLow:
            fixes.append(.clampNegatives)
        case .kwhHigh, .kwhLow:
            fixes.append(.ignoreTinyTopoff(minKWh: 0.3))
        case .costWithZero:
            fixes.append(.recategorizeToFee)
            fixes.append(.setEnergy(0))
        case .invalidNumber, .negativeValue:
            fixes.append(.clampNegatives)
        case .duplicateDate:
            if let mate = findMergeMate(for: entry, in: context) {
                fixes.append(.mergeWith(mate.id))
            }
        case .cpmOutlier:
            fixes.append(.divideCostBy100)
        }
        return fixes
    }

    static func append(_ notes: String?, _ line: String) -> String {
        let t = (notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? line : "\(line)\n\(t)"
    }

    private static func findMergeMate(for e: ALVEditableEntryModel, in all: [ALVEditableEntryModel]) -> ALVEditableEntryModel? {
        let day = Calendar.current.startOfDay(for: e.date)
        return all.first { $0.id != e.id && Calendar.current.startOfDay(for: $0.date) == day }
    }

    private static func guessKW(from entry: ALVEditableEntryModel) -> Double {
        let note = (entry.notes ?? "").lowercased()
        if note.contains("dcfc") || note.contains("ea") || note.contains("supercharger") || note.contains("dc fast") {
            return 100
        }
        return 7.2
    }
}

// MARK: - Robust Stats (MAD)

private struct RobustStats {
    let median: Double
    private let mad: Double

    init(values: [Double]) {
        if values.isEmpty {
            self.median = .nan
            self.mad = .nan
        } else {
            let m = RobustStats.median(of: values)
            self.median = m
            let deviations = values.map { abs($0 - m) }
            self.mad = RobustStats.median(of: deviations)
        }
    }

    func zScore(_ x: Double) -> Double {
        guard mad.isFinite, mad > 0 else { return 0 }
        // 0.67449 is the constant to make MAD comparable to std dev under normality
        return 0.6744897501960817 * (x - median) / mad
    }

    private static func median(of xs: [Double]) -> Double {
        let s = xs.sorted()
        let n = s.count
        if n == 0 { return .nan }
        if n % 2 == 1 { return s[n/2] }
        let a = s[n/2 - 1], b = s[n/2]
        return (a + b) / 2
    }
}

// MARK: - Utilities

private extension Double {
    func roundedString(_ places: Int) -> String {
        guard self.isFinite else { return "—" }
        let p = max(0, places)
        return String(format: "%.\(p)f", self)
    }
    func rounded(to places: Int) -> Double {
        let p = pow(10.0, Double(max(0, places)))
        return (self * p).rounded() / p
    }
    func formattedCurrency(code: String = Locale.current.currency?.identifier ?? "USD") -> String {
        self.formatted(.currency(code: code))
    }
}

// MARK: - Preview

#if DEBUG
struct AnomalyListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { AnomalyListView(observations: mockData) }
    }
    private static var mockData: [ALVObservation] {
        let now = Date()
        let cal = Calendar.current
        var items: [ALVObservation] = []
        for i in 0..<16 {
            let day = cal.date(byAdding: .day, value: -i, to: now) ?? now
            let kWh = Double.random(in: 6...24)
            let cost = kWh * Double.random(in: 0.10...0.22)
            let miles: Double? = Bool.random() ? Double.random(in: 15...120) : nil
            items.append(.init(date: day, energyKWh: kWh, cost: cost, miles: miles))
        }
        if let d = cal.date(byAdding: .day, value: -3, to: now) {
            items.append(.init(date: d, energyKWh: 12, cost: 12 * 0.59))
        }
        if let d = cal.date(byAdding: .day, value: -7, to: now) {
            items.append(.init(date: d, energyKWh: 0, cost: 8.0))
        }
        if let d = cal.date(byAdding: .day, value: -1, to: now) {
            items.append(.init(date: d, energyKWh: 8, cost: 1.2))
        }
        return items
    }
}
#endif
