//
//  LibreNavView.swift
//  KWh Gas Companion
//
//  Embeds LibreNav — the companion open-maps navigation app — as a first-class
//  in-app screen rather than a link-out.
//
//  Why a web view: LibreNav is a fully static browser app whose every data call
//  (Valhalla routing, Photon geocoding, Overpass chargers, basemap tiles) runs
//  against public OSM services at request time. There is nothing to bundle for
//  offline use, so hosting the shell locally would add moving parts without
//  buying capability. Loading the deployed build keeps a single source of truth.
//
//  ─────────────────────────────────────────────────────────────────────────
//  RELEASE INDEPENDENCE
//  ─────────────────────────────────────────────────────────────────────────
//  LibreNav ships on its OWN cadence and is never bundled into this binary.
//  Push to LibreNav's `main` → its deploy workflow builds the static export and
//  publishes to GitHub Pages → this screen serves the new build on next load.
//  No app rebuild, no App Store submission, no version coupling.
//
//  Staleness is bounded by GitHub Pages' `Cache-Control: max-age=600`, so a
//  fresh deploy is picked up within ~10 minutes; the Reload button calls
//  `reloadFromOrigin()` to bypass that cache and fetch immediately.
//
//  THE ONLY THINGS THAT COUPLE THE TWO CODEBASES — keep this list short, and
//  re-check it if LibreNav changes. None of them break the build; they fail
//  silently at runtime, which is why they are written down:
//
//    1. `baseURL` below — where LibreNav is deployed. Changing the repo name,
//       adding a custom domain, or moving off Pages requires editing it here.
//    2. The `librenav.vehicle` localStorage key and its `batteryKwh` /
//       `consumptionKwh100km` field names, used to seed the range model.
//       If LibreNav renames those, seeding quietly stops working (it does not
//       corrupt anything — `getVehicle()` just falls back to its defaults).
//    3. The `?trip=lat,lng,name|…&opts=` share-link format, which Route
//       Discovery stores as its route payload. LibreNav still decodes its own
//       legacy `?to=` links, so this format has proven stable, but a breaking
//       change there would invalidate saved routes.
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import WebKit
import CoreLocation

// MARK: - Screen

@MainActor
struct LibreNavView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @Environment(\.appThemeBox) private var themeBox

    @StateObject private var model = LibreNavWebModel()
    @StateObject private var locationGate = LibreNavLocationGate()

    /// Deployed LibreNav build. `trailingSlash: true` in its Next config, so the
    /// trailing slash matters — without it GitHub Pages issues a redirect.
    static let baseURL = URL(string: "https://rike4545.github.io/LibreNav/")!

    /// Optional trip to open on launch, as LibreNav's own share-link query
    /// (`trip=lat,lng,name|…&opts=…`). Route Discovery passes a saved route
    /// straight through here.
    private let tripQuery: String?
    private let title: String

    init(tripQuery: String? = nil, title: String = "Navigation") {
        self.tripQuery = tripQuery
        self.title = title
    }

    private var startURL: URL {
        guard let tripQuery, !tripQuery.isEmpty else { return Self.baseURL }
        return URL(string: "\(Self.baseURL.absoluteString)?\(tripQuery)") ?? Self.baseURL
    }

    var body: some View {
        ZStack {
            LibreNavWebView(
                url: startURL,
                vehicleSeed: vehicleSeed,
                model: model
            )
            .opacity(model.didFail ? 0 : 1)

            if model.isLoading && !model.didFail {
                ProgressView("Loading LibreNav…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if model.didFail {
                failureState
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    model.reload()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .disabled(model.isLoading)

                Button {
                    UIApplication.shared.open(startURL)
                } label: {
                    Label("Open in Safari", systemImage: "safari")
                }
            }
        }
        .task {
            // WKWebView only hands `navigator.geolocation` to the page when the
            // host app itself is authorized for location, so ask before load.
            locationGate.requestIfNeeded()
        }
    }

    private var failureState: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text("Couldn’t load LibreNav")
                .font(.headline)

            Text(model.failureMessage ?? "Check your connection and try again.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Try Again") { model.reload() }
                .buttonStyle(.borderedProminent)
        }
    }

    /// Seeds LibreNav's vehicle profile from the app's selected EV so its range
    /// estimates start from the user's real battery and efficiency.
    ///
    /// Only the two *stable* vehicle facts are seeded. State of charge is
    /// deliberately left to LibreNav's own default: this app does not track live
    /// SOC, and asserting a stale value would make the range warning lie.
    private var vehicleSeed: LibreNavVehicleSeed? {
        guard let vehicle = profileStore.selectedVehicle, vehicle.isEV else { return nil }

        let battery = vehicle.batteryCapacityKWh ?? 0
        // LibreNav wants kWh per 100 km; the app stores Wh per mile.
        // Wh/mi ÷ 16.09344 = kWh/100km  (100 km = 62.1371 mi, 1 kWh = 1000 Wh).
        let consumption = (vehicle.efficiencyWhPerMile ?? 0) / 16.09344

        guard battery > 0 || consumption > 0 else { return nil }
        return LibreNavVehicleSeed(batteryKwh: battery, consumptionKwh100km: consumption)
    }
}

// MARK: - Vehicle seed

struct LibreNavVehicleSeed: Equatable {
    let batteryKwh: Double
    let consumptionKwh100km: Double

    /// Matches LibreNav's `VehicleProfile` shape under its `librenav.vehicle`
    /// localStorage key. Only the keys we actually know are written; LibreNav
    /// merges over its own defaults (`{ ...DEFAULT_VEHICLE, ...stored }`), so
    /// omitting SOC/reserve leaves its defaults intact.
    var jsonObject: String {
        var fields: [String] = []
        if batteryKwh > 0 {
            fields.append("\"batteryKwh\":\(String(format: "%.2f", batteryKwh))")
        }
        if consumptionKwh100km > 0 {
            fields.append("\"consumptionKwh100km\":\(String(format: "%.2f", consumptionKwh100km))")
        }
        return "{\(fields.joined(separator: ","))}"
    }
}

// MARK: - Web view model

@MainActor
final class LibreNavWebModel: ObservableObject {
    @Published var isLoading = true
    @Published var didFail = false
    @Published var failureMessage: String?

    fileprivate weak var webView: WKWebView?

    /// Set once by the representable so a retry after a failed first load
    /// re-requests the right URL (including any trip query).
    fileprivate var startURL: URL?

    func reload() {
        didFail = false
        failureMessage = nil
        isLoading = true
        guard let webView else { return }
        if webView.url != nil {
            // `reloadFromOrigin`, not `reload`. GitHub Pages serves LibreNav
            // with `Cache-Control: max-age=600`, so a plain reload inside that
            // window can be served straight from cache and show the old build.
            // This button exists precisely to pull a fresh deploy, so it must
            // bypass the cache rather than revalidate against it.
            webView.reloadFromOrigin()
        } else if let startURL {
            webView.load(URLRequest(url: startURL))
        }
    }
}

// MARK: - UIViewRepresentable

private struct LibreNavWebView: UIViewRepresentable {
    let url: URL
    let vehicleSeed: LibreNavVehicleSeed?
    let model: LibreNavWebModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()

        // Write the vehicle profile before LibreNav's own scripts run, so its
        // first read of localStorage already sees it.
        if let vehicleSeed {
            // Precedence is the subtle part. LibreNav persists its own defaults
            // (75 kWh / 17 kWh per 100 km) to localStorage as soon as it runs,
            // so "a value is already stored" does NOT mean "the user chose it".
            // Letting stored values win unconditionally means the app's real
            // vehicle data never lands. Instead we record what we last seeded:
            // if the stored value still matches that, the user hasn't touched it
            // and we refresh it; once they edit a field inside LibreNav, their
            // value sticks.
            let js = """
            (function () {
              try {
                var key = 'librenav.vehicle';
                var seedKey = 'librenav.vehicle.hostSeed';
                var incoming = \(vehicleSeed.jsonObject);

                var stored = {};
                try { stored = JSON.parse(window.localStorage.getItem(key) || '{}') || {}; } catch (e) {}

                var hasSeededBefore = window.localStorage.getItem(seedKey) !== null;
                var lastSeed = {};
                try { lastSeed = JSON.parse(window.localStorage.getItem(seedKey) || '{}') || {}; } catch (e) {}

                var next = Object.assign({}, stored);
                Object.keys(incoming).forEach(function (field) {
                  // First seed ever: anything already stored is LibreNav's own
                  // first-run default, which the user never chose — overwrite it.
                  // After that, only refresh fields still equal to what we last
                  // wrote, so a value the user edited inside LibreNav sticks.
                  var untouched =
                    !hasSeededBefore ||
                    stored[field] === undefined ||
                    stored[field] === lastSeed[field];
                  if (untouched) next[field] = incoming[field];
                });

                window.localStorage.setItem(key, JSON.stringify(next));
                window.localStorage.setItem(seedKey, JSON.stringify(incoming));
              } catch (e) {}
            })();
            """
            controller.addUserScript(
                WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            )
        }

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        // Persistent store so LibreNav's saved places, recents and endpoint
        // settings survive between launches.
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false

        model.webView = webView
        model.startURL = url
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let model: LibreNavWebModel

        init(model: LibreNavWebModel) { self.model = model }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                model.isLoading = true
                model.didFail = false
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in model.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in self.fail(error) }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in self.fail(error) }
        }

        @MainActor
        private func fail(_ error: Error) {
            // A cancelled load is usually a redirect or a fast re-navigation,
            // not a real failure — don't flash the error state for it.
            let ns = error as NSError
            guard !(ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled) else { return }

            model.isLoading = false
            model.didFail = true
            model.failureMessage = ns.localizedDescription
        }
    }
}

// MARK: - Location authorization

/// LibreNav asks for position through `navigator.geolocation`. WKWebView only
/// serves that when the host app holds location authorization, so this nudges
/// the system prompt before the page needs it.
@MainActor
final class LibreNavLocationGate: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published private(set) var status: CLAuthorizationStatus

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func requestIfNeeded() {
        guard status == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor in self.status = newStatus }
    }
}
