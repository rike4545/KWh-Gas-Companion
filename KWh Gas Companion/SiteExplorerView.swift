//
//  SiteExplorerView.swift — My KWh Companion
//  Map clusters + per-site stats list + manual GPS overrides
//  Regenerated: Oct 2025 — Supercharger-only
//
//  Changes:
//  • Shows ONLY Tesla Supercharging sessions (no leases, no other categories)
//  • Supercharger detection is robust and string-based; no dependency on model flags
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Manual coordinate overrides (normalized lookup)

fileprivate enum ManualSiteCoordinates {
    /// Normalize keys (remove punctuation/diacritics, squash spaces, lowercase)
    static func normalize(_ s: String) -> String {
        let folded = s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let noPunctScalars = folded.unicodeScalars.filter { !CharacterSet.punctuationCharacters.contains($0) }
        let noPunct = String(String.UnicodeScalarView(noPunctScalars))
        let squashed = noPunct
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return squashed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // ----------------------------------------------------------------------
    // PASTE YOUR FULL TABLES HERE (examples kept so this compiles).
    // ----------------------------------------------------------------------
    static let byName: [String: CLLocationCoordinate2D] = [
        // (… your table …)
        "lake grove supercharger": CLLocationCoordinate2D(latitude: 40.862269, longitude: -73.129075),
        "shirley supercharger": CLLocationCoordinate2D(latitude: 40.804373, longitude: -72.860362),
        "islandia supercharger": CLLocationCoordinate2D(latitude: 40.805079, longitude: -73.180528),
        // … keep the rest of your entries …
    ]

    /// Likely spellings/addresses → canonical key in `byName`
    static let aliases: [String: String] = [
        // Example corrections (incl. Hwy/Highway variants)
        "999 montauk hwy": "shirley supercharger",
        "999 montauk highway": "shirley supercharger",
        "smith haven mall": "lake grove supercharger",
        "tesla lake grove ny": "lake grove supercharger",
        // … keep the rest of your aliases …
    ]
    // ----------------------------------------------------------------------

    // Normalized copies used internally for robust matching
    private static let _normByName: [String: CLLocationCoordinate2D] = {
        var m: [String: CLLocationCoordinate2D] = [:]
        for (k, v) in byName { m[normalize(k)] = v }
        return m
    }()

    private static let _normAliases: [String: String] = {
        var m: [String: String] = [:]
        for (k, v) in aliases { m[normalize(k)] = normalize(v) }
        return m
    }()

    /// Lookup with normalization → direct → alias → substring fallback
    static func lookup(for rawName: String) -> CLLocationCoordinate2D? {
        let k = normalize(rawName)
        if let direct = _normByName[k] { return direct }
        if let canonical = _normAliases[k], let via = _normByName[canonical] { return via }
        if let (_, value) = _normByName.first(where: { k.contains($0.key) }) { return value }
        return nil
    }
}

// MARK: - Shared currency formatter

fileprivate enum MoneyFmt {
    static func currency(_ v: Double, code: String?) -> String {
        let fmt = Shared.currency
        fmt.currencyCode = code ?? Locale.current.currency?.identifier ?? "USD"
        return fmt.string(from: NSNumber(value: v)) ?? String(format: "$%.2f", v)
    }
    private enum Shared {
        static let currency: NumberFormatter = {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.maximumFractionDigits = 2
            f.minimumFractionDigits = 2
            return f
        }()
    }
}

// MARK: - Local stats helpers (avoid global extension collisions)

fileprivate enum Stats {
    /// Median for [Double]
    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let s = values.sorted()
        let mid = s.count / 2
        return s.count % 2 == 0 ? (s[mid - 1] + s[mid]) / 2.0 : s[mid]
    }
    /// Median for [Double?] (ignores nils)
    static func median(_ values: [Double?]) -> Double? {
        median(values.compactMap { $0 })
    }
}

// MARK: - Main View (Supercharger-only)

@MainActor
struct SiteExplorerView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @State private var search: String = ""
    @State private var selectedSiteID: String? = nil
    @State private var sort: Sort = .totalSpendDesc

    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    enum Sort: String, CaseIterable, Identifiable {
        case totalSpendDesc, lastVisitDesc, nameAsc
        var id: String { rawValue }
        var label: String {
            switch self {
            case .totalSpendDesc: return "Spend ↓"
            case .lastVisitDesc:  return "Last Visit ↓"
            case .nameAsc:        return "Name A–Z"
            }
        }
    }

    // MARK: Supercharger detection (string-based; model-field agnostic)
    /// Returns true ONLY for Tesla Supercharging sessions.
    /// Uses common string fields so it compiles across data models.
    private func isSupercharger(_ e: ExpenseEntry) -> Bool {
        let name  = (e.charging?.siteName ?? "").lowercased()
        let loc   = (e.location ?? "").lowercased()
        let cat   = e.category.lowercased()
        let ctype = (e.chargeType ?? "").lowercased()

        // Direct token
        if name.contains("supercharger") || loc.contains("supercharger") || cat.contains("supercharger") {
            return true
        }
        // Tesla + fast/DC cues
        let hay = [name, loc, cat, ctype].joined(separator: " ")
        if hay.contains("tesla") && (hay.contains("dcfc") || hay.contains("dc fast") || hay.contains("fast charge") || hay.contains("super charge")) {
            return true
        }
        // Strict fallback: energy with DC fast-like type and Tesla label present somewhere
        if (e.energyAddedKWh ?? 0) > 0, (ctype.contains("dc") || ctype.contains("fast")), hay.contains("tesla") {
            return true
        }
        return false
    }

    // Sites computed from SUPERCHARGER entries only
    private var sites: [SiteStat] {
        // 1) Keep only supercharger sessions — this excludes leases and all non-SC categories.
        let supercharge = entriesStore.entries.filter { isSupercharger($0) }

        // 2) Group by site name (fallback to "Unknown Supercharger")
        let groups = Dictionary(grouping: supercharge) { (entry: ExpenseEntry) -> String in
            let key = entry.charging?.siteName ?? entry.location ?? "Unknown Supercharger"
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Unknown Supercharger" : trimmed
        }

        // 3) Per-site rollups
        let mapped: [SiteStat] = groups.map { (name, entries) in
            let spend = entries.reduce(0) { $0 + $1.amount }

            // price/kWh per entry (explicit > derived)
            let unitPrices = entries.compactMap { e -> Double? in
                if let explicit = e.charging?.pricePerKWh { return explicit }
                if let k = e.energyAddedKWh, k > 0 { return e.amount / k }
                return nil
            }
            let median = Stats.median(unitPrices)

            let last   = entries.map(\.date).max() ?? .distantPast
            let count  = entries.count

            // Prefer GPS median; otherwise manual override table
            let coord = medianCoordinate(from: entries) ?? ManualSiteCoordinates.lookup(for: name)

            return SiteStat(
                siteName: name,
                coordinate: coord,
                totalAmount: spend,
                medianPricePerKWh: median,
                lastVisit: last,
                sessionCount: count
            )
        }

        // 4) Search (normalized)
        let q = ManualSiteCoordinates.normalize(search)
        let filtered = mapped.filter { s in
            q.isEmpty || ManualSiteCoordinates.normalize(s.siteName).contains(q)
        }

        // 5) Sort
        switch sort {
        case .totalSpendDesc: return filtered.sorted { $0.totalAmount > $1.totalAmount }
        case .lastVisitDesc:  return filtered.sorted { $0.lastVisit > $1.lastVisit }
        case .nameAsc:        return filtered.sorted { $0.siteName.localizedCaseInsensitiveCompare($1.siteName) == .orderedAscending }
        }
    }

    // Only annotated sites for the map
    private var annotatedSites: [SiteStat] { sites.filter { $0.coordinate != nil } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MAP
                ClusterMapView(
                    sites: annotatedSites.map { SiteMapItem(id: $0.id, name: $0.siteName, coordinate: $0.coordinate!) },
                    selectedID: $selectedSiteID
                )
                .frame(height: 300)
                .overlay(alignment: .topTrailing) {
                    Picker("Sort by", selection: $sort) {
                        ForEach(Sort.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.trailing, 10)
                    .padding(.top, 10)
                    .allowsHitTesting(true)
                    .accessibilityLabel("Sort by")
                }

                // LIST
                if sites.isEmpty {
                    EmptySitesView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(Color.clear)
                } else {
                    List {
                        Section {
                            ForEach(sites) { s in
                                SiteRow(
                                    stat: s,
                                    currencyCode: currencyCode,
                                    isHighlighted: s.id == selectedSiteID
                                )
                                .contentShape(Rectangle())
                                .onTapGesture { selectedSiteID = s.id }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if let c = s.coordinate {
                                        Button {
                                            let item = MKMapItem(placemark: MKPlacemark(coordinate: c))
                                            item.name = s.siteName
                                            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                                        } label: {
                                            Label("Directions", systemImage: "map")
                                        }
                                        .tint(.indigo)
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text("Supercharger Sites")
                                Spacer()
                                Text("\(sites.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Site Explorer")
            .searchable(text: $search,
                        placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: "Search Superchargers")
        }
    }

    // Median coordinate across sessions (de-noise GPS)
    private func medianCoordinate(from entries: [ExpenseEntry]) -> CLLocationCoordinate2D? {
        let coords = entries.compactMap { e -> CLLocationCoordinate2D? in
            guard let lat = e.charging?.latitude, let lon = e.charging?.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        guard !coords.isEmpty else { return nil }
        let lats = coords.map(\.latitude).sorted()
        let lons = coords.map(\.longitude).sorted()
        let mid = coords.count / 2
        let lat = (coords.count % 2 == 0) ? (lats[mid-1] + lats[mid]) / 2.0 : lats[mid]
        let lon = (coords.count % 2 == 0) ? (lons[mid-1] + lons[mid]) / 2.0 : lons[mid]
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Data models

fileprivate struct SiteStat: Identifiable {
    // Stable id derived from normalized site name (keeps selection)
    let id: String
    let siteName: String
    let coordinate: CLLocationCoordinate2D?
    let totalAmount: Double
    let medianPricePerKWh: Double?
    let lastVisit: Date
    let sessionCount: Int

    init(siteName: String,
         coordinate: CLLocationCoordinate2D?,
         totalAmount: Double,
         medianPricePerKWh: Double?,
         lastVisit: Date,
         sessionCount: Int)
    {
        self.siteName = siteName
        self.coordinate = coordinate
        self.totalAmount = totalAmount
        self.medianPricePerKWh = medianPricePerKWh
        self.lastVisit = lastVisit
        self.sessionCount = sessionCount
        self.id = ManualSiteCoordinates.normalize(siteName)
    }
}

// Equatable/Hashable by id only (avoid CLLocationCoordinate2D synthesis issues)
extension SiteStat: Equatable { static func == (lhs: SiteStat, rhs: SiteStat) -> Bool { lhs.id == rhs.id } }
extension SiteStat: Hashable   { func hash(into hasher: inout Hasher) { hasher.combine(id) } }

fileprivate struct SiteMapItem: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
}

// Equatable/Hashable by id only
extension SiteMapItem: Equatable { static func == (lhs: SiteMapItem, rhs: SiteMapItem) -> Bool { lhs.id == rhs.id } }
extension SiteMapItem: Hashable   { func hash(into hasher: inout Hasher) { hasher.combine(id) } }

// MARK: - List row

fileprivate struct SiteRow: View {
    let stat: SiteStat
    let currencyCode: String
    var isHighlighted: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(isHighlighted ? 0.22 : 0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: stat.coordinate == nil ? "mappin.slash.circle" : "bolt.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.siteName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 8) {
                    Text("\(stat.sessionCount) session\(stat.sessionCount == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                    if let m = stat.medianPricePerKWh {
                        Text("@ \(MoneyFmt.currency(m, code: currencyCode))/kWh")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(MoneyFmt.currency(stat.totalAmount, code: currencyCode))
                    .font(.headline)
                    .minimumScaleFactor(0.8)
                Text(stat.lastVisit, style: .date)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Map with clustering (UIKit bridge)

fileprivate final class SiteAnnotation: NSObject, MKAnnotation {
    let id: String
    let titleText: String
    dynamic var coordinate: CLLocationCoordinate2D

    init(id: String, title: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.titleText = title
        self.coordinate = coordinate
        super.init()
    }
    var title: String? { titleText }
}

fileprivate struct ClusterMapView: UIViewRepresentable {
    var sites: [SiteMapItem]
    @Binding var selectedID: String?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.pointOfInterestFilter = .excludingAll
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "site")
        map.showsCompass = false
        map.showsScale = false
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Replace annotations on change
        let existing = map.annotations.compactMap { $0 as? SiteAnnotation }
        map.removeAnnotations(existing)

        let anns: [SiteAnnotation] = sites.map { s in
            SiteAnnotation(id: s.id, title: s.name, coordinate: s.coordinate)
        }
        map.addAnnotations(anns)

        // Fit region when sites change
        if !anns.isEmpty {
            let region = MKCoordinateRegion(fitting: anns.map(\.coordinate),
                                            edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40))
            map.setRegion(region, animated: true)
        }

        // If a row is tapped, select & center that annotation.
        if let sel = selectedID,
           let ann = anns.first(where: { $0.id == sel }) {
            map.selectAnnotation(ann, animated: true)
            map.setCenter(ann.coordinate, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(selectedID: $selectedID) }

    final class Coordinator: NSObject, MKMapViewDelegate {
        @Binding var selectedID: String?
        init(selectedID: Binding<String?>) { _selectedID = selectedID }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let a = annotation as? SiteAnnotation else { return nil }
            guard let view = mapView.dequeueReusableAnnotationView(withIdentifier: "site", for: a) as? MKMarkerAnnotationView else {
                return nil
            }
            view.clusteringIdentifier = "siteCluster"
            view.titleVisibility = .adaptive
            view.subtitleVisibility = .hidden
            view.glyphImage = UIImage(systemName: "bolt.fill")
            view.markerTintColor = UIColor(Color.accentColor)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let a = view.annotation as? SiteAnnotation else { return }
            selectedID = a.id
        }
    }
}

// MARK: - Utilities

fileprivate struct EmptySitesView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.slash")
                .font(.system(size: 34, weight: .semibold))
                .opacity(0.7)
            Text("No Supercharging sessions yet")
                .font(.headline)
            Text("When you log Tesla Supercharger charges, they’ll appear here and on the map.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 20)
    }
}

fileprivate extension MKCoordinateRegion {
    init(fitting coords: [CLLocationCoordinate2D], edgePadding: UIEdgeInsets) {
        guard let first = coords.first else {
            self.init(center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                      span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
            return
        }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for c in coords {
            minLat = Swift.min(minLat, c.latitude)
            maxLat = Swift.max(maxLat, c.latitude)
            minLon = Swift.min(minLon, c.longitude)
            maxLon = Swift.max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0,
                                            longitude: (minLon + maxLon) / 2.0)
        let span = MKCoordinateSpan(latitudeDelta: Swift.max((maxLat - minLat) * 1.4, 0.02),
                                    longitudeDelta: Swift.max((maxLon - minLon) * 1.4, 0.02))
        self.init(center: center, span: span)
    }
}

// #Preview {
//     SiteExplorerView().environmentObject(EntriesStore())
// }
