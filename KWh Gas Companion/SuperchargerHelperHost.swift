//
//  SuperchargerHelperHost.swift
//  My KWh Companion
//
//  Thin wrapper to present SuperchargerHelperView in navigation.
//

import SwiftUI

@MainActor
struct SuperchargerHelperHost: View {
    var body: some View {
        SuperchargerHelperView()
            .navigationTitle("Cheapest Charger Finder")
            .navigationBarTitleDisplayMode(.inline)
    }
}
