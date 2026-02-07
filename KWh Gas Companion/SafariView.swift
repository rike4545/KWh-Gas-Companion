import SwiftUI
import SafariServices
import CoreLocation

/// Lightweight wrapper around SFSafariViewController
struct EmbeddedSafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Local location manager (renamed to avoid conflicts)
final class EVLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    private let manager = CLLocationManager()
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }
}

/// Safari-based Tesla Find Us viewer centered on user location
struct TeslaFindUsSafariView: View {
    @StateObject private var locManager = EVLocationManager()

    private func teslaURL(for loc: CLLocation) -> URL {
        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude
        let d = 0.5
        // bounds = south,west,north,east
        let bounds = "\(lat - d),\(lon - d),\(lat + d),\(lon + d)"
        var comps = URLComponents(string: "https://www.tesla.com/findus")!
        comps.queryItems = [
            .init(name: "bounds", value: bounds),
            .init(name: "functionType", value: "supercharger")
        ]
        return comps.url!
    }

    var body: some View {
        Group {
            if let loc = locManager.location {
                EmbeddedSafariView(url: teslaURL(for: loc))
                    .edgesIgnoringSafeArea(.bottom)
            } else {
                VStack(spacing: 12) {
                    ProgressView("Obtaining location…")
                    Text("Allow location access to load nearby Superchargers.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Service Locator")
    }
}

struct TeslaFindUsSafariView_Previews: PreviewProvider {
    static var previews: some View {
        TeslaFindUsSafariView()
    }
}
