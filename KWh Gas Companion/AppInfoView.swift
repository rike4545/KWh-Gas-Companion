//
//  AppInfoView.swift
//  KWh Gas Companion
//
//

// AppInfoView.swift
import SwiftUI

struct AppInfoView: View {
    private struct InfoLink: Identifiable {
        let id: String
        let title: String
        let destination: URL
    }

    private let links: [InfoLink] = [
        .init(id: "website", title: "Visit our Website", destination: URL(string: "https://yourwebsite.com")!),
        .init(id: "mailing-list", title: "Mailing List", destination: URL(string: "https://yourwebsite.com/mailing-list")!),
        .init(id: "facebook", title: "Facebook Page", destination: URL(string: "https://facebook.com/yourpage")!)
    ]

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
                ForEach(links) { link in
                    Link(link.title, destination: link.destination)
                }
            }
            .padding()
            .navigationTitle("App Info")
        }
    }
}
