//
//  TeslaMateAPIClient.swift
//  KWh Gas Companion
//
//  Lightweight TeslaMate API client for teslamateapi endpoints.
//

import Foundation
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

enum JSONValue: Decodable, Equatable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode(Double.self) { self = .number(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        if let v = try? container.decode([String: JSONValue].self) { self = .object(v); return }
        if let v = try? container.decode([JSONValue].self) { self = .array(v); return }
        self = .null
    }
}

extension JSONValue {
    var object: [String: JSONValue]? { if case .object(let v) = self { return v } else { return nil } }
    var array: [JSONValue]? { if case .array(let v) = self { return v } else { return nil } }
    var string: String? { if case .string(let v) = self { return v } else { return nil } }
    var bool: Bool? { if case .bool(let v) = self { return v } else { return nil } }
    var double: Double? {
        switch self {
        case .number(let v): return v
        case .string(let v): return Double(v)
        default: return nil
        }
    }

    func child(_ key: String) -> JSONValue? { object?[key] }
    func string(_ key: String) -> String? { child(key)?.string }
    func double(_ key: String) -> Double? { child(key)?.double }
    func array(_ key: String) -> [JSONValue]? { child(key)?.array }
}

struct TeslaMateAPIClient {
    let baseURL: URL
    let token: String?
    let forceProxyToken: Bool

    init?(baseURL: String, token: String?, forceProxyToken: Bool = false) {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let urlString = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: urlString) else { return nil }
        self.baseURL = url
        self.token = token?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? token : nil
        self.forceProxyToken = forceProxyToken
    }

    func getJSON(path: String, query: [URLQueryItem] = []) async throws -> JSONValue {
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        comps?.path = joinPath(base: baseURL.path, append: normalizedPath)
        var items: [URLQueryItem] = query
        if let token, shouldUseQueryToken(baseURL: baseURL, token: token) || forceProxyToken {
            let clean = token.replacingOccurrences(of: "?token=", with: "")
                .replacingOccurrences(of: "token=", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                items.append(URLQueryItem(name: "token", value: clean))
            }
        }
        if !items.isEmpty { comps?.queryItems = items }
        guard let url = comps?.url else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if let token, (shouldUseQueryToken(baseURL: baseURL, token: token) == false) && forceProxyToken == false {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    func ping() async throws -> Bool {
        let json = try await getJSON(path: "/api/ping")
        return json != .null
    }

    private func joinPath(base: String, append: String) -> String {
        let basePath = base.isEmpty ? "" : base
        if basePath.hasSuffix("/api") || basePath.hasSuffix("/api/") {
            if append.hasPrefix("/api/") {
                return basePath + String(append.dropFirst("/api".count))
            }
            if append == "/api" {
                return basePath
            }
        }
        if basePath.hasSuffix("/") {
            return basePath + append.dropFirst()
        }
        return basePath + append
    }

    private func shouldUseQueryToken(baseURL: URL, token: String) -> Bool {
        let lowerHost = baseURL.host?.lowercased() ?? ""
        if lowerHost.contains("myteslamate.com") { return true }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("token=") || trimmed.hasPrefix("?")
    }
}

@MainActor
final class TeslaMateDataStore: ObservableObject {
    struct CarSummary: Identifiable, Hashable {
        let id: Int
        let name: String
        let model: String?
        let vin: String?
    }

    struct ChargeSummary: Identifiable, Hashable {
        let id: Int
        let startedAt: String?
        let endedAt: String?
        let energyKWh: Double?
        let cost: Double?
        let location: String?
    }

    struct DriveSummary: Identifiable, Hashable {
        let id: Int
        let startedAt: String?
        let endedAt: String?
        let distance: Double?
    }

    @Published private(set) var cars: [CarSummary] = []
    @Published private(set) var charges: [ChargeSummary] = []
    @Published private(set) var drives: [DriveSummary] = []
    @Published private(set) var lastStatus: JSONValue? = nil
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: String? = nil

    @AppStorage("teslamate.live_activities.enabled") private var liveActivitiesEnabled: Bool = false
    private let selectedCarKey = "teslamate.selected_car_id"

    func refreshAll(baseURL: String, token: String?, useProxyToken: Bool = false, selectedCarID: Int? = nil) async {
        guard let client = TeslaMateAPIClient(baseURL: baseURL, token: token, forceProxyToken: useProxyToken) else {
            lastError = "Invalid TeslaMate URL"
            return
        }
        isLoading = true
        defer { isLoading = false }
        lastError = nil

        do {
            let carsJSON = try await client.getJSON(path: "/api/v1/cars")
            cars = parseCars(from: carsJSON)

            if UserDefaults.standard.object(forKey: selectedCarKey) == nil,
               let first = cars.first {
                UserDefaults.standard.set(first.id, forKey: selectedCarKey)
            }

            if let car = resolveCar(selectedCarID: selectedCarID) {
                lastStatus = try await client.getJSON(path: "/api/v1/cars/\(car.id)/status")
                charges = try await fetchCharges(client: client, carID: car.id)
                drives = try await fetchDrives(client: client, carID: car.id)

                if liveActivitiesEnabled {
                    await updateLiveActivity(
                        carName: car.name,
                        status: lastStatus,
                        charges: charges
                    )
                }
            }
        } catch {
            lastError = "TeslaMate API error: \(error.localizedDescription)"
        }
    }

    private func parseCars(from json: JSONValue) -> [CarSummary] {
        let carsArray: [JSONValue]
        if let arr = json.child("data")?.array("cars") {
            carsArray = arr
        } else if let arr = json.child("cars")?.array {
            carsArray = arr
        } else if let arr = json.array {
            carsArray = arr
        } else {
            carsArray = []
        }

        return carsArray.compactMap { item in
            let obj = item.object ?? [:]
            let id = Int(obj["car_id"]?.double ?? obj["id"]?.double ?? -1)
            guard id >= 0 else { return nil }
            let name = obj["name"]?.string ?? obj["display_name"]?.string ?? "Car \(id)"
            let details = obj["car_details"]?.object ?? [:]
            let model = details["model"]?.string ?? obj["model"]?.string
            let vin = details["vin"]?.string ?? obj["vin"]?.string
            return CarSummary(id: id, name: name, model: model, vin: vin)
        }
    }

    private func fetchCharges(client: TeslaMateAPIClient, carID: Int) async throws -> [ChargeSummary] {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let fmt = ISO8601DateFormatter()
        fmt.timeZone = TimeZone(secondsFromGMT: 0)

        let json = try await client.getJSON(
            path: "/api/v1/cars/\(carID)/charges",
            query: [
                URLQueryItem(name: "startDate", value: fmt.string(from: start)),
                URLQueryItem(name: "endDate", value: fmt.string(from: now))
            ]
        )
        let arr = json.child("data")?.array("charges")
            ?? json.child("charges")?.array
            ?? json.array
            ?? []
        return arr.compactMap { item in
            let obj = item.object ?? [:]
            let id = Int(obj["id"]?.double ?? -1)
            guard id >= 0 else { return nil }
            let startedAt = obj["start_date"]?.string ?? obj["start_date_time"]?.string ?? obj["start_date_time_utc"]?.string
            let endedAt = obj["end_date"]?.string ?? obj["end_date_time"]?.string ?? obj["end_date_time_utc"]?.string
            let energy = obj["energy_added"]?.double ?? obj["energy_added_kwh"]?.double ?? obj["kwh"]?.double ?? obj["charge_energy_added"]?.double
            let cost = obj["cost"]?.double ?? obj["price"]?.double
            let location = obj["geofence"]?.string ?? obj["location"]?.string ?? obj["address"]?.string
            return ChargeSummary(id: id, startedAt: startedAt, endedAt: endedAt, energyKWh: energy, cost: cost, location: location)
        }
    }

    private func fetchDrives(client: TeslaMateAPIClient, carID: Int) async throws -> [DriveSummary] {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let fmt = ISO8601DateFormatter()
        fmt.timeZone = TimeZone(secondsFromGMT: 0)

        let json = try await client.getJSON(
            path: "/api/v1/cars/\(carID)/drives",
            query: [
                URLQueryItem(name: "startDate", value: fmt.string(from: start)),
                URLQueryItem(name: "endDate", value: fmt.string(from: now))
            ]
        )
        let arr = json.child("data")?.array("drives")
            ?? json.child("drives")?.array
            ?? json.array
            ?? []
        return arr.compactMap { item in
            let obj = item.object ?? [:]
            let id = Int(obj["id"]?.double ?? -1)
            guard id >= 0 else { return nil }
            let startedAt = obj["start_date"]?.string ?? obj["start_date_time"]?.string ?? obj["start_date_time_utc"]?.string
            let endedAt = obj["end_date"]?.string ?? obj["end_date_time"]?.string ?? obj["end_date_time_utc"]?.string
            let distance = obj["distance"]?.double ?? obj["distance_km"]?.double ?? obj["distance_mi"]?.double
            return DriveSummary(id: id, startedAt: startedAt, endedAt: endedAt, distance: distance)
        }
    }

    private func updateLiveActivity(
        carName: String,
        status: JSONValue?,
        charges: [ChargeSummary]
    ) async {
        guard let statusObj = status?.object else { return }
        let battery = Int(statusObj["battery_level"]?.double ?? -1)
        if battery < 0 { return }
        let chargingState = statusObj["charging_state"]?.string ?? "unknown"
        let latestCharge = charges.first

        let snapshot = TeslaMateWidgetSnapshot(
            vehicleName: carName,
            batteryLevel: battery,
            chargingState: chargingState,
            energyAddedKWh: latestCharge?.energyKWh,
            cost: latestCharge?.cost,
            updatedAt: Date()
        )
        TeslaMateWidgetStore.save(snapshot)
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "TeslaMateStatusWidget")
#endif

        await TeslaMateLiveActivityManager.shared.startOrUpdate(
            vehicleName: carName,
            batteryLevel: battery,
            chargingState: chargingState,
            energyAddedKWh: latestCharge?.energyKWh,
            cost: latestCharge?.cost
        )
    }

    private func resolveCar(selectedCarID: Int?) -> CarSummary? {
        if let id = selectedCarID, let match = cars.first(where: { $0.id == id }) {
            return match
        }
        return cars.first
    }
}
