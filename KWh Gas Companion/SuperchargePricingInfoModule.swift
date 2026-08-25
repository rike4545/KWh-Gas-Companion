//   • SuperchargePricingInfoStore.swift
//
//  Reliability-first approach:
//  - Nearby stations & accurate names/coords from Apple Maps (MapKit).
//  - Hard radius filter (default 50 miles / ~80 km).
//  - Optional Tesla "Find Us" directory scrape to attach official station detail URLs.
//  - Tap the station NAME (when an official Tesla URL exists) to open a detail sheet.
//  - Detail sheet scrapes that one Tesla page and shows:
//      • "Pricing for Tesla" formatted as $XX.XX/kWh
//
//  DISCLAIMER
//  - Not affiliated with Tesla.
//  - Tesla may block automated requests (403/101), rate-limit, or not show numeric pricing.
//  - Always confirm pricing in the Tesla app / vehicle UI.
//  - United States only.
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import CoreLocation
import MapKit
import Foundation
import UIKit

// MARK: - Public View

@MainActor
public struct SuperchargeInfoNearMeView: View {

    public enum InitialTab: String, CaseIterable, Identifiable {
        case directory
        case pricing
        public var id: String { rawValue }
    }

    public enum UnitMode: String, CaseIterable, Identifiable {
        case miles
        case kilometers
        public var id: String { rawValue }
    }

    public init(initialTab: InitialTab = .directory) {
        _tab = State(initialValue: initialTab)
    }

    @Environment(\.openURL) private var openURL
    @Environment(\.appThemeBox) private var themeBox

    @EnvironmentObject private var store: SuperchargePricingInfoStore
    @StateObject private var locator = SPINearMeLocationManager()

    @State private var tab: InitialTab
    @State private var filterText: String = ""
    @State private var unitMode: UnitMode = .miles
    @State private var radiusPreset: RadiusPreset = .p50
    @State private var selectedForDetail: TeslaNearbySite?

    private var theme: any AppThemeSpec { themeBox.base }
    private var card: Color { theme.cardBackground }
    private var cardAlt: Color { theme.cardBackground.opacity(0.78) }
    private var stroke: Color { theme.separator.opacity(0.7) }
    private var accent: Color { theme.accent }
    private var pill: Color { theme.pillTint }
    private var destructive: Color { .red }

    public var body: some View {
        ZStack {
            Rectangle().fill(theme.screenBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header

                List {
                    statusSection
                    actionsSection
                    nearbySection
                    disclaimerSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .tint(accent)
        .task {
            locator.ensureAuthorization()
            await store.bootstrapIfNeeded()
            await refreshNearbyIfPossible(force: true)
        }
        .onChange(of: locator.location) { _, _ in
            Task { await refreshNearbyIfPossible(force: true) }
        }
        .onChange(of: radiusPreset) { _, _ in
            Task { await refreshNearbyIfPossible(force: true) }
        }
        .sheet(item: $selectedForDetail) { site in
            TeslaSuperchargerDetailSheet(site: site)
                .environmentObject(store)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Superchargers Near Me")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("United States")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                }
                Spacer()
                Picker("", selection: $tab) {
                    Text("Directory").tag(InitialTab.directory)
                    Text("Pricing").tag(InitialTab.pricing)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)

                TextField("Search by name, city, state…", text: $filterText)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)

                Spacer()

                Menu {
                    Picker("Units", selection: $unitMode) {
                        Text("Miles").tag(UnitMode.miles)
                        Text("Kilometers").tag(UnitMode.kilometers)
                    }
                    Picker("Radius", selection: $radiusPreset) {
                        Text("50 mi / 80 km").tag(RadiusPreset.p50)
                        Text("25 mi / 40 km").tag(RadiusPreset.p25)
                        Text("100 mi / 160 km").tag(RadiusPreset.p100)
                    }
                    Divider()
                    Button { Task { await refreshNearbyIfPossible(force: true) } } label: {
                        Label("Refresh nearby list", systemImage: "arrow.clockwise")
                    }
                    Button { Task { await store.loadDirectoryIfNeeded(force: true) } } label: {
                        Label("Reload Tesla directory (links)", systemImage: "link")
                    }
                } label: {
                    Label("Options", systemImage: "slider.horizontal.3")
                        .foregroundStyle(accent)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(card)
            .overlay(
                RoundedRectangle(cornerRadius: theme.smallCorner, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.smallCorner, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private var statusSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {

                if let e = store.lastError.trimmedNonEmpty {
                    Label(e, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(destructive)
                        .font(.subheadline)

                    Button("Open Tesla Find Us") {
                        openURL(store.directoryURL)
                    }
                    .font(.subheadline.weight(.semibold))
                }

                HStack {
                    Label("Nearby: \(store.nearby.count)", systemImage: "location.fill")
                    Spacer()
                    Label("Directory links: \(store.directoryCount)", systemImage: "link")
                }
                .foregroundStyle(.primary)

                Group {
                    if let hr = store.homeResidentialRate {
                        HStack {
                            Label("Home avg (residential • \(hr.stateAbbrev))", systemImage: "house.fill")
                            Spacer()
                            Text(hr.usdPerKwhText)
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                        }
                        .foregroundStyle(.primary)

                        Text("Source: EIA state average (\(hr.asOf)).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let he = store.homeResidentialRateError.trimmedNonEmpty {
                        Text(he)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if store.isBusy {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: store.progress.fraction, total: 1.0)
                        Text(store.progress.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: { Text("Status") }
    }

    private var actionsSection: some View {
        Section {
            ActionGrid {
                ActionTile(title: "Refresh nearby", icon: "location.circle", tint: accent) {
                    Task { await refreshNearbyIfPossible(force: true) }
                }
                .disabled(store.isBusy || locator.location == nil)

                ActionTile(title: "Load Tesla links", icon: "link", tint: accent) {
                    Task { await store.loadDirectoryIfNeeded(force: true) }
                }
                .disabled(store.isBusy)

                ActionTile(title: "Refresh prices", icon: "dollarsign.circle", tint: accent) {
                    Task { await store.refreshPricesForNearby() }
                }
                .disabled(store.isBusy || tab != .pricing || store.nearby.isEmpty)
            }

            HStack {
                Button { store.cancelWork() } label: { Label("Cancel", systemImage: "xmark.circle") }
                    .buttonStyle(.bordered)
                    .tint(destructive)
                    .disabled(!store.isBusy)

                Spacer()

                Text(radiusPreset.displayText(unitMode: unitMode))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        } header: { Text("Actions") }
        footer: {
            Text("Tap a station name (when available) to see Tesla details and “Pricing for Tesla” as $XX.XX/kWh.")
        }
    }

    private var nearbySection: some View {
        Section {
            let shown = filteredNearby()

            if locator.location == nil {
                Text("Enable Location Services to see nearby Superchargers.")
                    .foregroundStyle(.secondary)
            } else if shown.isEmpty {
                Text("No stations found in this radius.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(shown) { site in
                    NearbyCard(
                        site: site,
                        distanceText: locator.location.map { store.distanceString(from: $0, to: site, unitMode: unitMode) },
                        priceText: tab == .pricing ? store.pricingSummary(for: site) : nil,
                        homeCompareText: tab == .pricing ? store.homeVsSuperchargerSummary(for: site) : nil,
                        showPrice: tab == .pricing,
                        pillTint: pill,
                        card: card,
                        cardAlt: cardAlt,
                        stroke: stroke,
                        accent: accent,
                        destructive: destructive,
                        onTapName: {
                            guard site.detailURL != nil else { return }
                            selectedForDetail = site
                        },
                        onApple: { if let url = store.appleMapsURL(for: site) { openURL(url) } },
                        onGoogle: { if let url = store.googleMapsURL(for: site) { openURL(url) } },
                        onTesla: { if let url = site.detailURL { openURL(url) } },
                        onRefresh: { Task { await store.refreshPrice(for: site.id) } }
                    )
                }
            }
        } header: { Text("Nearby") }
    }

    private var disclaimerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Reliability disclaimer")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("""
Nearby stations come from Apple Maps (MapKit) within a fixed radius. Tesla “Find Us” pages are used only to attach official links and attempt pricing extraction. Tesla may block automated requests (403/101) or not show numeric prices publicly.

Always confirm pricing in the Tesla app or vehicle UI. Not affiliated with Tesla. United States only.
""")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func filteredNearby() -> [TeslaNearbySite] {
        var items = store.nearby
        let q = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty { items = items.filter { $0.searchBlob.localizedCaseInsensitiveContains(q) } }
        if let here = locator.location {
            items.sort { store.distance(from: here, to: $0) < store.distance(from: here, to: $1) }
        } else {
            items.sort { $0.displayName < $1.displayName }
        }
        return items
    }

    private func refreshNearbyIfPossible(force: Bool) async {
    guard let loc = locator.location else { return }

    // Update home (residential) average first — used for price comparisons.
    async let _ = store.updateHomeResidentialRate(for: loc)

    await store.refreshNearby(center: loc.coordinate, radiusMeters: radiusPreset.meters(), force: force)
}

    private enum RadiusPreset: String, CaseIterable, Identifiable {
        case p25, p50, p100
        var id: String { rawValue }

        func meters() -> Double {
            let miles: Double
            switch self {
            case .p25: miles = 25
            case .p50: miles = 50
            case .p100: miles = 100
            }
            return miles * 1609.344
        }

        func displayText(unitMode: UnitMode) -> String {
            let miles: Double
            switch self {
            case .p25: miles = 25
            case .p50: miles = 50
            case .p100: miles = 100
            }
            if unitMode == .kilometers {
                let km = miles * 1.609344
                return String(format: "%.0f km", km)
            } else {
                return String(format: "%.0f mi", miles)
            }
        }
    }
}

// MARK: - Detail Sheet (tap station name)

@MainActor
private struct TeslaSuperchargerDetailSheet: View {
    let site: TeslaNearbySite

    @EnvironmentObject private var store: SuperchargePricingInfoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.appThemeBox) private var themeBox

    @State private var isLoading = true
    @State private var detail: TeslaSuperchargerDetail?
    @State private var errorText: String?

    private var theme: any AppThemeSpec { themeBox.base }
    private var card: Color { theme.cardBackground }
    private var stroke: Color { theme.separator.opacity(0.7) }
    private var destructive: Color { .red }

    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle().fill(theme.screenBackground).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacing) {
                        headerCard
                        if isLoading {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Loading Tesla details…").foregroundStyle(.secondary)
                            }
                            .padding(.top, 6)
                        } else if let errorText {
                            errorCard(errorText)
                        } else if let detail {
                            pricingCard(detail)
                            infoCard(detail)
                        } else {
                            errorCard("No detail available.")
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Supercharger Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.down") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let url = site.detailURL {
                        Button("Tesla") { openURL(url) }
                    }
                }
            }
        }
        .task { await load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(site.displayName)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Text(site.subtitleLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(card)
        .overlay(RoundedRectangle(cornerRadius: theme.corner, style: .continuous).stroke(stroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
    }

    private func pricingCard(_ d: TeslaSuperchargerDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Pricing").font(.headline).foregroundStyle(.primary)
                Spacer()
                if let ts = d.fetchedAt {
                    Text(ts.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            LabeledRateRow(title: "Pricing for Tesla", value: d.teslaPricingText)
            if let nt = d.nonTeslaPricingText { LabeledRateRow(title: "Pricing for Non‑Tesla", value: nt) }
            if let pm = d.perMinuteText { LabeledRateRow(title: "Per‑minute", value: pm) }
            if let cg = d.congestionText { LabeledRateRow(title: "Congestion fee", value: cg) }

            if let note = d.pricingUnavailableReason {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(card)
        .overlay(RoundedRectangle(cornerRadius: theme.corner, style: .continuous).stroke(stroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
    }

    private func infoCard(_ d: TeslaSuperchargerDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Station info").font(.headline).foregroundStyle(.primary)
            KeyValueLine(key: "Name", value: d.name ?? site.displayName)
            if let a1 = d.addressLine1 { KeyValueLine(key: "Address", value: a1) }
            if let csz = d.cityStateZipLine { KeyValueLine(key: "City/State", value: csz) }
            if let stalls = d.stallCount { KeyValueLine(key: "Stalls", value: "\(stalls)") }
            if let kw = d.maxKw { KeyValueLine(key: "Max kW", value: "\(kw) kW") }
            if let hours = d.accessHours { KeyValueLine(key: "Access hours", value: hours) }
        }
        .padding(14)
        .background(card)
        .overlay(RoundedRectangle(cornerRadius: theme.corner, style: .continuous).stroke(stroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(destructive)
            Text("Tesla may block automated requests (403/101) or render pricing dynamically. Tap “Tesla” to view in Safari.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(card)
        .overlay(RoundedRectangle(cornerRadius: theme.corner, style: .continuous).stroke(stroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
    }

    private func load() async {
        isLoading = true
        errorText = nil
        detail = nil

        guard let url = site.detailURL else {
            isLoading = false
            errorText = "No Tesla detail URL for this station."
            return
        }

        do {
            detail = try await store.fetchTeslaDetail(for: site.id, url: url)
        } catch {
            errorText = error.localizedDescription
        }

        isLoading = false
    }
}

private struct LabeledRateRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.monospacedDigit().weight(.semibold)).foregroundStyle(.primary)
        }
    }
}

private struct KeyValueLine: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}

// MARK: - Action UI

private struct ActionGrid<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            content
        }
    }
}

private struct ActionTile: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.appThemeBox) private var themeBox

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .background(isEnabled ? theme.cardBackground : theme.cardBackground.opacity(0.78))
            .overlay(RoundedRectangle(cornerRadius: theme.corner, style: .continuous).stroke(theme.separator.opacity(0.7), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
        }
        .tint(tint)
        .buttonStyle(.plain)
    }
}

private struct NearbyCard: View {
    let site: TeslaNearbySite
    let distanceText: String?
    let priceText: String?
    let homeCompareText: String?
    let showPrice: Bool

    // Theme colors passed in (keeps this tiny & avoids extra env lookups in lists)
    let pillTint: Color
    let card: Color
    let cardAlt: Color
    let stroke: Color
    let accent: Color
    let destructive: Color

    let onTapName: () -> Void
    let onApple: () -> Void
    let onGoogle: () -> Void
    let onTesla: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {

                    Button(action: onTapName) {
                        HStack(spacing: 6) {
                            Text(site.displayName).font(.headline)
                            if site.detailURL != nil {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .disabled(site.detailURL == nil)

                    Text(site.subtitleLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                if let d = distanceText {
                    Text(d)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if showPrice {
                HStack(spacing: 8) {
                    PriceChip(text: priceText ?? "Price: —", tint: pillTint)
                    if let c = homeCompareText { PriceChip(text: c, tint: pillTint) }
                    if site.detailURL != nil {
                        Button(action: onTesla) {
                            Label("Tesla", systemImage: "safari")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            HStack(spacing: 10) {
                Button(action: onApple) { Label("Apple Maps", systemImage: "map") }
                    .buttonStyle(.bordered)
                Button(action: onGoogle) { Label("Google Maps", systemImage: "location") }
                    .buttonStyle(.bordered)
                Spacer()
                if showPrice && site.detailURL != nil {
                    Button(action: onRefresh) { Label("Refresh", systemImage: "arrow.clockwise") }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(14)
        .background(card)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(stroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.vertical, 6)
    }
}

private struct PriceChip: View {
    let text: String
    let tint: Color
    var body: some View {
        Text(text)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Store

@MainActor
public final class SuperchargePricingInfoStore: ObservableObject {

    public let directoryURL = URL(string: "https://www.tesla.com/findus/list/superchargers/United%20States")!

    @Published public private(set) var isBusy: Bool = false
    @Published public private(set) var progress: ProgressState = .idle
    @Published public private(set) var lastError: String?
    @Published public private(set) var nearby: [TeslaNearbySite] = []

    // Home electricity (residential) average for user location (state-level).
    @Published public private(set) var homeResidentialRate: SPIHomeResidentialRate?
    @Published public private(set) var homeResidentialRateError: String?

    private(set) var directory: [TeslaDirectoryEntry] = []
    private var directoryIndexByState: [String: [TeslaDirectoryEntry]] = [:]

    public var directoryCount: Int { directory.count }

    private var detailCache: [String: TeslaSuperchargerDetail] = [:]
    private var activeTask: Task<Void, Never>?
    private var lastNearbyKey: NearbyKey?

    public init() {}

    public func bootstrapIfNeeded() async {
        // Nearby is driven by the view’s location manager.
    }

    public func cancelWork() {
        activeTask?.cancel()
        activeTask = nil
        isBusy = false
        progress = .idle
    }

// MARK: Home Electricity (Residential)

/// Updates the user's state-level average residential electricity price (EIA) used for comparisons.
/// This is best-effort and intentionally decoupled from Tesla endpoints.
public func updateHomeResidentialRate(for location: CLLocation) async {
    do {
        guard let st = try await SPIReverseGeocoder.stateAbbrev(for: location) else { return }

        // Skip if recently fetched for the same state (6 hours).
        if let existing = homeResidentialRate,
           existing.stateAbbrev.uppercased() == st.uppercased(),
           Date().timeIntervalSince(existing.fetchedAt) < 6 * 60 * 60 {
            return
        }

        let fetched = try await EIAResidentialElectricityPrice.fetchUSDPerKwh(stateAbbrev: st)
        homeResidentialRate = fetched
        homeResidentialRateError = nil
    } catch {
        // Don't spam the main error; this is auxiliary.
        homeResidentialRateError = "Home electricity average unavailable right now."
    }
}

/// Returns a comparison chip like: "Home $0.23 • SC $0.41 • +78%".
public func homeVsSuperchargerSummary(for site: TeslaNearbySite) -> String? {
    guard let home = homeResidentialRate?.usdPerKwh else { return nil }
    guard let sc = site.pricing?.teslaKwh else {
        return String(format: "Home $%.2f/kWh", home)
    }
    if home <= 0 { return nil }
    let pct = ((sc - home) / home) * 100.0
    return String(format: "Home $%.2f • SC $%.2f • %+0.0f%%", home, sc, pct)
}

    public func refreshNearby(center: CLLocationCoordinate2D, radiusMeters: Double, force: Bool) async {
        let key = NearbyKey(
            lat: Double(Int(center.latitude * 1000)) / 1000.0,
            lon: Double(Int(center.longitude * 1000)) / 1000.0,
            radius: Int(radiusMeters)
        )
        if !force, let lastNearbyKey, lastNearbyKey == key, !nearby.isEmpty { return }
        lastNearbyKey = key

        if isBusy { return }
        isBusy = true
        lastError = nil
        progress = .working(label: "Searching nearby…", done: 0, total: 1)

        let task = Task {
            do {
                let region = MKCoordinateRegion(
                    center: center,
                    latitudinalMeters: radiusMeters * 2.0,
                    longitudinalMeters: radiusMeters * 2.0
                )

                let items = try await MKSearch.search(query: "Tesla Supercharger", region: region)

                var sites: [TeslaNearbySite] = []
                sites.reserveCapacity(items.count)

                for mi in items {
                    let coordinate = mi.compatCoordinate
                    let fullAddress = mi.compatFullAddress

                    let street = mi.compatShortAddress
                        ?? Regex.firstGroup(
                            in: fullAddress ?? "",
                            pattern: #"(?m)^(\d{1,6}\s+[A-Za-z0-9].+)$"#,
                            options: []
                        ).trimmedNonEmpty

                    let city = mi.compatCityName
                    let st = Regex.firstGroup(
                        in: fullAddress ?? "",
                        pattern: #"\b([A-Z]{2})\s*(?:\d{5}(?:-\d{4})?)?\b"#,
                        options: []
                    ).trimmedNonEmpty
                    let zip = Regex.firstGroup(
                        in: fullAddress ?? "",
                        pattern: #"\b(\d{5}(?:-\d{4})?)\b"#,
                        options: []
                    ).trimmedNonEmpty

                    let rawName = mi.name.trimmedNonEmpty
                    let displayName = TeslaNearbySite.makeDisplayName(name: rawName, city: city, state: st)

                    let id = TeslaNearbySite.makeID(name: displayName, coordinate: coordinate)
                    let siteCoordinate = SPICoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)

                    sites.append(
                        TeslaNearbySite(
                            id: id,
                            displayName: displayName,
                            street: street,
                            city: city,
                            stateAbbrev: st,
                            postalCode: zip,
                            coordinate: siteCoordinate,
                            detailURL: nil,
                            pricing: nil
                        )
                    )
                }

                sites = TeslaNearbySite.dedup(sites)
                if !self.directory.isEmpty { sites = self.attachDirectoryLinks(to: sites) }

                await MainActor.run {
                    self.nearby = sites
                    self.progress = .idle
                    self.isBusy = false
                }
            } catch is CancellationError {
                await MainActor.run { self.progress = .idle; self.isBusy = false }
            } catch {
                await MainActor.run {
                    self.lastError = "Nearby search failed: \(error.localizedDescription)"
                    self.progress = .idle
                    self.isBusy = false
                }
            }
        }

        activeTask = task
        await task.value
        activeTask = nil
    }

    public func loadDirectoryIfNeeded(force: Bool = false) async {
        if !force, !directory.isEmpty { return }
        if isBusy { return }

        isBusy = true
        lastError = nil
        progress = .working(label: "Loading Tesla directory…", done: 0, total: 1)

        let task = Task { [directoryURL] in
            do {
                let html = try await SPIHTTP.fetchHTML(url: directoryURL)
                try Task.checkCancellation()

                let entries = TeslaDirectoryParser.parseDirectory(html: html)
                let index = TeslaDirectoryParser.indexByState(entries)

                await MainActor.run {
                    self.directory = entries
                    self.directoryIndexByState = index
                    if !self.nearby.isEmpty {
                        self.nearby = self.attachDirectoryLinks(to: self.nearby)
                    }
                    self.progress = .idle
                    self.isBusy = false
                }
            } catch is CancellationError {
                await MainActor.run { self.progress = .idle; self.isBusy = false }
            } catch {
                await MainActor.run {
                    self.lastError = "Directory load failed: \(error.localizedDescription)"
                    self.progress = .idle
                    self.isBusy = false
                }
            }
        }

        activeTask = task
        await task.value
        activeTask = nil
    }

    private func attachDirectoryLinks(to sites: [TeslaNearbySite]) -> [TeslaNearbySite] {
        var out = sites
        for i in out.indices {
            guard out[i].detailURL == nil else { continue }
            guard let st = out[i].stateAbbrev else { continue }
            guard let candidates = directoryIndexByState[st] else { continue }
            if let match = TeslaDirectoryParser.bestMatch(nearby: out[i], candidates: candidates) {
                out[i].detailURL = match.detailURL
            }
        }
        return out
    }

    // MARK: Detail & Pricing

    public func fetchTeslaDetail(for siteID: String, url: URL) async throws -> TeslaSuperchargerDetail {
        if let cached = detailCache[siteID] { return cached }
        let html = try await SPIHTTP.fetchHTML(url: url)
        let detail = TeslaDetailParser.parseDetail(html: html)
        detailCache[siteID] = detail
        return detail
    }

    public func refreshPricesForNearby() async {
        if isBusy { return }
        let targets = nearby.filter { $0.detailURL != nil }
        if targets.isEmpty { return }

        isBusy = true
        lastError = nil
        progress = .working(label: "Refreshing nearby prices…", done: 0, total: max(targets.count, 1))

        let task = Task {
            do {
                let limiter = SPIAsyncLimiter(maxConcurrent: 3)
                var updated = nearby
                var done = 0

                for idx in updated.indices {
                    try Task.checkCancellation()
                    guard let url = updated[idx].detailURL else { continue }

                    try await limiter.run {
                        do {
                            let html = try await SPIHTTP.fetchHTML(url: url)
                            let pricing = TeslaPricingParser.parsePricing(html: html)
                            await MainActor.run {
                                updated[idx].pricing = pricing
                                done += 1
                                self.progress = .working(label: "Refreshing nearby prices…", done: done, total: max(targets.count, 1))
                            }
                        } catch {
                            await MainActor.run {
                                updated[idx].pricing = TeslaNearbyPricing(status: .blockedOrUnavailable, fetchedAt: Date(), teslaKwh: nil)
                                done += 1
                                self.progress = .working(label: "Refreshing nearby prices…", done: done, total: max(targets.count, 1))
                            }
                        }
                    }
                }

                await MainActor.run {
                    self.nearby = updated
                    self.progress = .idle
                    self.isBusy = false
                }
            } catch is CancellationError {
                await MainActor.run { self.progress = .idle; self.isBusy = false }
            } catch {
                await MainActor.run {
                    self.lastError = "Pricing refresh failed: \(error.localizedDescription)"
                    self.progress = .idle
                    self.isBusy = false
                }
            }
        }

        activeTask = task
        await task.value
        activeTask = nil
    }

    public func refreshPrice(for id: String) async {
        guard let idx = nearby.firstIndex(where: { $0.id == id }) else { return }
        guard let url = nearby[idx].detailURL else { return }
        if isBusy { return }

        isBusy = true
        lastError = nil
        progress = .working(label: "Refreshing price…", done: 0, total: 1)

        let task = Task {
            do {
                let html = try await SPIHTTP.fetchHTML(url: url)
                let pricing = TeslaPricingParser.parsePricing(html: html)
                await MainActor.run {
                    var copy = self.nearby
                    copy[idx].pricing = pricing
                    self.nearby = copy
                    self.progress = .idle
                    self.isBusy = false
                }
            } catch {
                await MainActor.run {
                    var copy = self.nearby
                    copy[idx].pricing = TeslaNearbyPricing(status: .blockedOrUnavailable, fetchedAt: Date(), teslaKwh: nil)
                    self.nearby = copy
                    self.lastError = "Price fetch blocked/unavailable. Tap Tesla to view pricing in Safari."
                    self.progress = .idle
                    self.isBusy = false
                }
            }
        }

        activeTask = task
        await task.value
        activeTask = nil
    }

    public func pricingSummary(for site: TeslaNearbySite) -> String {
        guard let p = site.pricing else { return "—" }
        switch p.status {
        case .ok:
            if let v = p.teslaKwh { return String(format: "$%.2f/kWh", v) }
            return "Not shown"
        case .notShown:
            return "Not shown"
        case .blockedOrUnavailable:
            return "Blocked (tap Tesla)"
        }
    }

    // MARK: Distances & Maps

    public func distance(from here: CLLocation, to site: TeslaNearbySite) -> CLLocationDistance {
        here.distance(from: CLLocation(latitude: site.coordinate.latitude, longitude: site.coordinate.longitude))
    }

    public func distanceString(from here: CLLocation, to site: TeslaNearbySite, unitMode: SuperchargeInfoNearMeView.UnitMode) -> String {
        let meters = distance(from: here, to: site)
        if unitMode == .kilometers {
            let km = meters / 1000.0
            return km < 1 ? String(format: "%.0f m", meters) : String(format: "%.1f km", km)
        } else {
            let miles = meters / 1609.344
            return miles < 0.1 ? String(format: "%.0f ft", meters * 3.28084) : String(format: "%.1f mi", miles)
        }
    }

    public func appleMapsURL(for site: TeslaNearbySite) -> URL? {
        let c = site.coordinate
        return URL(string: "http://maps.apple.com/?ll=\(c.latitude),\(c.longitude)&q=\(site.displayName.urlQueryEncoded)")
    }

    public func googleMapsURL(for site: TeslaNearbySite) -> URL? {
        let c = site.coordinate
        return URL(string: "https://www.google.com/maps/search/?api=1&query=\(c.latitude),\(c.longitude)")
    }

    private struct NearbyKey: Equatable {
        let lat: Double
        let lon: Double
        let radius: Int
    }
}

// MARK: - Models

public struct TeslaNearbySite: Identifiable, Codable, Hashable {
    public var id: String
    public var displayName: String

    public var street: String?
    public var city: String?
    public var stateAbbrev: String?
    public var postalCode: String?

    public var coordinate: SPICoordinate
    public var detailURL: URL?
    public var pricing: TeslaNearbyPricing?

    public var subtitleLine: String {
        var parts: [String] = []
        if let s = street { parts.append(s) }
        var cs: [String] = []
        if let c = city { cs.append(c) }
        if let st = stateAbbrev { cs.append(st) }
        if let z = postalCode { cs.append(z) }
        if !cs.isEmpty { parts.append(cs.joined(separator: ", ")) }
        return parts.isEmpty ? "Tesla Supercharger" : parts.joined(separator: " • ")
    }

    public var searchBlob: String {
        [displayName, street ?? "", city ?? "", stateAbbrev ?? "", postalCode ?? ""].joined(separator: " ")
    }

    static func makeDisplayName(name: String?, city: String?, state: String?) -> String {
        if let c = city, let st = state { return "\(c), \(st) Supercharger" }
        if let n = name, !n.isEmpty { return n }
        return "Tesla Supercharger"
    }

    static func makeID(name: String, coordinate: CLLocationCoordinate2D) -> String {
        let lat = String(format: "%.5f", coordinate.latitude)
        let lon = String(format: "%.5f", coordinate.longitude)
        return "\(name)|\(lat),\(lon)".stableHashPrefix(16)
    }

    static func dedup(_ items: [TeslaNearbySite]) -> [TeslaNearbySite] {
        var seen: Set<String> = []
        var out: [TeslaNearbySite] = []
        out.reserveCapacity(items.count)
        for s in items {
            if seen.insert(s.id).inserted { out.append(s) }
        }
        return out
    }
}

public struct TeslaNearbyPricing: Codable, Hashable {
    public enum Status: String, Codable { case ok, notShown, blockedOrUnavailable }
    public var status: Status
    public var fetchedAt: Date
    public var teslaKwh: Double?
}

public struct SPIHomeResidentialRate: Codable, Hashable {
    public var stateAbbrev: String
    public var stateName: String
    /// Dollars per kWh (residential, state average).
    public var usdPerKwh: Double
    /// Human-readable source month/year, e.g. "October 2025".
    public var asOf: String
    public var fetchedAt: Date

    public var usdPerKwhText: String { String(format: "$%.2f/kWh", usdPerKwh) }
}
public struct TeslaDirectoryEntry: Codable, Hashable {
    public var detailURL: URL
    public var city: String?
    public var stateAbbrev: String?
    public var addressLine1: String?
}

public struct TeslaSuperchargerDetail: Codable, Hashable {
    public var fetchedAt: Date?
    public var name: String?
    public var addressLine1: String?
    public var cityStateZipLine: String?
    public var stallCount: Int?
    public var maxKw: Int?
    public var accessHours: String?

    public var teslaMemberKwh: Double?
    public var nonTeslaKwh: Double?
    public var perMinute: Double?
    public var congestionFeePerMinute: Double?

    public var pricingUnavailableReason: String?

    public var teslaPricingText: String {
        if let v = teslaMemberKwh { return String(format: "$%.2f/kWh", v) }
        return "Not shown"
    }
    public var nonTeslaPricingText: String? {
        guard let v = nonTeslaKwh else { return nil }
        return String(format: "$%.2f/kWh", v)
    }
    public var perMinuteText: String? {
        guard let v = perMinute else { return nil }
        return String(format: "$%.2f/min", v)
    }
    public var congestionText: String? {
        guard let v = congestionFeePerMinute else { return nil }
        return String(format: "$%.2f/min", v)
    }
}

public struct SPICoordinate: Codable, Hashable {
    public var latitude: Double
    public var longitude: Double
}

public struct ProgressState: Equatable {
    public var label: String
    public var done: Int
    public var total: Int

    public var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1.0, max(0.0, Double(done) / Double(total)))
    }

    public static let idle = ProgressState(label: "Idle", done: 0, total: 1)
    public static func working(label: String, done: Int, total: Int) -> ProgressState {
        ProgressState(label: label, done: done, total: total)
    }
}

// MARK: - Location Manager

final class SPINearMeLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    private let manager = CLLocationManager()
    private var didRequest = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func ensureAuthorization() {
        guard !didRequest else { return }
        didRequest = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.startUpdatingLocation()
            default:
                manager.stopUpdatingLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        Task { @MainActor in
            self.location = latest
        }
    }
}

// MARK: - MapKit Search (async wrapper)

enum MKSearch {
    static func search(query: String, region: MKCoordinateRegion) async throws -> [MKMapItem] {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        req.region = region

        let search = MKLocalSearch(request: req)
        return try await withCheckedThrowingContinuation { cont in
            search.start { resp, err in
                if let err = err { cont.resume(throwing: err); return }
                cont.resume(returning: resp?.mapItems ?? [])
            }
        }
    }
}

// MARK: - Networking

enum SPIHTTP {
    static func fetchHTML(url: URL) async throws -> String {
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "SPIHTTP", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP \(http.statusCode) from \(url.host ?? "server")"
            ])
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "SPIHTTP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to decode HTML as UTF-8"])
        }
        return html
    }
}

// MARK: - Home Electricity (EIA state average, residential)

enum SPIReverseGeocoder {
    static func stateAbbrev(for location: CLLocation) async throws -> String? {
        let items = try await MapKitCompat.reverseGeocodeMapItems(for: location)
        let fullAddress = items.first?.compatFullAddress
        let state = Regex.firstGroup(
            in: fullAddress ?? "",
            pattern: #"\b([A-Z]{2})\s*(?:\d{5}(?:-\d{4})?)?\b"#,
            options: []
        )
        return state?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum EIAResidentialElectricityPrice {
    // EIA Electric Power Monthly, Table 5.6.A (cents per kWh).
    // https://www.eia.gov/electricity/monthly/epm_table_grapher.php?t=epmt_5_6_a
    static let epmURL = URL(string: "https://www.eia.gov/electricity/monthly/epm_table_grapher.php?t=epmt_5_6_a")!

    static let stateNameByAbbrev: [String: String] = [
        "AK": "Alaska",
        "AL": "Alabama",
        "AR": "Arkansas",
        "AZ": "Arizona",
        "CA": "California",
        "CO": "Colorado",
        "CT": "Connecticut",
        "DC": "District of Columbia",
        "DE": "Delaware",
        "FL": "Florida",
        "GA": "Georgia",
        "HI": "Hawaii",
        "IA": "Iowa",
        "ID": "Idaho",
        "IL": "Illinois",
        "IN": "Indiana",
        "KS": "Kansas",
        "KY": "Kentucky",
        "LA": "Louisiana",
        "MA": "Massachusetts",
        "MD": "Maryland",
        "ME": "Maine",
        "MI": "Michigan",
        "MN": "Minnesota",
        "MO": "Missouri",
        "MS": "Mississippi",
        "MT": "Montana",
        "NC": "North Carolina",
        "ND": "North Dakota",
        "NE": "Nebraska",
        "NH": "New Hampshire",
        "NJ": "New Jersey",
        "NM": "New Mexico",
        "NV": "Nevada",
        "NY": "New York",
        "OH": "Ohio",
        "OK": "Oklahoma",
        "OR": "Oregon",
        "PA": "Pennsylvania",
        "RI": "Rhode Island",
        "SC": "South Carolina",
        "SD": "South Dakota",
        "TN": "Tennessee",
        "TX": "Texas",
        "UT": "Utah",
        "VA": "Virginia",
        "VT": "Vermont",
        "WA": "Washington",
        "WI": "Wisconsin",
        "WV": "West Virginia",
        "WY": "Wyoming"
    ]

    static func fetchUSDPerKwh(stateAbbrev: String) async throws -> SPIHomeResidentialRate {
        let st = stateAbbrev.uppercased()
        let stateName = stateNameByAbbrev[st] ?? st

        let html = try await SPIHTTP.fetchHTML(url: epmURL)

        // Convert to readable lines (strip tags, decode entities, keep newlines)
        let text = html
            .strippingTags()
            .decodeHTMLEntities()
            .condenseWhitespaceKeepingNewlines()

        let asOf =
            Regex.firstGroup(in: text, pattern: #"Data for\s+([A-Za-z]+\s+\d{4})"#, options: [.caseInsensitive])
            ?? Regex.firstGroup(in: text, pattern: #"by State,\s*([A-Za-z]+\s+\d{4})"#, options: [.caseInsensitive])
            ?? "Latest available"

        if let cents = parseCentsPerKwh(from: text, rowName: stateName) {
            return SPIHomeResidentialRate(
                stateAbbrev: st,
                stateName: stateName,
                usdPerKwh: cents / 100.0,
                asOf: asOf,
                fetchedAt: Date()
            )
        }

        // Fallback: U.S. average (still useful for comparison).
        if let usCents = parseCentsPerKwh(from: text, rowName: "U.S.") {
            return SPIHomeResidentialRate(
                stateAbbrev: st,
                stateName: stateName,
                usdPerKwh: usCents / 100.0,
                asOf: asOf,
                fetchedAt: Date()
            )
        }

        throw NSError(domain: "EIA", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "EIA state average not found in table."
        ])
    }

    private static func parseCentsPerKwh(from text: String, rowName: String) -> Double? {
        let target = rowName.lowercased()
        let words = rowName.split(separator: " ").count

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            guard line.lowercased().hasPrefix(target.lowercased() + " ") else { continue }

            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard parts.count > words else { continue }

            let value = parts[words]
            if let d = Double(value) {
                return d
            }
        }
        return nil
    }
}

// MARK: - Tesla Detail Parser

enum TeslaDetailParser {
    static func parseDetail(html: String) -> TeslaSuperchargerDetail {
        var out = TeslaSuperchargerDetail()
        out.fetchedAt = Date()

        let text = html.strippingTags().decodeHTMLEntities().condenseWhitespaceKeepingNewlines()

        if let title = Regex.firstGroup(in: html, pattern: #"<title>\s*([^<]+)\s*</title>"#, options: [.caseInsensitive]) {
            out.name = title
                .replacingOccurrences(of: "| Tesla", with: "", options: .caseInsensitive)
                .trimmedNonEmpty
        }

        out.addressLine1 = Regex.firstGroup(in: text, pattern: #"(?m)^(\d{1,6}\s+[A-Za-z0-9].+)$"#, options: []).trimmedNonEmpty
        out.cityStateZipLine = Regex.firstGroup(in: text, pattern: #"(?m)^([A-Za-z .'-]+,\s*[A-Z]{2}\s*\d{5}(?:-\d{4})?)$"#, options: []).trimmedNonEmpty

        if let s = Regex.firstGroup(in: text, pattern: #"(\d{1,3})\s+Superchargers"#, options: [.caseInsensitive]), let n = Int(s) {
            out.stallCount = n
        }
        if let s = Regex.firstGroup(in: text, pattern: #"Up to\s+(\d{2,3})\s*kW"#, options: [.caseInsensitive]), let n = Int(s) {
            out.maxKw = n
        }

        let kwhRates = Regex.allDoubles(in: text, pattern: #"\$(\d+(?:\.\d+)?)\s*/\s*kWh"#, options: [.caseInsensitive])
        let perMinRates = Regex.allDoubles(in: text, pattern: #"\$(\d+(?:\.\d+)?)\s*/\s*min"#, options: [.caseInsensitive])

        if !kwhRates.isEmpty {
            out.teslaMemberKwh = kwhRates.min()
            if kwhRates.count >= 2 { out.nonTeslaKwh = kwhRates.max() }
        }
        out.perMinute = perMinRates.min()

        if out.teslaMemberKwh == nil && out.perMinute == nil {
            out.pricingUnavailableReason = "Tesla did not expose numeric pricing on this page (or it was rendered dynamically)."
        }

        return out
    }
}

// MARK: - Directory Parser (best-effort link attachment)

enum TeslaDirectoryParser {

    static func parseDirectory(html: String) -> [TeslaDirectoryEntry] {
        let urls = extractDetailURLs(from: html)
        if urls.isEmpty { return [] }

        var out: [TeslaDirectoryEntry] = []
        out.reserveCapacity(urls.count)

        for url in urls {
            let key = url.absoluteString
            guard let r = html.range(of: key) else { continue }
            let start = html.index(r.lowerBound, offsetBy: -900, limitedBy: html.startIndex) ?? html.startIndex
            let end = html.index(r.upperBound, offsetBy: 900, limitedBy: html.endIndex) ?? html.endIndex
            let window = String(html[start..<end])

            let text = window.strippingTags().decodeHTMLEntities().condenseWhitespaceKeepingNewlines()

            let street = Regex.firstGroup(in: text, pattern: #"(?m)^(\d{1,6}\s+[A-Za-z0-9].+)$"#, options: []).trimmedNonEmpty
            let city = Regex.firstGroup(in: text, pattern: #"(?m)^([A-Za-z .'-]+),\s*[A-Z]{2}\b"#, options: []).trimmedNonEmpty
            let st = Regex.firstGroup(in: text, pattern: #"(?m)^[A-Za-z .'-]+,\s*([A-Z]{2})\b"#, options: []).trimmedNonEmpty

            out.append(TeslaDirectoryEntry(detailURL: url, city: city, stateAbbrev: st, addressLine1: street))
        }

        return out
    }

    static func indexByState(_ entries: [TeslaDirectoryEntry]) -> [String: [TeslaDirectoryEntry]] {
        var dict: [String: [TeslaDirectoryEntry]] = [:]
        for e in entries {
            guard let st = e.stateAbbrev else { continue }
            dict[st, default: []].append(e)
        }
        return dict
    }

    static func bestMatch(nearby: TeslaNearbySite, candidates: [TeslaDirectoryEntry]) -> TeslaDirectoryEntry? {
        let nStreet = (nearby.street ?? "").lowercased()
        let nCity = (nearby.city ?? "").lowercased()
        let nNum = leadingNumber(nStreet)

        var bestScore = -1
        var best: TeslaDirectoryEntry?

        for c in candidates {
            let cStreet = (c.addressLine1 ?? "").lowercased()
            let cCity = (c.city ?? "").lowercased()

            var score = 0
            if !nCity.isEmpty, !cCity.isEmpty, nCity == cCity { score += 5 }
            if let a = nNum, let b = leadingNumber(cStreet), a == b { score += 6 }
            score += tokenOverlap(a: nStreet, b: cStreet)

            if score > bestScore {
                bestScore = score
                best = c
            }
        }

        return bestScore >= 8 ? best : nil
    }

    private static func extractDetailURLs(from html: String) -> [URL] {
        let patterns = [
            #"https?:\/\/www\.tesla\.com\/findus\/location\/supercharger\/[A-Za-z0-9._-]+"#,
            #"\/findus\/location\/supercharger\/[A-Za-z0-9._-]+"#
        ]
        var set = Set<String>()
        for p in patterns {
            guard let re = try? NSRegularExpression(pattern: p, options: []) else { continue }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            re.enumerateMatches(in: html, options: [], range: range) { m, _, _ in
                guard let m = m, let rr = Range(m.range, in: html) else { return }
                let s = String(html[rr])
                if s.hasPrefix("/") { set.insert("https://www.tesla.com" + s) } else { set.insert(s) }
            }
        }
        return set.compactMap(URL.init(string:)).sorted { $0.absoluteString < $1.absoluteString }
    }

    private static func leadingNumber(_ s: String) -> Int? {
        let first = s.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
        return Int(first.filter(\.isNumber))
    }

    private static func tokenOverlap(a: String, b: String) -> Int {
        let stop: Set<String> = ["st","street","rd","road","ave","avenue","blvd","boulevard","dr","drive","ln","lane","hwy","highway","pkwy","parkway"]
        let ta = Set(a.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map { String($0) }.filter { !$0.isEmpty && !stop.contains($0) })
        let tb = Set(b.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map { String($0) }.filter { !$0.isEmpty && !stop.contains($0) })
        return min(5, ta.intersection(tb).count)
    }
}

// MARK: - Pricing Parser (list view, best-effort)

enum TeslaPricingParser {
    static func parsePricing(html: String) -> TeslaNearbyPricing {
        let text = html.strippingTags().decodeHTMLEntities().condenseWhitespaceKeepingNewlines()
        let kwhRates = Regex.allDoubles(in: text, pattern: #"\$(\d+(?:\.\d+)?)\s*/\s*kWh"#, options: [.caseInsensitive])

        if kwhRates.isEmpty {
            return TeslaNearbyPricing(status: .notShown, fetchedAt: Date(), teslaKwh: nil)
        }
        return TeslaNearbyPricing(status: .ok, fetchedAt: Date(), teslaKwh: kwhRates.min())
    }
}

// MARK: - Concurrency Limiter

actor SPIAsyncLimiter {
    private let maxConcurrent: Int
    private var inFlight: Int = 0

    init(maxConcurrent: Int) { self.maxConcurrent = max(1, maxConcurrent) }

    func run<T>(_ op: @escaping () async throws -> T) async throws -> T {
        while inFlight >= maxConcurrent {
            try await Task.sleep(nanoseconds: 120_000_000)
        }
        inFlight += 1
        defer { inFlight -= 1 }
        return try await op()
    }
}

// MARK: - Regex helpers

enum Regex {
    static func firstGroup(in text: String, pattern: String, options: NSRegularExpression.Options) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let m = re.firstMatch(in: text, options: [], range: range) else { return nil }
        guard m.numberOfRanges >= 2, let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    static func allDoubles(in text: String, pattern: String, options: NSRegularExpression.Options) -> [Double] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var out: [Double] = []
        re.enumerateMatches(in: text, options: [], range: range) { m, _, _ in
            guard let m = m, m.numberOfRanges >= 2, let r = Range(m.range(at: 1), in: text) else { return }
            if let v = Double(String(text[r])) { out.append(v) }
        }
        return out
    }
}

// MARK: - String helpers

fileprivate extension String {
    func strippingTags() -> String {
        guard let re = try? NSRegularExpression(pattern: #"<[^>]+>"#, options: []) else { return self }
        let range = NSRange(startIndex..<endIndex, in: self)
        return re.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: " ")
    }

    func condenseWhitespaceKeepingNewlines() -> String {
        let lines = self
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: "\n")
    }

    func decodeHTMLEntities() -> String {
        var s = self
        let map: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&lt;": "<",
            "&gt;": ">"
        ]
        for (k, v) in map { s = s.replacingOccurrences(of: k, with: v) }
        return s
    }

    var urlQueryEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }

    func stableHashPrefix(_ n: Int) -> String {
        // FNV-1a 64-bit (no CryptoKit dependency)
        var h: UInt64 = 1469598103934665603
        for b in utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        let s = String(h, radix: 16)
        return String(s.prefix(max(8, min(n, s.count))))
    }
}
