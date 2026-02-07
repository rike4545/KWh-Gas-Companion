//  ProductPlateScanner+Archive.swift
//  My KWh Companion
//
//  Product Plate scanning + long-term archive
//  - Live camera OCR via VisionKit DataScanner (iOS 17+)
//  - Photo import OCR fallback via Vision
//  - Robust regex parsing (VIN, MFD date, GVWR/GAWR, tires, PSI, paint/trim/axle)
//  - Archive: persist multiple scans to JSON with search, detail, export
//  - VIN quick actions: Tesla & NHTSA recall lookups
//
//  IMPORTANT (Info.plist):
//  • NSCameraUsageDescription = "Allow camera access to scan product/vehicle plates."
//  • (Optional) NSPhotoLibraryUsageDescription if you ever switch to direct Photos access
//
//  Updated: Sept 13, 2025

import SwiftUI
import Vision
import VisionKit
import PhotosUI
import AVFoundation // ✅ Needed for camera authorization

// MARK: - Data Model

public struct ProductPlateInfo: Codable, Hashable, Identifiable {
    public var id: UUID = .init()

    // Common fields found on product/vehicle plates
    public var manufacturer: String?
    public var manufactureDate: String?          // Normalized to "YYYY-MM" when possible
    public var vin: String?

    // Weights (store in both lb and kg if available)
    public var gvwrLB: Double?
    public var gvwrKG: Double?
    public var gawrFrontLB: Double?
    public var gawrFrontKG: Double?
    public var gawrRearLB: Double?
    public var gawrRearKG: Double?

    // Tires & pressures
    public var tireFront: String?
    public var tireRear: String?
    public var coldPressureFrontPSI: Double?
    public var coldPressureRearPSI: Double?

    // Other common plate hints
    public var paintCode: String?
    public var trimCode: String?
    public var axleCode: String?
    public var notes: String?

    // Provenance
    public var rawText: String?
    public var scannedAt: Date = .init()
}

// MARK: - Parser

enum ProductPlateParser {
    private static let vinRegex = try! NSRegularExpression(
        pattern: "(?i)(?:vin[:\\n\\r\\t\\s-]*)?([A-HJ-NPR-Z0-9]{17})"
    )

    private static let dateRegex = try! NSRegularExpression(
        pattern: "(?i)(?:mfd\\.?|mfg\\.?|manufactured|date)[:\\n\\r\\t\\s-]*((?:\\d{4}[\\-\\/]\\d{1,2})|(?:\\d{1,2}[\\-\\/]\\d{4}))"
    )

    private static let gvwrRegex = try! NSRegularExpression(
        pattern: "(?i)gvwr[:\\n\\r\\t\\s-]*([0-9]{3,5})\\s*(lb|lbs|pounds|kg)?"
    )
    private static let gawrFrontRegex = try! NSRegularExpression(
        pattern: "(?i)gawr\\s*(?:front|frt|f)[:\\n\\r\\t\\s-]*([0-9]{3,5})\\s*(lb|lbs|pounds|kg)?"
    )
    private static let gawrRearRegex = try! NSRegularExpression(
        pattern: "(?i)gawr\\s*(?:rear|rr|r)[:\\n\\r\\t\\s-]*([0-9]{3,5})\\s*(lb|lbs|pounds|kg)?"
    )

    private static let psiFrontRegex = try! NSRegularExpression(
        pattern: "(?i)(?:front|f|frt)[^\\n]*?(?:cold|psi)[^\\n]*?([2-6][0-9])\\s*psi"
    )
    private static let psiRearRegex = try! NSRegularExpression(
        pattern: "(?i)(?:rear|r|rr)[^\\n]*?(?:cold|psi)[^\\n]*?([2-6][0-9])\\s*psi"
    )
    private static let genericPSIRegex = try! NSRegularExpression(
        pattern: "(?i)(?:cold\\s*tire\\s*pressure|at\\s*cold)[:\\n\\r\\t\\s-]*([2-6][0-9])\\s*psi"
    )

    private static let tireRegex = try! NSRegularExpression(
        pattern: "(?i)(\\b[12][0-9]{2}\\/[0-9]{2}R?[0-9]{2}\\b[^\\n]*)"
    )

    private static let paintRegex = try! NSRegularExpression(
        pattern: "(?i)(?:paint|color|pnt)[:\\n\\r\\t\\s-]*([A-Z0-9]{3,6})"
    )

    private static let trimRegex = try! NSRegularExpression(
        pattern: "(?i)(?:trim)[:\\n\\r\\t\\s-]*([A-Z0-9\\-]{2,10})"
    )

    private static let axleRegex = try! NSRegularExpression(
        pattern: "(?i)(?:axle)[:\\n\\r\\t\\s-]*([A-Z0-9\\-]{1,6})"
    )

    private static let mfrRegex = try! NSRegularExpression(
        pattern: "(?i)(?:mfd\\.?\\s*by|manufactured\\s*by|mfg\\.?\\s*by)[:\\n\\r\\t\\s-]*([A-Z0-9\\-\\s&\\.]+)"
    )

    static func parse(from text: String) -> ProductPlateInfo {
        var info = ProductPlateInfo()
        info.rawText = text

        func firstMatch(_ regex: NSRegularExpression, group: Int = 1) -> String? {
            guard let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
            let r = m.range(at: group)
            guard r.location != NSNotFound, let range = Range(r, in: text) else { return nil }
            return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func numberAndUnit(_ regex: NSRegularExpression) -> (Double?, String?) {
            guard let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return (nil, nil) }
            let valueRange = m.range(at: 1)
            let unitRange = m.range(at: 2)
            var value: Double?
            var unit: String?
            if valueRange.location != NSNotFound, let r = Range(valueRange, in: text) { value = Double(text[r]) }
            if unitRange.location != NSNotFound, let ur = Range(unitRange, in: text) { unit = String(text[ur]).lowercased() }
            return (value, unit)
        }

        info.vin = firstMatch(vinRegex)

        if let dateRaw = firstMatch(dateRegex) {
            info.manufactureDate = normalizeMonthYear(dateRaw) ?? dateRaw
        }
        info.manufacturer = firstMatch(mfrRegex)

        let (gvwrValue, gvwrUnit) = numberAndUnit(gvwrRegex)
        if let v = gvwrValue { if gvwrUnit?.contains("kg") == true { info.gvwrKG = v; info.gvwrLB = v * 2.20462 } else { info.gvwrLB = v; info.gvwrKG = v / 2.20462 } }

        let (gawrFValue, gawrFUnit) = numberAndUnit(gawrFrontRegex)
        if let v = gawrFValue { if gawrFUnit?.contains("kg") == true { info.gawrFrontKG = v; info.gawrFrontLB = v * 2.20462 } else { info.gawrFrontLB = v; info.gawrFrontKG = v / 2.20462 } }

        let (gawrRValue, gawrRUnit) = numberAndUnit(gawrRearRegex)
        if let v = gawrRValue { if gawrRUnit?.contains("kg") == true { info.gawrRearKG = v; info.gawrRearLB = v * 2.20462 } else { info.gawrRearLB = v; info.gawrRearKG = v / 2.20462 } }

        let tireMatches = tireRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        if tireMatches.indices.contains(0), let r0 = Range(tireMatches[0].range(at: 1), in: text) { info.tireFront = String(text[r0]).trimmingCharacters(in: .whitespacesAndNewlines) }
        if tireMatches.indices.contains(1), let r1 = Range(tireMatches[1].range(at: 1), in: text) { info.tireRear = String(text[r1]).trimmingCharacters(in: .whitespacesAndNewlines) }

        if let mF = psiFrontRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let r = Range(mF.range(at: 1), in: text) { info.coldPressureFrontPSI = Double(text[r]) }
        if let mR = psiRearRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let r = Range(mR.range(at: 1), in: text) { info.coldPressureRearPSI = Double(text[r]) }
        if info.coldPressureFrontPSI == nil && info.coldPressureRearPSI == nil {
            if let m = genericPSIRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let r = Range(m.range(at: 1), in: text) {
                let psi = Double(text[r]); info.coldPressureFrontPSI = psi; info.coldPressureRearPSI = psi
            }
        }

        info.paintCode = firstMatch(paintRegex)
        info.trimCode = firstMatch(trimRegex)
        info.axleCode = firstMatch(axleRegex)

        return info
    }

    // Normalize "03/2024" or "2024-3" to "2024-03"
    private static func normalizeMonthYear(_ s: String) -> String? {
        let separators = CharacterSet(charactersIn: "-/")
        let parts = s.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: separators)
        guard parts.count == 2 else { return nil }
        var y = 0, m = 0
        if parts[0].count == 4, let yy = Int(parts[0]), let mm = Int(parts[1]) { y = yy; m = mm }
        else if let mm = Int(parts[0]), let yy = Int(parts[1]) { y = yy; m = mm }
        guard (2000...2100).contains(y), (1...12).contains(m) else { return nil }
        return String(format: "%04d-%02d", y, m)
    }
}

// MARK: - Archive (persistent multi-scan store)

@MainActor
final class PlateScanArchive: ObservableObject {
    @Published private(set) var scans: [ProductPlateInfo] = [] { didSet { save() } }

    private let url: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("plate_scans.json")
    }()

    init() { load() }

    func add(_ scan: ProductPlateInfo) { var s = scan; s.scannedAt = Date(); scans.insert(s, at: 0) }
    func update(_ scan: ProductPlateInfo) { if let i = scans.firstIndex(where: { $0.id == scan.id }) { scans[i] = scan } }
    func remove(_ scan: ProductPlateInfo) { scans.removeAll { $0.id == scan.id } }

    func find(byVIN vin: String) -> [ProductPlateInfo] { scans.filter { $0.vin?.caseInsensitiveCompare(vin) == .orderedSame } }

    // Export entire archive to a JSON file and return URL
    @discardableResult
    func exportArchive() -> URL? {
        do {
            let data = try JSONEncoder().encode(scans)
            let exportURL = url.deletingLastPathComponent().appendingPathComponent("plate_scans_export.json")
            try data.write(to: exportURL, options: .atomic)
            return exportURL
        } catch {
            print("[PlateScanArchive] export error: \(error)")
            return nil
        }
    }

    private func save() {
        do { let data = try JSONEncoder().encode(scans); try data.write(to: url, options: .atomic) } catch { print("[PlateScanArchive] save error: \(error)") }
    }

    private func load() {
        do { let data = try Data(contentsOf: url); let decoded = try JSONDecoder().decode([ProductPlateInfo].self, from: data); self.scans = decoded } catch { /* first run - ignore */ }
    }
}

// MARK: - Scanner Wrapper (VisionKit → SwiftUI)

@MainActor
struct DataScannerView: UIViewControllerRepresentable {
    @Binding var aggregatedText: String

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: DataScannerView
        private var buffer: Set<String> = []
        init(parent: DataScannerView) { self.parent = parent }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) { append(items: addedItems) }
        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) { append(items: updatedItems) }
        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) { for item in removedItems { if case .text(let t) = item { buffer.remove(t.transcript) } }; parent.aggregatedText = buffer.joined(separator: "\n") }
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) { if case .text(let t) = item { buffer.insert(t.transcript) }; parent.aggregatedText = buffer.joined(separator: "\n") }
        private func append(items: [RecognizedItem]) { var changed = false; for item in items { if case .text(let t) = item { if buffer.insert(t.transcript).inserted { changed = true } } }; if changed { parent.aggregatedText = buffer.joined(separator: "\n") } }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let ctrl = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        ctrl.delegate = context.coordinator
        return ctrl
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        try? uiViewController.startScanning()
    }
}

// MARK: - Photo OCR fallback

@MainActor
struct PhotoOCR {
    static func recognizeText(from image: CGImage) async throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.revision = VNRecognizeTextRequestRevision3
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        let strings = request.results?.compactMap { $0.topCandidates(1).first?.string }.filter { !$0.isEmpty } ?? []
        return strings.joined(separator: "\n")
    }
}

// MARK: - Main Scanner View

@MainActor
struct ProductPlateScannerView: View {
    @StateObject private var archive = PlateScanArchive()

    @State private var aggregatedText: String = ""
    @State private var parsed: ProductPlateInfo? = nil

    @State private var cameraAuthorized: Bool = false
    @State private var showPhotoPicker = false
    @State private var pickedItem: PhotosPickerItem? = nil
    @State private var errorMessage: String? = nil
    @State private var showHistory = false

    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            if DataScannerViewController.isSupported && cameraAuthorized {
                DataScannerView(aggregatedText: $aggregatedText)
                    .ignoresSafeArea() // camera fills behind insets safely
            } else {
                unsupportedView
            }
        }
        // Top and bottom bars are now safe-area insets so nothing gets clipped
        .safeAreaInset(edge: .top) { header }
        .safeAreaInset(edge: .bottom) { bottomInset }
        .task { await requestCamera() }
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, newValue in Task { await handlePickedItem(newValue) } }
        .sheet(isPresented: $showHistory) { ProductPlateHistoryView(archive: archive) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
            Text("Product Plate Scanner").font(.headline)
            Spacer()
            Button { showHistory = true } label: { Image(systemName: "clock.arrow.circlepath") }
                .accessibilityLabel("History")
            Button { showPhotoPicker = true } label: { Image(systemName: "photo.on.rectangle") }
                .accessibilityLabel("Import photo")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal)
    }

    private var bottomInset: some View {
        VStack(spacing: 10) {
            resultPanel
            controls
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                parsed = ProductPlateParser.parse(from: aggregatedText)
            } label: { Label("Parse", systemImage: "doc.text.viewfinder") }
            .buttonStyle(.borderedProminent)

            Button {
                guard var p = parsed else { return }
                p.rawText = aggregatedText
                p.scannedAt = Date()
                archive.add(p)
            } label: { Label("Save", systemImage: "tray.and.arrow.down") }
            .buttonStyle(.bordered)
            .disabled(parsed == nil)

            Button { aggregatedText = ""; parsed = nil } label: { Label("Clear", systemImage: "xmark.circle") }
                .buttonStyle(.bordered)
        }
    }

    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let parsed { plateSummary(parsed) } else { Text("Point your camera at the product plate. Tap **Parse** when the text is visible.").foregroundStyle(.secondary) }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    @ViewBuilder
    private func plateSummary(_ p: ProductPlateInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(p.manufacturer ?? "Manufacturer ?").font(.headline)
                Spacer()
                if let vin = p.vin { MonospaceChip(text: vin) }
            }
            HStack(spacing: 8) {
                if let date = p.manufactureDate { Chip(text: "MFD: \(date)") }
                Chip(text: DateFormatter.shortDateTime.string(from: p.scannedAt))
            }
            HStack(spacing: 12) {
                if let lb = p.gvwrLB { Chip(text: "GVWR: \(Int(lb)) lb") }
                if let kg = p.gvwrKG { Chip(text: "(\(Int(kg)) kg)") }
            }
            HStack(spacing: 12) {
                if let lb = p.gawrFrontLB { Chip(text: "GAWR F: \(Int(lb)) lb") }
                if let lb = p.gawrRearLB { Chip(text: "GAWR R: \(Int(lb)) lb") }
            }
            if p.tireFront != nil || p.tireRear != nil {
                HStack(spacing: 12) {
                    if let tf = p.tireFront { Chip(text: "Front: \(tf)") }
                    if let tr = p.tireRear { Chip(text: "Rear: \(tr)") }
                }
            }
            if p.coldPressureFrontPSI != nil || p.coldPressureRearPSI != nil {
                HStack(spacing: 12) {
                    if let f = p.coldPressureFrontPSI { Chip(text: "Front: \(Int(f)) PSI") }
                    if let r = p.coldPressureRearPSI { Chip(text: "Rear: \(Int(r)) PSI") }
                }
            }
            HStack(spacing: 12) {
                if let paint = p.paintCode { Chip(text: "Paint: \(paint)") }
                if let trim = p.trimCode { Chip(text: "Trim: \(trim)") }
                if let axle = p.axleCode { Chip(text: "Axle: \(axle)") }
            }

            if p.vin != nil {
                Divider().padding(.vertical, 4)
                HStack(spacing: 10) {
                    Button { openURL(URL(string: "https://service.tesla.com/en-US/vin-recall-search")!) } label: { Label("Tesla Recall", systemImage: "car.fill") }
                    Button { openURL(URL(string: "https://www.nhtsa.gov/recalls")!) } label: { Label("NHTSA Recall", systemImage: "exclamationmark.triangle") }
                }
                .buttonStyle(.bordered)
            }

            if let raw = p.rawText {
                DisclosureGroup("Raw text") {
                    ScrollView { Text(raw).font(.footnote).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                        .frame(maxHeight: 160) // prevent bottom panel from growing out of bounds
                }
            }
        }
    }

    private var unsupportedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.on.rectangle").font(.system(size: 44))
            Text("Live scanning not supported or camera permission denied.").multilineTextAlignment(.center)
            Button("Import Photo…") { showPhotoPicker = true }.buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Permissions & Photo flow

    private func requestCamera() async {
        guard DataScannerViewController.isSupported else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: cameraAuthorized = true
        case .notDetermined: cameraAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default: cameraAuthorized = false
        }
    }

    private func handlePickedItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self), let ui = UIImage(data: data), let cg = ui.cgImage {
                let text = try await PhotoOCR.recognizeText(from: cg)
                aggregatedText = text
                parsed = ProductPlateParser.parse(from: text)
            }
        } catch { errorMessage = "Photo OCR failed: \(error.localizedDescription)" }
    }
}

// MARK: - History (search, view, export)

@MainActor
struct ProductPlateHistoryView: View {
    @ObservedObject var archive: PlateScanArchive
    @State private var query: String = ""
    @State private var exportURL: URL? = nil

    var body: some View {
        NavigationStack {
            List(filteredScans) { scan in
                NavigationLink {
                    ProductPlateDetailView(scan: scan)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(scan.manufacturer ?? "Manufacturer ?").font(.headline)
                            Spacer()
                            if let vin = scan.vin { Text(vin).font(.footnote).monospaced() }
                        }
                        HStack(spacing: 8) {
                            if let date = scan.manufactureDate { Chip(text: "MFD: \(date)") }
                            Chip(text: DateFormatter.shortDateTime.string(from: scan.scannedAt))
                        }
                    }
                }
                .swipeActions {
                    Button(role: .destructive) { archive.remove(scan) } label: { Label("Delete", systemImage: "trash") }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search VIN, manufacturer, paint…")
            .navigationTitle("Plate History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let url = exportURL {
                        ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    } else {
                        Button { exportURL = archive.exportArchive() } label: { Image(systemName: "square.and.arrow.up") }
                    }
                }
            }
        }
    }

    private var filteredScans: [ProductPlateInfo] {
        guard !query.isEmpty else { return archive.scans }
        let q = query.lowercased()
        return archive.scans.filter { scan in
            [scan.vin, scan.manufacturer, scan.paintCode, scan.trimCode, scan.axleCode, scan.manufactureDate, scan.rawText].compactMap { $0?.lowercased() }.contains { $0.contains(q) }
        }
    }
}

@MainActor
struct ProductPlateDetailView: View {
    let scan: ProductPlateInfo
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text(scan.manufacturer ?? "Manufacturer ?").font(.title3.bold()); Spacer(); if let vin = scan.vin { MonospaceChip(text: vin) } }
                HStack(spacing: 8) {
                    if let date = scan.manufactureDate { Chip(text: "MFD: \(date)") }
                    Chip(text: DateFormatter.longDateTime.string(from: scan.scannedAt))
                }
                GroupBox("Weights") {
                    VStack(alignment: .leading, spacing: 6) {
                        if let lb = scan.gvwrLB { Text("GVWR: \(Int(lb)) lb (\(Int((scan.gvwrKG ?? lb / 2.20462).rounded())) kg)") }
                        if let f = scan.gawrFrontLB { Text("GAWR Front: \(Int(f)) lb") }
                        if let r = scan.gawrRearLB { Text("GAWR Rear: \(Int(r)) lb") }
                    }
                }
                GroupBox("Tires & PSI") {
                    VStack(alignment: .leading, spacing: 6) {
                        if let tf = scan.tireFront { Text("Front Tire: \(tf)") }
                        if let tr = scan.tireRear { Text("Rear Tire: \(tr)") }
                        if let f = scan.coldPressureFrontPSI { Text("Front PSI (cold): \(Int(f))") }
                        if let r = scan.coldPressureRearPSI { Text("Rear PSI (cold): \(Int(r))") }
                    }
                }
                GroupBox("Codes") {
                    HStack(spacing: 12) {
                        if let paint = scan.paintCode { Chip(text: "Paint: \(paint)") }
                        if let trim = scan.trimCode { Chip(text: "Trim: \(trim)") }
                        if let axle = scan.axleCode { Chip(text: "Axle: \(axle)") }
                    }
                }
                if let raw = scan.rawText { GroupBox("Raw text") { Text(raw).font(.footnote).textSelection(.enabled) } }
            }
            .padding()
        }
        .navigationTitle("Scan Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Small UI helpers

@MainActor
private struct Chip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.footnote)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.secondary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

@MainActor
private struct MonospaceChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(.footnote, design: .monospaced))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.secondary.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Date Formatters

private extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short; return f
    }()
    static let longDateTime: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .long; f.timeStyle = .short; return f
    }()
}

// MARK: - Preview

#Preview { ProductPlateScannerView() }
