//
//  AppInfoView.swift
//  KWh Gas Companion
//
//  Created by Bryan on 7/12/25.
//


// AppInfoView.swift
import SwiftUI

struct AppInfoView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("App Version \(version) (\(build))")
                    .font(.headline)
                Link("Visit our Website", destination: URL(string: "https://yourwebsite.com")!)
                Link("Mailing List", destination: URL(string: "https://yourwebsite.com/mailing-list")!)
                Link("Facebook Page", destination: URL(string: "https://facebook.com/yourpage")!)
            }
            .padding()
            .navigationTitle("App Info")
        }
    }
}
