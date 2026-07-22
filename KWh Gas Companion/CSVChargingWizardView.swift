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
    @State private var isLoadingCSV: Bool = false
    @State private var showImportedReview: Bool = false

    @State private var importedIDs: [UUID] = []
    @State private var missingKWhCount: Int = 0
    @State private var backfillUndo: [(UUID, Double?)] = []
    @State private var showBackfillConfirm: Bool = false
    @State private var backfillMessage: String? = nil
    @State private var validationTask: Task<Void, Never>? = nil

    // Structural / header-level warnings (e.g., column count mismatches)
    @State private var warnings: [String] = []

    // Row-level validation (CSVRowValidator)
    @State private var validationSummary: ValidationSummary? = nil

    var body: some View {
        content
            .background(Color(uiColor: .systemGroupedBackground))
            .contentMargins(.top, 88, for: .scrollContent)
            .navigationTitle(navigationTitleForStep(step))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    StepIndicator(current: step)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHelp = true
                    } label: {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [
                    .commaSeparatedText,
                    .plainText,
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
            .overlay(alignment: .top) {
                if showSuccessToast {
                    ToastBanner(text: "Imported successfully. Don't forget to tap Done.")
                        .padding(.top, 8)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .accessibilityHidden(false)
                        .accessibilityLabel("Import successful")
                }
            }
            .alert("Fill in missing energy?", isPresented: $showBackfillConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Fill In", action: backfillKWh)
            } message: {
                Text("\(missingKWhCount) session\(missingKWhCount == 1 ? "" : "s") are missing energy, but the file includes enough pricing details for us to calculate it. You can undo this later.")
            }
            .sheet(isPresented: $showHelp) { HelpSheet(step: step) }
            .sheet(isPresented: $showImportedReview) {
                ImportedEntriesReviewView(importedIDs: importedIDs)
                    .environmentObject(entriesStore)
            }
            .tint(.accentColor)
            .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Content
    //
    // FIX: Each step is now responsible for its own scrollability and bottom
    // padding so content never hides under the safeAreaInset bottom bar.
    // - .select  → ScrollView wrapper with bottom padding
    // - .map     → Form handles its own insets (no change needed)
    // - .options → Form handles its own insets (no change needed)
    // - .import  → ScrollView wrapper with bottom padding (was a bare VStack)

    // Expose accentColor for child views that can't safely use @EnvironmentObject
    // (e.g. when embedded in Form where environment injection may be incomplete).
    @EnvironmentObject private var appearance: AppAppearance

    @ViewBuilder private var content: some View {
        switch step {
        case .select:
            // 🔧 FIX: SelectCSVTextStep replaced with SelectCSVStepWithDrop.
            // The old SelectCSVTextStep called CSVDropTargetModifier which required
            // @EnvironmentObject AppAppearance — but didn't inject it, causing a crash.
            // SelectCSVStepWithDrop accepts accentColor as a plain parameter and also
            // displays the selected filename for better user feedback.
            SelectCSVStepWithDrop(
                selectAction: { isImporterPresented = true },
                onFileDrop: { url in loadCSV(from: url) },
                selectedFileName: pickedURL?.lastPathComponent,
                accentColor: appearance.accentColor
            )
            .safeAreaInset(edge: .bottom) {
                selectStepBottomBar
            }
            .overlay(alignment: .top) {
                if !errors.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(Array(errors.enumerated()), id: \.0) { _, msg in
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(msg).font(.footnote)
                                Spacer()
                            }
                            .foregroundStyle(.red)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.10)))
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 8)
                }
            }

        case .map:
            MapColumnsStep(
                headers: headers,
                firstRow: rows.first ?? [],
                mapping: $mapping,
                notes: autoMapNotes,
                warnings: warnings,
                validationSummary: validationSummary,
                canContinue: mapping.hasMinimumRequirements,
                onBack: goBack,
                onContinue: next
            )
            .onChange(of: mapping) { _, _ in revalidate() }

        case .options:
            OptionsStep(
                currencyCode: $currencyCode,
                defaultVATText: $defaultVATText,
                invoicePrefix: $invoicePrefix,
                dedupeEnabled: $dedupeEnabled,
                onBack: goBack,
                onContinue: next
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
                message: backfillMessage,
                canReviewImported: imported > 0,
                onReviewImported: { showImportedReview = true },
                onBack: goBack,
                onDone: next
            )
        }
    }

    // MARK: - Step helpers

    /// Bottom bar shown on the select step — provides loading feedback and Continue.
    @ViewBuilder private var selectStepBottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                if isLoadingCSV {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.85)
                        Text("Reading file…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let name = pickedURL?.lastPathComponent {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(name)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button("Continue", action: next)
                    .buttonStyle(.borderedProminent)
                    .tint(appearance.accentColor)
                    .disabled(!canProceed())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    private func navigationTitleForStep(_ s: Step) -> String {
        switch s {
        case .select: return "Import CSV"
        case .map:    return "Match Columns"
        case .options:return "Import Options"
        case .import: return "Import"
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
            return !isLoadingCSV && !headers.isEmpty && !rows.isEmpty
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
        errors.removeAll()
        warnings.removeAll()
        isLoadingCSV = true

        Task {
            defer { isLoadingCSV = false }

            do {
                let parsed = try await loadCSVContents(from: url)
                guard !parsed.rows.isEmpty else {
                    errors.append("No rows found in CSV")
                    return
                }
                headers = parsed.headers

                let headerCount = parsed.headers.count
                let mismatched = parsed.rows.enumerated().filter { $0.element.count != headerCount }
                if !mismatched.isEmpty {
                    let sample = mismatched.prefix(3)
                        .map { "#\($0.offset + 2)" }
                        .joined(separator: ", ")
                    warnings.append(
                        "Warning: \(mismatched.count) row(s) have a different number of columns than the header (\(headerCount)). Sample affected line numbers: \(sample)."
                    )
                }
                rows = OfficialTeslaCSVRowShape.paddedRows(parsed.rows, headerCount: headerCount)

                var m = ColumnMapping()
                _ = m.autoMap(with: headers)
                autoMapNotes = autoMapSummary(for: m)
                mapping = m
                step = .map
                revalidate()
            } catch let error as CSVWizardLoadError {
                errors.append(error.localizedDescription)
            } catch {
                errors.append("Failed reading CSV: \(error.localizedDescription)")
            }
        }
    }

    private func revalidate() {
        guard !rows.isEmpty else { validationSummary = nil; return }
        validationTask?.cancel()
        let vmap = ValidatorColumnMapping(
            startDate:      mapping.startDate,
            energyAddedKWh: mapping.energyAddedKWh,
            pricePerKWh:    mapping.pricePerKWh,
            totalIncVAT:    mapping.totalIncVAT,
            totalExcVAT:    mapping.totalExcVAT,
            vatAmount:      mapping.vatAmount
        )
        validationTask = Task<Void, Never>(priority: .userInitiated) { [rows] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            let result = CSVRowValidator.validate(rows: rows, mapping: vmap)
            guard !Task.isCancelled else { return }
            validationSummary = result
        }
    }

    private func autoMapSummary(for mapping: ColumnMapping) -> String? {
        var matches: [String] = []
        if mapping.startDate != nil { matches.append("date and time") }
        if mapping.energyAddedKWh != nil { matches.append("energy added") }
        if mapping.totalIncVAT != nil { matches.append("total paid") }
        if mapping.pricePerKWh != nil { matches.append("price per kWh") }
        if mapping.siteName != nil { matches.append("location") }
        if mapping.invoiceNumber != nil { matches.append("invoice number") }
        if mapping.vatAmount != nil { matches.append("tax") }
        if mapping.totalExcVAT != nil { matches.append("pre-tax total") }
        if mapping.vehicleName != nil { matches.append("vehicle name") }
        if mapping.vin != nil { matches.append("VIN") }
        if mapping.notes != nil { matches.append("notes") }
        guard !matches.isEmpty else { return nil }
        return "We matched these for you: \(matches.joined(separator: ", ")). Please give them a quick review before importing."
    }

    private func loadCSVContents(from url: URL) async throws -> (headers: [String], rows: [[String]]) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let started = url.startAccessingSecurityScopedResource()
                defer { if started { url.stopAccessingSecurityScopedResource() } }

                do {
                    let data = try Data(contentsOf: url)
                    guard let text = decodedWizardCSVText(from: data) else {
                        throw CSVWizardLoadError.unreadableText
                    }
                    continuation.resume(returning: CSVParser.parse(text))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
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
                .trimmingCharacters(in: .whitespacesAndNewlines)
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
        let indexByID = Dictionary(
            uniqueKeysWithValues: entriesStore.entries.enumerated().map { ($0.element.id, $0.offset) }
        )
        var count = 0
        for id in importedIDs {
            if let idx = indexByID[id] {
                let e = entriesStore.entries[idx]
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
        let indexByID = Dictionary(
            uniqueKeysWithValues: entriesStore.entries.enumerated().map { ($0.element.id, $0.offset) }
        )

        for id in importedIDs {
            guard let idx = indexByID[id] else { continue }
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
            backfillMessage = "Filled in energy for \(updated) session\(updated == 1 ? "" : "s"). Average added: \(avg) kWh."
        } else {
            backfillMessage = "We couldn't fill in any missing energy from the available pricing details."
        }
    }

    private func undoBackfill() {
        guard !backfillUndo.isEmpty else { return }
        let indexByID = Dictionary(
            uniqueKeysWithValues: entriesStore.entries.enumerated().map { ($0.element.id, $0.offset) }
        )
        for (id, old) in backfillUndo {
            guard let idx = indexByID[id] else { continue }
            var e = entriesStore.entries[idx]
            e.energyAddedKWh = old
            entriesStore.entries[idx] = e
        }
        backfillUndo.removeAll()
        backfillMessage = "Restored the original energy values."
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

enum CSVParser {
    static func parse(_ text: String) -> (headers: [String], rows: [[String]]) {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let records = parseRecords(normalized).filter { record in
            !record.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        guard let first = records.first else { return ([], []) }
        var headers = first
        if let firstHeader = headers.first {
            headers[0] = stripByteOrderMark(from: firstHeader)
        }
        return (headers, Array(records.dropFirst()))
    }

    /// Parse the full document so quoted Tesla description fields can contain commas
    /// and line breaks without turning one session into several malformed rows.
    private static func parseRecords(_ text: String) -> [[String]] {
        var records: [[String]] = []
        var row: [String] = []
        var cur = ""
        var inQ = false
        var i = text.startIndex

        while i < text.endIndex {
            let ch = text[i]
            if ch == "\"" {
                if inQ {
                    let next = text.index(after: i)
                    if next < text.endIndex && text[next] == "\"" {
                        cur.append("\"")
                        i = next
                    } else {
                        inQ = false
                    }
                } else {
                    inQ = true
                }
            } else if ch == "," && !inQ {
                row.append(cur)
                cur = ""
            } else if ch == "\n" && !inQ {
                row.append(cur)
                records.append(row)
                row = []
                cur = ""
            } else {
                cur.append(ch)
            }
            i = text.index(after: i)
        }
        if !cur.isEmpty || !row.isEmpty {
            row.append(cur)
            records.append(row)
        }
        return records
    }

    private static func stripByteOrderMark(from value: String) -> String {
        guard value.first == "\u{FEFF}" else { return value }
        return String(value.dropFirst())
    }
}

enum OfficialTeslaCSVRowShape {
    static func paddedRows(_ rows: [[String]], headerCount: Int) -> [[String]] {
        rows.map { row in
            guard row.count < headerCount else { return row }
            return row + Array(repeating: "", count: headerCount - row.count)
        }
    }
}

private enum CSVWizardLoadError: LocalizedError {
    case unreadableText

    var errorDescription: String? {
        switch self {
        case .unreadableText:
            return "Unable to decode CSV as UTF-8, UTF-16, or CP1252."
        }
    }
}

private func decodedWizardCSVText(from data: Data) -> String? {
    String(data: data, encoding: .utf8)
        ?? String(data: data, encoding: .utf16)
        ?? String(data: data, encoding: .utf16LittleEndian)
        ?? String(data: data, encoding: .utf16BigEndian)
        ?? String(data: data, encoding: .windowsCP1252)
}

private enum DateParser {
    private static let posixLocale = Locale(identifier: "en_US_POSIX")
    private static let isoWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let isoStandard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    private static let fallbackFormatters: [DateFormatter] = [
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "M/d/yyyy H:mm",
        "M/d/yy H:mm",
        "MM/dd/yyyy HH:mm",
        "dd/MM/yyyy HH:mm"
    ].map { format in
        let formatter = DateFormatter()
        formatter.locale = posixLocale
        formatter.dateFormat = format
        return formatter
    }

    static func parse(_ s: String) -> Date? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if let secs = Double(t) {
            return Date(timeIntervalSince1970: secs)
        }

        if let d = isoWithFractionalSeconds.date(from: t) { return d }

        if let d = isoStandard.date(from: t) { return d }

        for formatter in fallbackFormatters {
            if let d = formatter.date(from: t) { return d }
        }
        return nil
    }
}

private enum CSVWizardDisplayFormatter {
    static let previewDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
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
                    t = t
                        .replacingOccurrences(of: ".", with: "")
                        .replacingOccurrences(of: ",", with: ".")
                } else {
                    t = t.replacingOccurrences(of: ",", with: "")
                }
            }
        } else if hasComma {
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
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .imageScale(.large)
            Text(text)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThickMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.green.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

private struct StepIndicator: View {
    let current: CSVChargingWizardView.Step

    private let labels = ["Select", "Map", "Options", "Import"]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { index in
                let isComplete = index < current.rawValue
                let isCurrent  = index == current.rawValue

                HStack(spacing: 5) {
                    ZStack {
                        Circle()
                            .fill(isComplete ? Color.accentColor : (isCurrent ? Color.accentColor : Color.secondary.opacity(0.22)))
                            .frame(width: 18, height: 18)
                        if isComplete {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(isCurrent ? .white : .secondary)
                        }
                    }
                    if isCurrent {
                        Text(labels[index])
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, isCurrent ? 8 : 4)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isCurrent
                              ? Color.accentColor.opacity(0.12)
                              : Color.clear)
                )

                if index < 3 {
                    Rectangle()
                        .fill(index < current.rawValue ? Color.accentColor : Color.secondary.opacity(0.18))
                        .frame(height: 1.5)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: current)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current.rawValue + 1) of 4: \(labels[current.rawValue])")
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
                        .strokeBorder(Color.accentColor.opacity(0.15))
                )
        )
    }
}

private struct MapRow: View {
    let title: String
    let subtitle: String?
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
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Steps UI

// SelectCSVTextStep has been replaced by SelectCSVStepWithDrop from CSVDropTargetModifier.swift.
// See the .select case in CSVChargingWizardView.content for usage.

private struct MapColumnsStep: View {
    let headers: [String]
    let firstRow: [String]
    @Binding var mapping: ColumnMapping
    var notes: String?
    var warnings: [String]
    var validationSummary: ValidationSummary? = nil
    let canContinue: Bool
    let onBack: () -> Void
    let onContinue: () -> Void

    private func val(_ idx: Int?) -> String? {
        guard let i = idx,
              i >= 0,
              i < firstRow.count else { return nil }
        let v = firstRow[i].trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? nil : v
    }

    private func usageForHeader(index: Int) -> String? {
        var roles: [String] = []
        if mapping.startDate       == index { roles.append("Date & time") }
        if mapping.energyAddedKWh  == index { roles.append("Energy added") }
        if mapping.totalIncVAT     == index { roles.append("Total paid") }
        if mapping.pricePerKWh     == index { roles.append("Price per kWh") }
        if mapping.siteName        == index { roles.append("Location name") }
        if mapping.invoiceNumber   == index { roles.append("Invoice number") }
        if mapping.vatAmount       == index { roles.append("Tax amount") }
        if mapping.totalExcVAT     == index { roles.append("Pre-tax total") }
        if mapping.vehicleName     == index { roles.append("Vehicle name") }
        if mapping.vin             == index { roles.append("VIN") }
        if mapping.notes           == index { roles.append("Notes") }
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

            if let summary = validationSummary, !summary.isEmpty {
                Section {
                    MappingValidationBanner(summary: summary)
                }
            }

            if let notes, !notes.isEmpty {
                Section {
                    InfoBanner(text: notes)
                }
            }

            Section {
                InfoBanner(text: "Check the matches below and change anything that doesn’t look right.")
            }

            Section("Required to Import") {
                Text(mapping.startDate != nil ? "Date & time: Ready" : "Date & time: Needed")
                Text(mapping.energyAddedKWh != nil ? "Energy added: Ready" : "Energy added: Needed")
                Text(mapping.totalIncVAT != nil || mapping.pricePerKWh != nil ? "Total paid or price per kWh: Ready" : "Total paid or price per kWh: Needed")
                    .foregroundColor((mapping.totalIncVAT != nil || mapping.pricePerKWh != nil) ? .primary : .orange)
                Text("Everything we found in your file is listed below.")
                    .foregroundStyle(.secondary)
            }

            Section("Needed Fields") {
                MapRow(
                    title: "Date & time",
                    subtitle: "Tesla column: ChargeStartDateTime",
                    selection: $mapping.startDate,
                    headers: headers
                )
                MapRow(
                    title: "Energy added (kWh)",
                    subtitle: "Tesla column: QuantityBase",
                    selection: $mapping.energyAddedKWh,
                    headers: headers
                )
                MapRow(
                    title: "Total paid",
                    subtitle: "Tesla column: Total Inc. VAT",
                    selection: $mapping.totalIncVAT,
                    headers: headers
                )
                MapRow(
                    title: "Price per kWh",
                    subtitle: "Tesla column: UnitCostBase",
                    selection: $mapping.pricePerKWh,
                    headers: headers
                )
            }

            Section("Extra Details") {
                MapRow(
                    title: "Location name",
                    subtitle: "Tesla column: SiteLocationName",
                    selection: $mapping.siteName,
                    headers: headers
                )
                MapRow(
                    title: "Invoice number",
                    subtitle: "Tesla column: InvoiceNumber",
                    selection: $mapping.invoiceNumber,
                    headers: headers
                )
                MapRow(
                    title: "Tax amount",
                    subtitle: "Tesla column: VAT",
                    selection: $mapping.vatAmount,
                    headers: headers
                )
                MapRow(
                    title: "Pre-tax total",
                    subtitle: "Tesla column: Total Exc. VAT",
                    selection: $mapping.totalExcVAT,
                    headers: headers
                )
                MapRow(
                    title: "Vehicle name",
                    subtitle: "Tesla column: Name",
                    selection: $mapping.vehicleName,
                    headers: headers
                )
                MapRow(
                    title: "VIN",
                    subtitle: "Tesla column: Vin",
                    selection: $mapping.vin,
                    headers: headers
                )
                MapRow(
                    title: "Notes",
                    subtitle: "Tesla column: Description",
                    selection: $mapping.notes,
                    headers: headers
                )
            }

            if !firstRow.isEmpty {
                Section("Preview") {
                    let dateStr: String = {
                        if let s = val(mapping.startDate),
                           let d = DateParser.parse(s) {
                            return CSVWizardDisplayFormatter.previewDateTime.string(from: d)
                        }
                        return "—"
                    }()
                    LabeledContent("Date & time", value: dateStr)
                    LabeledContent("Energy added", value: val(mapping.energyAddedKWh) ?? "—")
                    LabeledContent("Price per kWh", value: val(mapping.pricePerKWh) ?? "—")
                    LabeledContent("Total paid", value: val(mapping.totalIncVAT) ?? "—")
                    LabeledContent("Tax", value: val(mapping.vatAmount) ?? "—")
                    LabeledContent("Location", value: val(mapping.siteName) ?? "—")
                    LabeledContent("Invoice", value: val(mapping.invoiceNumber) ?? "—")
                }
            }

            Section("Columns in Your File (\(headers.count))") {
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
                            Text("Not used")
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
                    Label("Match Again", systemImage: "wand.and.stars")
                }
            }

            Section {
                if !canContinue {
                    Text("Choose a date and time column, an energy column, and either a total paid column or a price per kWh column to continue.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Back", action: onBack)
                    Spacer()
                    Button("Continue", action: onContinue)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canContinue)
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
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        Form {
            Section("Currency") {
                TextField("Currency code (for example, USD or EUR)", text: $currencyCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                TextField("Default tax amount (optional)", text: $defaultVATText)
                    .keyboardType(.decimalPad)
                Text("If your file already includes tax for a session, we’ll use that value instead.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Invoice") {
                TextField("Invoice prefix (optional)", text: $invoicePrefix)
                Text("If a row is missing an invoice number, we’ll try to build one from this prefix.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Duplicates") {
                Toggle("Skip duplicates (recommended)", isOn: $dedupeEnabled)
                Text("We compare the session time, energy amount, and location to avoid importing the same stop twice.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Button("Back", action: onBack)
                    Spacer()
                    Button("Start Import", action: onContinue)
                        .buttonStyle(.borderedProminent)
                }
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
    let canReviewImported: Bool
    let onReviewImported: () -> Void
    let onBack: () -> Void
    let onDone: () -> Void

    var body: some View {
        Form {
            if isImporting {
                Section {
                    VStack(spacing: 20) {
                        // Circular progress ring
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    Color.accentColor,
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 0.1), value: progress)
                            Text("\(Int((progress * 100).rounded()))%")
                                .font(.title3.weight(.bold).monospacedDigit())
                        }
                        .frame(width: 80, height: 80)
                        .padding(.top, 8)

                        Text("Importing your sessions…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else {
                Section {
                    // Results summary row
                    HStack(spacing: 0) {
                        importResultStat(
                            value: "\(imported)",
                            label: "Imported",
                            icon: "checkmark.circle.fill",
                            color: imported > 0 ? .green : .secondary
                        )
                        Divider().frame(height: 50).padding(.horizontal, 16)
                        importResultStat(
                            value: "\(skipped)",
                            label: "Skipped",
                            icon: "minus.circle.fill",
                            color: .secondary
                        )
                    }
                } header: {
                    Text("Results")
                }

                if let msg = message, !msg.isEmpty {
                    Section {
                        Text(msg)
                            .foregroundStyle(.secondary)
                    }
                }

                if canReviewImported {
                    Section("Next Steps") {
                        Text("Spot-check the imported sessions now to confirm prices, energy, and locations look right.")
                            .foregroundStyle(.secondary)
                        Button(action: onReviewImported) {
                            Label("Review Imported Sessions", systemImage: "list.bullet.rectangle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if missingKWhCount > 0 {
                    // 🔧 FIX: Removed duplicate Text("Missing energy found") label —
                    // it appeared twice (once as plain Text, once as Section header).
                    Section("Missing Energy Found") {
                        Text(
                            "\(missingKWhCount) imported session\(missingKWhCount == 1 ? "" : "s") are missing the energy amount, but include enough pricing details for us to calculate it."
                        )
                        .foregroundStyle(.secondary)
                        Button(action: onBackfillTap) {
                            Label(
                                "Fill In Energy (\(missingKWhCount))",
                                systemImage: "wand.and.stars"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if canUndo {
                    // 🔧 FIX: Removed duplicate Text("Undo available") label.
                    Section("Undo") {
                        Text("Restore the original energy values for the sessions we just updated.")
                            .foregroundStyle(.secondary)
                        Button(action: onUndo) {
                            Label("Undo Changes", systemImage: "arrow.uturn.backward.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if !errors.isEmpty {
                Section("Issues") {
                    ForEach(Array(errors.enumerated()), id: \.0) { _, msg in
                        Text("• " + msg)
                            .font(.footnote)
                    }
                }
            }

            Section {
                HStack {
                    if !isImporting {
                        Button("Back", action: onBack)
                    }
                    Spacer()
                    Button("Done", action: onDone)
                        .buttonStyle(.borderedProminent)
                        .disabled(isImporting)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
    }
    private func importResultStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
                        Text("Download your charging history CSV from Tesla, then choose it here.")
                    }
                    Section("Quick steps") {
                        Label("Tap **Select CSV**.", systemImage: "1.circle")
                        Label("Pick the CSV file.", systemImage: "2.circle")
                        Label("Match the key items.", systemImage: "3.circle")
                        Label("Review options and import.", systemImage: "4.circle")
                    }
                case .map:
                    Section("What matters most") {
                        Text("Make sure the app knows which columns contain the session date and time, the energy added, and either the total paid or the price per kWh.")
                    }
                    Section("Double-check the matches") {
                        Text("Every column from your file is shown on this screen so you can quickly confirm nothing important was matched incorrectly.")
                    }
                case .options:
                    Section("Currency and tax") {
                        Text("Choose your currency and, if needed, a default tax amount. Session-level tax from the file will override the default.")
                    }
                    Section("Duplicates") {
                        Text("We skip likely duplicates automatically. You can turn that off, but most people should leave it on.")
                    }
                case .import:
                    Section("What's next?") {
                        Text("When the import finishes, you can review the imported sessions first or tap Done to return to your charging history.")
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

private struct ImportedEntriesReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entriesStore: EntriesStore

    let importedIDs: [UUID]

    @State private var selectedEntry: ExpenseEntry?

    private var importedEntries: [ExpenseEntry] {
        let importedSet = Set(importedIDs)
        return entriesStore.entries
            .filter { importedSet.contains($0.id) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if importedEntries.isEmpty {
                    ContentUnavailableView(
                        "Nothing to Review",
                        systemImage: "tray",
                        description: Text("Imported sessions will appear here after the wizard finishes.")
                    )
                } else {
                    List(importedEntries) { entry in
                        Button {
                            selectedEntry = entry
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.location ?? entry.charging?.siteName ?? "Charging session")
                                        .font(.subheadline.weight(.semibold))
                                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(entry.amount, format: .currency(code: entry.currencyCode ?? Locale.current.currency?.identifier ?? "USD"))
                                        .monospacedDigit()
                                    if let kWh = entry.energyAddedKWh, kWh > 0 {
                                        Text("\(kWh.formatted(.number.precision(.fractionLength(1)))) kWh")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Imported Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedEntry) { entry in
                AddEditEntryView(entry: entry) { updated in
                    entriesStore.upsert(updated)
                    selectedEntry = nil
                }
                .environmentObject(entriesStore)
            }
        }
    }
}
