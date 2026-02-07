//
//  AckCredit.swift
//  KWh Gas Companion
//
//  Created by Bryan on 9/15/25.
//


//
//  AcknowledgementsView.swift
//  My KWh Companion
//
//  Fully regenerated acknowledgements screen.
//  - Search across Credits, Data Sources, Libraries
//  - Expand/Collapse sections, Expand All / Collapse All
//  - Share license summary
//  - Dark/Light compatible via AppTheme surfaces
//
//  Requires: AppCard, AppSectionHeader, TagPill, SecondaryButtonStyle (from AppTheme.swift)
//

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Models

struct AckCredit: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let role: String
    let notes: String
    let url: URL?
    let tags: [String]
}

struct AckSource: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let summary: String
    let url: URL?
    let tags: [String]
}

struct AckLibrary: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let license: String
    let url: URL?
    let tags: [String]
}

// MARK: - View

@MainActor
struct AcknowledgementsView: View {
    // Search
    @State private var query = ""

    // Section expansion
    @State private var showCredits = true
    @State private var showSources = true
    @State private var showLibraries = true
    @State private var showLegal = true

    // Content (edit to match your real deps/attributions)
    private let credits: [AckCredit] = [
        .init(
            name: "Early Testers",
            role: "QA & Feedback",
            notes: "Thoughtful bug reports, usage notes, and UI/UX suggestions.",
            url: nil,
            tags: ["Community", "QA"]
        ),
        .init(
            name: "EV Community",
            role: "Insights & Practices",
            notes: "Real-world charging data, etiquette, and best practices.",
            url: URL(string: "https://teslamotorsclub.com"),
            tags: ["Community"]
        ),
        .init(
            name: "Apple Developer Community",
            role: "Ecosystem & Samples",
            notes: "Swift/SwiftUI techniques and platform guidance.",
            url: URL(string: "https://developer.apple.com"),
            tags: ["SwiftUI", "Apple"]
        )
    ]

    private let sources: [AckSource] = [
        .init(
            name: "supercharge.info",
            summary: "Community-maintained Supercharger site metadata used for mapping context.",
            url: URL(string: "https://supercharge.info"),
            tags: ["Supercharger", "Sites"]
        ),
        .init(
            name: "Open Charge Map",
            summary: "Public EV charge point data sometimes used for enrichment.",
            url: URL(string: "https://openchargemap.org"),
            tags: ["OCM", "EV Charging"]
        ),
        .init(
            name: "Tesla App / CSV Exports",
            summary: "User-initiated CSV exports for personal charging/expenses; processed on-device.",
            url: URL(string: "https://www.tesla.com/support/account-support/tesla-app"),
            tags: ["CSV", "Personal Data"]
        ),
        .init(
            name: "TeslaFi (User-Provided)",
            summary: "Optional user-provided CSV logs parsed locally in the app.",
            url: URL(string: "https://teslafi.com"),
            tags: ["TeslaFi", "CSV"]
        )
    ]

    private let libraries: [AckLibrary] = [
        .init(
            name: "Swift",
            license: "Apache License 2.0",
            url: URL(string: "https://github.com/apple/swift/blob/main/LICENSE.txt"),
            tags: ["Apple"]
        ),
        .init(
            name: "SwiftUI / Combine / Foundation",
            license: "Apple SDK Terms",
            url: URL(string: "https://developer.apple.com/terms"),
            tags: ["Apple"]
        ),
        .init(
            name: "MapKit & CoreLocation",
            license: "Apple SDK Terms",
            url: URL(string: "https://developer.apple.com/terms"),
            tags: ["Apple"]
        )
        // Add any third-party packages you actually link here.
    ]

    // MARK: - Filters

    private var filteredCredits: [AckCredit] {
        guard !query.isEmpty else { return credits }
        return credits.filter { c in
            c.name.localizedCaseInsensitiveContains(query)
            || c.role.localizedCaseInsensitiveContains(query)
            || c.notes.localizedCaseInsensitiveContains(query)
            || c.tags.joined(separator: " ").localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredSources: [AckSource] {
        guard !query.isEmpty else { return sources }
        return sources.filter { s in
            s.name.localizedCaseInsensitiveContains(query)
            || s.summary.localizedCaseInsensitiveContains(query)
            || s.tags.joined(separator: " ").localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredLibraries: [AckLibrary] {
        guard !query.isEmpty else { return libraries }
        return libraries.filter { l in
            l.name.localizedCaseInsensitiveContains(query)
            || l.license.localizedCaseInsensitiveContains(query)
            || l.tags.joined(separator: " ").localizedCaseInsensitiveContains(query)
        }
    }

    private var licenseSummaryText: String {
        libraries.map { lib in
            var line = "• \(lib.name) — \(lib.license)"
            if let u = lib.url { line += " (\(u.absoluteString))" }
            return line
        }
        .joined(separator: "\n")
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                headerControls

                // Credits
                sectionHeader("Credits & Thanks", systemImage: "hands.and.sparkles.fill")
                AppCard {
                    DisclosureGroup(isExpanded: $showCredits) {
                        if filteredCredits.isEmpty {
                            emptyQueryMessage
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(filteredCredits) { c in
                                    ackCreditRow(c)
                                    Divider().opacity(0.3)
                                }
                            }
                        }
                    } label: {
                        Text("People & Communities").font(.headline)
                    }
                }

                // Data Sources
                sectionHeader("Data Sources", systemImage: "externaldrive.connected.to.line.below.fill")
                AppCard {
                    DisclosureGroup(isExpanded: $showSources) {
                        if filteredSources.isEmpty {
                            emptyQueryMessage
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(filteredSources) { s in
                                    ackSourceRow(s)
                                    Divider().opacity(0.3)
                                }
                            }
                            Text("Personal data you import (e.g., CSVs) is processed locally on-device.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 6)
                        }
                    } label: {
                        Text("Sites & Datasets").font(.headline)
                    }
                }

                // Libraries
                sectionHeader("Open Source & SDKs", systemImage: "curlybraces.square")
                AppCard {
                    DisclosureGroup(isExpanded: $showLibraries) {
                        if filteredLibraries.isEmpty {
                            emptyQueryMessage
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(filteredLibraries) { l in
                                    ackLibraryRow(l)
                                    Divider().opacity(0.3)
                                }
                            }
                        }
                    } label: {
                        Text("Libraries & Licenses").font(.headline)
                    }
                }

                // Legal
                sectionHeader("Legal & Notices", systemImage: "doc.text.magnifyingglass")
                AppCard {
                    DisclosureGroup(isExpanded: $showLegal) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Trademarks & Affiliation").font(.headline)
                            Text("""
This app is an independent tool for EV owners. It is not endorsed by, directly affiliated with, maintained, authorized, or sponsored by Tesla, Inc., Rivian Automotive, Inc., or any other manufacturer. All product and company names are trademarks™ or registered® trademarks of their respective holders.
""")

                            Text("Data Disclaimer").font(.headline).padding(.top, 8)
                            Text("""
Data may include user-provided content (e.g., CSV logs) and public information (e.g., supercharger metadata). While best efforts are made to keep information accurate and current, no guarantees are made. Verify important details with official sources.
""")

                            Text("Privacy").font(.headline).padding(.top, 8)
                            Text("""
User-provided CSVs are processed locally. No personal charging or expense data is sent to external servers by default.
""")

                            Text("Contact").font(.headline).padding(.top, 8)
                            Text("If any attribution is missing or needs correction, please reach out so it can be updated.")
                        }
                    } label: {
                        Text("Read Notices").font(.headline)
                    }
                }

                // Share licenses summary
                AppCard {
                    HStack {
                        Text("Export License Summary").font(.headline)
                        Spacer()
                        if !licenseSummaryText.isEmpty {
                            ShareLink(item: licenseSummaryText) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            #if canImport(UIKit)
                            Button {
                                UIPasteboard.general.string = licenseSummaryText
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            #endif
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Acknowledgements")
        .appScreenBackground()
        .searchable(text: $query, placement: .automatic, prompt: "Search acknowledgements")
    }

    // MARK: - Subviews

    @ViewBuilder private var headerControls: some View {
        AppSectionHeader("Acknowledgements", systemImage: "heart.circle.fill")
        AppCard {
            HStack(spacing: 12) {
                Button {
                    showCredits = true; showSources = true; showLibraries = true; showLegal = true
                } label: {
                    Label("Expand All", systemImage: "arrow.down.right.and.arrow.up.left")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    showCredits = false; showSources = false; showLibraries = false; showLegal = false
                } label: {
                    Label("Collapse All", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(SecondaryButtonStyle())

                Spacer()

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Label("Clear Search", systemImage: "xmark.circle")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        AppSectionHeader(title, systemImage: systemImage).padding(.top, 4)
    }

    @ViewBuilder private var emptyQueryMessage: some View {
        Text("No matches. Try a different search.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func ackCreditRow(_ c: AckCredit) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(c.name).font(.headline)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(c.tags, id: \.self) { TagPill(text: $0) }
                }
            }
            Text(c.role).font(.subheadline).foregroundStyle(.secondary)
            Text(c.notes).font(.callout)
            if let url = c.url {
                Link("Visit", destination: url)
                    .font(.footnote.weight(.semibold))
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func ackSourceRow(_ s: AckSource) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(s.name).font(.headline)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(s.tags, id: \.self) { TagPill(text: $0) }
                }
            }
            Text(s.summary).font(.callout)
            if let url = s.url {
                Link("Open Site", destination: url)
                    .font(.footnote.weight(.semibold))
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func ackLibraryRow(_ l: AckLibrary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(l.name).font(.headline)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(l.tags, id: \.self) { TagPill(text: $0) }
                }
            }
            Text(l.license).font(.callout)
            if let url = l.url {
                Link("License / Repo", destination: url)
                    .font(.footnote.weight(.semibold))
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#if DEBUG
@MainActor
struct AcknowledgementsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack { AcknowledgementsView() }
                .preferredColorScheme(.light)
            NavigationStack { AcknowledgementsView() }
                .preferredColorScheme(.dark)
        }
    }
}
#endif
