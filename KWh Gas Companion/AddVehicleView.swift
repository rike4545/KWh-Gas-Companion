//  AddVehicleView.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//

import SwiftUI

@MainActor
struct AddVehicleView: View {

    @EnvironmentObject private var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    private let newId = UUID()

    var body: some View {
        VehicleProfileView(profileID: newId, setSelected: true)
            .navigationTitle("Add Vehicle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
    }
}
