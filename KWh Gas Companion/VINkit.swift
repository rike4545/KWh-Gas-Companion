//  VINKit.swift
//  KWh Gas Companion
//
//  Shared VIN helpers + file-backed repository (uses Persistence.swift).
//  Also performs a one-time migration from legacy UserDefaults keys.

import Foundation

// MARK: - VIN helpers
enum VIN {
    /// Uppercases, removes invalid chars (I, O, Q), strips non-alphanumerics, truncates to 17.
    static func sanitize(_ input: String) -> String {
        input.uppercased()
            .filter { $0.isNumber || $0.isLetter }
            .replacingOccurrences(of: "I", with: "")
            .replacingOccurrences(of: "O", with: "")
            .replacingOccurrences(of: "Q", with: "")
            .prefix(17)
            .map(String.init)
            .joined()
    }

    /// Basic format check (17 chars; excludes I/O/Q).
    static func isValid(_ vin: String) -> Bool {
        let v = sanitize(vin)
        guard v.count == 17 else { return false }
        return v.allSatisfy { $0.isNumber || "ABCDEFGHJKLMNPRSTUVWXYZ".contains($0) }
    }

    /// Mask middle characters, e.g. 5YJ•••••••••3456
    static func mask(_ vin: String) -> String {
        let v = sanitize(vin)
        guard v.count == 17 else { return v }
        return "\(v.prefix(3))•••••••••\(v.suffix(4))"
    }
}

// MARK: - VIN repository (file-backed via Persistence)

protocol VINRepository {
    func loadVIN() -> String?
    func saveVIN(_ vin: String)
}

/// Stores the primary VIN in Documents as "primary_vin.json".
/// Prefers a live VehicleProfile VIN if provided; otherwise loads from file.
/// Silently migrates from legacy UserDefaults keys on first read.
struct DefaultVINRepository: VINRepository {
    var vehicleVINProvider: () -> String? = { nil }
    var onWriteVehicleVIN: ((String) -> Void)? = nil

    init(
        vehicleVINProvider: @escaping () -> String? = { nil },
        onWriteVehicleVIN: ((String) -> Void)? = nil
    ) {
        self.vehicleVINProvider = vehicleVINProvider
        self.onWriteVehicleVIN = onWriteVehicleVIN
    }

    private let fileName = "primary_vin.json"
    private let legacyKeys = ["primaryVIN", "vehicleVIN", "savedVIN"]

    func loadVIN() -> String? {
        // 1) Vehicle model wins (live source of truth)
        if let v = vehicleVINProvider()?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty {
            return VIN.sanitize(v)
        }

        // 2) File in Documents (Persistence.swift)
        if let s: String = Persistence.load(String.self, from: fileName), !s.isEmpty {
            return VIN.sanitize(s)
        }

        // 3) One-time migration from any legacy defaults key
        let d = UserDefaults.standard
        for key in legacyKeys {
            if let legacy = d.string(forKey: key), !legacy.isEmpty {
                let sanitized = VIN.sanitize(legacy)
                Persistence.save(sanitized, to: fileName)
                d.removeObject(forKey: key) // optional: cleanup after migration
                return sanitized
            }
        }
        return nil
    }

    func saveVIN(_ vin: String) {
        let s = VIN.sanitize(vin)
        onWriteVehicleVIN?(s)             // update your VehicleProfile/store
        Persistence.save(s, to: fileName) // single file-backed source
    }
}
