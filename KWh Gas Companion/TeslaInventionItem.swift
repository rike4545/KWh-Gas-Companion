//
//  TeslaInventionsShiftView.swift
//  My KWh Companion
//
//  Browse Nikola Tesla's inventions with emphasis on EV relevance.
//  - Swift 6 / iOS 17+
//  - No external dependencies
//  - Sorting, filtering, searchable, share
//
//  Drop-in file. Present from a tile or menu.
//

import SwiftUI

// MARK: - Model

struct TeslaInventionItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let year: Int
    let isEVRelevant: Bool
    let patentNumbers: String?
    let summary: String
    let sources: [URL]
}

// MARK: - View

@MainActor
struct TeslaInventionsShiftView: View {
    // Search / Filters
    @State private var searchText = ""
    @State private var showEVOnly = false
    @State private var decadeFilter: DecadeFilter = .all
    @State private var sort: SortOption = .yearDesc

    private var filtered: [TeslaInventionItem] {
        var items = Self.inventions

        if showEVOnly {
            items = items.filter { $0.isEVRelevant }
        }
        if decadeFilter != .all {
            items = items.filter { decadeFilter.contains($0.year) }
        }
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let needle = searchText.lowercased()
            items = items.filter { inv in
                let haystack = "\(inv.title) \(inv.summary) \(inv.patentNumbers ?? "") \(inv.year)".lowercased()
                return haystack.contains(needle)
            }
        }

        switch sort {
        case .yearDesc:
            return items.sorted { $0.year > $1.year }
        case .yearAsc:
            return items.sorted { $0.year < $1.year }
        case .title:
            return items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    private var shareText: String {
        let lines = filtered.map { inv in
            var line = "• \(inv.title) (\(inv.year))"
            if let p = inv.patentNumbers, !p.isEmpty { line += " — US Patent \(p)" }
            if inv.isEVRelevant { line += " [EV]" }
            return line
        }
        return """
        Nikola Tesla — Selected Inventions
        \(lines.joined(separator: "\n"))
        """
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No results",
                        systemImage: "magnifyingglass",
                        description: Text("Try adjusting filters or your search.")
                    )
                } else {
                    ForEach(filtered) { invention in
                        Section {
                            InventionRow(invention: invention)
                        }
                    }
                }
            }
            .navigationTitle("Tesla’s Inventions")
            .searchable(text: $searchText, prompt: "Search inventions…")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(SortOption.allCases) { opt in
                                Text(opt.label).tag(opt)
                            }
                        }
                        .pickerStyle(.inline)

                        Picker("Decade", selection: $decadeFilter) {
                            ForEach(DecadeFilter.allCases) { dec in
                                Text(dec.label).tag(dec)
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Label("Options", systemImage: "slider.horizontal.3")
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Toggle(isOn: $showEVOnly) {
                        Text("EV Only")
                    }
                    .toggleStyle(.switch)

                    ShareLink(item: shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share list")
                }
            }
        }
    }
}

// MARK: - Row

private struct InventionRow: View {
    let invention: TeslaInventionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(invention.title)
                    .font(.headline)

                if invention.isEVRelevant {
                    Text("EV")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .clipShape(Capsule())
                        .accessibilityLabel("EV relevant")
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                Text("\(invention.year)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let p = invention.patentNumbers, !p.isEmpty {
                    Text("•")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("U.S. Patent \(p)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Text(invention.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !invention.sources.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(invention.sources, id: \.self) { url in
                        Link(destination: url) {
                            Label("View Source", systemImage: "arrow.up.right.square")
                                .font(.caption)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Filters / Sorting

private enum SortOption: String, CaseIterable, Identifiable {
    case yearDesc, yearAsc, title
    var id: String { rawValue }
    var label: String {
        switch self {
        case .yearDesc: "Year (newest)"
        case .yearAsc:  "Year (oldest)"
        case .title:    "Title (A–Z)"
        }
    }
}

private enum DecadeFilter: String, CaseIterable, Identifiable {
    case all, d1880s, d1890s, d1900s, d1910s
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all:   "All decades"
        case .d1880s:"1880s"
        case .d1890s:"1890s"
        case .d1900s:"1900s"
        case .d1910s:"1910s"
        }
    }
    func contains(_ year: Int) -> Bool {
        switch self {
        case .all: return true
        case .d1880s: return (1880...1889).contains(year)
        case .d1890s: return (1890...1899).contains(year)
        case .d1900s: return (1900...1909).contains(year)
        case .d1910s: return (1910...1919).contains(year)
        }
    }
}

// MARK: - Seed Data

extension TeslaInventionsShiftView {
    static let inventions: [TeslaInventionItem] = [
        TeslaInventionItem(
            title: "Alternating Current (AC) Motor & Power System",
            year: 1888,
            isEVRelevant: true,
            patentNumbers: "381,968; 382,279; 416,191–195",
            summary: "Polyphase AC motor and power transmission. Forms the backbone of modern grids and underpins AC charging for EVs.",
            sources: [URL(string: "https://patents.google.com/patent/US381968A/en")!]
        ),
        TeslaInventionItem(
            title: "Polyphase Induction Motor",
            year: 1888,
            isEVRelevant: true,
            patentNumbers: "381,968; 382,279",
            summary: "Efficient, robust induction motor—direct ancestor of many traction motors used in EVs.",
            sources: [URL(string: "https://en.wikipedia.org/wiki/Induction_motor")!]
        ),
        TeslaInventionItem(
            title: "Wireless Power Transmission (Tesla Coil)",
            year: 1891,
            isEVRelevant: true,
            patentNumbers: nil,
            summary: "High-frequency resonant transformer for wireless energy transfer; conceptually related to modern wireless EV charging.",
            sources: [URL(string: "https://en.wikipedia.org/wiki/Tesla_coil")!]
        ),
        TeslaInventionItem(
            title: "Magnifying Transmitter",
            year: 1897,
            isEVRelevant: false,
            patentNumbers: nil,
            summary: "Large-scale resonant transformer aimed at long-distance wireless energy & communication experiments.",
            sources: [URL(string: "https://teslasciencecenter.org/nikola-tesla-inventions/")!]
        ),
        TeslaInventionItem(
            title: "Radio-Controlled Boat",
            year: 1898,
            isEVRelevant: false,
            patentNumbers: "613,809",
            summary: "Demonstration of wireless teleautomation—an early precursor to modern remote/telemetry systems in vehicles.",
            sources: [URL(string: "https://en.wikipedia.org/wiki/Tesla%27s_remote-controlled_boat")!]
        ),
        TeslaInventionItem(
            title: "Bladeless (Tesla) Turbine",
            year: 1913,
            isEVRelevant: false,
            patentNumbers: "1,061,206",
            summary: "Smooth-disc turbine emphasizing boundary-layer effects; ideas echo in clean generation and efficiency research.",
            sources: [URL(string: "https://patents.google.com/patent/US1061206A/en")!]
        )
    ]
}
