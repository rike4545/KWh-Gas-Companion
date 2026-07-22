//
//  DirectConnectionAPIClient.swift
//  KWh Gas Companion
//
//  Lightweight direct API client for compatible vehicle dashboards.
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
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Double.self) { self = .number(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([String: JSONValue].self) { self = .object(value); return }
        if let value = try? container.decode([JSONValue].self) { self = .array(value); return }
        self = .null
    }
}

extension JSONValue {
    var object: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    var array: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    var string: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var bool: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var double: Double? {
        switch self {
        case .number(let value): return value
        case .string(let value): return Double(value)
        default: return nil
        }
    }

    func child(_ key: String) -> JSONValue? { object?[key] }
    func string(_ key: String) -> String? { child(key)?.string }
    func double(_ key: String) -> Double? { child(key)?.double }
    func array(_ key: String) -> [JSONValue]? { child(key)?.array }
}

extension Dictionary where Key == String, Value == JSONValue {
    func firstString(_ keys: [String]) -> String? {
        for key in keys {
            if let value = self[key]?.string?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    func firstDouble(_ keys: [String]) -> Double? {
        for key in keys {
            if let value = self[key]?.double {
                return value
            }
        }
        return nil
    }

    func nestedObject(_ keys: [String]) -> [String: JSONValue] {
        var out: [String: JSONValue] = [:]
        for key in keys {
            guard let object = self[key]?.object else { continue }
            out.merge(object) { current, _ in current }
        }
        return out
    }
}

struct DirectConnectionAPIClient {
    let baseURL: URL
    let token: String?
    let forceQueryToken: Bool

    init?(baseURL: String, token: String?, forceQueryToken: Bool = false) {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let urlString = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: urlString) else { return nil }

        self.baseURL = url
        self.token = token?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? token : nil
        self.forceQueryToken = forceQueryToken
    }

    func getJSON(path: String, query: [URLQueryItem] = []) async throws -> JSONValue {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        components?.path = joinPath(base: baseURL.path, append: normalizedPath)

        var queryItems = query
        if let token, shouldUseQueryToken(token: token) || forceQueryToken {
            let cleanToken = token
                .replacingOccurrences(of: "?token=", with: "")
                .replacingOccurrences(of: "token=", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanToken.isEmpty {
                queryItems.append(URLQueryItem(name: "token", value: cleanToken))
            }
        }
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token, shouldUseQueryToken(token: token) == false, forceQueryToken == false {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    func ping() async throws -> Bool {
        let json = try await getJSON(path: "/api/ping")
        return json != .null
    }

    func getFirstJSON(paths: [String], query: [URLQueryItem] = []) async throws -> JSONValue {
        var lastError: Error?
        for path in paths {
            do {
                return try await getJSON(path: path, query: query)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? URLError(.badURL)
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

    private func shouldUseQueryToken(token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("token=") || trimmed.hasPrefix("?")
    }
}

@MainActor
final class DirectConnectionDataStore: ObservableObject {
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
        let powerKW: Double?
        let startBatteryLevel: Double?
        let endBatteryLevel: Double?
    }

    struct DriveSummary: Identifiable, Hashable {
        let id: Int
        let startedAt: String?
        let endedAt: String?
        let distance: Double?
        let energyKWh: Double?
        let cost: Double?
        let gasSavings: Double?
        let efficiencyWhPerMile: Double?
    }

    @Published private(set) var cars: [CarSummary] = []
    @Published private(set) var charges: [ChargeSummary] = []
    @Published private(set) var drives: [DriveSummary] = []
    @Published private(set) var lastStatus: JSONValue? = nil
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String? = nil
    @Published private(set) var lastImportedCount = 0

    @AppStorage("direct_connection.live_activities.enabled") private var liveActivitiesEnabled = false
    private let selectedCarKey = "direct_connection.selected_car_id"

    func refreshAll(baseURL: String, token: String?, useProxyToken: Bool = false, selectedCarID: Int? = nil) async {
        guard let client = DirectConnectionAPIClient(baseURL: baseURL, token: token, forceQueryToken: useProxyToken) else {
            lastError = "Invalid connection URL"
            return
        }

        isLoading = true
        defer { isLoading = false }
        lastError = nil

        do {
            let carsJSON = try await client.getFirstJSON(paths: [
                "/api/v1/cars",
                "/api/cars",
                "/api/car"
            ])
            cars = parseCars(from: carsJSON)

            if UserDefaults.standard.object(forKey: selectedCarKey) == nil, let first = cars.first {
                UserDefaults.standard.set(first.id, forKey: selectedCarKey)
            }

            if let car = resolveCar(selectedCarID: selectedCarID) {
                let statusJSON = try await client.getFirstJSON(paths: [
                    "/api/v1/cars/\(car.id)/status",
                    "/api/car/\(car.id)/status",
                    "/api/car/status"
                ])
                lastStatus = flattenTeslaMateStatus(statusJSON)
                charges = try await fetchCharges(client: client, carID: car.id)
                drives = try await fetchDrives(client: client, carID: car.id)

                if liveActivitiesEnabled {
                    await updateLiveActivity(carName: car.name, status: lastStatus, charges: charges)
                }
            }
        } catch {
            lastError = "Connection error: \(error.localizedDescription)"
        }
    }

    func importFetchedCharges(into store: TeslaFiSessionStore) {
        let imported = makeImportedSessions(existing: store.rawSessions)
        store.append(imported)
        lastImportedCount = imported.count
    }

    private func parseCars(from json: JSONValue) -> [CarSummary] {
        let carsArray: [JSONValue]
        if let array = json.child("data")?.array("cars") {
            carsArray = array
        } else if let array = json.child("data")?.array("vehicles") {
            carsArray = array
        } else if let array = json.child("cars")?.array {
            carsArray = array
        } else if let array = json.child("vehicles")?.array {
            carsArray = array
        } else if let array = json.array {
            carsArray = array
        } else if let car = json.child("data")?.child("car") {
            carsArray = [car]
        } else if json.object != nil {
            carsArray = [json]
        } else {
            carsArray = []
        }

        return carsArray.compactMap { item in
            var object = item.object ?? [:]
            object.merge(object.nestedObject(["car", "vehicle", "car_details"])) { current, _ in current }
            let id = Int(object.firstDouble(["car_id", "vehicle_id", "id"]) ?? -1)
            guard id >= 0 else { return nil }
            let name = object.firstString(["name", "car_name", "display_name", "vehicle_name"]) ?? "Car \(id)"
            let details = object["car_details"]?.object ?? [:]
            let model = details.firstString(["model", "trim_badging"]) ?? object.firstString(["model", "trim_badging"])
            let vin = details.firstString(["vin"]) ?? object.firstString(["vin"])
            return CarSummary(id: id, name: name, model: model, vin: vin)
        }
    }

    private func fetchCharges(client: DirectConnectionAPIClient, carID: Int) async throws -> [ChargeSummary] {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let json = try await client.getFirstJSON(
            paths: [
                "/api/v1/cars/\(carID)/charges",
                "/api/car/\(carID)/charges",
                "/api/car/charges"
            ],
            query: [
                URLQueryItem(name: "startDate", value: formatter.string(from: start)),
                URLQueryItem(name: "endDate", value: formatter.string(from: now))
            ]
        )

        let array = json.child("data")?.array("charges")
            ?? json.child("data")?.array("charging_processes")
            ?? json.child("charges")?.array
            ?? json.child("charging_processes")?.array
            ?? json.child("data")?.array
            ?? json.array
            ?? []

        return array.compactMap { item in
            var object = item.object ?? [:]
            object.merge(object.nestedObject(["charge", "charging_process", "battery_details", "charger_details", "car_geodata", "geofence"])) { current, _ in current }
            let id = Int(object.firstDouble(["id", "charge_id", "charging_process_id"]) ?? -1)
            guard id >= 0 else { return nil }
            let startedAt = object.firstString(["start_date", "start_date_time", "start_date_time_utc", "started_at", "date"])
            let endedAt = object.firstString(["end_date", "end_date_time", "end_date_time_utc", "ended_at"])
            let energy = object.firstDouble(["energy_added", "energy_added_kwh", "kwh", "charge_energy_added", "charge_energy_added_kwh"])
            let cost = object.firstDouble(["cost", "price", "total_cost", "charge_cost"])
            let location = object.firstString(["geofence", "location", "address", "name"])
            let power = object.firstDouble(["charge_power", "power", "max_power", "charger_power", "charger_power_kw"])
            let startBattery = object.firstDouble(["start_battery_level", "battery_level_start", "start_soc", "start_rated_range_km"])
            let endBattery = object.firstDouble(["end_battery_level", "battery_level_end", "end_soc", "battery_level"])
            return ChargeSummary(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                energyKWh: energy,
                cost: cost,
                location: location,
                powerKW: power,
                startBatteryLevel: startBattery,
                endBatteryLevel: endBattery
            )
        }
        .sorted { ($0.startedAt ?? "") > ($1.startedAt ?? "") }
    }

    private func fetchDrives(client: DirectConnectionAPIClient, carID: Int) async throws -> [DriveSummary] {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let json = try await client.getFirstJSON(
            paths: [
                "/api/v1/cars/\(carID)/drives",
                "/api/car/\(carID)/drives",
                "/api/car/drives"
            ],
            query: [
                URLQueryItem(name: "startDate", value: formatter.string(from: start)),
                URLQueryItem(name: "endDate", value: formatter.string(from: now))
            ]
        )

        let array = json.child("data")?.array("drives")
            ?? json.child("drives")?.array
            ?? json.child("data")?.array
            ?? json.array
            ?? []

        return array.compactMap { item in
            var object = item.object ?? [:]
            object.merge(object.nestedObject(["drive", "start_position", "end_position"])) { current, _ in current }
            let id = Int(object.firstDouble(["id", "drive_id"]) ?? -1)
            guard id >= 0 else { return nil }
            let startedAt = object.firstString(["start_date", "start_date_time", "start_date_time_utc", "started_at", "date"])
            let endedAt = object.firstString(["end_date", "end_date_time", "end_date_time_utc", "ended_at"])
            let distance = object.firstDouble(["distance", "distance_mi", "distance_km"])
            let energy = object.firstDouble(["energy_used", "energy_used_kwh", "kwh_used", "consumption_kwh"])
            let cost = object.firstDouble(["cost", "drive_cost"])
            let gasSavings = object.firstDouble(["gas_savings", "fuel_savings"])
            let efficiency = object.firstDouble(["efficiency", "wh_per_mile", "avg_wh_per_mile", "consumption"])
            return DriveSummary(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                distance: distance,
                energyKWh: energy,
                cost: cost,
                gasSavings: gasSavings,
                efficiencyWhPerMile: efficiency
            )
        }
        .sorted { ($0.startedAt ?? "") > ($1.startedAt ?? "") }
    }

    private func makeImportedSessions(existing: [TeslaFiSession]) -> [TeslaFiSession] {
        let parser = FlexibleDateParser()
        var out: [TeslaFiSession] = []

        for charge in charges {
            guard
                let startedAt = charge.startedAt,
                let start = parser.date(from: startedAt),
                let energy = charge.energyKWh,
                energy > 0
            else { continue }

            let end = charge.endedAt.flatMap(parser.date(from:)) ?? start
            let costText = charge.cost.map { String($0) } ?? ""
            let powerText = charge.powerKW.map { String($0) } ?? ""
            let startBatteryText = charge.startBatteryLevel.map { String($0) } ?? ""
            let endBatteryText = charge.endBatteryLevel.map { String($0) } ?? ""
            let raw: [String: String] = [
                "Source": "TeslaMate",
                "TeslaMateChargeID": "\(charge.id)",
                "Start": startedAt,
                "End": charge.endedAt ?? "",
                "EnergyAddedKWh": "\(energy)",
                "Cost": costText,
                "Location": charge.location ?? "",
                "PowerKW": powerText,
                "StartBatteryLevel": startBatteryText,
                "EndBatteryLevel": endBatteryText
            ]

            let session = TeslaFiSession(
                startDate: start,
                endDate: max(end, start),
                energyAddedKWh: energy,
                cost: charge.cost,
                location: charge.location,
                raw: raw
            )

            let duplicate = existing.contains { $0.sessionHash == session.sessionHash }
                || out.contains { $0.sessionHash == session.sessionHash }
            if !duplicate {
                out.append(session)
            }
        }

        return out
    }

    private func flattenTeslaMateStatus(_ json: JSONValue) -> JSONValue {
        let root = json.child("data")?.child("status")?.object
            ?? json.child("status")?.object
            ?? json.child("data")?.object
            ?? json.object
            ?? [:]

        var flat = root
        for nested in [
            "battery_details",
            "car_status",
            "car_details",
            "car_geodata",
            "car_versions",
            "driving_details",
            "climate_details",
            "charger_details"
        ] {
            guard let object = root[nested]?.object else { continue }
            flat.merge(object) { current, _ in current }
        }

        if flat["car_version"] == nil, let version = flat["version"] {
            flat["car_version"] = version
        }
        if flat["charging_state"] == nil, let state = flat["charger_phases"] ?? flat["charger_actual_current"] {
            flat["charging_state"] = state
        }

        return .object(flat)
    }

    private func updateLiveActivity(carName: String, status: JSONValue?, charges: [ChargeSummary]) async {
        guard let statusObject = status?.object else { return }
        let battery = Int(statusObject["battery_level"]?.double ?? -1)
        guard battery >= 0 else { return }

        let chargingState = statusObject["charging_state"]?.string ?? "unknown"
        let latestCharge = charges.first

        let snapshot = ChargeWidgetSnapshot(
            vehicleName: carName,
            batteryLevel: battery,
            chargingState: chargingState,
            energyAddedKWh: latestCharge?.energyKWh,
            cost: latestCharge?.cost,
            updatedAt: Date()
        )
        ChargeWidgetStore.save(snapshot)
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "ChargeStatusWidget")
#endif

        await ChargeLiveActivityManager.shared.startOrUpdate(
            vehicleName: carName,
            batteryLevel: battery,
            chargingState: chargingState,
            energyAddedKWh: latestCharge?.energyKWh,
            cost: latestCharge?.cost
        )
    }

    private func resolveCar(selectedCarID: Int?) -> CarSummary? {
        if let selectedCarID, let match = cars.first(where: { $0.id == selectedCarID }) {
            return match
        }
        return cars.first
    }
}

private struct FlexibleDateParser {
    private let isoWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private let formatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd HH:mm:ss Z",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "MM/dd/yyyy HH:mm:ss",
            "M/d/yyyy h:mm:ss a"
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            return formatter
        }
    }()

    func date(from value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let date = isoWithFractional.date(from: trimmed) ?? iso.date(from: trimmed) {
            return date
        }
        for formatter in formatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }
}
