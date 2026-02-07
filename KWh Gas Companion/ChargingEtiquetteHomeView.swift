//
//  MEVEtiquetteTip.swift
//  KWh Gas Companion
//
//  Created by Bryan on 1/21/26.
//


//
//  ChargingEtiquetteHomeView.swift
//  KWh Gas Companion / My EV Companion
//
//  Charging Etiquette mini-guide (offline-friendly)
//  Swift 6 • iOS 17+
//
//  ✅ Compile-safe replacement for the entire file.
//  ✅ Does NOT depend on any other custom app types (theme boxes, stores, etc.).
//  ✅ Loads tips from charging_etiquette.json if present in the app bundle.
//  ✅ Falls back to built-in tips if JSON is missing.
//
//  Add a JSON file named: charging_etiquette.json
//  (Target Membership checked) to override the built-in list.
//

import SwiftUI
import Foundation

// MARK: - Model

fileprivate struct MEVEtiquetteTip: Codable, Identifiable, Hashable {
    let id: String
    let category: String
    let title: String
    let bullets: [String]
    let why: String
    let tags: [String]
    let priority: Int
}

// MARK: - Store

@MainActor
fileprivate final class MEVEtiquetteStore: ObservableObject {
    @Published private(set) var tips: [MEVEtiquetteTip] = []
    @Published private(set) var loadError: String? = nil

    init() {
        load()
    }

    func load() {
        loadError = nil

        if let url = Bundle.main.url(forResource: "charging_etiquette", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([MEVEtiquetteTip].self, from: data)
                tips = decoded.sorted { $0.priority > $1.priority }
                return
            } catch {
                loadError = "Failed to load charging_etiquette.json: \(error.localizedDescription)"
                // Fall through to built-in tips so the UI still works.
            }
        }

        tips = Self.builtinTips
    }

    var categories: [String] {
        let set = Set(tips.map { $0.category })
        let preferred = [
            "Before you plug in",
            "While charging",
            "When it's busy",
            "When you're done",
            "Respect & safety"
        ]
        return preferred.filter(set.contains) + set.subtracting(preferred).sorted()
    }

    // Built-in fallback tips (used if JSON is missing or fails to parse)
    private static let builtinTips: [MEVEtiquetteTip] = [
        .init(
            id: "move-when-done",
            category: "When you're done",
            title: "Move promptly when charging finishes",
            bullets: [
                "If your session is complete, unplug and move as soon as you can.",
                "If you must step away, keep an eye on the app/notifications."
            ],
            why: "Finished stalls block drivers who may be low on charge, and can trigger idle fees at some networks.",
            tags: ["busy", "courtesy"],
            priority: 95
        ),
        .init(
            id: "queue-like-human",
            category: "When it's busy",
            title: "Queue politely (first come, first served)",
            bullets: [
                "If all stalls are full, form a simple queue.",
                "Avoid cutting in or hovering aggressively near a stall."
            ],
            why: "Clear, calm queues reduce conflict and keep everyone moving.",
            tags: ["busy", "queue", "courtesy"],
            priority: 92
        ),
        .init(
            id: "dont-block-stalls",
            category: "Respect & safety",
            title: "Don't block stalls or drive lanes",
            bullets: [
                "Avoid parking across multiple stalls.",
                "Keep access lanes clear for turning and towing."
            ],
            why: "Blocked lanes slow the site down and create safety risks.",
            tags: ["safety", "courtesy"],
            priority: 90
        ),
        .init(
            id: "cable-care",
            category: "While charging",
            title: "Be gentle with the cable and connector",
            bullets: [
                "Avoid stretching the cable beyond its natural reach.",
                "Don't let the connector drop or drag on the ground."
            ],
            why: "Cable damage causes downtime and can make a stall unusable for everyone.",
            tags: ["cable", "safety"],
            priority: 85
        ),
        .init(
            id: "choose-stall-smart",
            category: "Before you plug in",
            title: "Pick the stall that makes traffic flow easiest",
            bullets: [
                "If possible, choose a stall with easy entry/exit.",
                "Avoid awkward angles that block adjacent stalls."
            ],
            why: "Smooth entry/exit improves throughput and reduces frustration.",
            tags: ["stall", "courtesy"],
            priority: 82
        ),
        .init(
            id: "charge-only-when-needed",
            category: "When it's busy",
            title: "Charge what you need when it's crowded",
            bullets: [
                "If the station is packed, consider charging just enough to continue.",
                "Top-off sessions can be slower near the top of the battery."
            ],
            why: "Shorter, efficient sessions help more drivers charge sooner.",
            tags: ["busy", "courtesy"],
            priority: 80
        ),
        .init(
            id: "keep-area-clean",
            category: "Respect & safety",
            title: "Leave the site better than you found it",
            bullets: [
                "Dispose of trash properly.",
                "Avoid blocking sidewalks or accessible routes."
            ],
            why: "Clean, accessible sites help keep charging locations welcomed and maintained.",
            tags: ["courtesy", "safety"],
            priority: 70
        )
    ]
}

// MARK: - Favorites

@MainActor
fileprivate final class MEVEtiquetteFavorites: ObservableObject {
    @AppStorage("mev_etiquette_favorite_ids_v1") private var raw: String = ""
    @Published private(set) var ids: Set<String> = []

    init() {
        ids = Self.parse(raw)
    }

    func isFavorite(_ id: String) -> Bool { ids.contains(id) }

    func toggle(_ id: String) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        raw = Self.serialize(ids)
        ids = Self.parse(raw)
    }

    private static func parse(_ raw: String) -> Set<String> {
        Set(raw.split(separator: "|").map(String.init).filter { !$0.isEmpty })
    }

    private static func serialize(_ ids: Set<String>) -> String {
        ids.sorted().joined(separator: "|")
    }
}

// MARK: - Home View (PUBLIC)

public struct ChargingEtiquetteHomeView: View {
    @StateObject private var store = MEVEtiquetteStore()
    @StateObject private var favorites = MEVEtiquetteFavorites()

    @State private var searchText: String = ""
    @State private var selectedCategory: String? = nil
    @State private var busyMode: Bool = false

    public init() {}

    public var body: some View {
        Group {
            if let err = store.loadError, store.tips.isEmpty {
                ContentUnavailableView(
                    "Couldn't load etiquette tips",
                    systemImage: "exclamationmark.triangle",
                    description: Text(err)
                )
                .padding()
            } else if store.tips.isEmpty {
                ContentUnavailableView(
                    "No etiquette tips available",
                    systemImage: "hand.raised",
                    description: Text("Add charging_etiquette.json to your app bundle, or keep the built-in tips.")
                )
                .padding()
            } else {
                List {
                    headerSection

                    if !favoriteTips.isEmpty && searchText.isEmpty && selectedCategory == nil {
                        Section("Saved") {
                            ForEach(favoriteTips) { tip in
                                tipRow(tip)
                            }
                        }
                    }

                    if showEssentialsSection {
                        Section("Essentials") {
                            ForEach(essentialTips) { tip in
                                tipRow(tip)
                            }
                        }
                    }

                    ForEach(filteredCategories, id: \.self) { cat in
                        let catTips = filteredTips.filter { $0.category == cat }
                        if !catTips.isEmpty {
                            Section(cat) {
                                ForEach(catTips) { tip in
                                    tipRow(tip)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Charging Etiquette")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search tips")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.load() } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Reload tips")
            }
        }
        .environmentObject(favorites)
    }

    // MARK: Header

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                categoryChips

                Toggle(isOn: $busyMode) {
                    Label("Busy station mode", systemImage: "person.3")
                }

                if selectedCategory != nil || !searchText.isEmpty {
                    Button {
                        withAnimation {
                            selectedCategory = nil
                            searchText = ""
                        }
                    } label: {
                        Label("Clear filters", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", isSelected: selectedCategory == nil) { selectedCategory = nil }
                ForEach(store.categories, id: \.self) { cat in
                    chip(title: cat, isSelected: selectedCategory == cat) { selectedCategory = cat }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.primary.opacity(0.12) : Color.secondary.opacity(0.10))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Filtering + scoring

    private var tokens: [String] {
        searchText
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func matches(_ tip: MEVEtiquetteTip) -> Bool {
        guard !tokens.isEmpty else { return true }
        let hay = "\(tip.title) \(tip.why) \(tip.category) \(tip.tags.joined(separator: " ")) \(tip.bullets.joined(separator: " "))".lowercased()
        return tokens.allSatisfy { hay.contains($0) }
    }

    private func score(_ tip: MEVEtiquetteTip) -> Int {
        var s = tip.priority
        let tags = Set(tip.tags.map { $0.lowercased() })

        if busyMode {
            if tags.contains("busy") { s += 25 }
            if tags.contains("queue") { s += 20 }
        }
        if tags.contains("safety") { s += 10 }
        if tags.contains("courtesy") { s += 6 }

        // Slight boost if user searched and the title includes tokens
        if !tokens.isEmpty {
            let title = tip.title.lowercased()
            for t in tokens where title.contains(t) { s += 3 }
        }

        return s
    }

    private var filteredTips: [MEVEtiquetteTip] {
        var out = store.tips

        if let selectedCategory {
            out = out.filter { $0.category == selectedCategory }
        }

        out = out.filter(matches)

        // When busy mode or searching, sort by dynamic score; otherwise by priority.
        if busyMode || !tokens.isEmpty {
            out = out.sorted { score($0) > score($1) }
        } else {
            out = out.sorted { $0.priority > $1.priority }
        }

        return out
    }

    private var filteredCategories: [String] {
        if let selectedCategory { return [selectedCategory] }
        return store.categories
    }

    private var favoriteTips: [MEVEtiquetteTip] {
        let fav = favorites.ids
        return store.tips
            .filter { fav.contains($0.id) }
            .sorted { score($0) > score($1) }
            .prefix(12)
            .map { $0 }
    }

    private var essentialTips: [MEVEtiquetteTip] {
        store.tips.sorted { score($0) > score($1) }.prefix(10).map { $0 }
    }

    private var showEssentialsSection: Bool {
        searchText.isEmpty && selectedCategory == nil
    }

    // MARK: Rows

    private func tipRow(_ tip: MEVEtiquetteTip) -> some View {
        NavigationLink {
            ChargingEtiquetteTipDetailView(tip: tip)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: rowIcon(for: tip))
                    .imageScale(.large)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(tip.title)
                        .font(.headline)

                    Text(tip.why)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    if !tip.tags.isEmpty {
                        Text(tip.tags.map { "#\($0)" }.joined(separator: " "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    favorites.toggle(tip.id)
                } label: {
                    Image(systemName: favorites.isFavorite(tip.id) ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(favorites.isFavorite(tip.id) ? .primary : .secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(favorites.isFavorite(tip.id) ? "Unsave tip" : "Save tip")
            }
            .padding(.vertical, 2)
        }
    }

    private func rowIcon(for tip: MEVEtiquetteTip) -> String {
        let tags = Set(tip.tags.map { $0.lowercased() })
        if tags.contains("safety") { return "shield" }
        if tags.contains("queue") || tags.contains("busy") { return "person.2" }
        if tags.contains("cable") { return "cable.connector" }
        if tags.contains("stall") { return "bolt" }
        return "hand.raised"
    }
}

// MARK: - Detail View

fileprivate struct ChargingEtiquetteTipDetailView: View {
    let tip: MEVEtiquetteTip
    @EnvironmentObject private var favorites: MEVEtiquetteFavorites

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hand.raised")
                        .imageScale(.large)
                        .padding(.top, 3)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(tip.title)
                            .font(.title2.weight(.semibold))
                        Text(tip.category)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button { favorites.toggle(tip.id) } label: {
                        Image(systemName: favorites.isFavorite(tip.id) ? "bookmark.fill" : "bookmark")
                            .imageScale(.large)
                    }
                    .accessibilityLabel(favorites.isFavorite(tip.id) ? "Unsave tip" : "Save tip")
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("What to do")
                        .font(.headline)

                    ForEach(Array(tip.bullets.enumerated()), id: \.offset) { _, bullet in
                        HStack(alignment: .top, spacing: 10) {
                            Text("•")
                                .font(.body.weight(.bold))
                                .padding(.top, 1)
                            Text(bullet)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Why it matters")
                        .font(.headline)
                    Text(tip.why)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                if !tip.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.headline)
                        Text(tip.tags.map { "#\($0)" }.joined(separator: " "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                ShareLink(item: shareText) {
                    Label("Share tip", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding(16)
        }
        .navigationTitle("Etiquette")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var shareText: String {
        var lines: [String] = []
        lines.append("Charging Etiquette Tip")
        lines.append(tip.title)
        lines.append("")
        lines.append("What to do:")
        for b in tip.bullets { lines.append("• \(b)") }
        lines.append("")
        lines.append("Why: \(tip.why)")
        return lines.joined(separator: "\n")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ChargingEtiquetteHomeView()
    }
}
#endif
