//  GarageVehicleSummaryPreviewCompat.swift
//  KWh Gas Companion
//
//  Compatibility helpers for older call sites like:
//    GarageVehicleSummary(vehicles: GarageVehicleSummary.sampleVehicles)
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import Foundation

extension GarageVehicleSummary {

    /// Keeps older call sites compiling. Newer `GarageVehicleSummary` is assumed
    /// to be environment/store-driven, so this parameter is intentionally ignored.
    init(vehicles: [Any]) {
        self.init(
            displayName: "Sample Vehicle",
            make: "Unknown",
            model: "Unknown",
            lifetimeKWh: 0,
            lifetimeCost: 0
        )
    }

    /// Used only for previews / demo wiring in older files.
    static var sampleVehicles: [Any] { [] }
}
