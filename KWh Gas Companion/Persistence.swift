//
//  Persistence.swift
//  KWh Gas Companion
//

import Foundation

struct Persistence {
    private static func documentsURL(for fileName: String) -> URL {
        let base = (try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(fileName)
    }

    static func save<T: Codable>(_ object: T, to fileName: String) {
        let url = documentsURL(for: fileName)
        do {
            let data = try JSONEncoder().encode(object)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Persistence.save failed:", error)
        }
    }

    static func load<T: Codable>(_ type: T.Type, from fileName: String) -> T? {
        let url = documentsURL(for: fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
