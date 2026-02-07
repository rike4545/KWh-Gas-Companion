//
//  ProfileStore.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//

import Foundation
import Combine

@MainActor
final class ProfileStore: ObservableObject {

    // MARK: - Notifications (legacy observers)
    static let vehicleProfilesDidChangeNotification = Notification.Name("ProfileStore.vehicleProfilesDidChange")

    // MARK: - Published state

    @Published var vehicles: [VehicleProfile] = [] {
        didSet {
            guard !isBootstrapping else { return }
            normalizeSelectionIfNeeded()
            refreshTrackedCache()
            persistAsync()
            notifyVehiclesChanged()
        }
    }

    /// Canonical selection: UUID? (matches VehicleProfile.id)
    @Published var selectedVehicleID: UUID? {
        didSet {
            guard !isBootstrapping else { return }
            normalizeSelectionIfNeeded()
            refreshTrackedCache()
            persistAsync()
        }
    }

    /// Convenience (some screens expect this)
    @Published var currencyCode: String = (Locale.current.currency?.identifier ?? "USD")

    /// VIN tools: stable “current vehicle VIN”
    @Published private(set) var trackedVehicleVIN: String = ""

    /// Optional convenience
    @Published private(set) var trackedVehicleName: String = ""

    /// Many screens want this
    var selectedVehicle: VehicleProfile? {
        guard let id = selectedVehicleID else { return nil }
        return vehicles.first(where: { $0.id == id })
    }

    // MARK: - Persistence

    private let fileName = "profiles_v1.json"
    private var isBootstrapping = true
    private let persistQueue = DispatchQueue(label: "ProfileStore.persist", qos: .utility)

    init() {
        load()
        normalizeSelectionIfNeeded()
        refreshTrackedCache()
        isBootstrapping = false
    }

    // MARK: - Public API (current)

    func load() {
        do {
            let url = try persistenceURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)

            let decoded = try JSONDecoder().decode(Payload.self, from: data)

            // Avoid didSet cascades while bootstrapping
            isBootstrapping = true
            vehicles = decoded.vehicles
            selectedVehicleID = decoded.selectedVehicleID
            isBootstrapping = false
        } catch {
            // Fail silently; don't crash app
        }
    }

    func add(_ vehicle: VehicleProfile) {
        vehicles.append(vehicle)
        vehicles.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        if selectedVehicleID == nil {
            selectedVehicleID = vehicle.id
        }
    }

    func update(_ vehicle: VehicleProfile) {
        guard let idx = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        vehicles[idx] = vehicle
        vehicles.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func removeVehicle(id: UUID) {
        vehicles.removeAll { $0.id == id }
        if selectedVehicleID == id {
            selectedVehicleID = vehicles.first?.id
        }
    }

    func selectVehicle(id: UUID) {
        selectedVehicleID = id
    }

    func setSelected(_ id: UUID?) {
        selectedVehicleID = id
    }

    // MARK: - Compatibility API (older code paths that pass String UUIDs)

    func allVehicleProfiles() -> [VehicleProfile] { vehicles }

    func currentVehicleProfile() -> VehicleProfile? { selectedVehicle }

    func setCurrentVehicle(_ id: String) { setSelected(id) }

    func addVehicle(_ v: VehicleProfile) { add(v) }

    func deleteVehicle(id: String) { delete(id) }

    func delete(_ vehicleID: String) {
        if let uuid = UUID(uuidString: vehicleID) {
            removeVehicle(id: uuid)
            return
        }
        // fallback: match by uuidString text (in case caller passes weird casing/spaces)
        let trimmed = vehicleID.trimmingCharacters(in: .whitespacesAndNewlines)
        vehicles.removeAll { $0.id.uuidString == trimmed }
        if selectedVehicleID?.uuidString == trimmed {
            selectedVehicleID = vehicles.first?.id
        }
    }

    func setSelected(_ vehicleID: String?) {
        guard let vehicleID else {
            selectedVehicleID = nil
            return
        }
        let trimmed = vehicleID.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedVehicleID = UUID(uuidString: trimmed)
    }

    func upsertVehicleProfile(_ v: VehicleProfile, setCurrent: Bool = false) {
        if vehicles.contains(where: { $0.id == v.id }) {
            update(v)
        } else {
            add(v)
        }
        if setCurrent { selectedVehicleID = v.id }
    }

    // MARK: - Private

    private struct Payload: Codable {
        var vehicles: [VehicleProfile]
        var selectedVehicleID: UUID?

        // ✅ Migration-safe decode:
        // - Prefer UUID if present
        // - Fall back to String UUID if older payload stored it as String
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            vehicles = try c.decode([VehicleProfile].self, forKey: .vehicles)

            if let uuid = try? c.decodeIfPresent(UUID.self, forKey: .selectedVehicleID) {
                selectedVehicleID = uuid
                return
            }

            if let str = try? c.decodeIfPresent(String.self, forKey: .selectedVehicleID),
               let uuid = UUID(uuidString: str.trimmingCharacters(in: .whitespacesAndNewlines)) {
                selectedVehicleID = uuid
                return
            }

            selectedVehicleID = nil
        }

        init(vehicles: [VehicleProfile], selectedVehicleID: UUID?) {
            self.vehicles = vehicles
            self.selectedVehicleID = selectedVehicleID
        }
    }

    private func normalizeSelectionIfNeeded() {
        if selectedVehicleID == nil {
            selectedVehicleID = vehicles.first?.id
            return
        }
        if let sel = selectedVehicleID, !vehicles.contains(where: { $0.id == sel }) {
            selectedVehicleID = vehicles.first?.id
        }
    }

    private func refreshTrackedCache() {
        trackedVehicleVIN = selectedVehicle?.vin ?? ""
        trackedVehicleName = selectedVehicle?.displayName ?? ""
    }

    private func persistAsync() {
        let snapshotVehicles: [VehicleProfile] = vehicles
        let snapshotSelected: UUID? = selectedVehicleID
        let fileName = self.fileName

        persistQueue.async {
            do {
                let payload = Payload(vehicles: snapshotVehicles, selectedVehicleID: snapshotSelected)
                let data = try JSONEncoder().encode(payload)
                let url = try Self.persistenceURLStatic(fileName: fileName)
                try data.write(to: url, options: [.atomic])
            } catch {
                // ignore
            }
        }
    }

    private func persistenceURL() throws -> URL {
        try Self.persistenceURLStatic(fileName: fileName)
    }

    private nonisolated static func persistenceURLStatic(fileName: String) throws -> URL {
        let dir = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let bundle = Bundle.main.bundleIdentifier ?? "KWhGasCompanion"
        let appDir = dir.appendingPathComponent(bundle, isDirectory: true)
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir.appendingPathComponent(fileName)
    }

    private func notifyVehiclesChanged() {
        NotificationCenter.default.post(name: Self.vehicleProfilesDidChangeNotification, object: nil)
    }
}
