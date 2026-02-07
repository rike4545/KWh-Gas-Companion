//
//  SuperchargerStore.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//
//  Supercharger directory store backed by supercharge.info (allSites + databaseInfo).
//  - No SCISite usage (avoids SCISite ambiguity issues).
//  - Uses SuperchargeInfoClient.fetchAllSites() + fetchDatabaseInfo().
//  - Persists cache to Application Support for reuse across app launches.
//

import Foundation
import CoreLocation

@MainActor
final class SuperchargerStore: ObservableObject {

    // MARK: - Public types

    struct Nearby: Identifiable, Hashable, Sendable {
        var id: Int { site.id }
        let site: SuperchargeInfoSite
        let distanceMeters: CLLocationDistance
    }

    // MARK: - Published state

    @Published private(set) var sitesUS: [SuperchargeInfoSite] = []
    @Published private(set) var lastRefreshed: Date?
    @Published private(set) var databaseLastModified: Date?

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    // MARK: - Tunables

    /// If DB stamp didn’t change and we have sites, skip refetching allSites.
    var refreshTTL: TimeInterval = 60 * 60 * 24 * 2 // 2 days

    /// When true, keep only likely-active entries (open/expanding/temp-closed heuristics).
    var defaultOnlyActive: Bool = true

    // MARK: - Private

    private let client: SuperchargeInfoClient
    private let cacheFilename = "supercharge_info_us_sites_cache_v1.json"
    private let cacheSchemaVersion = 1

    // MARK: - Init

    init(client: SuperchargeInfoClient? = nil) {
        self.client = client ?? .shared
        loadCache()
    }

    // MARK: - Cache

    func loadCache() {
        do {
            let url = try cacheFileURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cached = try decoder.decode(CacheContainer.self, from: data)

            guard cached.schemaVersion == cacheSchemaVersion else { return }

            self.sitesUS = cached.sitesUS
            self.lastRefreshed = cached.lastRefreshed
            self.databaseLastModified = cached.databaseLastModified
        } catch {
            #if DEBUG
            print("SuperchargerStore loadCache error:", error)
            #endif
        }
    }

    private func saveCache() {
        do {
            let url = try cacheFileURL()
            let payload = CacheContainer(
                schemaVersion: cacheSchemaVersion,
                savedAt: Date(),
                sitesUS: sitesUS,
                lastRefreshed: lastRefreshed,
                databaseLastModified: databaseLastModified
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)

            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )

            try data.write(to: url, options: [.atomic])
        } catch {
            #if DEBUG
            print("SuperchargerStore saveCache error:", error)
            #endif
        }
    }

    private func cacheFileURL() throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("KWhGasCompanion", isDirectory: true)
        return dir.appendingPathComponent(cacheFilename, isDirectory: false)
    }

    // MARK: - Refresh

    /// Refresh US sites list. Uses databaseInfo stamp to avoid unnecessary full downloads.
    func refresh(force: Bool = false, onlyActive: Bool? = nil) async {
        if isLoading { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let shouldOnlyActive = onlyActive ?? defaultOnlyActive

        do {
            // TTL shortcut
            if !force,
               let last = lastRefreshed,
               Date().timeIntervalSince(last) < refreshTTL,
               !sitesUS.isEmpty {
                return
            }

            // Check database stamp
            let dbInfo = try await client.fetchDatabaseInfo()
            let remoteStamp = dbInfo.lastModifiedDate

            if !force,
               let remoteStamp,
               let localStamp = databaseLastModified,
               remoteStamp <= localStamp,
               !sitesUS.isEmpty {
                // DB didn't change; just mark refreshed
                lastRefreshed = Date()
                saveCache()
                return
            }

            // Fetch all sites then filter
            let all = try await client.fetchAllSites()

            let filteredUS = all
                .filter { site in
                    isLikelyUS(site)
                }
                .filter { site in
                    if shouldOnlyActive { return isLikelyActive(site) }
                    return true
                }
                .sorted { a, b in
                    // stable sort by state/city/name if available
                    let aState = a.address?.state ?? ""
                    let bState = b.address?.state ?? ""
                    if aState != bState { return aState < bState }

                    let aCity = a.address?.city ?? ""
                    let bCity = b.address?.city ?? ""
                    if aCity != bCity { return aCity < bCity }

                    let aName = a.name ?? ""
                    let bName = b.name ?? ""
                    return aName < bName
                }

            self.sitesUS = filteredUS
            self.databaseLastModified = remoteStamp
            self.lastRefreshed = Date()
            self.saveCache()

        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Queries

    func site(forLocationId locationId: String) -> SuperchargeInfoSite? {
        sitesUS.first(where: { $0.locationId == locationId })
    }

    func nearby(
        from coordinate: CLLocationCoordinate2D,
        radiusMeters: CLLocationDistance = 80_000,
        limit: Int = 60
    ) -> [Nearby] {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        var hits: [Nearby] = []
        hits.reserveCapacity(min(limit, 200))

        for s in sitesUS {
            let d = origin.distance(from: CLLocation(latitude: s.gps.latitude, longitude: s.gps.longitude))
            if d <= radiusMeters {
                hits.append(.init(site: s, distanceMeters: d))
            }
        }

        hits.sort { $0.distanceMeters < $1.distanceMeters }
        if hits.count > limit { return Array(hits.prefix(limit)) }
        return hits
    }

    // MARK: - Heuristics

    private func isLikelyUS(_ site: SuperchargeInfoSite) -> Bool {
        // Prefer explicit country when present.
        if let c = site.address?.country?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !c.isEmpty {
            if c == "usa" || c == "united states" || c == "united states of america" { return true }
            return false
        }

        // Fallback: if it has a 2-letter state code, treat as US.
        if let st = site.address?.state?.trimmingCharacters(in: .whitespacesAndNewlines), st.count == 2 {
            return true
        }

        return false
    }

    private func isLikelyActive(_ site: SuperchargeInfoSite) -> Bool {
        let s = (site.status ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // supercharge.info commonly uses values like:
        // "OPEN", "PERMIT", "CONSTRUCTION", "PLANNED", "TEMP_CLOSED", "EXPANDING", etc.
        if s.contains("open") { return true }
        if s.contains("expand") { return true }
        if s.contains("temp") && s.contains("close") { return true }

        return false
    }
}

// MARK: - Cache container

private struct CacheContainer: Codable {
    let schemaVersion: Int
    let savedAt: Date

    let sitesUS: [SuperchargeInfoSite]
    let lastRefreshed: Date?
    let databaseLastModified: Date?
}
