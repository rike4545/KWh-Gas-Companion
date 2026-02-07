//
//  DistanceUnit.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/17/25.
//


//
//  Units.swift
//  My EV Companion
//
//  iOS 17+ / Swift 6
//

import Foundation
import Observation

enum DistanceUnit: String, CaseIterable, Identifiable, Codable {
    case miles
    case kilometers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .miles: return "Miles"
        case .kilometers: return "Kilometers"
        }
    }

    var symbol: String {
        switch self {
        case .miles: return "mi"
        case .kilometers: return "km"
        }
    }

    var unitLength: UnitLength {
        switch self {
        case .miles: return .miles
        case .kilometers: return .kilometers
        }
    }

    static var defaultForDevice: DistanceUnit {
        Locale.current.measurementSystem == .metric ? .kilometers : .miles
    }
}

@Observable
final class AppSettings {
    private enum Keys {
        static let distanceUnit = "settings.distanceUnit"
    }

    var distanceUnit: DistanceUnit {
        didSet { UserDefaults.standard.set(distanceUnit.rawValue, forKey: Keys.distanceUnit) }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Keys.distanceUnit),
           let unit = DistanceUnit(rawValue: raw) {
            self.distanceUnit = unit
        } else {
            self.distanceUnit = .defaultForDevice
            UserDefaults.standard.set(self.distanceUnit.rawValue, forKey: Keys.distanceUnit)
        }
    }
}

enum Units {
    /// Format a distance where your source of truth is meters (recommended).
    static func formatDistance(meters: Double, unit: DistanceUnit, maxFractionDigits: Int = 1) -> String {
        let m = Measurement(value: meters, unit: UnitLength.meters).converted(to: unit.unitLength)
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = maxFractionDigits
        nf.minimumFractionDigits = 0
        let value = nf.string(from: NSNumber(value: m.value)) ?? String(format: "%.\(maxFractionDigits)f", m.value)
        return "\(value) \(unit.symbol)"
    }

    /// Convenience if you still store miles today (works immediately).
    static func formatDistance(miles: Double, unit: DistanceUnit, maxFractionDigits: Int = 1) -> String {
        let meters = miles * 1609.344
        return formatDistance(meters: meters, unit: unit, maxFractionDigits: maxFractionDigits)
    }

    /// EV efficiency display helper (optional but usually needed):
    /// - miles -> Wh/mi
    /// - km -> kWh/100km
    static func formatEfficiency(whPerMile: Double, unit: DistanceUnit, maxFractionDigits: Int = 0) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = maxFractionDigits

        switch unit {
        case .miles:
            let v = nf.string(from: NSNumber(value: whPerMile)) ?? "\(whPerMile)"
            return "\(v) Wh/mi"

        case .kilometers:
            // Convert Wh/mi -> kWh/100km
            // Wh/mi * (1 mi / 1.609344 km) = Wh/km
            // Wh/km * 100 / 1000 = kWh/100km
            let whPerKm = whPerMile / 1.609344
            let kWhPer100km = (whPerKm * 100.0) / 1000.0
            let v = nf.string(from: NSNumber(value: kWhPer100km)) ?? "\(kWhPer100km)"
            return "\(v) kWh/100km"
        }
    }
}
