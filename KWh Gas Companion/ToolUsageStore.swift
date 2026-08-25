//  ToolUsageStore.swift
//  My KWh Companion
//
//  Pinned tools + recent tools (persisted to Application Support).
//  Swift 6 • iOS 17+
//

import Foundation
import Combine

@MainActor
final class ToolUsageStore: ObservableObject {

    struct UsageRecord: Codable, Hashable, Identifiable {
        var id: String { kindRaw }
        let kindRaw: String
        var lastUsedAt: Date
    }

    private struct Persisted: Codable {
        var pinned: [String]
        var recent: [UsageRecord]
    }

    @Published private(set) var pinned: Set<String> = []
    @Published private(set) var recent: [UsageRecord] = [] // most recent first

    private let fileURL: URL
    private let writeQueue = DispatchQueue(label: "ToolUsageStore.WriteQueue", qos: .utility)

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let fm = FileManager.default
            let base =
                fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fm.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? fm.temporaryDirectory

            if !fm.fileExists(atPath: base.path) {
                try? fm.createDirectory(at: base, withIntermediateDirectories: true)
            }
            self.fileURL = base.appendingPathComponent("tools.usage.json")
        }
        load()
    }

    func isPinned(_ kind: CalculatorKind) -> Bool { pinned.contains(kind.rawValue) }

    func togglePin(_ kind: CalculatorKind) {
        let key = kind.rawValue
        if pinned.contains(key) { pinned.remove(key) } else { pinned.insert(key) }
        persistAsync()
    }

    func recordUse(_ kind: CalculatorKind) {
        let key = kind.rawValue
        let now = Date()

        if let idx = recent.firstIndex(where: { $0.kindRaw == key }) {
            recent[idx].lastUsedAt = now
            let item = recent.remove(at: idx)
            recent.insert(item, at: 0)
        } else {
            recent.insert(.init(kindRaw: key, lastUsedAt: now), at: 0)
        }

        if recent.count > 16 { recent.removeLast(recent.count - 16) }
        persistAsync()
    }

    func clearRecents() {
        recent.removeAll()
        persistAsync()
    }

    func clearAllData() {
        pinned.removeAll()
        recent.removeAll()
        persistAsync()
    }

    // MARK: - Persistence

    private func persistAsync() {
        let snapshot = Persisted(
            pinned: Array(pinned).sorted(),
            recent: recent
        )

        let data: Data
        do { data = try encoder.encode(snapshot) }
        catch { return }

        let url = fileURL
        writeQueue.async {
            try? data.write(to: url, options: [.atomic])
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try decoder.decode(Persisted.self, from: data)
            pinned = Set(decoded.pinned)
            recent = decoded.recent.sorted(by: { $0.lastUsedAt > $1.lastUsedAt })
        } catch {
            pinned = []
            recent = []
        }
    }
}
