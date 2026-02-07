//
//  DataDeletionView.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//
//  - Uses ProfileStore.vehicles (no vehicleCount / clearAllVehicles)
//  - Avoids $profileStore dynamic-member binding entirely
//  - Best-effort removes stored vehicle photos via VehicleImageStore.delete(id:)
//

import SwiftUI

@MainActor
struct DataDeletionView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var profileStore: ProfileStore

    @State private var confirmDeleteExpenses = false
    @State private var confirmDeleteVehicles = false

    var body: some View {
        List {
            Section {
                // Delete All Expenses
                Button(role: .destructive) {
                    confirmDeleteExpenses = true
                } label: {
                    HStack {
                        Label("Delete All Expenses", systemImage: "trash")
                        Spacer()
                        Text("\(entriesStore.entries.count)")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                }
                .confirmationDialog(
                    "Delete all expenses?",
                    isPresented: $confirmDeleteExpenses,
                    titleVisibility: .visible
                ) {
                    Button("Delete All Expenses", role: .destructive) {
                        // Keep this as you originally intended.
                        entriesStore.clearAll()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This permanently removes all stored expense entries.")
                }

                // Delete All Vehicles
                Button(role: .destructive) {
                    confirmDeleteVehicles = true
                } label: {
                    HStack {
                        Label("Delete All Vehicles", systemImage: "trash")
                        Spacer()
                        Text("\(profileStore.vehicles.count)")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                }
                .confirmationDialog(
                    "Delete all vehicles?",
                    isPresented: $confirmDeleteVehicles,
                    titleVisibility: .visible
                ) {
                    Button("Delete All Vehicles", role: .destructive) {
                        Task { await deleteAllVehicles() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This permanently removes all stored vehicles (and their on-device photos).")
                }

            } header: {
                Text("Data Tools")
            } footer: {
                Text("Deleting data is permanent and cannot be undone.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Data Deletion")
    }

    private func deleteAllVehicles() async {
        // 1) Best-effort delete photos for each vehicle id
        let ids = profileStore.vehicles.map { $0.id }
        for id in ids {
            await VehicleImageStore.delete(id: id)
        }

        // 2) Clear vehicles
        profileStore.vehicles.removeAll()

        // 3) Clear selection (works whether selectedVehicleID is String? or UUID?)
        profileStore.selectedVehicleID = nil
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        DataDeletionView()
            .environmentObject(EntriesStore())
            .environmentObject(ProfileStore())
    }
}
#endif
