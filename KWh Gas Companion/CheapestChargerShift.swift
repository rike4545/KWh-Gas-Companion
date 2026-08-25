//
//  CheapestChargerShift.swift — v4 (fixed, compile-ready)
//  My KWh Companion
//
//  Find and rank the cheapest nearby public EV chargers.
//  • Apple Maps discovery (POI: .evCharger + NLQ fallback)
//  • Open Charge Map price enrichment (best-effort $/kWh)
//  iOS 17+ / Swift 6
//

import SwiftUI
import MapKit
import CoreLocation
import Foundation

// MARK: - Small utilities

private func coordKey(_ c: CLLocationCoordinate2D, precision: Int = 5) -> String {
    let fmt = "%.\(precision)f"
    return String(format: fmt, c.latitude) + "," + String(format: fmt, c.longitude)
}

private extension Locale {
    var isMetric: Bool {
        if #available(iOS 16.0, *) { return measurementSystem == .metric }
        let cc = (self as NSLocale).object(forKey: .countryCode) as? String
        return !(["US", "LR", "MM"].contains(cc ?? ""))
    }
}

private func distance(from: CLLocation?, to coord: CLLocationCoordinate2D) -> CLLocationDistance {
    guard let from else { return .infinity }
    return from.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
}

private func formatDistance(_ meters: CLLocationDistance, locale: Locale) -> String {
    if meters.isInfinite { return "—" }
    if locale.isMetric {
        let km = meters / 1000.0
        return String(format: "%.1f km", km)
    } else {
        let miles = meters / 1609.34
        return String(format: "%.1f mi", miles)
    }
}

// MARK: - Radius

private enum SearchRadius: String, CaseIterable, Identifiable {
    case r10, r25, r50, r100
    var id: String { rawValue }

    func label(locale: Locale) -> String {
        switch self {
        case .r10:  return locale.isMetric ? "10 km"  : "10 mi"
        case .r25:  return locale.isMetric ? "25 km"  : "25 mi"
        case .r50:  return locale.isMetric ? "50 km"  : "50 mi"
        case .r100: return locale.isMetric ? "100 km" : "100 mi"
        }
    }

    func meters(locale: Locale) -> CLLocationDistance {
        switch self {
        case .r10:  return locale.isMetric ? 10_000  : 16_093
        case .r25:  return locale.isMetric ? 25_000  : 40_234
        case .r50:  return locale.isMetric ? 50_000  : 80_467
        case .r100: return locale.isMetric ? 100_000 : 160_934
        }
    }
}

// MARK: - Location Provider

private final class BuiltInLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authorization: CLAuthorizationStatus = .notDetermined
    @Published var location: CLLocation?
    @Published var error: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            Task { @MainActor in
                self.error = "Location permission denied. Enable it in Settings."
            }
        @unknown default:
            break
        }
    }

    func refresh() {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
        }
        if authorization == .authorizedAlways || authorization == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        Task { @MainActor in
            self.location = latest
            self.error = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.error = message
        }
    }
}

// MARK: - Provider Guess

private func nmGuessProvider(from name: String?, fallback: String) -> String {
    let n = (name ?? "").lowercased()
    if n.contains("tesla") { return "Tesla" }
    if n.contains("electrify america") || n.contains("ea ") { return "Electrify America" }
    if n.contains("evgo") { return "EVgo" }
    if n.contains("chargepoint") || n.contains("charge point") { return "ChargePoint" }
    return fallback
}

// MARK: - Discovery (Apple Maps)

private actor AppleMapsDiscovery {
    func discoverEVChargers(center: CLLocationCoordinate2D,
                            radiusMeters: CLLocationDistance,
                            limit: Int) async -> [MKMapItem] {
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusMeters * 2.0,
            longitudinalMeters: radiusMeters * 2.0
        )

        func run(_ configure: (inout MKLocalSearch.Request) -> Void) async -> [MKMapItem] {
            var req = MKLocalSearch.Request()
            req.region = region
            configure(&req)
            do {
                let resp = try await MKLocalSearch(request: req).start()
                return resp.mapItems
            } catch {
                return []
            }
        }

        // Prefer POI filter:
        var items = await run { $0.pointOfInterestFilter = .init(including: [.evCharger]) }

        // Fallback to NLQ:
        if items.isEmpty {
            items = await run { $0.naturalLanguageQuery = "EV charger" }
        }

        // De-dupe by name + rounded coord; keep only EV category when it’s known.
        var seen: [String: MKMapItem] = [:]
        for it in items {
            if let cat = it.pointOfInterestCategory, cat != .evCharger { continue }
            let key = (it.name ?? "EV Charger") + "@" + coordKey(it.compatCoordinate, precision: 5)
            if seen[key] == nil { seen[key] = it }
        }

        return Array(seen.values.prefix(limit))
    }
}

// MARK: - OCM Enrichment (best-effort $/kWh)

private actor OCMPriceService {
    /// Optional: set your key to reduce throttling.
    private let apiKey: String? = nil
    private var cache: [String: (Double?, String?)] = [:] // rounded coord => (price/kWh, display text)

    struct POI: Decodable {
        struct Connection: Decodable { var PowerKW: Double? }
        var UsageCost: String?
        var Connections: [Connection]?
    }

    func priceNear(_ coordinate: CLLocationCoordinate2D) async -> (Double?, String?) {
        let key = coordKey(coordinate, precision: 4)
        if let c = cache[key] { return c }

        var comps = URLComponents(string: "https://api.openchargemap.io/v3/poi/")!
        comps.queryItems = [
            .init(name: "output", value: "json"),
            .init(name: "latitude", value: String(format: "%.6f", coordinate.latitude)),
            .init(name: "longitude", value: String(format: "%.6f", coordinate.longitude)),
            .init(name: "maxresults", value: "5"),
            .init(name: "distance", value: "0.5"),
            .init(name: "distanceunit", value: "Miles"),
            .init(name: "compact", value: "true"),
            .init(name: "verbose", value: "false")
        ]
        guard let url = comps.url else {
            cache[key] = (nil, nil)
            return (nil, nil)
        }

        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("MyKWhCompanion/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        if let apiKey { req.setValue(apiKey, forHTTPHeaderField: "X-API-Key") }

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                cache[key] = (nil, nil)
                return (nil, nil)
            }
            if let ct = http.value(forHTTPHeaderField: "Content-Type"),
               !ct.lowercased().contains("application/json") {
                cache[key] = (nil, nil)
                return (nil, nil)
            }

            let pois = (try? JSONDecoder().decode([POI].self, from: data)) ?? []
            guard let first = pois.first else {
                cache[key] = (nil, nil)
                return (nil, nil)
            }

            let usage = first.UsageCost?.trimmingCharacters(in: .whitespacesAndNewlines)
            let maxKW = first.Connections?.compactMap { $0.PowerKW }.max()
            let normalized = Self.normalizeCost(usage, assumedKW: maxKW)

            cache[key] = (normalized.pricePerKWh, normalized.display)
            return (normalized.pricePerKWh, normalized.display)
        } catch {
            cache[key] = (nil, nil)
            return (nil, nil)
        }
    }

    // Parse a variety of pricing formats and (if needed) estimate $/kWh from $/min.
    private static func normalizeCost(_ text: String?, assumedKW: Double?) -> (pricePerKWh: Double?, display: String?) {
        guard let t = text, !t.isEmpty else { return (nil, nil) }

        if let direct = firstDouble(in: t, patterns: [
            "\\$([0-9]*\\.?[0-9]+)\\s*/\\s*kwh",
            "\\$([0-9]*\\.?[0-9]+)\\s*per\\s*kwh"
        ]) {
            return (direct, t)
        }

        if let cents = firstDouble(in: t, patterns: [
            "([0-9]*\\.?[0-9]+)\\s*¢\\s*/\\s*kwh",
            "([0-9]*\\.?[0-9]+)\\s*cents\\s*per\\s*kwh"
        ]) {
            return (cents / 100.0, t)
        }

        if let perMin = firstDouble(in: t, patterns: [
            "\\$([0-9]*\\.?[0-9]+)\\s*/\\s*(?:min|minute)",
            "\\$([0-9]*\\.?[0-9]+)\\s*per\\s*(?:min|minute)"
        ]) {
            let kw = assumedKW ?? guessKW(from: t)
            if kw > 0 {
                let perKWh = (perMin * 60.0) / kw
                return (perKWh, t + " (≈ $" + String(format: "%.2f", perKWh) + "/kWh)")
            }
        }

        return (nil, t)
    }

    private static func firstDouble(in s: String, patterns: [String]) -> Double? {
        for p in patterns {
            if let v = firstCapturedDouble(p, in: s) { return v }
        }
        return nil
    }

    private static func firstCapturedDouble(_ pattern: String, in s: String) -> Double? {
        do {
            let re = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(s.startIndex..<s.endIndex, in: s)
            if let m = re.firstMatch(in: s, options: [], range: range),
               m.numberOfRanges >= 2,
               let r = Range(m.range(at: 1), in: s) {
                return Double(s[r].replacingOccurrences(of: ",", with: ""))
            }
        } catch {
            return nil
        }
        return nil
    }

    private static func guessKW(from s: String) -> Double {
        let lower = s.lowercased()
        if ["supercharger", "dcfc", "dc fast", "electrify america", "ea"].contains(where: { lower.contains($0) }) {
            return 100.0
        }
        return 7.2
    }
}

// MARK: - View Model

private struct ChargerVM: Identifiable, Equatable {
    let mapItem: MKMapItem
    var distanceMeters: CLLocationDistance = .infinity
    var pricePerKWh: Double?
    var usageCostText: String?
    var providerName: String

    var coordinate: CLLocationCoordinate2D { mapItem.compatCoordinate }
    var title: String { mapItem.name ?? "EV Charger" }

    var id: String {
        // Stable enough for selection + row identity
        coordKey(coordinate, precision: 5) + "|" + (mapItem.name ?? "EV Charger")
    }

    var subtitleLine: String {
        if let p = pricePerKWh { return String(format: "$%.2f / kWh", p) }
        return usageCostText ?? "Price: Unknown"
    }
}

// MARK: - Main View

@MainActor
struct CheapestChargerShift: View {
    // Services
    @StateObject private var locationProvider = BuiltInLocationProvider()
    private let discovery = AppleMapsDiscovery()
    private let ocm = OCMPriceService()

    // UI State
    @State private var camera: MapCameraPosition = .automatic
    @State private var radius: SearchRadius = .r25
    @State private var isLoading = false

    @State private var errorMessage: String?
    @State private var showErrorAlert = false

    @State private var sites: [ChargerVM] = []
    @State private var selectedID: ChargerVM.ID? = nil

    // Debounce / cancel
    @State private var radiusChangeTask: Task<Void, Never>?
    @State private var searchTask: Task<Void, Never>?
    @State private var lastQueryKey: String?

    // Tuning
    private let searchLimit = 60
    private let renderLimit = 25
    private let annotationLimit = 50
    private let ocmEnrichLimit = 35

    var body: some View {
        VStack(spacing: 0) {
            headerControls
            mapSection
            listSection
        }
        .overlay(overlayLoading)
        .alert("Error", isPresented: $showErrorAlert, actions: {
            Button("OK", role: .cancel) { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "Unknown error")
        })
        .task(id: radius) {
            radiusChangeTask?.cancel()
            radiusChangeTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                startSearch()
            }
        }
        .onAppear { locationProvider.request() }
        .onChange(of: locationProvider.location) { _, _ in startSearch() }
        .onChange(of: locationProvider.error) { _, newValue in
            if let msg = newValue, !msg.isEmpty {
                errorMessage = msg
                showErrorAlert = true
            }
        }
        .navigationTitle("Cheapest Nearby Charger")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - UI Sections

    private var headerControls: some View {
        HStack(spacing: 12) {
            Picker("Radius", selection: $radius) {
                ForEach(SearchRadius.allCases) { r in
                    Text(r.label(locale: .current)).tag(r)
                }
            }
            .pickerStyle(.segmented)

            Spacer(minLength: 8)

            Button {
                startSearch(force: true)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)
            .accessibilityLabel("Refresh chargers")
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var mapSection: some View {
        Map(position: $camera, selection: $selectedID) {
            UserAnnotation()

            ForEach(Array(sites.prefix(annotationLimit))) { site in
                Annotation(site.title, coordinate: site.coordinate) {
                    ZStack {
                        Circle()
                            .fill(.background)
                            .frame(width: 34, height: 34)
                            .shadow(radius: 2)
                        Image(systemName: "bolt.circle.fill")
                            .imageScale(.large)
                            .foregroundStyle(.tint)
                    }
                }
                .tag(site.id)
            }
        }
        .mapControls {
            MapCompass()
            MapPitchToggle()
            MapScaleView()
            MapUserLocationButton()
        }
        .frame(height: 300)
        .onChange(of: selectedID) { _, newValue in
            guard let id = newValue,
                  let s = sites.first(where: { $0.id == id }) else { return }
            camera = .region(.init(center: s.coordinate,
                                   latitudinalMeters: 3_000,
                                   longitudinalMeters: 3_000))
        }
        .onChange(of: radius) { _, r in
            if let loc = locationProvider.location {
                let d = r.meters(locale: .current)
                camera = .region(.init(center: loc.coordinate,
                                       latitudinalMeters: d * 1.2,
                                       longitudinalMeters: d * 1.2))
            }
        }
    }

    private var listSection: some View {
        List {
            Section {
                if sites.isEmpty && !isLoading {
                    if let e = errorMessage, !e.isEmpty {
                        ContentUnavailableView(
                            "Couldn’t load chargers",
                            systemImage: "exclamationmark.triangle",
                            description: Text(e)
                        )
                    } else if locationProvider.authorization == .denied || locationProvider.authorization == .restricted {
                        ContentUnavailableView(
                            "Location Permission Needed",
                            systemImage: "location.slash",
                            description: Text("Enable location access in Settings to find nearby chargers.")
                        )
                    } else {
                        ContentUnavailableView(
                            "No chargers found",
                            systemImage: "bolt.slash",
                            description: Text("Try a larger radius or tap Refresh.")
                        )
                    }
                }

                ForEach(Array(sites.prefix(renderLimit))) { site in
                    chargerRow(site)
                }
            } footer: {
                Text("Prices are estimates from Open Charge Map and may vary by plan, time, power tier, idle fees, and taxes. Verify in the provider’s app or at the station.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func chargerRow(_ site: ChargerVM) -> some View {
        let here = locationProvider.location
        let distText = formatDistance(site.distanceMeters, locale: .current)

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 6) {
                Text(site.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let p = site.pricePerKWh {
                        Label(String(format: "$%.2f/kWh", p), systemImage: "dollarsign.circle")
                    } else {
                        Label(site.usageCostText ?? "Price: Unknown", systemImage: "questionmark.circle")
                    }

                    Label(distText, systemImage: "location")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let addr = site.mapItem.compatFullAddress {
                    Text(addr)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    Button { openInMaps(site) } label: {
                        Label("Navigate", systemImage: "car.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Button {
                        selectedID = site.id
                        camera = .region(.init(center: site.coordinate,
                                               latitudinalMeters: 2_000,
                                               longitudinalMeters: 2_000))
                    } label: {
                        Label("Show on Map", systemImage: "map")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 2)

                // tiny helper (optional)
                if let here, site.distanceMeters.isFinite, site.distanceMeters > 0 {
                    let _ = here // just clarifies intent (no-op)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var overlayLoading: some View {
        Group {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.05).ignoresSafeArea()
                    ProgressView("Finding chargers…")
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Actions

    private func openInMaps(_ site: ChargerVM) {
        site.mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func startSearch(force: Bool = false) {
        searchTask?.cancel()
        searchTask = Task { await runSearch(force: force) }
    }

    private func runSearch(force: Bool = false) async {
        guard let loc = locationProvider.location else {
            if force { locationProvider.refresh() }
            return
        }

        // Avoid hammering if nothing materially changed
        let key = "\(coordKey(loc.coordinate, precision: 4))|\(radius.rawValue)|\(searchLimit)"
        if !force, lastQueryKey == key, !sites.isEmpty { return }
        lastQueryKey = key

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // 1) Discover chargers (Apple Maps)
        let items = await discovery.discoverEVChargers(
            center: loc.coordinate,
            radiusMeters: radius.meters(locale: .current),
            limit: searchLimit
        )
        if Task.isCancelled { return }

        // 2) Map to VMs + compute distance
        var vms: [ChargerVM] = items.map { item in
            var vm = ChargerVM(
                mapItem: item,
                distanceMeters: .infinity,
                pricePerKWh: nil,
                usageCostText: nil,
                providerName: nmGuessProvider(from: item.name, fallback: "Charger")
            )
            vm.distanceMeters = distance(from: loc, to: vm.coordinate)
            return vm
        }
        .sorted { $0.distanceMeters < $1.distanceMeters }

        if Task.isCancelled { return }

        // 3) Enrich with OCM (best-effort) — limit to keep network reasonable
        let enrichCount = min(ocmEnrichLimit, vms.count)

        await withTaskGroup(of: (Int, Double?, String?).self) { group in
            for idx in 0..<enrichCount {
                let coord = vms[idx].coordinate
                group.addTask {
                    if Task.isCancelled { return (idx, nil, nil) }
                    let (price, text) = await ocm.priceNear(coord)
                    return (idx, price, text)
                }
            }

            for await (idx, price, text) in group {
                if Task.isCancelled { return }
                guard vms.indices.contains(idx) else { continue }
                vms[idx].pricePerKWh = price
                vms[idx].usageCostText = text
            }
        }

        if Task.isCancelled { return }

        // 4) Sort: priced first by $/kWh, then distance; unpriced last by distance
        vms.sort { a, b in
            switch (a.pricePerKWh, b.pricePerKWh) {
            case let (pa?, pb?):
                if pa == pb { return a.distanceMeters < b.distanceMeters }
                return pa < pb
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.distanceMeters < b.distanceMeters
            }
        }

        // 5) Initialize camera if needed
        if case .automatic = camera {
            let d = radius.meters(locale: .current)
            camera = .region(.init(center: loc.coordinate,
                                   latitudinalMeters: d * 1.2,
                                   longitudinalMeters: d * 1.2))
        }

        sites = vms
        // selection might be stale after refresh
        if let sel = selectedID, !sites.contains(where: { $0.id == sel }) {
            selectedID = nil
        }

        if vms.isEmpty {
            errorMessage = "No chargers found within the selected radius."
            showErrorAlert = true
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CheapestChargerShift_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { CheapestChargerShift() }
    }
}
#endif
