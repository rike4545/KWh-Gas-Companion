//
//  VehicleIdentity.swift
//  KWh Gas Companion
//
//  Created by Bryan on 10/30/25.
//


// VehicleIdentity.swift
// My KWh Companion

import Foundation

public enum VehicleIdentity {
    /// Use the VehicleProfile.id as the canonical key everywhere.
    public static func key(for profile: VehicleProfile) -> String {
        profile.id.uuidString.lowercased()
    }

    public static func normVIN(_ vin: String?) -> String {
        (vin ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
    }

    public static func normPlate(_ plate: String?) -> String {
        (plate ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
    }

    /// Conservative name normalization (only used as *last* fallback).
    public static func normName(_ name: String?) -> String {
        (name ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
