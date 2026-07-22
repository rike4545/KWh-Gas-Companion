//
//  GarageView.swift
//  KWh Gas Companion
//
//  Legacy Garage entry point.
//  The active user-facing Garage experience lives in `VehicleProfileListView`.
//

import SwiftUI

@MainActor
struct GarageView: View {
    var body: some View {
        VehicleProfileListView()
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        GarageView()
            .environmentObject(ProfileStore())
            .environmentObject(AppAppearance())
            .environment(\.appThemeBox, AppThemeBox(base: SystemTheme(accentColor: .red, scheme: .light)))
    }
}
#endif
