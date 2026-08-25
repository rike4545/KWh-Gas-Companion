//
//  PublicIncentiveFinderView.swift
//  KWh Gas Companion
//
//

// =============================
// File: PublicIncentiveFinderView.swift
// =============================
import SwiftUI
import CoreLocation
import MapKit

/// PublicIncentiveFinderView
/// Location & vehicle-based incentive browser (offline stub + bookmarking).
@MainActor
public struct PublicIncentiveFinderView: View {
    @StateObject private var locator = LocationHelper()
    @State private var vehicleMake: String = "Tesla"
    @State private var vehicleModel: String = "Model 3"
    @State private var vehicleYear: String = "2023"

    @State private var saved: Set<String> = [] // bookmark by id

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Your Vehicle") {
                    TextField("Make", text: $vehicleMake)
                    TextField("Model", text: $vehicleModel)
                    TextField("Year", text: $vehicleYear)
                }

                Section(header: headerView) {
                    let stateCode = locator.stateCode ?? "—"
                    ForEach(Self.incentives[stateCode] ?? []) { inc in
                        IncentiveRow(inc: inc, saved: saved.contains(inc.id)) {
                            if saved.contains(inc.id) { saved.remove(inc.id) } else { saved.insert(inc.id) }
                        }
                    }
                    if (Self.incentives[stateCode] ?? []).isEmpty {
                        Text("No incentives in \(stateCode). Try another state or check back soon.")
                            .foregroundStyle(.secondary)
                    }
                }

                if !saved.isEmpty {
                    Section("Saved") {
                        ForEach(saved.sorted(), id: \.self) { id in
                            if let inc = Self.allIncentives[id] { IncentiveSavedRow(inc: inc) }
                        }
                    }
                }
            }
            .navigationTitle("Incentives")
            .task { await locator.request() }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Menu("State") { ForEach(Self.states, id: \.self) { code in Button(code) { locator.overrideState(code) } } } } }
        }
    }

    private var headerView: some View {
        HStack { Image(systemName: "mappin.and.ellipse"); Text(locator.stateCode ?? "Locating…"); Spacer(); if locator.isLocating { ProgressView() } }
    }

    // MARK: - Static data (replace with API/DB later)
    public struct Incentive: Identifiable, Hashable { public let id: String; public let title: String; public let kind: Kind; public let detail: String; public let url: String; public enum Kind: String { case rebate = "Rebate", credit = "Tax Credit", hov = "HOV", utility = "Utility" } }

    static let incentives: [String: [Incentive]] = [
        "NY": [
            .init(id: "ny-serc-evse", title: "State EVSE Rebate up to $1,000", kind: .rebate, detail: "Residential charger rebate via utility participation.", url: "https://afdc.energy.gov"),
            .init(id: "ny-hov", title: "HOV lane access (Clean Pass)", kind: .hov, detail: "Eligible EVs may use HOV on select LI/NYC roads.", url: "https://www.dot.ny.gov")
        ],
        "CA": [
            .init(id: "ca-cvrp", title: "Clean Vehicle Rebate Project", kind: .rebate, detail: "Income-capped rebates for eligible EVs.", url: "https://cleanvehiclerebate.org"),
            .init(id: "ca-utility", title: "Utility Off-Peak Discounts", kind: .utility, detail: "TOU EV plans from major IOUs.", url: "https://www.cpuc.ca.gov")
        ]
    ]

    static let allIncentives: [String: Incentive] = incentives.values.flatMap { $0 }.reduce(into: [:]) { $0[$1.id] = $1 }
    static let states = ["AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","IA","ID","IL","IN","KS","KY","LA","MA","MD","ME","MI","MN","MO","MS","MT","NC","ND","NE","NH","NJ","NM","NV","NY","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VA","VT","WA","WI","WV","WY"]
}

fileprivate struct IncentiveRow: View { let inc: PublicIncentiveFinderView.Incentive; let saved: Bool; let toggle: ()->Void; var body: some View { HStack(alignment: .top, spacing: 12) { VStack(alignment: .leading, spacing: 4) { Text(inc.title).font(.body).bold(); Text("\(inc.kind.rawValue) • \(inc.detail)").font(.footnote).foregroundStyle(.secondary) }; Spacer(); Button(action: toggle) { Image(systemName: saved ? "bookmark.fill" : "bookmark") } } }
}
fileprivate struct IncentiveSavedRow: View { let inc: PublicIncentiveFinderView.Incentive; var body: some View { VStack(alignment: .leading, spacing: 4) { Text(inc.title).font(.body); Text(inc.detail).font(.footnote).foregroundStyle(.secondary) } }
}

fileprivate final class LocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var stateCode: String? = nil
    @Published var isLocating: Bool = false
    private let manager = CLLocationManager()
    private var overridden: String? = nil

    func request() async {
        if overridden != nil { self.stateCode = overridden; return }
        isLocating = true
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    func overrideState(_ code: String) { overridden = code; stateCode = code }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { defer { isLocating = false }; guard let loc = locations.first else { return }; fetchState(for: loc) }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { isLocating = false }
    private func fetchState(for loc: CLLocation) {
        Task { [weak self] in
            guard let self else { return }
            let mapItems = try? await MapKitCompat.reverseGeocodeMapItems(for: loc)
            let fullAddress = mapItems?.first?.compatFullAddress
            self.stateCode = Self.extractUSStateCode(from: fullAddress)
        }
    }

    private static func extractUSStateCode(from fullAddress: String?) -> String? {
        guard let fullAddress else { return nil }
        let pattern = #"\b([A-Z]{2})\s*(?:\d{5}(?:-\d{4})?)?\b"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: []),
              let match = re.firstMatch(
                  in: fullAddress,
                  options: [],
                  range: NSRange(fullAddress.startIndex..<fullAddress.endIndex, in: fullAddress)
              ),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: fullAddress) else { return nil }
        return String(fullAddress[range])
    }
}
