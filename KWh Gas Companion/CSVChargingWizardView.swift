//
//  CSVChargingWizardView.swift
//  My KWh Companion
//
//  End-to-end importer for the **official Tesla Supercharging CSV** (not TeslaFi).
//  Steps: Select CSV → Map Columns → Options → Import.
//  - Only shows Tesla headers the user listed.
//  - Robust CSV + number/date parsing.
//  - Dedupe via ExpenseEntry.dedupeKey().
//  - Optional kWh backfill (Amount ÷ Price/kWh) with confirm + undo.
//  - Friendly success toast after import.
//
//  Requires EnvironmentObject EntriesStore (read/write `entries`, and you added addOrReplace(_:)).
//
//  Swift 6 / iOS 17+
//

import SwiftUI
import UniformTypeIdentifiers
import Foundation

@MainActor
struct CSVChargingWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var appearance: AppAppearance
    @Environment(\.colorScheme) private var scheme

    enum Step: Int { case select, map, options, `import` }
    @State private var step: Step = .select

    @State private var isImporterPresented = false
    @State private var pickedURL: URL?
    @State private var headers: [String] = []
    @State private var rows: [[String]] = []

    @State private var mapping = ColumnMapping()
    @State private var autoMapNotes: String? = nil

    @State private var currencyCode: String = Locale.current.currency?.identifier ?? "USD"
    @State private var defaultVATText: String = ""
    @State private var invoicePrefix: String = ""
    @State private var dedupeEnabled: Bool = true

    @State private var isImporting: Bool = false
    @State private var progress: Double = 0
    @State private var imported: Int = 0
    @State private var skipped: Int = 0
    @State private var errors: [String] = []

    @State private var showHelp: Bool = false
    @State private var showSuccessToast: Bool = false

    @State private var importedIDs: [UUID] = []
    @State private var missingKWhCount: Int = 0
    @State private var backfillUndo: [(UUID, Double?)] = []
    @State private var showBackfillConfirm: Bool = false
    @State private var backfillMessage: String? = nil

    // Structural / header-level warnings (e.g., column count mismatches)
    @State private var warnings: [String] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()
                content
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Import Supercharging CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [
                    .commaSeparatedText,
                    .plainText,        // broader than .text, better match for CSVs
                    .data
                ],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { loadCSV(from: url) }
                case .failure(let err):
                    errors.append("File import failed: \(err.localizedDescription)")
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .overlay(alignment: .top) {
                if showSuccessToast {
                    ToastBanner(text: "Imported successfully. Don’t forget to tap Done.")
                        .padding(.top, 8)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .accessibilityHidden(false)
                        .accessibilityLabel("Import successful")
                }
            }
            .alert("Backfill kWh?", isPresented: $showBackfillConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Backfill", action: backfillKWh)
            } message: {
                Text("Compute kWh = Amount ÷ Price/kWh for \(missingKWhCount) session\(missingKWhCount == 1 ? "" : "s"). You can undo this action.")
            }
            .tint(appearance.accentColor)
        }
    }

    // MARK: - Header

    private var header: some View {
        let accent = appearance.accentColor

        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(accent.opacity(0.12))
                Image(systemName: "bolt.car.fill").font(.title2)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(titleForStep(step)).font(.headline)
                Text(subtitleForStep(step))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if step != .select { StepIndicator(current: step) }
        }
        .padding()
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        accent.opacity(scheme == .dark ? 0.30 : 0.22),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.plusLighter)
                Color.clear.background(.thinMaterial)
            }
        )
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        switch step {
        case .select:
            SelectCSVStep(selectAction: { isImporterPresented = true })
        case .map:
            MapColumnsStep(
                headers: headers,
                firstRow: rows.first ?? [],
                mapping: $mapping,
                notes: autoMapNotes,
                warnings: warnings
            )
        case .options:
            OptionsStep(
                currencyCode: $currencyCode,
                defaultVATText: $defaultVATText,
                invoicePrefix: $invoicePrefix,
                dedupeEnabled: $dedupeEnabled
            )
        case .import:
            ImportStep(
                isImporting: isImporting,
                progress: progress,
                imported: imported,
                skipped: skipped,
                errors: errors,
                missingKWhCount: missingKWhCount,
                onBackfillTap: { showBackfillConfirm = true },
                canUndo: !backfillUndo.isEmpty,
                onUndo: undoBackfill,
                message: backfillMessage
            )
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            Divider()
            HStack(spacing: 12) {
                if step != .select { Button("Back", action: goBack) }

                Button {
                    showHelp = true
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(primaryButtonTitle(), action: next)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed())
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            if step == .map && !mapping.hasMinimumRequirements {
                Text("Map ChargeStartDateTime, QuantityBase, and either Total Inc. VAT or UnitCostBase to continue.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.horizontal, .bottom])
            }
        }
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showHelp) { HelpSheet(step: step) }
    }

    // MARK: - Step helpers

    private func titleForStep(_ s: Step) -> String {
        switch s {
        case .select: return "Select CSV"
        case .map:    return "Map Columns"
        case .options:return "Options"
        case .import: return "Import"
        }
    }

    private func subtitleForStep(_ s: Step) -> String {
        switch s {
        case .select: return "Choose your official Supercharging CSV."
        case .map:    return "Confirm which CSV columns correspond to charging fields."
        case .options:return "Currency, VAT, invoice, and duplicate handling."
        case .import: return "We’ll create entries and skip duplicates automatically."
        }
    }

    private func primaryButtonTitle() -> String {
        switch step {
        case .select, .map: return "Continue"
        case .options:      return "Start Import"
        case .import:       return "Done"
        }
    }

    private func canProceed() -> Bool {
        switch step {
        case .select:
            return !headers.isEmpty && !rows.isEmpty
        case .map:
            return mapping.hasMinimumRequirements
        case .options:
            return true
        case .import:
            return !isImporting
        }
    }

    private func goBack() {
        switch step {
        case .select: break
        case .map:    step = .select
        case .options:step = .map
        case .import: step = .options
        }
    }

    private func next() {
        switch step {
        case .select: step = .map
        case .map:    step = .options
        case .options:startImport()
        case .import: dismiss()
        }
    }

    // MARK: - CSV load

    private func loadCSV(from url: URL) {
        pickedURL = url
        warnings.removeAll()

        do {
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .utf16)
                ?? String(data: data, encoding: .windowsCP1252) // fallback for some regional exports
            else {
                errors.append("Unable to decode CSV as UTF-8/UTF-16/CP1252")
                return
            }

            let parsed = CSVParser.parse(text)
            guard !parsed.rows.isEmpty else {
                errors.append("No rows found in CSV")
                return
            }
            headers = parsed.headers
            rows = parsed.rows

            // Structural sanity-check: every row should have same column count as headers.
            let headerCount = headers.count
            let mismatched = rows.enumerated().filter { $0.element.count != headerCount }
            if !mismatched.isEmpty {
                let sample = mismatched.prefix(3)
                    .map { "#\($0.offset + 2)" }    // +2 (1-based line number, plus header line)
                    .joined(separator: ", ")
                warnings.append(
                    "Warning: \(mismatched.count) row(s) have a different number of columns than the header (\(headerCount)). Sample affected line numbers: \(sample)."
                )
            }

            var m = ColumnMapping()
            autoMapNotes = m.autoMap(with: headers)
            mapping = m
            step = .map
        } catch {
            errors.append("Failed reading CSV: \(error.localizedDescription)")
        }
    }

    // MARK: - Import

    private func startImport() {
        step = .import
        isImporting = true
        imported = 0
        skipped = 0
        errors.removeAll()
        progress = 0
        importedIDs = []
        backfillUndo.removeAll()
        backfillMessage = nil

        let existingKeys = Set(entriesStore.entries.map { $0.dedupeKey() })
        var seen = existingKeys

        let defaultVAT: Double? = Double(
            defaultVATText
                .replacingOccurrences(of: ",", with: "")
                .trimmingCharacters(in: .whitespaces)
        )

        let total = rows.count
        for (idx, row) in rows.enumerated() {
            if let entry = buildEntry(
                from: row,
                defaultCurrency: currencyCode,
                defaultVAT: defaultVAT
            ) {
                let key = entry.dedupeKey()
                if dedupeEnabled && seen.contains(key) {
                    skipped += 1
                } else {
                    entriesStore.addOrReplace(entry)
                    imported += 1
                    seen.insert(key)
                    importedIDs.append(entry.id)
                }
            } else {
                skipped += 1
            }
            progress = Double(idx + 1) / Double(max(total, 1))
        }

        missingKWhCount = computeMissingKWhCount()
        isImporting = false
        if imported > 0 { presentSuccessToast() }
    }

    private func computeMissingKWhCount() -> Int {
        var count = 0
        for id in importedIDs {
            if let e = entriesStore.entries.first(where: { $0.id == id }) {
                let hasKWh = (e.energyAddedKWh ?? 0) > 0
                let price = e.charging?.pricePerKWh ?? 0
                if !hasKWh && price > 0 { count += 1 }
            }
        }
        return count
    }

    private func backfillKWh() {
        guard missingKWhCount > 0 else { return }
        backfillUndo.removeAll()
        var updated = 0
        var totalKWh: Double = 0

        for id in importedIDs {
            guard let idx = entriesStore.entries.firstIndex(where: { $0.id == id }) else { continue }
            var e = entriesStore.entries[idx]
            let hasKWh = (e.energyAddedKWh ?? 0) > 0
            if !hasKWh,
               let price = e.charging?.pricePerKWh,
               price > 0,
               e.amount > 0 {
                let old = e.energyAddedKWh
                let kwh = (e.amount / price).rounded(to: 3)
                e.energyAddedKWh = kwh
                entriesStore.entries[idx] = e
                backfillUndo.append((id, old))
                updated += 1
                totalKWh += kwh
            }
        }

        missingKWhCount = computeMissingKWhCount()
        if updated > 0 {
            let avg = (totalKWh / Double(updated)).rounded(to: 2)
            backfillMessage = "Backfilled \(updated) session\(updated == 1 ? "" : "s") (avg \(avg) kWh)."
        } else {
            backfillMessage = "No sessions required backfill or lacked valid Price/kWh."
        }
    }

    private func undoBackfill() {
        guard !backfillUndo.isEmpty else { return }
        for (id, old) in backfillUndo {
            guard let idx = entriesStore.entries.firstIndex(where: { $0.id == id }) else { continue }
            var e = entriesStore.entries[idx]
            e.energyAddedKWh = old
            entriesStore.entries[idx] = e
        }
        backfillUndo.removeAll()
        backfillMessage = "Restored original kWh values."
        missingKWhCount = computeMissingKWhCount()
    }

    private func presentSuccessToast() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
            showSuccessToast = true
        }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeInOut) { showSuccessToast = false }
        }
    }

    // MARK: - Build an entry from a CSV row

    private func buildEntry(
        from row: [String],
        defaultCurrency: String,
        defaultVAT: Double?
    ) -> ExpenseEntry? {
        func val(_ idx: Int?) -> String? {
            guard let idx, idx >= 0, idx < row.count else { return nil }
            let v = row[idx].trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? nil : v
        }

        let startDateStr = val(mapping.startDate)
        let kWhStr       = val(mapping.energyAddedKWh)
        let ppkStr       = val(mapping.pricePerKWh)
        let site         = val(mapping.siteName)
        let incStr       = val(mapping.totalIncVAT)
        let excStr       = val(mapping.totalExcVAT)
        let vatStr       = val(mapping.vatAmount)
        let invoiceNo    = val(mapping.invoiceNumber)
        let vehicleName  = val(mapping.vehicleName)
        let vin          = val(mapping.vin)
        let note         = val(mapping.notes)

        let startDate: Date? = startDateStr != nil ? DateParser.parse(startDateStr!) : nil
        let kWh: Double?     = kWhStr != nil ? NumberParser.parseDouble(kWhStr!) : nil
        let pricePerKWh: Double? = ppkStr != nil ? NumberParser.parseDouble(ppkStr!) : nil
        let incMapped: Double?   = incStr != nil ? NumberParser.parseDouble(incStr!) : nil
        let excMapped: Double?   = excStr != nil ? NumberParser.parseDouble(excStr!) : nil
        let vatAmount: Double?   = (vatStr != nil ? NumberParser.parseDouble(vatStr!) : nil) ?? defaultVAT

        let gross: Double? = incMapped
            ?? ((excMapped != nil && vatAmount != nil) ? (excMapped! + vatAmount!) : nil)
            ?? ((kWh != nil && pricePerKWh != nil) ? (kWh! * pricePerKWh!) : nil)
        guard let amount = gross else { return nil }

        let details = ChargingDetails(
            startDate: startDate,
            endDate: nil,
            energyAddedKWh: kWh,
            startSOC: nil,
            endSOC: nil,
            durationMinutes: nil,
            odometerStart: nil,
            odometerEnd: nil,
            isSupercharger: true,
            siteName: site,
            latitude: nil,
            longitude: nil,
            pricePerKWh: pricePerKWh,
            outsideTempC: nil,
            chargeId: invoiceNo,
            chargerPowerkW: nil,
            chargerVolts: nil,
            chargerAmps: nil,
            chargerPhases: nil,
            fastChargerBrand: nil,
            vehicleName: vehicleName,
            vin: vin,
            notes: note
        )

        let entry = ExpenseEntry.fromCharging(
            amount: amount,
            currencyCode: defaultCurrency,
            category: "Supercharging",
            location: site,
            notes: note,
            baseDate: startDate,
            details: details,
            vatAmount: vatAmount,
            invoiceNumber: (invoiceNo ?? (invoicePrefix.isEmpty ? nil : invoicePrefix))
        )
        return entry
    }
}

// ===== Helper types =====

private struct ColumnMapping: Equatable {
    var startDate: Int?
    var siteName: Int?
    var energyAddedKWh: Int?
    var pricePerKWh: Int?

    var vatAmount: Int?
    var totalExcVAT: Int?
    var totalIncVAT: Int?

    var invoiceNumber: Int?
    var vehicleName: Int?
    var vin: Int?
    var notes: Int?

    var hasMinimumRequirements: Bool {
        startDate != nil &&
        energyAddedKWh != nil &&
        (totalIncVAT != nil || pricePerKWh != nil)
    }

    private func normKey(_ s: String) -> String {
        s.lowercased().replacingOccurrences(
            of: "[^a-z0-9]",
            with: "",
            options: .regularExpression
        )
    }

    mutating func autoMap(with headers: [String]) -> String {
        var hits: [String] = []
        var m: [String: Int] = [:]
        for (i, h) in headers.enumerated() { m[normKey(h)] = i }

        func set(
            _ kp: WritableKeyPath<ColumnMapping, Int?>,
            _ key: String,
            _ shown: String
        ) {
            if self[keyPath: kp] == nil,
               let idx = m[normKey(key)] {
                self[keyPath: kp] = idx
                hits.append(shown)
            }
        }

        set(\.startDate,       "ChargeStartDateTime", "ChargeStartDateTime")
        set(\.siteName,        "SiteLocationName",    "SiteLocationName")
        set(\.energyAddedKWh,  "QuantityBase",        "QuantityBase")
        set(\.pricePerKWh,     "UnitCostBase",        "UnitCostBase")
        set(\.vatAmount,       "VAT",                 "VAT")
        set(\.totalExcVAT,     "Total Exc. VAT",      "Total Exc. VAT")
        set(\.totalIncVAT,     "Total Inc. VAT",      "Total Inc. VAT")
        set(\.invoiceNumber,   "InvoiceNumber",       "InvoiceNumber")
        set(\.vehicleName,     "Name",                "Name")
        set(\.vin,             "Vin",                 "Vin")
        set(\.notes,           "Description",         "Description")

        return hits.isEmpty ? "" : "Auto-mapped: " + hits.joined(separator: ", ")
    }
}

private enum CSVParser {
    static func parse(_ text: String) -> (headers: [String], rows: [[String]]) {
        // Normalize CRLF → LF to avoid blank-field artifacts on Windows CSVs
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        var lines: [String] = []
        normalized.enumerateLines { line, _ in lines.append(line) }
        guard let first = lines.first else { return ([], []) }

        let headers = parseLine(first)
        var rows: [[String]] = []
        for line in lines.dropFirst() {
            let fields = parseLine(line)
            if fields.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                continue
            }
            rows.append(fields)
        }
        return (headers, rows)
    }

    private static func parseLine(_ line: String) -> [String] {
        var out: [String] = []
        var cur = ""
        var inQ = false
        var i = line.startIndex

        while i < line.endIndex {
            let ch = line[i]
            if ch == "\"" {
                if inQ {
                    let next = line.index(after: i)
                    if next < line.endIndex && line[next] == "\"" {
                        cur.append("\"")
                        i = next
                    } else {
                        inQ = false
                    }
                } else {
                    inQ = true
                }
            } else if ch == "," && !inQ {
                out.append(cur)
                cur = ""
            } else {
                cur.append(ch)
            }
            i = line.index(after: i)
        }
        out.append(cur)
        return out
    }
}

private enum DateParser {
    static func parse(_ s: String) -> Date? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if let secs = Double(t) {
            return Date(timeIntervalSince1970: secs)
        }

        let iso1 = ISO8601DateFormatter()
        iso1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso1.date(from: t) { return d }

        let iso2 = ISO8601DateFormatter()
        iso2.formatOptions = [.withInternetDateTime]
        if let d = iso2.date(from: t) { return d }

        for fmt in [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "M/d/yyyy H:mm",
            "M/d/yy H:mm",
            "MM/dd/yyyy HH:mm",
            "dd/MM/yyyy HH:mm"
        ] {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = fmt
            if let d = df.date(from: t) { return d }
        }
        return nil
    }
}

private enum NumberParser {
    static func parseDouble(_ s: String) -> Double? {
        if s.isEmpty { return nil }
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        t = t.replacingOccurrences(of: "kwh", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "kw h", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "£", with: "")

        let hasComma = t.contains(",")
        let hasDot = t.contains(".")
        if hasComma && hasDot {
            if let lc = t.lastIndex(of: ","),
               let ld = t.lastIndex(of: ".") {
                if lc > ld {
                    // comma as decimal separator, dot as thousands
                    t = t
                        .replacingOccurrences(of: ".", with: "")
                        .replacingOccurrences(of: ",", with: ".")
                } else {
                    // dot as decimal, comma as thousands
                    t = t.replacingOccurrences(of: ",", with: "")
                }
            }
        } else if hasComma {
            // If only comma present, treat as decimal separator for EU locales
            t = t.replacingOccurrences(of: ",", with: ".")
        }

        let allowed = CharacterSet(charactersIn: "+-0123456789.eE")
        t = String(t.unicodeScalars.filter { allowed.contains($0) })
        return Double(t)
    }
}

private extension Double {
    func rounded(to places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}

// MARK: - Small UI bits

private struct ToastBanner: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill").imageScale(.large)
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 8, x: 0, y: 4)
    }
}

private struct StepIndicator: View {
    @EnvironmentObject private var appearance: AppAppearance

    let current: CSVChargingWizardView.Step

    private func dot(_ on: Bool) -> some View {
        Circle()
            .fill(on ? appearance.accentColor : Color.secondary.opacity(0.25))
            .frame(width: 8, height: 8)
    }

    var body: some View {
        HStack(spacing: 6) {
            dot(current.rawValue >= 0)
            dot(current.rawValue >= 1)
            dot(current.rawValue >= 2)
            dot(current.rawValue >= 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current.rawValue + 1) of 4")
    }
}

private struct InfoBanner: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb")
            Text(text)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .tertiarySystemBackground))
        )
    }
}

private struct StatChip: View {
    @EnvironmentObject private var appearance: AppAppearance

    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(appearance.accentColor.opacity(0.15))
                )
        )
    }
}

private struct MapRow: View {
    let title: String
    @Binding var selection: Int?
    let headers: [String]

    var body: some View {
        LabeledContent {
            Picker("", selection: $selection) {
                Text("Not Mapped").tag(Int?.none)
                ForEach(Array(headers.enumerated()), id: \.0) { idx, h in
                    Text(h).tag(Int?.some(idx))
                }
            }
            .pickerStyle(.navigationLink)
        } label: {
            Text(title)
        }
    }
}

// MARK: - Steps UI

private struct SelectCSVStep: View {
    @EnvironmentObject private var appearance: AppAppearance
    @Environment(\.colorScheme) private var scheme

    var selectAction: () -> Void

    var body: some View {
        let accent = appearance.accentColor

        return VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(scheme == .dark ? 0.22 : 0.16),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    VStack(spacing: 14) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 40))
                        Text("Import your Supercharging CSV")
                            .font(.title3).bold()
                        Text("Follow these steps:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Download the official CSV from Tesla.", systemImage: "1.circle")
                            Label("Tap **Select CSV** and pick the file.", systemImage: "2.circle")
                            Label("On the next screen, map the required headers.", systemImage: "3.circle")
                            Label("Review options, then import.", systemImage: "4.circle")
                        }
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: 520, alignment: .leading)
                        Button("Select CSV", action: selectAction)
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 6)
                            .accessibilityLabel("Select CSV file")
                    }
                    .padding(28)
                )
                .frame(maxWidth: .infinity, minHeight: 280)
        }
        .padding(.horizontal)
    }
}

private struct MapColumnsStep: View {
    let headers: [String]
    let firstRow: [String]
    @Binding var mapping: ColumnMapping
    var notes: String?
    var warnings: [String]

    private func val(_ idx: Int?) -> String? {
        guard let i = idx,
              i >= 0,
              i < firstRow.count else { return nil }
        let v = firstRow[i].trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? nil : v
    }

    /// For a given header index, describe how it's used in the mapping (if at all).
    private func usageForHeader(index: Int) -> String? {
        var roles: [String] = []
        if mapping.startDate       == index { roles.append("ChargeStartDateTime") }
        if mapping.energyAddedKWh  == index { roles.append("QuantityBase") }
        if mapping.totalIncVAT     == index { roles.append("Total Inc. VAT") }
        if mapping.pricePerKWh     == index { roles.append("UnitCostBase") }
        if mapping.siteName        == index { roles.append("SiteLocationName") }
        if mapping.invoiceNumber   == index { roles.append("InvoiceNumber") }
        if mapping.vatAmount       == index { roles.append("VAT") }
        if mapping.totalExcVAT     == index { roles.append("Total Exc. VAT") }
        if mapping.vehicleName     == index { roles.append("Name") }
        if mapping.vin             == index { roles.append("Vin") }
        if mapping.notes           == index { roles.append("Description") }
        return roles.isEmpty ? nil : roles.joined(separator: ", ")
    }

    var body: some View {
        Form {
            if !warnings.isEmpty {
                Section("File Warnings") {
                    ForEach(Array(warnings.enumerated()), id: \.0) { _, msg in
                        InfoBanner(text: msg)
                    }
                }
            }

            if let notes, !notes.isEmpty {
                Section {
                    InfoBanner(text: notes)
                }
            }

            Section("Status") {
                HStack(spacing: 8) {
                    StatusPill(
                        title: "ChargeStartDateTime",
                        ok: mapping.startDate != nil
                    )
                    StatusPill(
                        title: "QuantityBase",
                        ok: mapping.energyAddedKWh != nil
                    )
                    StatusPill(
                        title: "Total Inc. VAT or UnitCostBase",
                        ok: mapping.totalIncVAT != nil || mapping.pricePerKWh != nil
                    )
                }
                Text("Every header from your CSV is listed below. The pills above show mapping status for the required Tesla fields.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Required") {
                MapRow(
                    title: "ChargeStartDateTime",
                    selection: $mapping.startDate,
                    headers: headers
                )
                MapRow(
                    title: "QuantityBase",
                    selection: $mapping.energyAddedKWh,
                    headers: headers
                )
                MapRow(
                    title: "Total Inc. VAT",
                    selection: $mapping.totalIncVAT,
                    headers: headers
                )
                MapRow(
                    title: "UnitCostBase",
                    selection: $mapping.pricePerKWh,
                    headers: headers
                )
            }

            Section("Optional") {
                MapRow(
                    title: "SiteLocationName",
                    selection: $mapping.siteName,
                    headers: headers
                )
                MapRow(
                    title: "InvoiceNumber",
                    selection: $mapping.invoiceNumber,
                    headers: headers
                )
                MapRow(
                    title: "VAT",
                    selection: $mapping.vatAmount,
                    headers: headers
                )
                MapRow(
                    title: "Total Exc. VAT",
                    selection: $mapping.totalExcVAT,
                    headers: headers
                )
                MapRow(
                    title: "Name",
                    selection: $mapping.vehicleName,
                    headers: headers
                )
                MapRow(
                    title: "Vin",
                    selection: $mapping.vin,
                    headers: headers
                )
                MapRow(
                    title: "Description",
                    selection: $mapping.notes,
                    headers: headers
                )
            }

            if !firstRow.isEmpty {
                Section("Preview (first row)") {
                    let dateStr: String = {
                        if let s = val(mapping.startDate),
                           let d = DateParser.parse(s) {
                            let f = DateFormatter()
                            f.dateStyle = .medium
                            f.timeStyle = .short
                            return f.string(from: d)
                        }
                        return "—"
                    }()
                    LabeledContent("Date", value: dateStr)
                    LabeledContent("kWh", value: val(mapping.energyAddedKWh) ?? "—")
                    LabeledContent("Price/kWh", value: val(mapping.pricePerKWh) ?? "—")
                    LabeledContent("Total Inc. VAT", value: val(mapping.totalIncVAT) ?? "—")
                    LabeledContent("VAT", value: val(mapping.vatAmount) ?? "—")
                    LabeledContent("Site", value: val(mapping.siteName) ?? "—")
                    LabeledContent("Invoice", value: val(mapping.invoiceNumber) ?? "—")
                }
            }

            Section("Detected Headers (\(headers.count))") {
                ForEach(Array(headers.enumerated()), id: \.0) { idx, name in
                    HStack {
                        Text(name)
                        Spacer()
                        if let usage = usageForHeader(index: idx) {
                            Text(usage)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.18))
                                )
                        } else {
                            Text("Not mapped")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button {
                    var m = ColumnMapping()
                    _ = m.autoMap(with: headers)
                    mapping = m
                } label: {
                    Label("Auto-map again", systemImage: "wand.and.stars")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct OptionsStep: View {
    @Binding var currencyCode: String
    @Binding var defaultVATText: String
    @Binding var invoicePrefix: String
    @Binding var dedupeEnabled: Bool

    var body: some View {
        Form {
            Section("Currency & VAT") {
                TextField("Currency Code (e.g., USD, EUR)", text: $currencyCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                TextField("Default VAT Amount (optional)", text: $defaultVATText)
                    .keyboardType(.decimalPad)
                Text("If your CSV includes VAT/Tax per row, that will override the default above.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Invoice") {
                TextField("Invoice Prefix (optional)", text: $invoicePrefix)
                Text("If a row has no Invoice column, we’ll use `prefix + chargeId` when available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Duplicates") {
                Toggle("Skip duplicates (recommended)", isOn: $dedupeEnabled)
                Text("Duplicate detection uses a key of start-minute + kWh + site.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct ImportStep: View {
    let isImporting: Bool
    let progress: Double
    let imported: Int
    let skipped: Int
    let errors: [String]
    let missingKWhCount: Int
    let onBackfillTap: () -> Void
    let canUndo: Bool
    let onUndo: () -> Void
    let message: String?

    var body: some View {
        VStack(spacing: 16) {
            if isImporting {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                Text("Importing… \(Int((progress * 100).rounded()))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 18) {
                    StatChip(
                        title: "Imported",
                        value: "\(imported)",
                        systemImage: "tray.and.arrow.down.fill"
                    )
                    StatChip(
                        title: "Skipped",
                        value: "\(skipped)",
                        systemImage: "arrow.uturn.left.circle.fill"
                    )
                }

                if let msg = message, !msg.isEmpty {
                    Text(msg)
                        .font(.subheadline)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(uiColor: .tertiarySystemBackground))
                        )
                }

                if missingKWhCount > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional step available")
                            .font(.headline)
                        Text(
                            "\(missingKWhCount) imported sessions are missing Energy (kWh) but include Price/kWh. We can derive kWh = Amount ÷ Price/kWh."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        Button(action: onBackfillTap) {
                            Label(
                                "Backfill kWh (\(missingKWhCount))",
                                systemImage: "wand.and.stars"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
                }

                if canUndo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Undo available")
                            .font(.headline)
                        Text("Restore original Energy (kWh) values for the sessions we just backfilled.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button(action: onUndo) {
                            Label("Undo Backfill", systemImage: "arrow.uturn.backward.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
                }
            }

            if !errors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Issues")
                        .font(.headline)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(errors.enumerated()), id: \.0) { _, msg in
                                Text("• " + msg)
                                    .font(.footnote)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 160)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
            }
        }
    }
}

private struct StatusPill: View {
    let title: String
    let ok: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            Text(title)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(ok ? Color.green.opacity(0.18) : Color.orange.opacity(0.18))
        )
        .foregroundStyle(ok ? .green : .orange)
    }
}

private struct HelpSheet: View {
    let step: CSVChargingWizardView.Step

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .select:
                    Section("What file do I need?") {
                        Text("Download the **official Supercharging CSV** from Tesla. This importer only lists those headers.")
                    }
                    Section("Quick steps") {
                        Label("Tap **Select CSV**.", systemImage: "1.circle")
                        Label("Pick the CSV file.", systemImage: "2.circle")
                        Label("Map required headers.", systemImage: "3.circle")
                        Label("Review options and import.", systemImage: "4.circle")
                    }
                case .map:
                    Section("Required headers") {
                        Text("Map **ChargeStartDateTime**, **QuantityBase**, and either **Total Inc. VAT** or **UnitCostBase**. Optional fields like **VAT**, **InvoiceNumber**, **SiteLocationName** improve analytics.")
                    }
                    Section("Header integrity") {
                        Text("Every header from your CSV is imported and listed. The Detected Headers section shows which columns are mapped to which charging fields, so you can verify there’s no missing or mis-linked column before importing.")
                    }
                case .options:
                    Section("Currency & VAT") {
                        Text("Set your currency code and an optional default VAT amount. If the CSV row includes VAT, that value takes precedence.")
                    }
                    Section("Duplicates") {
                        Text("We skip likely duplicates using **start minute + kWh + site**. You can turn this off, but it’s recommended.")
                    }
                case .import:
                    Section("What’s next?") {
                        Text("Close this sheet when finished. Your imported sessions will appear in your log and analytics.")
                    }
                }
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#if DEBUG
#Preview {
    let appearance = AppAppearance()
    let entries = EntriesStore()

    return CSVChargingWizardView()
        .environmentObject(entries)
        .environmentObject(appearance)
}
#endif
