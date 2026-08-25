import CoreLocation
import MapKit

extension MKMapItem {
    var compatLocation: CLLocation? {
        if #available(iOS 26.0, *) {
            return location
        }
        return placemark.location
    }

    var compatCoordinate: CLLocationCoordinate2D {
        compatLocation?.coordinate ?? placemark.coordinate
    }

    var compatShortAddress: String? {
        if #available(iOS 26.0, *) {
            return address?.shortAddress?.trimmedNonEmpty ?? address?.fullAddress.trimmedNonEmpty
        }

        return [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmedNonEmpty
    }

    var compatCityName: String? {
        if #available(iOS 26.0, *) {
            return addressRepresentations?.cityName.trimmedNonEmpty
        }
        return placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty
            ?? placemark.subAdministrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty
    }

    var compatStateName: String? {
        if #available(iOS 26.0, *) {
            return addressRepresentations?.regionName.trimmedNonEmpty
        }
        return placemark.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty
    }

    var compatCountryCode: String? {
        if #available(iOS 26.0, *) {
            return addressRepresentations?.region?.identifier.uppercased().trimmedNonEmpty
        }
        return placemark.isoCountryCode?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty
    }

    var compatFullAddress: String? {
        if #available(iOS 26.0, *) {
            return addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)?.trimmedNonEmpty
                ?? address?.fullAddress.trimmedNonEmpty
        }

        return [
            compatShortAddress,
            compatCityName,
            compatStateName,
            placemark.postalCode?.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty,
            compatCountryCode
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
        .trimmedNonEmpty
    }
}

enum MapKitCompat {
    static func reverseGeocodeMapItems(for location: CLLocation) async throws -> [MKMapItem] {
        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else { return [] }
            return try await request.mapItems
        }

        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        return placemarks.map { MKMapItem(placemark: MKPlacemark(placemark: $0)) }
    }
}
