//  ChargingModels.swift
//  My EV Companion / My KWh Companion
//
//  Shared models for charging-related features.
//

import Foundation

enum MECChargingProvider: String, CaseIterable, Identifiable, Codable {
    case home
    case supercharger
    case dcFast
    case acPublic
    case workplace
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home:         return "Home"
        case .supercharger: return "Supercharger"
        case .dcFast:       return "DC Fast"
        case .acPublic:     return "AC Public"
        case .workplace:    return "Workplace"
        case .other:        return "Other"
        }
    }

    var systemImageName: String {
        switch self {
        case .home:         return "house.fill"
        case .supercharger: return "bolt.car"
        case .dcFast:       return "bolt.batteryblock"
        case .acPublic:     return "bolt.fill"
        case .workplace:    return "building.2"
        case .other:        return "ellipsis.circle"
        }
    }
}

struct MECChargingDataSession: Identifiable, Hashable, Codable {
    let id: UUID
    let vehicleId: UUID?
    let startDate: Date
    let endDate: Date
    let location: String
    let provider: MECChargingProvider
    let kWh: Double
    let cost: Double
    let tags: [String]

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var pricePerKWh: Double {
        guard kWh > 0 else { return 0 }
        return cost / kWh
    }
}

extension MECChargingDataSession {
    /// Lightweight sample data for previews / testing
    static func sampleSessions(now: Date = Date()) -> [MECChargingDataSession] {
        let calendar = Calendar.current

        func session(
            daysAgo: Int,
            hour: Int,
            kWh: Double,
            cost: Double,
            provider: MECChargingProvider,
            location: String,
            tags: [String] = [],
            vehicleId: UUID? = nil
        ) -> MECChargingDataSession {
            let baseDate = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            let start = calendar.date(
                bySettingHour: hour,
                minute: 0,
                second: 0,
                of: baseDate
            ) ?? baseDate

            let end = calendar.date(
                byAdding: .minute,
                value: Int(30 + kWh * 3),
                to: start
            ) ?? start

            return MECChargingDataSession(
                id: UUID(),
                vehicleId: vehicleId,
                startDate: start,
                endDate: end,
                location: location,
                provider: provider,
                kWh: kWh,
                cost: cost,
                tags: tags
            )
        }

        let car1 = UUID()
        let car2 = UUID()

        return [
            session(
                daysAgo: 2,
                hour: 21,
                kWh: 38,
                cost: 9.50,
                provider: .home,
                location: "Home",
                tags: ["off-peak"],
                vehicleId: car1
            ),
            session(
                daysAgo: 5,
                hour: 18,
                kWh: 56,
                cost: 24.00,
                provider: .supercharger,
                location: "I-95 Supercharger",
                tags: ["roadtrip"],
                vehicleId: car1
            ),
            session(
                daysAgo: 8,
                hour: 8,
                kWh: 18,
                cost: 7.20,
                provider: .workplace,
                location: "Office Garage",
                tags: ["work"],
                vehicleId: car1
            ),
            session(
                daysAgo: 15,
                hour: 20,
                kWh: 42,
                cost: 10.50,
                provider: .home,
                location: "Home",
                tags: ["off-peak"],
                vehicleId: car2
            ),
            session(
                daysAgo: 22,
                hour: 14,
                kWh: 30,
                cost: 15.00,
                provider: .dcFast,
                location: "EVGo Midtown",
                tags: ["errand"],
                vehicleId: car2
            ),
            session(
                daysAgo: 40,
                hour: 19,
                kWh: 50,
                cost: 22.50,
                provider: .supercharger,
                location: "NJ Turnpike Supercharger",
                tags: ["roadtrip"],
                vehicleId: car1
            )
        ]
    }
}
