//
//  TeslaFindUsIndexEntry.swift
//  KWh Gas Companion
//
//  Created by Bryan on 9/17/25.
//


//  TeslaFindUsIndex.swift
//  My KWh Companion
//
//  Scrape Tesla's US Superchargers list page to build a mapping of
//  State → [ (name, address, slug, coordinate?) ] and a quick slug lookup.
//  Page: https://www.tesla.com/findus/list/superchargers/United%20States
//
//  Notes
//  • HTML structure can change; parsing is regex-based and conservative.
//  • Caches for 24h. Provide simple filtering by state name or text query.
//  • Coordinates are not on the list page; we fetch each site page lazily
//    only when needed to resolve coordinates or pricing.
//

import Foundation

struct TeslaFindUsIndexEntry: Codable, Hashable, Sendable {
    let state: String
    let name: String
    let address: String?
    let slug: String            // e.g., "LakeGroveNYsupercharger"
}

@MainActor
final class TeslaFindUsIndex: ObservableObject {
    private let session: URLSession
    private let cache = Cache()
    @Published private(set) var entries: [TeslaFindUsIndexEntry] = []

    init(session: URLSession = .shared) { self.session = session }

    func loadUnitedStatesList(force: Bool = false) async throws {
        let key = "tesla_us_superchargers_index.json"
        if !force, let cached: [TeslaFindUsIndexEntry] = cache.read(key: key) {
            self.entries = cached
            return
        }
        let url = URL(string: "https://www.tesla.com/findus/list/superchargers/United%20States")!
        var req = URLRequest(url: url)
        req.setValue("MyKwhCompanion/1.0 (TeslaFindUsIndex)", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200, let html = String(data: data, encoding: .utf8) else { return }
        let parsed = parseUSListHTML(html)
        self.entries = parsed
        cache.write(key: key, value: parsed)
    }

    func findSlug(matching text: String, stateHint: String? = nil) -> String? {
        let hay = entries.filter { e in
            if let hint = stateHint { if !e.state.localizedCaseInsensitiveContains(hint) { return false } }
            return e.name.localizedCaseInsensitiveContains(text) || (e.address?.localizedCaseInsensitiveContains(text) ?? false)
        }
        return hay.first?.slug
    }

    // MARK: - HTML parsing
    private func parseUSListHTML(_ html: String) -> [TeslaFindUsIndexEntry] {
        // The list page renders as sections per state with links like:
        // <a href="/findus/location/supercharger/LakeGroveNYsupercharger">Lake Grove, NY</a>
        // We'll capture (state header) then within it, links and approximate address lines.
        let ns = html as NSString

        // Capture state headers
        let stateHeaderRegex = try! NSRegularExpression(pattern: #"<h2[^>]*>([^<]+)</h2>"#, options: [.caseInsensitive])
        let linkRegex = try! NSRegularExpression(pattern: #"<a\s+href=\"/findus/location/supercharger/([^"]+)\"[^>]*>([^<]+)</a>"#, options: [.caseInsensitive])
        let addressRegex = try! NSRegularExpression(pattern: #"<div[^>]*class=\"location-address[^\"]*\"[^>]*>(.*?)</div>"#, options: [.caseInsensitive, .dotMatchesLineSeparators])

        var out: [TeslaFindUsIndexEntry] = []

        // Iterate sections by splitting on <h2>
        let headerMatches = stateHeaderRegex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        guard !headerMatches.isEmpty else { return out }

        for (idx, hMatch) in headerMatches.enumerated() {
            let state = ns.substring(with: hMatch.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            let sectionStart = hMatch.range.location + hMatch.range.length
            let sectionEnd = (idx + 1 < headerMatches.count) ? headerMatches[idx+1].range.location : ns.length
            let sectionRange = NSRange(location: sectionStart, length: sectionEnd - sectionStart)
            let sectionHTML = ns.substring(with: sectionRange)
            let sns = sectionHTML as NSString

            // Links inside this section
            let links = linkRegex.matches(in: sectionHTML, range: NSRange(location: 0, length: sns.length))
            let addrs = addressRegex.matches(in: sectionHTML, range: NSRange(location: 0, length: sns.length))

            for (j, l) in links.enumerated() {
                let slug = sns.substring(with: l.range(at: 1))
                let name = sns.substring(with: l.range(at: 2)).replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                let addr = j < addrs.count ? sns.substring(with: addrs[j].range(at: 1)).strippedHTML().condensedWhitespace() : nil
                out.append(.init(state: state, name: name, address: addr, slug: slug))
            }
        }
        return out
    }

    // MARK: - Cache
    private final class Cache {
        private let dir: URL = {
            let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let d = base.appendingPathComponent("TeslaFindUsIndexCache", isDirectory: true)
            try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
            return d
        }()
        func read<T: Decodable>(key: String) -> T? {
            let url = dir.appendingPathComponent(key)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(T.self, from: data)
        }
        func write<T: Encodable>(key: String, value: T) {
            let url = dir.appendingPathComponent(key)
            if let data = try? JSONEncoder().encode(value) { try? data.write(to: url) }
        }
    }
}

private extension String {
    func strippedHTML() -> String { self.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression) }
    func condensedWhitespace() -> String {
        components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }
}
