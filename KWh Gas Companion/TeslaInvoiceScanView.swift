import SwiftUI
import PDFKit
import Vision
import UniformTypeIdentifiers
import UIKit

@MainActor
struct TeslaInvoiceScanView: View {
    @Environment(\.appThemeBox) private var themeBox
    @EnvironmentObject private var entriesStore: EntriesStore
    @StateObject private var adsStore = AdsEntitlementStore.shared

    @State private var showImporter = false
    @State private var pdfURL: URL?
    @State private var isScanning = false
    @State private var rawText: String = ""

    @State private var location: String = ""
    @State private var dateText: String = ""
    @State private var energyKWh: String = ""
    @State private var pricePerKWh: String = ""
    @State private var totalCost: String = ""
    @State private var additionalNotes: String = ""

    @State private var showingEntryPicker = false
    @State private var selectedEntryID: UUID?
    @State private var showingEditor = false
    @State private var editorEntry: ExpenseEntry?

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                instructionsCard
                importCard
                extractedCard
                saveActionsCard

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Tesla Invoice Scan")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    pdfURL = url
                    Task { await scanPDF(url) }
                }
            case .failure:
                break
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let editorEntry {
                AddEditEntryView(entry: editorEntry) { updated in
                    entriesStore.upsert(updated)
                    showingEditor = false
                } onCancel: {
                    showingEditor = false
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scan Tesla Supercharger invoices")
                .font(.headline)
            Text("Upload the official Tesla invoice PDF and we’ll extract the key fields.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How to export")
                .font(.headline)
            Text("Tesla App > picture in top right > account > charging > history > tap the session you want > tap “invoice”.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                showImporter = true
            } label: {
                Label("Select invoice PDF", systemImage: "doc")
                    .font(.subheadline.weight(.semibold))
            }

            if let url = pdfURL {
                Text(url.lastPathComponent)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Scanning…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .themedCard()
    }

    private var extractedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Extracted fields")
                .font(.headline)

            fieldRow("Location", text: $location)
            fieldRow("Date", text: $dateText)
            fieldRow("Energy (kWh)", text: $energyKWh)
            fieldRow("Price / kWh", text: $pricePerKWh)
            fieldRow("Total", text: $totalCost)
            fieldRow("Notes", text: $additionalNotes)

            if !rawText.isEmpty {
                Divider().opacity(0.2)
                Text("Raw OCR")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(rawText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(8)
            }
        }
        .themedCard()
    }

    private var saveActionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Save to Expenses")
                .font(.headline)

            if let suggestion = suggestedEntry {
                Button {
                    updateExistingEntry(suggestion)
                    openEditor(with: suggestion)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Update suggested entry")
                            .font(.subheadline.weight(.semibold))
                        Text("\(suggestion.location ?? suggestion.charging?.siteName ?? "Charging") · \(suggestion.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
            }

            Button {
                saveNewExpense()
            } label: {
                Label("Save as new expense", systemImage: "plus.circle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)

            Button {
                showingEntryPicker = true
            } label: {
                Label("Update existing entry", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
        }
        .themedCard()
        .sheet(isPresented: $showingEntryPicker) {
            NavigationStack {
                List {
                    ForEach(recentEnergyEntries) { entry in
                        Button {
                            selectedEntryID = entry.id
                            updateExistingEntry(entry)
                            openEditor(with: entry)
                            showingEntryPicker = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.location ?? entry.charging?.siteName ?? "Charging")
                                    .font(.headline)
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .navigationTitle("Select Entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { showingEntryPicker = false }
                    }
                }
            }
        }
    }

    private func fieldRow(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", text: text)
                .multilineTextAlignment(.trailing)
                .frame(width: 200)
        }
        .font(.subheadline)
    }

    private func scanPDF(_ url: URL) async {
        isScanning = true
        defer { isScanning = false }

        guard let doc = PDFDocument(url: url) else { return }
        var lines: [String] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let image = page.thumbnail(of: CGSize(width: 1200, height: 1600), for: .mediaBox)
            if let pageLines = await recognizeText(from: image) {
                lines.append(contentsOf: pageLines)
            }
        }

        let cleaned = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        rawText = cleaned.joined(separator: "\n")
        parseTeslaInvoice(lines: cleaned)
    }

    private func recognizeText(from image: UIImage) async -> [String]? {
        guard let cg = image.cgImage else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do {
            try handler.perform([request])
            let observations = request.results ?? []
            return observations.compactMap { $0.topCandidates(1).first?.string }
        } catch {
            return nil
        }
    }

    private func parseTeslaInvoice(lines: [String]) {
        let joined = lines.joined(separator: "\n")

        if location.isEmpty {
            location = lines.first(where: { $0.localizedCaseInsensitiveContains("Supercharger") }) ?? ""
        }

        if dateText.isEmpty {
            dateText = joined.firstMatch(#"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#) ?? ""
        }

        if energyKWh.isEmpty {
            energyKWh = joined.firstMatch(#"(\d+(\.\d+)?)\s*kWh"#) ?? ""
        }

        if pricePerKWh.isEmpty {
            pricePerKWh = joined.firstMatch(#"\$?\d+\.\d+\s*/\s*kWh"#) ?? ""
        }

        if totalCost.isEmpty {
            totalCost = joined.firstMatch(#"(Total.*?\$?\d+[.,]\d{2})"#)
                ?? joined.firstMatch(#"\$?\d+[.,]\d{2}"#) ?? ""
        }
    }

    private var recentEnergyEntries: [ExpenseEntry] {
        entriesStore.energyEntries()
            .sorted { $0.date > $1.date }
            .prefix(25)
            .map { $0 }
    }

    private var suggestedEntry: ExpenseEntry? {
        guard let parsedDate = parsedDate() else { return nil }
        let targetKWh = parsedEnergy()
        let windowStart = Calendar.current.date(byAdding: .day, value: -2, to: parsedDate) ?? parsedDate
        let windowEnd = Calendar.current.date(byAdding: .day, value: 2, to: parsedDate) ?? parsedDate

        let candidates = entriesStore.energyEntries().filter {
            $0.date >= windowStart && $0.date <= windowEnd
        }

        guard !candidates.isEmpty else { return nil }

        func score(_ entry: ExpenseEntry) -> Double {
            let dateDiff = abs(entry.date.timeIntervalSince(parsedDate)) / 3600.0
            let kwhDiff: Double
            if let targetKWh, let ekwh = entry.energyAddedKWh {
                kwhDiff = abs(ekwh - targetKWh) * 4.0
            } else {
                kwhDiff = 10
            }
            return dateDiff + kwhDiff
        }

        return candidates.min { score($0) < score($1) }
    }

    private func saveNewExpense() {
        let entry = buildEntry(from: nil)
        entriesStore.add(entry)
        openEditor(with: entry)
    }

    private func updateExistingEntry(_ entry: ExpenseEntry) {
        var updated = entry
        let incoming = buildChargingDetails()
        updated.mergeCharging(incoming)

        if let amount = parsedAmount() {
            updated.amount = amount
        }
        if let date = parsedDate() {
            updated.date = date
        }

        let notes = additionalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            let prefix = updated.notes?.isEmpty == false ? "\n" : ""
            updated.notes = (updated.notes ?? "") + prefix + notes
        }

        entriesStore.update(updated)
    }

    private func openEditor(with entry: ExpenseEntry) {
        editorEntry = entry
        showingEditor = true
    }

    private func buildEntry(from existing: ExpenseEntry?) -> ExpenseEntry {
        let amount = parsedAmount() ?? 0
        let date = parsedDate() ?? Date()
        let notes = additionalNotes.trimmingCharacters(in: .whitespacesAndNewlines)

        var entry = ExpenseEntry(date: date, amount: amount)
        entry.category = "Supercharging"
        entry.isEnergy = true
        entry.notes = notes.isEmpty ? "Imported from Tesla invoice." : "Imported from Tesla invoice.\n\(notes)"
        entry.charging = buildChargingDetails()
        entry.location = location.isEmpty ? nil : location
        entry.energyAddedKWh = parsedEnergy()
        entry.charging?.pricePerKWh = parsedPricePerKWh()
        return entry
    }

    private func buildChargingDetails() -> ChargingDetails {
        var details = ChargingDetails()
        details.isSupercharger = true
        details.siteName = location.isEmpty ? nil : location
        details.energyAddedKWh = parsedEnergy()
        details.pricePerKWh = parsedPricePerKWh()
        return details
    }

    private func parsedAmount() -> Double? {
        parseNumber(totalCost)
    }

    private func parsedEnergy() -> Double? {
        parseNumber(energyKWh)
    }

    private func parsedPricePerKWh() -> Double? {
        parseNumber(pricePerKWh)
    }

    private func parsedDate() -> Date? {
        let raw = dateText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let fmts = ["M/d/yyyy", "MM/dd/yyyy", "M/d/yy", "MM/dd/yy", "yyyy-MM-dd"]
        for fmt in fmts {
            let f = DateFormatter()
            f.dateFormat = fmt
            if let d = f.date(from: raw) { return d }
        }
        return nil
    }

    private func parseNumber(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "kWh", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "/kWh", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Total", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned)
    }
}

private extension String {
    func firstMatch(_ pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let match = regex.firstMatch(in: self, range: range),
              let r = Range(match.range(at: 1), in: self) ?? Range(match.range, in: self) else { return nil }
        return String(self[r])
    }
}
