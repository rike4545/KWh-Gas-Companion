import SwiftUI
import MapKit

@MainActor
struct ResilientMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let annotations: [MKPointAnnotation]
    let onTileError: (Error) -> Void

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ResilientMapView
        init(_ parent: ResilientMapView) { self.parent = parent }

        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
            parent.onTileError(error)

            // Fallback to a simpler configuration when tiles fail.
            if #available(iOS 17.0, *) {
                mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
            } else {
                mapView.mapType = .standard
            }

            // Nudge the region slightly to trigger a redraw without jarring the user.
            let r = mapView.region
            let delta = MKCoordinateSpan(latitudeDelta: r.span.latitudeDelta * 0.98,
                                         longitudeDelta: r.span.longitudeDelta * 0.98)
            mapView.setRegion(MKCoordinateRegion(center: r.center, span: delta), animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mv = MKMapView()
        mv.delegate = context.coordinator
        mv.showsUserLocation = true
        mv.pointOfInterestFilter = .includingAll
        mv.isRotateEnabled = true
        mv.isPitchEnabled = true

        if #available(iOS 17.0, *) {
            mv.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        } else {
            mv.mapType = .standard
        }

        mv.setRegion(region, animated: false)
        return mv
    }

    func updateUIView(_ mv: MKMapView, context: Context) {
        // Sync region with churn guard
        if !mv.region.isApproximately(region) {
            mv.setRegion(region, animated: false)
        }

        // Sync annotations (compare by coordinate + title without relying on Equatable/==)
        let existing = mv.annotations.compactMap { $0 as? MKPointAnnotation }
        if existing.count != annotations.count || !listsMatch(existing, annotations) {
            let toRemove = mv.annotations.filter { !($0 is MKUserLocation) }
            mv.removeAnnotations(toRemove)
            mv.addAnnotations(annotations)
        }
    }

    // MARK: - Helpers

    /// Compare two lists of point annotations by order, coordinate, and title.
    private func listsMatch(_ a: [MKPointAnnotation], _ b: [MKPointAnnotation]) -> Bool {
        guard a.count == b.count else { return false }
        for i in 0..<a.count {
            let lhs = a[i], rhs = b[i]
            if !(coordsEqual(lhs.coordinate, rhs.coordinate) &&
                 (lhs.title ?? "") == (rhs.title ?? "")) {
                return false
            }
        }
        return true
    }

    /// Coordinate equality with epsilon tolerance (no Equatable needed).
    private func coordsEqual(_ x: CLLocationCoordinate2D, _ y: CLLocationCoordinate2D, eps: CLLocationDegrees = 1e-6) -> Bool {
        abs(x.latitude - y.latitude) < eps && abs(x.longitude - y.longitude) < eps
    }
}

// MARK: - Region churn guard

private extension MKCoordinateRegion {
    func isApproximately(_ other: MKCoordinateRegion, eps: CLLocationDegrees = 1e-6) -> Bool {
        abs(center.latitude - other.center.latitude) < eps &&
        abs(center.longitude - other.center.longitude) < eps &&
        abs(span.latitudeDelta - other.span.latitudeDelta) < eps &&
        abs(span.longitudeDelta - other.span.longitudeDelta) < eps
    }
}
