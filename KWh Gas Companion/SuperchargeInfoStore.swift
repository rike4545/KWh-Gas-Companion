//
//  SuperchargeInfoStore.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//
//  Supercharge.info directory store (US-focused) using SuperchargeInfoClient.
//  - NO SCISite usage (prevents ambiguity collisions).
//  - Disk cache (Application Support) for reuse across app.
//  - Optional change list (SCISiteChange) for UI badges/feeds.
//

import Foundation
import CoreLocation

@MainActor
public final class SuperchargeInfoStore: ObservableObject {

    // MARK: - Change model (safe + Codable)

    public struct SCISiteChange: Identifiable, Codable, Hashable, Sendable {
        public enum Kind: String, Codable, Hashable, Sendable {
            case added
            case removed
            case updated
        }

        public let id: UUID
        public let kind: Kind
        public let locationId: String
        public let timestamp: Date
        public let summary: String

        public init(
            id: UUID = UUID(),
            kind: Kind,
            locationId: String,
            timestamp: Date = Date(),
            summary: String
        ) {
            self.id = id
            self.kind = kind
            self.locationId = locationId
            self.timestamp = timestamp
            self.summary = summary
        }
    }

    public struct Nearby: Identifiable, Hashable, Sendable {
        public var id: Int { site.id }
        public let site: SuperchargeInfoSite
        public let distanceMeters: CLLocationDistance
    }

    // MARK: - Published

    @Published public private(set) var sitesUS: [SuperchargeInfoSite] = []
    @Published public private(set) var databaseLastModified: Date?
    @Published public private(set) var lastRefreshed: Date?

    @Published public private(set) var recentChanges: [SCISiteChange] = []

    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?

    // MARK: - Tunables

    public var refreshTTL: TimeInterval = 60 * 60 * 24 * 2 // 2 days
    public var onlyActiveByDefault: Bool = true
    public var maxChangeItems: Int = 60

    // MARK: - Private

    private let client: SuperchargeInfoClient
    private let cacheSchemaVersion = 1
    private let cacheFilename = "supercharge_info_store_cache_v1.json"

    // MARK: - Init

    public init(client: SuperchargeInfoClient? = nil) {
        self.client = client ?? .shared
        loadCache()
    }

    // MARK: - Cache

    public func loadCache() {
        do {
            let url = try cacheFileURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let cached = try decoder.decode(CacheContainer.self, from: data)
            guard cached.schemaVersion == cacheSchemaVersion else { return }

            self.sitesUS = cached.sitesUS
            self.databaseLastModified = cached.databaseLastModified
            self.lastRefreshed = cached.lastRefreshed
            self.recentChanges = cached.recentChanges
        } catch {
            #if DEBUG
            print("SuperchargeInfoStore loadCache error:", error)
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
                databaseLastModified: databaseLastModified,
                lastRefreshed: lastRefreshed,
                recentChanges: recentChanges
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
            print("SuperchargeInfoStore saveCache error:", error)
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

    public func refresh(force: Bool = false, onlyActive: Bool? = nil) async {
        if isLoading { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let keepOnlyActive = onlyActive ?? onlyActiveByDefault

        do {
            if !force,
               let last = lastRefreshed,
               Date().timeIntervalSince(last) < refreshTTL,
               !sitesUS.isEmpty {
                return
            }

            // Check DB stamp (skip full download if unchanged)
            let db = try await client.fetchDatabaseInfo()
            let remoteStamp = db.lastModifiedDate

            if !force,
               let remoteStamp,
               let localStamp = databaseLastModified,
               remoteStamp <= localStamp,
               !sitesUS.isEmpty {
                lastRefreshed = Date()
                saveCache()
                return
            }

            let oldByLocation = Dictionary(uniqueKeysWithValues: sitesUS.map { ($0.locationId, $0) })

            // Download all sites, then filter US + active
            let all = try await client.fetchAllSites()
            let us = all
                .filter { isLikelyUS($0) }
                .filter { keepOnlyActive ? isLikelyActive($0) : true }
                .sorted { a, b in
                    let aState = a.address?.state ?? ""
                    let bState = b.address?.state ?? ""
                    if aState != bState { return aState < bState }

                    let aCity = a.address?.city ?? ""
                    let bCity = b.address?.city ?? ""
                    if aCity != bCity { return aCity < bCity }

                    return (a.name ?? "") < (b.name ?? "")
                }

            // Build change list (best-effort)
            let newByLocation = Dictionary(uniqueKeysWithValues: us.map { ($0.locationId, $0) })
            let changes = diff(old: oldByLocation, new: newByLocation)

            self.sitesUS = us
            self.databaseLastModified = remoteStamp
            self.lastRefreshed = Date()

            if !changes.isEmpty {
                self.recentChanges = Array((changes + recentChanges).prefix(maxChangeItems))
            }

            saveCache()

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Queries

    public func site(locationId: String) -> SuperchargeInfoSite? {
        sitesUS.first(where: { $0.locationId == locationId })
    }

    public func nearby(
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
        if let c = site.address?.country?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !c.isEmpty {
            return (c == "usa" || c == "united states" || c == "united states of america")
        }

        // Fallback: 2-letter state code is a decent hint
        if let st = site.address?.state?.trimmingCharacters(in: .whitespacesAndNewlines), st.count == 2 {
            return true
        }
        return false
    }

    private func isLikelyActive(_ site: SuperchargeInfoSite) -> Bool {
        let s = (site.status ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.contains("open") { return true }
        if s.contains("expand") { return true }
        if s.contains("temp") && s.contains("close") { return true }
        return false
    }

    // MARK: - Diff

    private func diff(old: [String: SuperchargeInfoSite], new: [String: SuperchargeInfoSite]) -> [SCISiteChange] {
        var out: [SCISiteChange] = []

        // Added
        for (id, s) in new where old[id] == nil {
            out.append(.init(kind: .added, locationId: id, summary: "Added: \(s.name ?? id)"))
        }

        // Removed
        for (id, s) in old where new[id] == nil {
            out.append(.init(kind: .removed, locationId: id, summary: "Removed: \(s.name ?? id)"))
        }

        // Updated (compare a few high-signal fields)
        for (id, newSite) in new {
            guard let oldSite = old[id] else { continue }

            var fields: [String] = []

            let oStatus = (oldSite.status ?? "").lowercased()
            let nStatus = (newSite.status ?? "").lowercased()
            if oStatus != nStatus { fields.append("status") }

            if oldSite.stallCount != newSite.stallCount { fields.append("stalls") }
            if oldSite.powerKilowatt != newSite.powerKilowatt { fields.append("kW") }

            let oName = (oldSite.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let nName = (newSite.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if oName != nName { fields.append("name") }

            if !fields.isEmpty {
                out.append(.init(
                    kind: .updated,
                    locationId: id,
                    summary: "Updated (\(fields.joined(separator: ", "))): \(newSite.name ?? id)"
                ))
            }
        }

        // Newest first
        out.sort { $0.timestamp > $1.timestamp }
        return out
    }
}

// MARK: - Cache container

private struct CacheContainer: Codable {
    let schemaVersion: Int
    let savedAt: Date

    let sitesUS: [SuperchargeInfoSite]
    let databaseLastModified: Date?
    let lastRefreshed: Date?
    let recentChanges: [SuperchargeInfoStore.SCISiteChange]
}
