//
//  TeslaSCOfficialPriceRecord.swift
//  KWh Gas Companion
//
//  Created by Bryan on 1/2/26.
//

//
//  TeslaOfficialSuperchargerPricingShift.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//
//  Official Tesla FindUs scraper (public pages):
//  - Fetch state list pages -> station links
//  - Fetch station pages -> address + pricing blocks
//  - Persist locally (Application Support JSON) for app-wide reuse
//
//  Notes:
//  - This is best run on-demand (manual sync) due to volume.
//  - Tesla page formats can change; parsing is defensive.
//

import SwiftUI
import Foundation

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Model

public struct TeslaSCOfficialPriceRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String { stationId }

    public let stationId: String              // last path component (slug or numeric id)
    public let stationURL: String             // canonical URL we fetched

    public var title: String                  // e.g. "Florence, SC" or "Orangeburg, NY"
    public var siteName: String?              // e.g. "Magnolia Mall"
    public var addressLines: [String]         // street + city/state/zip (best-effort)

    public var stallCount: Int?
    public var maxKW: Int?

    public var pricingTeslaLabel: String?     // e.g. "Pricing for Tesla" / "Pricing for Tesla & Members"
    public var pricingTeslaText: String?      // raw joined text under that label
    public var pricingTeslaPrices: [Double]   // extracted $/kWh values found in Tesla pricing block

    public var pricingNonTeslaText: String?   // raw joined text under "Pricing for Non-Tesla" (if present)

    public var congestionFeeText: String?     // extracted if present (best-effort)

    public var lastFetched: Date

    public init(
        stationId: String,
        stationURL: String,
        title: String,
        siteName: String?,
        addressLines: [String],
        stallCount: Int?,
        maxKW: Int?,
        pricingTeslaLabel: String?,
        pricingTeslaText: String?,
        pricingTeslaPrices: [Double],
        pricingNonTeslaText: String?,
        congestionFeeText: String?,
        lastFetched: Date
    ) {
        self.stationId = stationId
        self.stationURL = stationURL
        self.title = title
        self.siteName = siteName
        self.addressLines = addressLines
        self.stallCount = stallCount
        self.maxKW = maxKW
        self.pricingTeslaLabel = pricingTeslaLabel
        self.pricingTeslaText = pricingTeslaText
        self.pricingTeslaPrices = pricingTeslaPrices
        self.pricingNonTeslaText = pricingNonTeslaText
        self.congestionFeeText = congestionFeeText
        self.lastFetched = lastFetched
    }
}

// MARK: - Sync Status

public enum TeslaSCOfficialSyncPhase: String, Codable, Sendable {
    case idle
    case fetchingStatePages
    case fetchingStationPages
    case persisting
    case done
    case cancelled
    case failed
}

public struct TeslaSCOfficialSyncStatus: Codable, Sendable {
    public var phase: TeslaSCOfficialSyncPhase = .idle
    public var total: Int = 0
    public var completed: Int = 0
    public var current: String? = nil
    public var errorMessage: String? = nil

    public var isSyncing: Bool {
        switch phase {
        case .fetchingStatePages, .fetchingStationPages, .persisting: return true
        default: return false
        }
    }

    public var progress: Double {
        guard total > 0 else { return 0 }
        return min(1.0, max(0.0, Double(completed) / Double(total)))
    }
}

// MARK: - Store (APP-WIDE)

@MainActor
public final class TeslaOfficialSuperchargerPricingStore: ObservableObject {

    @Published public private(set) var records: [TeslaSCOfficialPriceRecord] = []
    @Published public private(set) var syncStatus: TeslaSCOfficialSyncStatus = .init()

    private var syncTask: Task<Void, Never>?

    // Disk persistence
    private let filename = "TeslaOfficialSuperchargerPricing.v1.json"

    public init() {
        loadFromDiskAsync()
    }

    deinit {
        syncTask?.cancel()
    }

    // MARK: Public query API

    public func record(for stationId: String) -> TeslaSCOfficialPriceRecord? {
        records.first(where: { $0.stationId == stationId })
    }

    public func search(_ query: String) -> [TeslaSCOfficialPriceRecord] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return records }
        let needle = q.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        return records.filter { r in
            let blob = "\(r.title) \(r.siteName ?? "") \(r.addressLines.joined(separator: " ")) \(r.stationId)"
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return blob.contains(needle)
        }
    }

    /// Helpful if you want a “best guess” $/kWh for UI.
    public func bestSingleTeslaPrice(for stationId: String) -> Double? {
        guard let r = record(for: stationId) else { return nil }
        if r.pricingTeslaPrices.isEmpty { return nil }
        return r.pricingTeslaPrices.min()
    }

    // MARK: Sync control

    public func cancelSync() {
        syncTask?.cancel()
        syncTask = nil
        syncStatus.phase = .cancelled
        syncStatus.current = nil
    }

    /// Sync ALL US states (heavy). Recommended to run manually.
    public func syncAllUS(maxConcurrency: Int = 4) {
        sync(states: Self.usStatesAndDC, maxConcurrency: maxConcurrency)
    }

    /// Sync a subset of states (recommended).
    public func sync(states: [String], maxConcurrency: Int = 4) {
        cancelSync()

        syncStatus = TeslaSCOfficialSyncStatus(
            phase: .fetchingStatePages,
            total: 0,
            completed: 0,
            current: "Preparing…",
            errorMessage: nil
        )

        syncTask = Task {
            do {
                try Task.checkCancellation()

                let stationURLs = try await fetchAllStationURLs(states: states)

                try Task.checkCancellation()

                await MainActor.run {
                    self.syncStatus.phase = .fetchingStationPages
                    self.syncStatus.total = stationURLs.count
                    self.syncStatus.completed = 0
                    self.syncStatus.current = stationURLs.first ?? "Starting…"
                    self.syncStatus.errorMessage = nil
                }

                try await fetchStationPagesAndUpsert(
                    stationURLs: stationURLs,
                    maxConcurrency: max(1, min(12, maxConcurrency))
                )

                try Task.checkCancellation()

                await MainActor.run {
                    self.syncStatus.phase = .persisting
                    self.syncStatus.current = "Saving…"
                }
                saveToDisk()

                await MainActor.run {
                    self.syncStatus.phase = .done
                    self.syncStatus.current = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.syncStatus.phase = .cancelled
                    self.syncStatus.current = nil
                }
            } catch {
                await MainActor.run {
                    self.syncStatus.phase = .failed
                    self.syncStatus.errorMessage = String(describing: error)
                    self.syncStatus.current = nil
                }
            }
        }
    }

    // MARK: - Internals: Fetch state pages -> station URLs

    private func fetchAllStationURLs(states: [String]) async throws -> [String] {
        await MainActor.run {
            self.syncStatus.phase = .fetchingStatePages
            self.syncStatus.total = states.count
            self.syncStatus.completed = 0
            self.syncStatus.current = states.first
            self.syncStatus.errorMessage = nil
        }

        var all: Set<String> = []
        for (i, state) in states.enumerated() {
            try Task.checkCancellation()

            await MainActor.run {
                self.syncStatus.current = "State: \(state)"
                self.syncStatus.completed = i
            }

            let url = Self.stateListURL(stateName: state)
            let html = try await fetchHTML(urlString: url)
            let found = Self.extractStationLinks(fromListHTML: html)

            for s in found {
                all.insert(Self.normalizeTeslaURL(s))
            }

            await MainActor.run {
                self.syncStatus.completed = i + 1
            }
        }

        return Array(all).sorted()
    }

    // MARK: - Internals: Fetch station pages

    private actor StationQueue {
        var items: [String]
        init(_ items: [String]) { self.items = items }
        func next() -> String? {
            guard !items.isEmpty else { return nil }
            return items.removeFirst()
        }
    }

    private func fetchStationPagesAndUpsert(stationURLs: [String], maxConcurrency: Int) async throws {
        let queue = StationQueue(stationURLs)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<maxConcurrency {
                group.addTask { [weak self] in
                    guard let self else { return }

                    while let url = await queue.next() {
                        try Task.checkCancellation()

                        let html = try await self.fetchHTML(urlString: url)

                        // ✅ parseStationPage is now nonisolated, so this is legal from background tasks
                        let record = Self.parseStationPage(html: html, stationURL: url)

                        await MainActor.run {
                            self.upsert(record)
                            self.syncStatus.completed += 1
                            self.syncStatus.current = record.title
                        }
                    }
                }
            }

            try await group.waitForAll()
        }
    }

    // MARK: - Upsert + persistence

    private func upsert(_ r: TeslaSCOfficialPriceRecord) {
        if let idx = records.firstIndex(where: { $0.stationId == r.stationId }) {
            records[idx] = r
        } else {
            records.append(r)
        }
    }

    private nonisolated static func appSupportURL(filename: String) throws -> URL {
        let fm = FileManager.default
        let dir = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let bundleDir = dir.appendingPathComponent("KWhGasCompanion", isDirectory: true)
        if !fm.fileExists(atPath: bundleDir.path) {
            try fm.createDirectory(at: bundleDir, withIntermediateDirectories: true)
        }
        return bundleDir.appendingPathComponent(filename, isDirectory: false)
    }

    private func appSupportURL() throws -> URL {
        try Self.appSupportURL(filename: filename)
    }

    private func loadFromDiskAsync() {
        let file = filename
        Task.detached(priority: .utility) {
            do {
                let url = try Self.appSupportURL(filename: file)
                guard FileManager.default.fileExists(atPath: url.path) else {
                    await MainActor.run { self.records = [] }
                    return
                }
                let data = try Data(contentsOf: url)
                let dec = JSONDecoder()
                dec.dateDecodingStrategy = .iso8601
                let decoded = try dec.decode([TeslaSCOfficialPriceRecord].self, from: data)
                await MainActor.run { self.records = decoded }
            } catch {
                await MainActor.run { self.records = [] }
            }
        }
    }

    private func saveToDisk() {
        do {
            let url = try appSupportURL()
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            enc.dateEncodingStrategy = .iso8601
            let data = try enc.encode(records)
            try data.write(to: url, options: [.atomic])
        } catch {
            #if DEBUG
            print("TeslaOfficialSuperchargerPricingStore save error: \(error)")
            #endif
        }
    }

    public func clearAll() {
        cancelSync()
        records = []
        saveToDisk()
        syncStatus = .init()
    }

    // MARK: - Networking

    private func fetchHTML(urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.timeoutInterval = 45
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        req.setValue("KWhGasCompanion/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Tesla URLs + parsing

    /// Tesla list pages appear at /findus/list/superchargers/<Region>.
    /// For US states, <Region> is the state name.
    public nonisolated static func stateListURL(stateName: String) -> String {
        let encoded = stateName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? stateName
        return "https://www.tesla.com/findus/list/superchargers/\(encoded)"
    }

    /// Normalize relative URLs -> absolute.
    public nonisolated static func normalizeTeslaURL(_ maybeRelative: String) -> String {
        if maybeRelative.hasPrefix("http://") || maybeRelative.hasPrefix("https://") {
            return maybeRelative
        }
        if maybeRelative.hasPrefix("/") {
            return "https://www.tesla.com\(maybeRelative)"
        }
        return "https://www.tesla.com/\(maybeRelative)"
    }

    /// Extract /findus/location/supercharger/... links from a Tesla list page.
    public nonisolated static func extractStationLinks(fromListHTML html: String) -> [String] {
        let pattern = #"href\s*=\s*"([^"]*?/findus/location/supercharger/[^"]+)""#
        let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])

        let ns = html as NSString
        let range = NSRange(location: 0, length: ns.length)

        var out: [String] = []
        re?.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
            guard let match, match.numberOfRanges >= 2 else { return }
            let r1 = match.range(at: 1)
            let s = ns.substring(with: r1)
            out.append(s)
        }

        var seen = Set<String>()
        var unique: [String] = []
        for s in out {
            let norm = normalizeTeslaURL(s)
            if !seen.contains(norm) {
                seen.insert(norm)
                unique.append(norm)
            }
        }
        return unique
    }

    /// Convert HTML -> readable text (best-effort)
    private nonisolated static func htmlToText(_ html: String) -> String {
        #if canImport(UIKit)
        if let data = html.data(using: .utf8),
           let attr = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
           ) {
            return attr.string
        }
        #endif

        return html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    }

    /// Parse a station page into a record (defensive; Tesla formatting varies).
    public nonisolated static func parseStationPage(html: String, stationURL: String) -> TeslaSCOfficialPriceRecord {
        let text = htmlToText(html)

        var lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        lines.removeAll(where: { l in
            let lower = l.lowercased()
            return lower == "back to list"
            || lower.hasPrefix("tesla ©")
            || lower == "privacy & legal"
            || lower == "locations"
            || l == "* * *"
        })

        let stationId: String = {
            guard let u = URL(string: stationURL) else { return stationURL }
            let last = u.lastPathComponent
            return last.isEmpty ? stationURL : last
        }()

        let headerIdx = lines.firstIndex(where: { $0.lowercased().contains("supercharger") }) ?? 0
        let title = lines[safe: headerIdx + 1] ?? stationId

        var i = headerIdx + 2
        var siteName: String? = nil

        func looksLikeAddress(_ s: String) -> Bool {
            if s.rangeOfCharacter(from: .decimalDigits) != nil { return true }
            if s.contains("+") { return true }
            let lower = s.lowercased()
            let tokens = ["street","st.","st ","road","rd","rd.","ave","avenue","blvd","boulevard","hwy","highway","drive","dr","lane","ln","court","ct","plaza","parkway","pkwy","suite","unit"]
            if tokens.contains(where: { lower.contains($0) }) { return true }
            return false
        }

        func isSectionStart(_ s: String) -> Bool {
            let lower = s.lowercased()
            return lower.contains(" superchargers")
            || lower.hasPrefix("access hours")
            || lower.hasPrefix("pricing for ")
            || lower.contains("roadside assistance")
            || lower.hasPrefix("supported vehicles")
        }

        if let candidate = lines[safe: i], !isSectionStart(candidate), !looksLikeAddress(candidate) {
            siteName = candidate
            i += 1
        }

        var address: [String] = []
        while let l = lines[safe: i], !isSectionStart(l) {
            address.append(l)
            i += 1
            if address.count >= 4 { break }
        }

        let stallCount = lines.compactMap { parseFirstInt(prefix: nil, in: $0, pattern: #"(\d+)\s+Superchargers"#) }.first
        let maxKW = lines.compactMap { parseFirstInt(prefix: nil, in: $0, pattern: #"Up\s+to\s+(\d+)\s*kW"#) }.first

        let (teslaLabel, teslaBlockLines) = extractPricingBlock(
            lines: lines,
            labelCandidates: ["Pricing for Tesla & Members", "Pricing for Tesla"]
        )
        let teslaText = teslaBlockLines?.joined(separator: " ")
        let teslaPrices = extractKwhPrices(from: teslaText ?? "")

        let (_, nonTeslaBlockLines) = extractPricingBlock(
            lines: lines,
            labelCandidates: ["Pricing for Non-Tesla"]
        )
        let nonTeslaText = nonTeslaBlockLines?.joined(separator: " ")

        let congestionFeeText: String? = {
            let blob = "\(teslaText ?? "") \(nonTeslaText ?? "")"
            let re = try? NSRegularExpression(pattern: #"(Congestion\s+fees.*?$)"#, options: [.caseInsensitive])
            let ns = blob as NSString
            let range = NSRange(location: 0, length: ns.length)
            if let m = re?.firstMatch(in: blob, options: [], range: range), m.numberOfRanges >= 2 {
                return ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if blob.lowercased().contains("congestion fees") {
                return "Congestion fees (see station page)"
            }
            return nil
        }()

        return TeslaSCOfficialPriceRecord(
            stationId: stationId,
            stationURL: stationURL,
            title: title,
            siteName: siteName,
            addressLines: address,
            stallCount: stallCount,
            maxKW: maxKW,
            pricingTeslaLabel: teslaLabel,
            pricingTeslaText: teslaText,
            pricingTeslaPrices: teslaPrices,
            pricingNonTeslaText: nonTeslaText,
            congestionFeeText: congestionFeeText,
            lastFetched: Date()
        )
    }

    private nonisolated static func extractPricingBlock(lines: [String], labelCandidates: [String]) -> (String?, [String]?) {
        let labelIdx: Int? = {
            for (idx, line) in lines.enumerated() {
                for label in labelCandidates {
                    if line.caseInsensitiveCompare(label) == .orderedSame { return idx }
                }
            }
            return nil
        }()

        guard let labelIdx else { return (nil, nil) }

        let label = lines[labelIdx]
        var out: [String] = []

        var i = labelIdx + 1
        while i < lines.count {
            let l = lines[i]
            let lower = l.lowercased()
            if lower.hasPrefix("pricing for ")
                || lower.hasPrefix("access hours")
                || lower.contains("roadside assistance")
                || lower.hasPrefix("supported vehicles")
                || lower.contains("supercharger open to others")
                || lower == "back to list"
            {
                break
            }
            if l != "* * *" {
                out.append(l)
            }
            i += 1
            if out.count >= 6 { break }
        }

        return (label, out.isEmpty ? nil : out)
    }

    private nonisolated static func extractKwhPrices(from text: String) -> [Double] {
        guard !text.isEmpty else { return [] }

        let pattern = #"(?:US)?\$\s*([0-9]+(?:\.[0-9]+)?)\s*/\s*kwh"#
        let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])

        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)

        var vals: [Double] = []
        re?.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match, match.numberOfRanges >= 2 else { return }
            let s = ns.substring(with: match.range(at: 1))
            if let v = Double(s) {
                vals.append(v)
            }
        }

        var seen = Set<Double>()
        var unique: [Double] = []
        for v in vals {
            if !seen.contains(v) {
                seen.insert(v)
                unique.append(v)
            }
        }
        return unique
    }

    private nonisolated static func parseFirstInt(prefix: String?, in text: String, pattern: String) -> Int? {
        let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let m = re?.firstMatch(in: text, options: [], range: range),
              m.numberOfRanges >= 2 else { return nil }
        let s = ns.substring(with: m.range(at: 1))
        return Int(s)
    }

    // MARK: - US state list (stable)

    public static let usStatesAndDC: [String] = [
        "Alabama","Alaska","Arizona","Arkansas","California","Colorado","Connecticut","Delaware",
        "District Of Columbia",
        "Florida","Georgia","Hawaii","Idaho","Illinois","Indiana","Iowa","Kansas","Kentucky","Louisiana",
        "Maine","Maryland","Massachusetts","Michigan","Minnesota","Mississippi","Missouri","Montana",
        "Nebraska","Nevada","New Hampshire","New Jersey","New Mexico","New York","North Carolina","North Dakota","Ohio",
        "Oklahoma","Oregon","Pennsylvania","Rhode Island","South Carolina","South Dakota","Tennessee","Texas","Utah",
        "Vermont","Virginia","Washington","West Virginia","Wisconsin","Wyoming"
    ]
}

// MARK: - Safe indexing helper

fileprivate extension Array {
    subscript(safe idx: Int) -> Element? {
        guard idx >= 0, idx < count else { return nil }
        return self[idx]
    }
}

// MARK: - Shift View (UI)

@MainActor
public struct TeslaOfficialSuperchargerPricingShiftView: View {

    @EnvironmentObject private var store: TeslaOfficialSuperchargerPricingStore

    @State private var query: String = ""
    @State private var selectedStates: Set<String> = ["New York"]
    @State private var showStatePicker = false

    public init() {}

    private var filtered: [TeslaSCOfficialPriceRecord] {
        store.search(query).sorted { a, b in
            if a.title != b.title { return a.title < b.title }
            return a.stationId < b.stationId
        }
    }

    public var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Official Tesla Supercharger Pricing")
                        .font(.headline)

                    Text("Fetches Tesla’s public FindUs pages and stores station pricing locally for reuse across the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if store.syncStatus.isSyncing {
                        ProgressView(value: store.syncStatus.progress) {
                            Text(store.syncStatus.current ?? "Working…")
                                .font(.subheadline)
                        }
                        .padding(.top, 6)

                        Button(role: .destructive) {
                            store.cancelSync()
                        } label: {
                            Label("Cancel Sync", systemImage: "xmark.circle")
                        }
                    } else {
                        HStack {
                            Button {
                                showStatePicker = true
                            } label: {
                                Label("Pick States", systemImage: "checklist")
                            }

                            Spacer()

                            Button {
                                store.sync(states: Array(selectedStates).sorted(), maxConcurrency: 4)
                            } label: {
                                Label("Sync Selected", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .disabled(selectedStates.isEmpty)

                            Button {
                                store.syncAllUS(maxConcurrency: 4)
                            } label: {
                                Label("Sync All US", systemImage: "globe.americas")
                            }
                        }
                    }

                    if let err = store.syncStatus.errorMessage, !err.isEmpty {
                        Text("Error: \(err)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Saved records") {
                TextField("Search (city, site, address, id)…", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                if filtered.isEmpty {
                    Text("No records yet. Run a sync to populate pricing.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filtered) { r in
                        NavigationLink {
                            TeslaOfficialPricingDetail(record: r)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(r.title).font(.headline)
                                    Spacer()
                                    if let best = r.pricingTeslaPrices.min() {
                                        Text(String(format: "$%.2f/kWh", best))
                                            .font(.subheadline.weight(.semibold))
                                    } else {
                                        Text("—")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if let site = r.siteName, !site.isEmpty {
                                    Text(site)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                if !r.addressLines.isEmpty {
                                    Text(r.addressLines.joined(separator: ", "))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                HStack(spacing: 10) {
                                    if let stalls = r.stallCount {
                                        Text("\(stalls) stalls")
                                    }
                                    if let kw = r.maxKW {
                                        Text("up to \(kw) kW")
                                    }
                                    Text(r.lastFetched.formatted(date: .abbreviated, time: .shortened))
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    store.clearAll()
                } label: {
                    Label("Clear Local Cache", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Tesla Pricing")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showStatePicker) {
            NavigationStack {
                List {
                    ForEach(TeslaOfficialSuperchargerPricingStore.usStatesAndDC, id: \.self) { s in
                        Button {
                            if selectedStates.contains(s) { selectedStates.remove(s) }
                            else { selectedStates.insert(s) }
                        } label: {
                            HStack {
                                Text(s)
                                Spacer()
                                if selectedStates.contains(s) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("States to Sync")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showStatePicker = false }
                    }
                }
            }
        }
    }
}

fileprivate struct TeslaOfficialPricingDetail: View {
    let record: TeslaSCOfficialPriceRecord

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.title).font(.title3.weight(.semibold))
                    if let site = record.siteName { Text(site).foregroundStyle(.secondary) }
                    if !record.addressLines.isEmpty {
                        Text(record.addressLines.joined(separator: "\n"))
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Capacity") {
                HStack {
                    Text("Stalls")
                    Spacer()
                    Text(record.stallCount.map(String.init) ?? "—").foregroundStyle(.secondary)
                }
                HStack {
                    Text("Max kW")
                    Spacer()
                    Text(record.maxKW.map(String.init) ?? "—").foregroundStyle(.secondary)
                }
            }

            Section(record.pricingTeslaLabel ?? "Pricing") {
                Text(record.pricingTeslaText ?? "—")
                    .foregroundStyle(.secondary)

                if !record.pricingTeslaPrices.isEmpty {
                    Text("Detected $/kWh: " + record.pricingTeslaPrices.map { String(format: "$%.2f", $0) }.joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let nonTesla = record.pricingNonTeslaText, !nonTesla.isEmpty {
                Section("Pricing for Non-Tesla") {
                    Text(nonTesla).foregroundStyle(.secondary)
                }
            }

            if let congestion = record.congestionFeeText, !congestion.isEmpty {
                Section("Fees") {
                    Text(congestion).foregroundStyle(.secondary)
                }
            }

            Section("Source") {
                Text(record.stationURL)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text("Last fetched: \(record.lastFetched.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
