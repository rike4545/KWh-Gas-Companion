//
//  DetailVehicleView.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/24/25.
//


//
//  DetailVehicleView.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//

import SwiftUI

@MainActor
struct DetailVehicleView: View {

    private let id: UUID

    init(vehicle: VehicleProfile) {
        self.id = vehicle.id
    }

    init(profile: VehicleProfile) {
        self.id = profile.id
    }

    init(profileID: UUID) {
        self.id = profileID
    }

    var body: some View {
        VehicleProfileView(profileID: id)
    }
}
