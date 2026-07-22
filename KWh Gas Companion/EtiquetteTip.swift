//
//  EtiquetteTip.swift
//  KWh Gas Companion
//
//

import Foundation
import SwiftUI

struct EtiquetteTip: Codable, Identifiable, Hashable {
    let id: String
    let category: String
    let title: String
    let bullets: [String]
    let why: String
    let tags: [String]
    let priority: Int
}

@MainActor
final class EtiquetteStore: ObservableObject {
    @Published private(set) var tips: [EtiquetteTip] = []
    @Published private(set) var loadError: String?

    init() {
        load()
    }

    func load() {
        loadError = nil
        guard let url = Bundle.main.url(forResource: "charging_etiquette", withExtension: "json") else {
            tips = []
            loadError = "Missing charging_etiquette.json in app bundle."
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([EtiquetteTip].self, from: data)
            tips = decoded.sorted { $0.priority > $1.priority }
        } catch {
            tips = []
            loadError = "Failed to load etiquette tips: \(error.localizedDescription)"
        }
    }

    var categories: [String] {
        let set = Set(tips.map { $0.category })
        // keep a nice stable ordering if your JSON categories match these names:
        let preferred = ["Before you plug in", "While charging", "When it’s busy", "When you're done", "Respect & safety"]
        return preferred.filter(set.contains) + set.subtracting(preferred).sorted()
    }
}

/// Lightweight favorites store using AppStorage.
/// Stored as a "|" delimited string for maximal compatibility.
@MainActor
final class EtiquetteFavorites: ObservableObject {
    @AppStorage("evc_favorite_tip_ids_v1") private var raw: String = ""

    @Published private(set) var ids: Set<String> = []

    init() {
        ids = Self.parse(raw)
    }

    func isFavorite(_ id: String) -> Bool { ids.contains(id) }

    func toggle(_ id: String) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        raw = Self.serialize(ids)
        // keep @Published in sync
        ids = Self.parse(raw)
    }

    private static func parse(_ raw: String) -> Set<String> {
        let parts = raw.split(separator: "|").map(String.init).filter { !$0.isEmpty }
        return Set(parts)
    }

    private static func serialize(_ ids: Set<String>) -> String {
        ids.sorted().joined(separator: "|")
    }
}
