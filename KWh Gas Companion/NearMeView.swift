//
//  NearMeView.swift
//  My KWh Companion
//
//  Swift 6 • iOS 17+
//
//  - Debounced, cancellable MKLocalSearch
//  - Token-guarded result application
//  - Strong de-dup
//  - Performance guards: capped annotations + paged list + height limit
//  - Safe-area aware UI (no out-of-bounds on modern devices)
//
//  Fixes included:
//  ✅ NMSite Equatable/Sendable issues (stores lat/lon as Double; computed coordinate)
//  ✅ UIKit import for haptics
//  ✅ Keeps your overall structure intact
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit

// MARK: - Providers

fileprivate enum NMProvider: String, CaseIterable, Identifiable, Sendable {
    case tesla, electrifyAmerica, evgo, chargePoint, other
    var id: String { rawValue }

    var title: String {
        switch self {
        case .tesla: return "Tesla"
        case .electrifyAmerica: return "Electrify America"
        case .evgo: return "EVgo"
        case .chargePoint: return "ChargePoint"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .tesla: return "bolt.car"
        case .electrifyAmerica: return "leaf.circle"
        case .evgo: return "bolt.badge.clock"
        case .chargePoint: return "battery.100.bolt"
        case .other: return "mappin.and.ellipse"
        }
    }
}

// MARK: - Site model
// NOTE: We store lat/lon as Doubles so the model is Hashable/Sendable and Equatable works.
// CLLocationCoordinate2D is a framework type that can cause strict-concurrency + Equatable pain in Swift 6.

fileprivate struct NMSite: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let provider: NMProvider
    let latitude: Double
    let longitude: Double
    let subtitle: String?
    let url: URL?
    var priceNote: String? = nil

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        id: UUID = UUID(),
        name: String,
        provider: NMProvider,
        coordinate: CLLocationCoordinate2D,
        subtitle: String?,
        url: URL?
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.subtitle = subtitle
        self.url = url
    }
}

// MARK: - Location service

fileprivate final class NMLocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authorization: CLAuthorizationStatus = .notDetermined
    @Published var location: CLLocation? = nil

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
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let latest = locations.last {
            location = latest
            // reduces jitter / repeated searches on some devices
            manager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silent; UI shows friendly message if needed
    }
}

// MARK: - Helpers

fileprivate func nmGuessProvider(from name: String?, fallback: NMProvider) -> NMProvider {
    let n = (name ?? "").lowercased()
    if n.contains("tesla") { return .tesla }
    if n.contains("electrify america") || n.contains("ea ") { return .electrifyAmerica }
    if n.contains("evgo") { return .evgo }
    if n.contains("chargepoint") || n.contains("charge point") { return .chargePoint }
    return fallback
}

// MARK: - View

@MainActor
public struct NearMeView: View {
    public init() {}

    // Search source toggle
    private let useAppleLocalSearch = true
    private var externalSites: [NMSite] { [] }

    // PERF GUARDS
    private let maxAnnotations = 80
    private let maxSites = 200
    private let initialPage = 5
    private let pageStep = 5

    @State private var camera: MapCameraPosition = .automatic
    @State private var selection: UUID? = nil
    @State private var didSetInitialRegion = false

    // minimization
    @State private var filtersMinimized = false
    @State private var listMinimized = false

    @State private var isFiltersOpen = true
    @State private var isNearbyOpen = true

    @AppStorage("near.radius.mi") private var radiusMiles: Double = 25
    @AppStorage("near.show.tesla") private var showTesla = true
    @AppStorage("near.show.ea") private var showEA = true
    @AppStorage("near.show.evgo") private var showEVgo = true
    @AppStorage("near.show.cp") private var showChargePoint = true
    @AppStorage("near.show.other") private var showOther = true

    @StateObject private var loc = NMLocationService()

    // Search state
    @State private var sites: [NMSite] = []
    @State private var isSearching = false
    @State private var userMessage: String? = nil
    @State private var pendingSearch: Task<Void, Never>? = nil
    @State private var activeSearchID = UUID()

    // Paging state
    @State private var pageSize: Int = 5

    public var body: some View {
        GeometryReader { geo in
            let maxListHeight = min(420, geo.size.height * 0.42)

            ZStack {
                mapLayer

                Color.clear
                    .safeAreaInset(edge: .top, spacing: 8) {
                        chipsOverlay
                            .padding(.horizontal, 10)
                            .padding(.top, 6)
                    }

                Color.clear
                    .safeAreaInset(edge: .bottom, spacing: 10) {
                        VStack(spacing: 10) {
                            filtersDock
                            nearbyDock(maxListHeight: maxListHeight)
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 6)
                    }
            }
        }
        .navigationTitle("Near Me")
        .navigationBarTitleDisplayMode(.inline)
        .task { loc.request() }
        .task(id: searchTriggerToken) { resetPagingAndScheduleSearch() }
        .onReceive(loc.$location) { location in
            guard let c = location?.coordinate else { return }
            if !didSetInitialRegion {
                let span = spanForRadiusMiles(radiusMiles, at: c.latitude)
                camera = .region(.init(center: c, span: span))
                didSetInitialRegion = true
            }
            resetPagingAndScheduleSearch()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: filtersMinimized)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: listMinimized)
    }

    // MARK: Map

    private var mapLayer: some View {
        Map(position: $camera, selection: $selection) {
            if loc.location != nil { UserAnnotation() }

            ForEach(cappedAnnotations) { site in
                Annotation(site.name, coordinate: site.coordinate) {
                    NMSitePin(provider: site.provider)
                }
                .annotationTitles(.hidden)
                .tag(site.id)
            }
        }
        .mapControls { MapUserLocationButton(); MapCompass() }
        .overlay(alignment: .topTrailing) {
            if isSearching {
                ProgressView()
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .padding(.trailing, 8)
            }
        }
        .ignoresSafeArea()
    }

    private var cappedAnnotations: [NMSite] {
        Array(filteredSites.prefix(maxAnnotations))
    }

    // MARK: Chips

    private var chipsOverlay: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(.tesla, isOn: $showTesla)
                chip(.electrifyAmerica, isOn: $showEA)
                chip(.evgo, isOn: $showEVgo)
                chip(.chargePoint, isOn: $showChargePoint)
                chip(.other, isOn: $showOther)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private func chip(_ provider: NMProvider, isOn: Binding<Bool>) -> some View {
        let on = isOn.wrappedValue
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.snappy) { isOn.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: provider.symbol).font(.system(size: 15, weight: .semibold))
                Text(provider.title).font(.callout.weight(.medium))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(on ? Color.accentColor : Color.secondary.opacity(0.25))
            .foregroundStyle(on ? .white : .primary)
            .clipShape(Capsule())
            .overlay { Capsule().stroke(.white.opacity(0.22)) }
        }
        .buttonStyle(.plain)
    }

    // MARK: Docks

    private var filtersDock: some View {
        Group {
            if filtersMinimized { minimizedFilters } else { filtersPanel }
        }
    }

    private func nearbyDock(maxListHeight: CGFloat) -> some View {
        Group {
            if listMinimized { minimizedNearby } else { nearbyList(maxListHeight: maxListHeight) }
        }
    }

    // MARK: Filters

    private var filtersPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Filters").font(.headline)
                Spacer()

                Button {
                    withAnimation(.snappy) { isFiltersOpen.toggle() }
                } label: {
                    Image(systemName: isFiltersOpen ? "chevron.down" : "chevron.up")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring) { filtersMinimized = true }
                } label: {
                    Image(systemName: "rectangle.compress.vertical")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Minimize filters")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if isFiltersOpen {
                VStack(spacing: 12) {
                    VStack(spacing: 10) {
                        providerRow("Tesla", icon: "bolt.car", isOn: $showTesla)
                        providerRow("Electrify America", icon: "leaf.circle", isOn: $showEA)
                        providerRow("EVgo", icon: "bolt.badge.clock", isOn: $showEVgo)
                        providerRow("ChargePoint", icon: "battery.100.bolt", isOn: $showChargePoint)
                        providerRow("Other", icon: "mappin.and.ellipse", isOn: $showOther)
                    }

                    HStack(spacing: 12) {
                        Button("All") { setAll(true) }.buttonStyle(.bordered)
                        Button("None") { setAll(false) }.buttonStyle(.bordered)
                        Spacer()
                        Button {
                            loc.request()
                        } label: {
                            Label("Refresh", systemImage: "location.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 12)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Search Radius")
                            Spacer()
                            Text("\(Int(radiusMiles)) mi")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)

                        Slider(value: $radiusMiles, in: 5...150, step: 5)
                            .onChange(of: radiusMiles) {
                                if let c = loc.location?.coordinate {
                                    let span = spanForRadiusMiles(radiusMiles, at: c.latitude)
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        camera = .region(.init(center: c, span: span))
                                    }
                                }
                                resetPagingAndScheduleSearch()
                            }
                            .padding(.horizontal, 12)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use toggles + radius to control which networks appear. Settings are remembered on this device.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Stations are discovered live using Apple Maps near your location.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08)) }
    }

    private func providerRow(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
        }
        .padding(.horizontal, 12)
    }

    private func setAll(_ value: Bool) {
        withAnimation(.snappy) {
            showTesla = value
            showEA = value
            showEVgo = value
            showChargePoint = value
            showOther = value
        }
        resetPagingAndScheduleSearch()
    }

    private var minimizedFilters: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle").imageScale(.large)
            Text("Filters").font(.headline)
            Spacer()
            let enabled = [showTesla, showEA, showEVgo, showChargePoint, showOther].filter { $0 }.count
            Text("\(enabled) on").font(.subheadline).foregroundStyle(.secondary)
            Image(systemName: "chevron.up").imageScale(.medium)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08)))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.spring) { filtersMinimized = false } }
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Nearby

    private func nearbyList(maxListHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(isExpanded: $isNearbyOpen) {
                if let message = userMessage {
                    Text(message).foregroundStyle(.secondary).padding(.vertical, 4)
                }

                if pagedSites.isEmpty && isSearching {
                    HStack { ProgressView(); Text("Searching…").foregroundStyle(.secondary) }
                        .padding(.vertical, 4)
                } else if pagedSites.isEmpty && userMessage == nil {
                    Text(loc.authorization == .denied
                         ? "Location is off. Enable it in Settings to find nearby chargers."
                         : "No sites found in the current radius.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                } else {
                    Text("Tap a row to center the map. Use the arrow for Apple Maps directions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 6)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(pagedSites) { site in
                                siteRow(site)
                                Divider().opacity(0.2)
                            }

                            if pageSize < cappedSites.count {
                                Button {
                                    withAnimation(.snappy) {
                                        pageSize = min(pageSize + pageStep, cappedSites.count)
                                    }
                                } label: {
                                    Text("Show \(min(pageStep, cappedSites.count - pageSize)) more")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: maxListHeight)
                }
            } label: {
                HStack {
                    Text("Nearby Sites").font(.headline)
                    Spacer()
                    Text("\(min(pagedSites.count, cappedSites.count)) of \(cappedSites.count) • \(Int(radiusMiles)) mi")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        withAnimation(.spring) { listMinimized = true }
                    } label: {
                        Image(systemName: "rectangle.compress.vertical")
                            .imageScale(.medium)
                            .padding(.leading, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08)) }
    }

    private var minimizedNearby: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill").opacity(0.75)
            Text(nearbySummaryLine).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "chevron.up").imageScale(.medium)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08)))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.spring) { listMinimized = false } }
        .accessibilityAddTraits(.isButton)
    }

    private var nearbySummaryLine: String {
        let total = cappedSites.count
        if let here = loc.location, let first = filteredSites.first {
            let d = here.distance(from: CLLocation(latitude: first.latitude, longitude: first.longitude))
            return "\(total) sites • closest \(formatMiles(d))"
        }
        return "\(total) sites nearby"
    }

    private func siteRow(_ site: NMSite) -> some View {
        let here = loc.location
        let distMeters = here.map {
            $0.distance(from: CLLocation(latitude: site.latitude, longitude: site.longitude))
        }

        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            NMSitePin(provider: site.provider).frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(site.name).font(.headline)
                HStack(spacing: 6) {
                    Text(site.provider.title).foregroundStyle(.secondary)
                    if let sub = site.subtitle, !sub.isEmpty {
                        Text("•").foregroundStyle(.secondary)
                        Text(sub).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .font(.caption)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let d = distMeters {
                    Text(formatMiles(d)).font(.subheadline).monospacedDigit()
                } else {
                    Text("—").font(.subheadline).foregroundStyle(.secondary)
                }

                Button { openInMaps(site) } label: {
                    Image(systemName: "arrow.triangle.turn.up.right.circle")
                }
                .buttonStyle(.plain)
                .font(.title3)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = site.id
                camera = .region(.init(center: site.coordinate,
                                       span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)))
            }
        }
    }

    // MARK: Filtering / Derived

    private var allowedProviders: Set<NMProvider> {
        [
            showTesla ? .tesla : nil,
            showEA ? .electrifyAmerica : nil,
            showEVgo ? .evgo : nil,
            showChargePoint ? .chargePoint : nil,
            showOther ? .other : nil
        ]
        .compactMap { $0 }
        .reduce(into: Set<NMProvider>()) { $0.insert($1) }
    }

    private var filteredSites: [NMSite] {
        let base = sites.filter { allowedProviders.contains($0.provider) }
        guard let here = loc.location else { return base }
        return base.sorted {
            let d0 = here.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
            let d1 = here.distance(from: CLLocation(latitude: $1.latitude, longitude: $1.longitude))
            return d0 < d1
        }
    }

    private var cappedSites: [NMSite] { Array(filteredSites.prefix(maxSites)) }
    private var pagedSites: [NMSite] { Array(cappedSites.prefix(pageSize)) }

    private var searchTriggerToken: String {
        [
            "\(Int(radiusMiles))",
            showTesla.description,
            showEA.description,
            showEVgo.description,
            showChargePoint.description,
            showOther.description
        ].joined(separator: "|")
    }

    // MARK: Search

    private func resetPagingAndScheduleSearch() {
        pageSize = initialPage
        pendingSearch?.cancel()
        pendingSearch = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            await runSearch()
        }
    }

    private func runSearch() async {
        guard useAppleLocalSearch else {
            sites = externalSites
            userMessage = nil
            return
        }
        guard let center = loc.location?.coordinate else { return }

        isSearching = true
        userMessage = nil
        let searchID = UUID()
        activeSearchID = searchID

        do {
            let region = MKCoordinateRegion(center: center, span: spanForRadiusMiles(radiusMiles, at: center.latitude))
            let queries: [(NMProvider, String)] = [
                (.tesla, "Tesla Supercharger"),
                (.electrifyAmerica, "Electrify America"),
                (.evgo, "EVgo"),
                (.chargePoint, "ChargePoint"),
                (.other, "EV charger")
            ]

            var all: [NMSite] = []
            try await withThrowingTaskGroup(of: [NMSite].self) { group in
                for (prov, q) in queries {
                    group.addTask {
                        let req = MKLocalSearch.Request()
                        req.naturalLanguageQuery = q
                        req.region = region
                        let resp = try await MKLocalSearch(request: req).start()
                        return resp.mapItems.compactMap { item in
                            guard let coord = item.placemark.location?.coordinate else { return nil }
                            return NMSite(
                                name: item.name ?? prov.title,
                                provider: nmGuessProvider(from: item.name, fallback: prov),
                                coordinate: coord,
                                subtitle: item.placemark.title,
                                url: item.url
                            )
                        }
                    }
                }
                for try await chunk in group { all += chunk }
            }

            if let here = loc.location {
                all = all.filter {
                    here.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
                    <= radiusMiles * 1609.34
                }
            }

            let unique = Array(dedupSites(all).prefix(maxSites))

            if activeSearchID == searchID {
                sites = unique
                isSearching = false
                userMessage = unique.isEmpty ? "No sites found in the current radius." : nil
                pageSize = min(initialPage, unique.count)
            }
        } catch {
            if activeSearchID == searchID {
                isSearching = false
                if sites.isEmpty { userMessage = "Search is temporarily unavailable. Try again in a moment." }
            }
        }
    }

    private func dedupSites(_ input: [NMSite]) -> [NMSite] {
        var out: [NMSite] = []
        let proximity: CLLocationDistance = 120

        for s in input {
            let already = out.contains(where: { existing in
                let n0 = existing.name.lowercased()
                let n1 = s.name.lowercased()
                let a0 = (existing.subtitle ?? "").lowercased()
                let a1 = (s.subtitle ?? "").lowercased()

                let nameClose = !n0.isEmpty && (n0 == n1 || n0.contains(n1) || n1.contains(n0))
                let addrClose = !a0.isEmpty && (a0 == a1 || a0.contains(a1) || a1.contains(a0))

                guard nameClose || addrClose else { return false }

                let d = CLLocation(latitude: existing.latitude, longitude: existing.longitude)
                    .distance(from: CLLocation(latitude: s.latitude, longitude: s.longitude))
                return d <= proximity
            })

            if !already { out.append(s) }
        }
        return out
    }

    // MARK: Helpers

    private func spanForRadiusMiles(_ miles: Double, at latitude: CLLocationDegrees) -> MKCoordinateSpan {
        let latDelta = miles / 69.0
        let lonDelta = miles / (69.0 * max(0.2, cos(latitude * .pi / 180)))
        return MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
    }

    private func formatMiles(_ meters: CLLocationDistance) -> String {
        let miles = meters / 1609.34
        return miles < 10 ? String(format: "%.1f mi", miles) : "\(Int(round(miles))) mi"
    }

    private func openInMaps(_ site: NMSite) {
        let placemark = MKPlacemark(coordinate: site.coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = site.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

// MARK: - Pin View

fileprivate struct NMSitePin: View {
    let provider: NMProvider

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: 34, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(0.25))
                )

            Image(systemName: provider.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(radius: 1)
                .padding(2)
                .background(
                    Circle()
                        .fill(color(for: provider))
                        .frame(width: 22, height: 22)
                )
        }
    }

    private func color(for p: NMProvider) -> Color {
        switch p {
        case .tesla: return .red
        case .electrifyAmerica: return .green
        case .evgo: return .blue
        case .chargePoint: return .orange
        case .other: return .gray
        }
    }
}

#if DEBUG
#Preview { NavigationStack { NearMeView() } }
#endif
