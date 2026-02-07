//
//  MEVSuperchargeNearMeView.swift
//  My EV Companion
//
//  Swift 6 • iOS 17+
//
//  Supercharge.info dataset viewer (near-me).
//
//  Includes:
//  ✅ Import normalization removes "(unknown)"/"unknown"/"N/A" placeholders
//  ✅ Parses more key variants (matches /data headers + admin JSON field names)
//  ✅ UI never prints "unknown" — uses "Not listed" instead
//  ✅ Closest 5 section (based on live user location)
//  ✅ Buttons to open directions in Apple Maps or Google Maps
//
#if canImport(UIKit)
import UIKit
#endif

import SwiftUI
import MapKit
import CoreLocation
import Foundation

// MARK: - Model

public struct MEVSCISite: Identifiable, Hashable, Sendable {
    public let id: Int

    public var name: String
    public var street: String?
    public var city: String?
    public var state: String?
    public var zip: String?
    public var country: String?

    public var latitude: Double
    public var longitude: Double

    /// Elevation in meters (per supercharge.info admin UI)
    public var elevationM: Double?

    /// Total stalls (may be nil; we compute from breakdown if possible)
    public var stallCount: Int?

    /// Breakdown stalls
    public var stallsUrban: Int?
    public var stallsV2: Int?
    public var stallsV3: Int?
    public var stallsV4: Int?

    /// Max power in kW
    public var maxPowerKW: Int?

    public var statusRaw: String?
    public var dateOpened: Date?

    /// Free-form string from dataset (may be nil)
    public var hours: String?

    /// Free-form string from dataset (may be nil)
    public var parking: String?

    /// Whether “Other EVs OK” flag is set
    public var otherEVsOK: Bool?

    /// Plugs (booleans)
    public var plugTeslaTPC: Bool
    public var plugNACS: Bool
    public var plugCCS1: Bool
    public var plugCCS2: Bool
    public var plugType2: Bool
    public var plugGBT: Bool

    public init(
        id: Int,
        name: String,
        street: String?,
        city: String?,
        state: String?,
        zip: String?,
        country: String?,
        latitude: Double,
        longitude: Double,
        elevationM: Double?,
        stallCount: Int?,
        stallsUrban: Int?,
        stallsV2: Int?,
        stallsV3: Int?,
        stallsV4: Int?,
        maxPowerKW: Int?,
        statusRaw: String?,
        dateOpened: Date?,
        hours: String?,
        parking: String?,
        otherEVsOK: Bool?,
        plugTeslaTPC: Bool,
        plugNACS: Bool,
        plugCCS1: Bool,
        plugCCS2: Bool,
        plugType2: Bool,
        plugGBT: Bool
    ) {
        self.id = id
        self.name = name
        self.street = street
        self.city = city
        self.state = state
        self.zip = zip
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.elevationM = elevationM
        self.stallCount = stallCount
        self.stallsUrban = stallsUrban
        self.stallsV2 = stallsV2
        self.stallsV3 = stallsV3
        self.stallsV4 = stallsV4
        self.maxPowerKW = maxPowerKW
        self.statusRaw = statusRaw
        self.dateOpened = dateOpened
        self.hours = hours
        self.parking = parking
        self.otherEVsOK = otherEVsOK
        self.plugTeslaTPC = plugTeslaTPC
        self.plugNACS = plugNACS
        self.plugCCS1 = plugCCS1
        self.plugCCS2 = plugCCS2
        self.plugType2 = plugType2
        self.plugGBT = plugGBT
    }
}

// MARK: - Computed display helpers

public extension MEVSCISite {

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }

    var status: MEVSCIStatus {
        MEVSCIStatus(raw: statusRaw)
    }

    /// Sum stalls from breakdowns if total is missing.
    var computedTotalStalls: Int? {
        let parts = [stallsUrban, stallsV2, stallsV3, stallsV4].compactMap { $0 }
        if let total = stallCount { return total }
        guard !parts.isEmpty else { return nil }
        let sum = parts.reduce(0, +)
        return sum > 0 ? sum : nil
    }

    /// Best short label like "8 V3" or "24 stalls"
    var stallsShortLabel: String? {
        let total = computedTotalStalls

        if let t = total {
            let v2 = stallsV2 ?? 0
            let v3 = stallsV3 ?? 0
            let v4 = stallsV4 ?? 0
            let u  = stallsUrban ?? 0
            let nonZero = [(u, "Urban"), (v2, "V2"), (v3, "V3"), (v4, "V4")].filter { $0.0 > 0 }
            if nonZero.count == 1, let only = nonZero.first, only.0 == t {
                return "\(t) \(only.1)"
            }
            return "\(t) stalls"
        }

        if let v3 = stallsV3, v3 > 0 { return "\(v3) V3" }
        if let v2 = stallsV2, v2 > 0 { return "\(v2) V2" }
        if let v4 = stallsV4, v4 > 0 { return "\(v4) V4" }
        if let u = stallsUrban, u > 0 { return "\(u) Urban" }

        return nil
    }

    var plugTypes: [String] {
        var out: [String] = []
        if plugTeslaTPC { out.append("Tesla") }
        if plugNACS { out.append("NACS") }
        if plugCCS1 { out.append("CCS1") }
        if plugCCS2 { out.append("CCS2") }
        if plugType2 { out.append("Type2") }
        if plugGBT { out.append("GB/T") }
        return out
    }

    /// - If exactly one plug type and we have stalls, show "8 NACS"
    /// - Else show "NACS • CCS1"
    var plugsShortLabel: String? {
        let types = plugTypes
        guard !types.isEmpty else { return nil }

        if types.count == 1, let t = computedTotalStalls, t > 0 {
            return "\(t) \(types[0])"
        }
        return types.joined(separator: " • ")
    }

    var powerShortLabel: String? {
        if let kw = maxPowerKW, kw > 0 { return "\(kw) kW" }
        return nil
    }

    var addressLine: String? {
        if let street, !street.isEmpty { return street }
        return nil
    }

    var localityLine: String? {
        let parts = [city, state, zip].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    var openedDateString: String? {
        guard let dateOpened else { return nil }
        let f = DateFormatter()
        f.locale = .current
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: dateOpened)
    }

    var openForString: String? {
        guard let d = dateOpened else { return nil }
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: d, to: Date())
        if let y = comps.year, y > 0 { return y == 1 ? "1 year" : "\(y) years" }
        if let m = comps.month, m > 0 { return m == 1 ? "1 month" : "\(m) months" }
        return "Recently"
    }

    var otherEVsLine: String {
        guard let ok = otherEVsOK else { return "Not listed" }
        if ok {
            if plugNACS { return "Yes (NACS / adapter)" }
            if plugCCS1 || plugCCS2 || plugType2 || plugGBT { return "Yes (supported connectors)" }
            return "Yes"
        } else {
            return "No"
        }
    }

    var elevationFeetString: String? {
        guard let m = elevationM else { return nil }
        let ft = m * 3.280839895
        let rounded = Int(ft.rounded())
        return "\(rounded) ft"
    }
}

// MARK: - Status

public enum MEVSCIStatus: String, CaseIterable, Sendable {
    case open
    case openLimitedHours
    case expanding
    case construction
    case permit
    case plan
    case voting
    case temporarilyClosed
    case permanentlyClosed
    case custom
    case unknown

    init(raw: String?) {
        let s = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.isEmpty { self = .unknown; return }

        if s.contains("OPEN") && s.contains("LIMIT") { self = .openLimitedHours; return }
        if s == "OPEN" { self = .open; return }
        if s.contains("EXPAND") { self = .expanding; return }
        if s.contains("CONSTRUCT") { self = .construction; return }
        if s == "PERMIT" { self = .permit; return }
        if s == "PLAN" { self = .plan; return }
        if s == "VOTING" { self = .voting; return }
        if s.contains("TEMP") && s.contains("CLOSE") { self = .temporarilyClosed; return }
        if s.contains("PERMANENT") && s.contains("CLOSE") { self = .permanentlyClosed; return }
        if s == "CUSTOM" { self = .custom; return }
        if s == "CLOSED" { self = .permanentlyClosed; return }

        self = .unknown
    }

    var title: String {
        switch self {
        case .open: return "Open"
        case .openLimitedHours: return "Open - Limited Hours"
        case .expanding: return "Expanding"
        case .construction: return "Construction"
        case .permit: return "Permit"
        case .plan: return "Plan"
        case .voting: return "Voting"
        case .temporarilyClosed: return "Temporarily Closed"
        case .permanentlyClosed: return "Permanently Closed"
        case .custom: return "Custom"
        case .unknown: return "Not listed"
        }
    }

    var systemImage: String {
        switch self {
        case .open: return "checkmark.seal.fill"
        case .openLimitedHours: return "clock.badge.checkmark"
        case .expanding: return "arrow.up.right.square"
        case .construction: return "hammer.fill"
        case .permit: return "doc.badge.clock"
        case .plan: return "sparkles"
        case .voting: return "checkmark.circle"
        case .temporarilyClosed: return "pause.circle"
        case .permanentlyClosed: return "xmark.octagon.fill"
        case .custom: return "mappin.circle"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Import (no "unknown")

enum MEVSCIImport {

    private static let placeholderStrings: Set<String> = [
        "UNKNOWN", "(UNKNOWN)", "N/A", "NA", "NONE", "-", "—", "–", "(NONE)"
    ]

    static func cleanString(_ any: Any?) -> String? {
        guard let any else { return nil }
        if let s = any as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return nil }
            if placeholderStrings.contains(t.uppercased()) { return nil }
            if t.replacingOccurrences(of: " ", with: "").uppercased() == "(UNKNOWN)" { return nil }
            return t
        }
        return nil
    }

    static func cleanBool(_ any: Any?) -> Bool? {
        guard let any else { return nil }
        if let b = any as? Bool { return b }
        if let n = any as? NSNumber { return n.boolValue }
        if let s = cleanString(any)?.lowercased() {
            if ["true","yes","y","1"].contains(s) { return true }
            if ["false","no","n","0"].contains(s) { return false }
        }
        return nil
    }

    static func cleanInt(_ any: Any?) -> Int? {
        guard let any else { return nil }
        if let i = any as? Int { return i }
        if let n = any as? NSNumber { return n.intValue }
        if let s = cleanString(any) {
            let digits = s.filter { $0.isNumber }
            if let v = Int(digits), v > 0 { return v }
        }
        return nil
    }

    static func cleanDouble(_ any: Any?) -> Double? {
        guard let any else { return nil }
        if let d = any as? Double { return d }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = cleanString(any) {
            let filtered = s.filter { $0.isNumber || $0 == "." || $0 == "-" }
            if let v = Double(filtered) { return v }
        }
        return nil
    }

    static func parseDate(_ any: Any?) -> Date? {
        guard let s = cleanString(any) else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }

        let iso2 = ISO8601DateFormatter()
        iso2.formatOptions = [.withFullDate]
        if let d = iso2.date(from: s) { return d }

        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        if let d = f.date(from: s) { return d }

        return nil
    }

    static func parseGPS(_ any: Any?) -> (Double, Double)? {
        guard let any else { return nil }

        if let s = cleanString(any) {
            let parts = s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if parts.count >= 2,
               let lat = Double(parts[0]),
               let lon = Double(parts[1]) {
                return (lat, lon)
            }
        }

        if let dict = any as? [String: Any] {
            if let lat = cleanDouble(dict["lat"] ?? dict["latitude"]),
               let lon = cleanDouble(dict["lng"] ?? dict["lon"] ?? dict["longitude"]) {
                return (lat, lon)
            }
        }

        if let arr = any as? [Any], arr.count >= 2 {
            if let lat = cleanDouble(arr[0]), let lon = cleanDouble(arr[1]) {
                return (lat, lon)
            }
        }

        return nil
    }

    static func parsePlugs(from dict: [String: Any]) -> (tpc: Bool, nacs: Bool, ccs1: Bool, ccs2: Bool, type2: Bool, gbt: Bool) {
        func boolFor(_ keys: [String]) -> Bool {
            for k in keys {
                if let b = cleanBool(dict[k]) { return b }
            }
            return false
        }

        let plugsNested = dict["plugs"] as? [String: Any]
        func boolNested(_ keys: [String]) -> Bool {
            guard let plugsNested else { return false }
            for k in keys {
                if let b = cleanBool(plugsNested[k]) { return b }
            }
            return false
        }

        let tpc  = boolFor(["tpc","plugTPC","plugTesla","tesla","plugTeslaTPC"]) || boolNested(["tpc","tesla"])
        let nacs = boolFor(["nacs","plugNACS"]) || boolNested(["nacs"])
        let ccs1 = boolFor(["ccs1","plugCCS1"]) || boolNested(["ccs1"])
        let ccs2 = boolFor(["ccs2","plugCCS2"]) || boolNested(["ccs2"])
        let type2 = boolFor(["type2","plugType2"]) || boolNested(["type2"])
        let gbt  = boolFor(["gbt","gb/t","plugGBT"]) || boolNested(["gbt","gb/t"])

        return (tpc, nacs, ccs1, ccs2, type2, gbt)
    }

    static func parseStallsString(_ any: Any?) -> (total: Int?, v2: Int?, v3: Int?, v4: Int?, urban: Int?) {
        guard let s = cleanString(any) else { return (nil,nil,nil,nil,nil) }
        let upper = s.uppercased()
        let num = cleanInt(s)
        if num == nil { return (nil,nil,nil,nil,nil) }

        if upper.contains("V4") { return (num, nil, nil, num, nil) }
        if upper.contains("V3") { return (num, nil, num, nil, nil) }
        if upper.contains("V2") { return (num, num, nil, nil, nil) }
        if upper.contains("URBAN") { return (num, nil, nil, nil, num) }

        return (num, nil, nil, nil, nil)
    }

    static func parseSite(_ dict: [String: Any]) -> MEVSCISite? {
        guard let id = cleanInt(dict["id"] ?? dict["siteId"] ?? dict["ID"]) else { return nil }

        let name = cleanString(dict["name"] ?? dict["siteName"] ?? dict["Site Name"] ?? dict["Name"]) ?? "Unnamed Site"

        let street = cleanString(dict["street"] ?? dict["address"] ?? dict["streetAddress"] ?? dict["Street Address"] ?? dict["Street"])
        let city   = cleanString(dict["city"] ?? dict["City"])
        let state  = cleanString(dict["state"] ?? dict["State"])
        let zip    = cleanString(dict["zip"] ?? dict["Zip"] ?? dict["postalCode"])
        let country = cleanString(dict["country"] ?? dict["Country"])

        let gpsAny = dict["gps"] ?? dict["GPS"] ?? dict["location"] ?? dict["coords"] ?? dict["coordinate"]
        guard let (lat, lon) = parseGPS(gpsAny) else { return nil }

        let elevationM = cleanDouble(dict["elevation"] ?? dict["elevationM"] ?? dict["Elev"] ?? dict["elev"] ?? dict["Elevation"])
        let maxKW = cleanInt(dict["maxPower"] ?? dict["maxPowerKW"] ?? dict["kW"] ?? dict["kw"] ?? dict["Max Power (kW)"] ?? dict["MaxPower"])
        let status = cleanString(dict["status"] ?? dict["Status"] ?? dict["statusRaw"])
        let opened = parseDate(dict["dateOpened"] ?? dict["opened"] ?? dict["Opened"] ?? dict["Open Date"] ?? dict["openDate"])

        let hours = cleanString(dict["hours"] ?? dict["Hours"])
        let parking = cleanString(dict["parking"] ?? dict["Parking"])
        let otherEVsOK = cleanBool(dict["otherEVs"] ?? dict["otherEVsOK"] ?? dict["Other EVs"] ?? dict["Open To"])

        let stallTotal = cleanInt(dict["stallCount"] ?? dict["stalls"] ?? dict["Stalls"] ?? dict["stall_count"])
        let stallsUrban = cleanInt(dict["stallsUrban"] ?? dict["stallCountUrban"] ?? dict["Urban"] ?? dict["stalls_urban"])
        let stallsV2 = cleanInt(dict["stallsV2"] ?? dict["stallCountV2"] ?? dict["V2"] ?? dict["stalls_v2"])
        let stallsV3 = cleanInt(dict["stallsV3"] ?? dict["stallCountV3"] ?? dict["V3"] ?? dict["stalls_v3"])
        let stallsV4 = cleanInt(dict["stallsV4"] ?? dict["stallCountV4"] ?? dict["V4"] ?? dict["stalls_v4"])

        let stallsText = dict["Stalls"] ?? dict["stallType"] ?? dict["stallSummary"]
        let parsedText = parseStallsString(stallsText)

        let resolvedTotal = stallTotal ?? parsedText.total
        let resolvedV2 = stallsV2 ?? parsedText.v2
        let resolvedV3 = stallsV3 ?? parsedText.v3
        let resolvedV4 = stallsV4 ?? parsedText.v4
        let resolvedUrban = stallsUrban ?? parsedText.urban

        let plugs = parsePlugs(from: dict)

        return MEVSCISite(
            id: id,
            name: name,
            street: street,
            city: city,
            state: state,
            zip: zip,
            country: country,
            latitude: lat,
            longitude: lon,
            elevationM: elevationM,
            stallCount: resolvedTotal,
            stallsUrban: resolvedUrban,
            stallsV2: resolvedV2,
            stallsV3: resolvedV3,
            stallsV4: resolvedV4,
            maxPowerKW: maxKW,
            statusRaw: status,
            dateOpened: opened,
            hours: hours,
            parking: parking,
            otherEVsOK: otherEVsOK,
            plugTeslaTPC: plugs.tpc,
            plugNACS: plugs.nacs,
            plugCCS1: plugs.ccs1,
            plugCCS2: plugs.ccs2,
            plugType2: plugs.type2,
            plugGBT: plugs.gbt
        )
    }

    static func parseSites(from data: Data) throws -> [MEVSCISite] {
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard let arr = obj as? [Any] else { return [] }

        var out: [MEVSCISite] = []
        out.reserveCapacity(arr.count)

        for item in arr {
            guard let dict = item as? [String: Any] else { continue }
            if let site = parseSite(dict) { out.append(site) }
        }
        return out
    }
}

// MARK: - Store

@MainActor
public final class MEVSuperchargeInfoStore: ObservableObject {
    @Published public private(set) var sites: [MEVSCISite] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?

    public init() {}

    public func refresh() { Task { await load() } }
    public func loadIfNeeded() { if sites.isEmpty && !isLoading { refresh() } }

    private func endpoint() -> URL {
        // Dataset endpoint used by the community site
        URL(string: "https://supercharge.info/service/supercharge/allSites")!
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var req = URLRequest(url: endpoint())
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, resp) = try await URLSession.shared.data(for: req)

            if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw NSError(domain: "MEVSCI", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"
                ])
            }

            let parsed = try MEVSCIImport.parseSites(from: data)
            self.sites = parsed
        } catch {
            self.errorMessage = "Failed to load supercharge.info sites: \(error.localizedDescription)"
        }
    }
}

// MARK: - Location

final class MEVLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authorization: CLAuthorizationStatus = .notDetermined
    @Published var location: CLLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
        }
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        Task { @MainActor in
            self.location = latest
        }
    }
}

// MARK: - View

@MainActor
public struct MEVSuperchargeNearMeView: View {

    public init() {}

    @StateObject private var store = MEVSuperchargeInfoStore()
    @StateObject private var loc = MEVLocationManager()

    @Environment(\.openURL) private var openURL

    @State private var selected: MEVSCISite?
    @State private var tab: Int = 0

    public var body: some View {
        VStack(spacing: 0) {

            Picker("", selection: $tab) {
                Text("List").tag(0)
                Text("Map").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 10)

            content
        }
        .navigationTitle("Superchargers Near Me")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Refresh")
            }
        }
        .onAppear {
            loc.request()
            store.loadIfNeeded()
        }
        .sheet(item: $selected) { site in
            MEVSuperchargeSiteDetailView(
                site: site,
                openAppleMaps: { openAppleMaps(site) },
                openGoogleMaps: { openGoogleMaps(site) }
            )
        }
    }

    // MARK: - Navigation helpers

    private func openAppleMaps(_ site: MEVSCISite) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: site.coordinate))
        item.name = site.name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func openGoogleMaps(_ site: MEVSCISite) {
        let lat = site.latitude
        let lon = site.longitude

        guard
            let appURL = URL(string: "comgooglemaps://?daddr=\(lat),\(lon)&directionsmode=driving"),
            let webURL = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lon)&travelmode=driving")
        else { return }

        #if canImport(UIKit)
        UIApplication.shared.open(appURL, options: [:]) { success in
            if !success {
                UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
            }
        }
        #else
        openURL(webURL)
        #endif
    }

    // MARK: - Derived lists

    private var sortedNearMe: [(site: MEVSCISite, miles: Double?)] {
        let user = loc.location
        let items = store.sites.map { s -> (MEVSCISite, Double?) in
            guard let user else { return (s, nil) }
            let d = CLLocation(latitude: s.latitude, longitude: s.longitude)
                .distance(from: user) / 1609.344
            return (s, d)
        }
        return items.sorted {
            switch ($0.1, $1.1) {
            case let (a?, b?): return a < b
            case (_?, nil): return true
            case (nil, _?): return false
            default: return $0.0.name < $1.0.name
            }
        }
    }

    private var closestFive: [(site: MEVSCISite, miles: Double)] {
        sortedNearMe
            .compactMap { pair in
                guard let m = pair.miles else { return nil }
                return (pair.site, m)
            }
            .prefix(5)
            .map { $0 }
    }

    private var remainderAfterClosestFive: [(site: MEVSCISite, miles: Double?)] {
        guard loc.location != nil else { return sortedNearMe }
        let ids = Set(closestFive.map { $0.site.id })
        return sortedNearMe.filter { !ids.contains($0.site.id) }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.sites.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                Text("Loading supercharger dataset…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = store.errorMessage, store.sites.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button("Try Again") { store.refresh() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            if tab == 0 { listView } else { mapView }
        }
    }

    // MARK: - List

    private var listView: some View {
        List {
            Section {
                MEVDisclaimerCard()
                    .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
            }

            if loc.location == nil {
                Section("Closest 5") {
                    Label("Enable Location Services to compute closest sites.", systemImage: "location.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Closest 5") {
                    ForEach(closestFive, id: \.site.id) { row in
                        MEVSiteRow(
                            site: row.site,
                            miles: row.miles,
                            onOpenDetail: { selected = row.site },
                            onAppleMaps: { openAppleMaps(row.site) },
                            onGoogleMaps: { openGoogleMaps(row.site) }
                        )
                    }
                }
            }

            Section("Nearby") {
                ForEach(remainderAfterClosestFive.prefix(250), id: \.site.id) { row in
                    MEVSiteRow(
                        site: row.site,
                        miles: row.miles,
                        onOpenDetail: { selected = row.site },
                        onAppleMaps: { openAppleMaps(row.site) },
                        onGoogleMaps: { openGoogleMaps(row.site) }
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { store.refresh() }
    }

    // MARK: - Map

    private var mapView: some View {
        let center = loc.location?.coordinate ?? CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35)
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0))

        return Map(initialPosition: .region(region)) {
            ForEach(sortedNearMe.prefix(400), id: \.site.id) { row in
                Annotation(row.site.name, coordinate: row.site.coordinate) {
                    Button {
                        selected = row.site
                    } label: {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                MEVDisclaimerCard(compact: true)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                if let first = closestFive.first {
                    HStack {
                        Text("Closest: \(first.site.name)")
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)

                        Spacer()

                        Text(String(format: "%.1f mi", first.miles))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button {
                            openAppleMaps(first.site)
                        } label: {
                            Image(systemName: "map")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            openGoogleMaps(first.site)
                        } label: {
                            Image(systemName: "globe")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 12)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button { store.refresh() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .buttonStyle(.bordered)

                Spacer()

                Button { tab = 0 } label: { Label("List", systemImage: "list.bullet") }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Row

private struct MEVSiteRow: View {
    let site: MEVSCISite
    let miles: Double?

    let onOpenDetail: () -> Void
    let onAppleMaps: () -> Void
    let onGoogleMaps: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack(alignment: .firstTextBaseline) {
                Text(site.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if let miles {
                    Text(String(format: "%.1f mi", miles))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let addr = site.addressLine {
                Text(addr)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            let stalls = site.stallsShortLabel
            let plugs = site.plugsShortLabel
            let power = site.powerShortLabel

            let left = [stalls, plugs].compactMap { $0 }.joined(separator: " ")
            let right = power

            if !left.isEmpty || right != nil {
                HStack(spacing: 8) {
                    if !left.isEmpty {
                        Text(left)
                            .font(.footnote.weight(.semibold))
                    }
                    if let right {
                        Text("• \(right)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Label(site.status.title, systemImage: site.status.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button(action: onAppleMaps) {
                    Label("Apple Maps", systemImage: "map")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: onGoogleMaps) {
                    Label("Google Maps", systemImage: "globe")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button(action: onOpenDetail) {
                    Label("Details", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Open details")
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { onOpenDetail() }
    }
}

// MARK: - Detail

private struct MEVSuperchargeSiteDetailView: View {
    let site: MEVSCISite
    let openAppleMaps: () -> Void
    let openGoogleMaps: () -> Void

    private func valueOrNotListed(_ s: String?) -> String {
        let t = (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Not listed" : t
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    VStack(alignment: .leading, spacing: 10) {
                        Text(site.name)
                            .font(.title2.weight(.semibold))

                        if let addr = site.addressLine {
                            Text(addr)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let loc = site.localityLine {
                            Text(loc)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        let line = [site.stallsShortLabel, site.plugsShortLabel]
                            .compactMap { $0 }
                            .joined(separator: " ")

                        if !line.isEmpty || site.powerShortLabel != nil {
                            HStack(spacing: 8) {
                                if !line.isEmpty {
                                    Text(line)
                                        .font(.headline)
                                }
                                if let p = site.powerShortLabel {
                                    Text("• \(p)")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if let openFor = site.openForString {
                            Text("Open for: \(openFor)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 10) {
                            Button(action: openAppleMaps) {
                                Label("Apple Maps", systemImage: "map")
                            }
                            .buttonStyle(.borderedProminent)

                            Button(action: openGoogleMaps) {
                                Label("Google Maps", systemImage: "globe")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 4)
                    }
                    .padding(14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        MEVKeyValueRow(label: "Stalls", value: valueOrNotListed(site.stallsShortLabel))
                        MEVKeyValueRow(label: "Plugs", value: valueOrNotListed(site.plugsShortLabel))
                        MEVKeyValueRow(label: "Parking", value: valueOrNotListed(site.parking))
                        MEVKeyValueRow(label: "Date Opened", value: valueOrNotListed(site.openedDateString))
                        MEVKeyValueRow(label: "Elevation", value: valueOrNotListed(site.elevationFeetString))
                        MEVKeyValueRow(label: "GPS", value: "\(site.latitude), \(site.longitude)")
                        MEVKeyValueRow(label: "Hours", value: valueOrNotListed(site.hours))
                        MEVKeyValueRow(label: "Other EVs", value: site.otherEVsLine)
                        MEVKeyValueRow(label: "Supercharger Status", value: site.status.title)
                    }
                    .padding(14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    MEVStatusExplainerCard()
                }
                .padding(16)
            }
            .navigationTitle("Site Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct MEVKeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.footnote)
                .foregroundStyle(value == "Not listed" ? .secondary : .primary)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Cards

private struct MEVDisclaimerCard: View {
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                Text("Data source")
                    .font(.footnote.weight(.semibold))
                Text("Community dataset from supercharge.info. Always verify in Tesla’s official Find Us / in-car nav.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, compact ? 0 : 16)
    }
}

private struct MEVStatusExplainerCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Supercharger Status", systemImage: "list.bullet.rectangle")
                .font(.headline)

            Group {
                Text("• Open: Charging possible at all times (host facilities may vary).")
                Text("• Open - Limited Hours: Charging possible only during limited times.")
                Text("• Expanding: Partially open and being updated/expanded.")
                Text("• Construction: Progress visible at the site.")
                Text("• Permit: Tesla has submitted a permit/plan/application.")
                Text("• Plan: Placeholder for expected/rumored site.")
                Text("• Voting: Recent winner of Supercharger Voting.")
                Text("• Temporarily Closed: Charging not possible right now.")
                Text("• Permanently Closed: Charging not possible.")
                Text("• Custom: User-added custom marker.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        MEVSuperchargeNearMeView()
    }
}
#endif
