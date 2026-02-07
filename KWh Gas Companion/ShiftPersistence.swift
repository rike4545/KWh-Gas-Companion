//
//  ShiftPersistence.swift
//  KWh Gas Companion
//

import Foundation

/// Lightweight JSON persistence utilities for any Codable list.
/// Use with your existing `Shift` model (or any other Codable type).
enum ShiftPersistence {

    // MARK: - Public API

    /// Load an array of `T` from Application Support (default: "shifts.json").
    static func load<T: Codable>(
        _ type: T.Type = T.self,
        filename: String = defaultFilename,
        decoder: JSONDecoder = defaultDecoder
    ) -> [T] {
        do {
            let url = try storageURL(for: filename)
            guard FileManager.default.fileExists(atPath: url.path) else { return [] }
            let data = try Data(contentsOf: url)
            return try decoder.decode([T].self, from: data)
        } catch {
            #if DEBUG
            print("ShiftPersistence.load error:", error)
            #endif
            return []
        }
    }

    /// Save an array of `T` to Application Support (default: "shifts.json").
    @discardableResult
    static func save<T: Codable>(
        _ items: [T],
        filename: String = defaultFilename,
        encoder: JSONEncoder = defaultEncoder
    ) -> Bool {
        do {
            let data = try encoder.encode(items)
            let url = try storageURL(for: filename)
            try ensureDirectoryExists(for: url)
            let opts: Data.WritingOptions = [.atomic]
            try data.write(to: url, options: opts)
            return true
        } catch {
            #if DEBUG
            print("ShiftPersistence.save error:", error)
            #endif
            return false
        }
    }

    /// Insert or replace by id, then persist.
    @discardableResult
    static func upsert<T: Codable & Identifiable & Equatable>(
        _ item: T,
        filename: String = defaultFilename,
        encoder: JSONEncoder = defaultEncoder,
        decoder: JSONDecoder = defaultDecoder
    ) -> [T] where T.ID: Equatable {
        var list: [T] = load(T.self, filename: filename, decoder: decoder)
        if let i = list.firstIndex(where: { $0.id == item.id }) {
            list[i] = item
        } else {
            list.append(item)
        }
        _ = save(list, filename: filename, encoder: encoder)
        return list
    }

    /// Remove by id, then persist.
    @discardableResult
    static func remove<T: Codable & Identifiable>(
        id: T.ID,
        _ type: T.Type = T.self,
        filename: String = defaultFilename,
        encoder: JSONEncoder = defaultEncoder,
        decoder: JSONDecoder = defaultDecoder
    ) -> [T] where T.ID: Equatable {
        var list: [T] = load(T.self, filename: filename, decoder: decoder)
        list.removeAll { $0.id == id }
        _ = save(list, filename: filename, encoder: encoder)
        return list
    }

    /// Convenience: return the first item matching a predicate.
    static func currentMatch<T>(
        in items: [T],
        where predicate: (T) -> Bool
    ) -> T? {
        items.first(where: predicate)
    }

    // MARK: - Storage details

    static let defaultFilename = "shifts.json"

    static var defaultEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static var defaultDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func storageURL(for filename: String) throws -> URL {
        let fm = FileManager.default
        #if os(iOS) || os(tvOS) || os(watchOS) || os(macOS)
        let base = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        #else
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        #endif
        let bundleID = Bundle.main.bundleIdentifier ?? "com.yourcompany.KWhGasCompanion"
        return base
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent(filename, isDirectory: false)
    }

    static func ensureDirectoryExists(for fileURL: URL) throws {
        let dir = fileURL.deletingLastPathComponent()
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
