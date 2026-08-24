//
//  RouteDiscoveryStore.swift
//  KWh Gas Companion
//
//  Route Discovery — the catalog of shared driving routes, the user's favorites
//  and published routes, and the moderation state (reports + blocked authors).
//
//  BACKEND STATUS
//  ──────────────
//  This ships against `LocalRouteCatalog`, which is fully functional offline:
//  a curated starter set plus anything the user publishes, persisted on device.
//  `RouteCatalog` is the seam a remote backend drops into — see
//  `RouteDiscoveryBackend.md` notes at the bottom for exactly what has to exist
//  server-side first (Firebase Auth, Firestore, security rules, and the UGC
//  moderation surface App Review requires). Nothing here talks to the network,
//  so no cloud resources are created without the owner doing it deliberately.
//
//  Swift 6 • iOS 17+
//

import Foundation
import Combine

// MARK: - Catalog seam

/// The operations Route Discovery needs. A remote implementation replaces the
/// local one without the UI changing.
protocol RouteCatalog {
    func loadRoutes() async throws -> [SharedRoute]
    func publish(_ route: SharedRoute) async throws
    func report(routeID: UUID, reason: String) async throws
}

// MARK: - Store

@MainActor
final class RouteDiscoveryStore: ObservableObject {

    // MARK: Published state

    @Published private(set) var catalogRoutes: [SharedRoute] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?

    /// Routes this user published. Kept separate so they survive a catalog
    /// refresh and are always visible to their author.
    @Published private(set) var myRoutes: [SharedRoute] = [] { didSet { persist() } }

    @Published private(set) var favoriteIDs: Set<UUID> = [] { didSet { persist() } }

    /// Moderation. Reported routes are hidden immediately for the reporter —
    /// App Review expects a report to take effect without waiting on a server
    /// round trip. Blocked authors disappear entirely.
    @Published private(set) var reportedRouteIDs: Set<UUID> = [] { didSet { persist() } }
    @Published private(set) var blockedAuthorIDs: Set<String> = [] { didSet { persist() } }

    // MARK: Dependencies

    private let catalog: RouteCatalog

    init(catalog: RouteCatalog = LocalRouteCatalog()) {
        self.catalog = catalog
        hydrate()
    }

    // MARK: Derived

    /// Everything visible to this user, moderation applied.
    var visibleRoutes: [SharedRoute] {
        (myRoutes + catalogRoutes)
            .filter { !reportedRouteIDs.contains($0.id) }
            .filter { !blockedAuthorIDs.contains($0.authorID) }
    }

    var favoriteRoutes: [SharedRoute] {
        visibleRoutes.filter { favoriteIDs.contains($0.id) }
    }

    /// Region labels present in the visible set, for the filter chips.
    var regions: [String] {
        Array(Set(visibleRoutes.map(\.region))).sorted()
    }

    func isFavorite(_ route: SharedRoute) -> Bool { favoriteIDs.contains(route.id) }

    func isMine(_ route: SharedRoute) -> Bool { myRoutes.contains { $0.id == route.id } }

    /// Search + region filter + sort, done in one pass over the visible set.
    func filtered(search: String, region: String?, sort: RouteSort) -> [SharedRoute] {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var rows = visibleRoutes
        if let region { rows = rows.filter { $0.region == region } }
        if !needle.isEmpty {
            // Precompute each haystack once rather than per comparison.
            rows = rows.filter { $0.searchHaystack.contains(needle) }
        }

        switch sort {
        case .newest:   rows.sort { $0.createdAt > $1.createdAt }
        case .shortest: rows.sort { $0.sortableMiles < $1.sortableMiles }
        case .longest:  rows.sort { $0.sortableMiles > $1.sortableMiles }
        case .name:     rows.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return rows
    }

    // MARK: Actions

    func refresh() async {
        isLoading = true
        loadError = nil
        do {
            catalogRoutes = try await catalog.loadRoutes()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    func toggleFavorite(_ route: SharedRoute) {
        if favoriteIDs.contains(route.id) {
            favoriteIDs.remove(route.id)
        } else {
            favoriteIDs.insert(route.id)
        }
    }

    func publish(_ route: SharedRoute) async {
        myRoutes.append(route)
        // Local catalog accepts immediately; a remote one may reject, in which
        // case the route stays visible to its author and surfaces the error.
        do { try await catalog.publish(route) }
        catch { loadError = error.localizedDescription }
    }

    func deleteMyRoute(_ route: SharedRoute) {
        myRoutes.removeAll { $0.id == route.id }
        favoriteIDs.remove(route.id)
    }

    func report(_ route: SharedRoute, reason: String) async {
        reportedRouteIDs.insert(route.id)
        do { try await catalog.report(routeID: route.id, reason: reason) }
        catch { /* the local hide already happened; a failed upload must not undo it */ }
    }

    func blockAuthor(of route: SharedRoute) {
        blockedAuthorIDs.insert(route.authorID)
    }

    func unblockAll() {
        blockedAuthorIDs.removeAll()
        reportedRouteIDs.removeAll()
    }

    // MARK: Persistence
    //
    // Same coalescing shape as EntriesStore: a burst of mutations in one
    // run-loop turn produces a single encode + write, off the main thread.
    // Publishing a batch or toggling several favorites must not re-serialize
    // the whole file once per change.

    private var hasPendingSave = false
    private var isHydrating = true
    private let writeQueue = DispatchQueue(label: "RouteDiscoveryStore.WriteQueue", qos: .utility)

    private struct Payload: Codable {
        var myRoutes: [SharedRoute] = []
        var favoriteIDs: [UUID] = []
        var reportedRouteIDs: [UUID] = []
        var blockedAuthorIDs: [String] = []
    }

    private static func makeSaveURL() -> URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true))
            ?? FileManager.default.temporaryDirectory
        let bundle = Bundle.main.bundleIdentifier ?? "KWhGasCompanion"
        let dir = base.appendingPathComponent(bundle, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("route_discovery_v1.json")
    }

    private let saveURL: URL = RouteDiscoveryStore.makeSaveURL()

    private func hydrate() {
        defer { isHydrating = false }
        guard let data = try? Data(contentsOf: saveURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(Payload.self, from: data) else { return }

        myRoutes = payload.myRoutes
        favoriteIDs = Set(payload.favoriteIDs)
        reportedRouteIDs = Set(payload.reportedRouteIDs)
        blockedAuthorIDs = Set(payload.blockedAuthorIDs)
    }

    private func persist() {
        guard !isHydrating, !hasPendingSave else { return }
        hasPendingSave = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.hasPendingSave = false
            self.flush(Payload(
                myRoutes: self.myRoutes,
                favoriteIDs: Array(self.favoriteIDs),
                reportedRouteIDs: Array(self.reportedRouteIDs),
                blockedAuthorIDs: Array(self.blockedAuthorIDs)
            ))
        }
    }

    private func flush(_ payload: Payload) {
        let url = saveURL
        writeQueue.async {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(payload) else { return }
            try? data.write(to: url, options: [.atomic])
        }
    }
}

// MARK: - Sorting

enum RouteSort: String, CaseIterable, Identifiable {
    case newest, shortest, longest, name
    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest:   return "Newest"
        case .shortest: return "Shortest"
        case .longest:  return "Longest"
        case .name:     return "A–Z"
        }
    }
}

// MARK: - Local catalog

/// Ships a curated starter set so Route Discovery is useful on first launch and
/// entirely offline. Coordinates are real; distances are author-stated.
struct LocalRouteCatalog: RouteCatalog {

    func loadRoutes() async throws -> [SharedRoute] { Self.starterRoutes }

    func publish(_ route: SharedRoute) async throws {
        // No-op locally: RouteDiscoveryStore already keeps `myRoutes` on device.
    }

    func report(routeID: UUID, reason: String) async throws {
        // No-op locally: the reporter-side hide is what matters until there is
        // a server to receive the report.
    }

    static let starterRoutes: [SharedRoute] = {
        func route(
            _ title: String,
            _ summary: String,
            region: String,
            tags: [String],
            miles: Double,
            charging: Bool,
            daysAgo: Int,
            stops: [(String, Double, Double)],
            options: SharedRouteOptions = .init()
        ) -> SharedRoute {
            let mapped = stops.map {
                SharedRouteStop(name: $0.0, coordinate: .init(latitude: $0.1, longitude: $0.2))
            }
            return SharedRoute(
                title: title,
                summary: summary,
                tripQuery: SharedRoute.makeTripQuery(stops: mapped, options: options),
                region: region,
                tags: tags,
                statedMiles: miles,
                authorName: "LibreNav Community",
                authorID: "curated",
                createdAt: Date(timeIntervalSinceNow: -Double(daysAgo) * 86_400),
                hasChargingNoted: charging
            )
        }

        return [
            route(
                "North Fork Wine Run",
                "Riverhead out to Orient Point along Route 25, past the vineyards. Easy pace, plenty of stops.",
                region: "Long Island, NY",
                tags: ["scenic", "coastal", "day trip"],
                miles: 48, charging: true, daysAgo: 3,
                stops: [("Riverhead", 40.9170, -72.6620),
                        ("Jamesport", 40.9490, -72.5810),
                        ("Southold", 41.0648, -72.4262),
                        ("Orient Point", 41.1626, -72.2373)],
                options: SharedRouteOptions(avoidHighways: true, preferTwisty: true)
            ),
            route(
                "Montauk Point Loop",
                "The classic South Fork run to the lighthouse and back through the Napeague stretch.",
                region: "Long Island, NY",
                tags: ["coastal", "lighthouse", "weekend"],
                miles: 92, charging: true, daysAgo: 9,
                stops: [("Southampton", 40.8843, -72.3895),
                        ("East Hampton", 40.9634, -72.1848),
                        ("Montauk Point", 41.0715, -71.8573)],
                options: SharedRouteOptions(preferTwisty: true)
            ),
            route(
                "Hudson Valley Ridge",
                "Bear Mountain and Perkins Memorial Drive, then north along 9W. Best in autumn.",
                region: "Hudson Valley, NY",
                tags: ["mountain", "twisty", "fall foliage"],
                miles: 74, charging: true, daysAgo: 16,
                stops: [("Bear Mountain", 41.3126, -73.9887),
                        ("West Point", 41.3915, -73.9568),
                        ("Newburgh", 41.5034, -74.0104)],
                options: SharedRouteOptions(avoidTolls: true, preferTwisty: true)
            ),
            route(
                "Litchfield Hills Run",
                "Connecticut backroads through Kent and Cornwall. Narrow, quiet, and worth the detour.",
                region: "Connecticut",
                tags: ["twisty", "backroads", "scenic"],
                miles: 63, charging: false, daysAgo: 24,
                stops: [("Kent CT", 41.7237, -73.4773),
                        ("Cornwall Bridge", 41.8154, -73.3696),
                        ("Litchfield CT", 41.7470, -73.1887)],
                options: SharedRouteOptions(avoidHighways: true, preferTwisty: true)
            ),
            route(
                "Jersey Shore Cruise",
                "Sandy Hook down through the barrier islands on Ocean Avenue. Flat, open, and fast-charging friendly.",
                region: "New Jersey",
                tags: ["coastal", "cruise", "summer"],
                miles: 57, charging: true, daysAgo: 31,
                stops: [("Sandy Hook", 40.4676, -73.9971),
                        ("Asbury Park", 40.2204, -74.0121),
                        ("Point Pleasant", 40.0912, -74.0446)],
                options: SharedRouteOptions(avoidHighways: true)
            ),
            route(
                "Catskills Escape",
                "Kingston up to Hunter over Route 23A, including the Kaaterskill switchbacks.",
                region: "Hudson Valley, NY",
                tags: ["mountain", "twisty", "waterfalls"],
                miles: 88, charging: true, daysAgo: 44,
                stops: [("Kingston NY", 41.9270, -73.9974),
                        ("Palenville", 42.1737, -74.0157),
                        ("Hunter NY", 42.2100, -74.2200)],
                options: SharedRouteOptions(avoidTolls: true, preferTwisty: true)
            )
        ]
    }()
}
