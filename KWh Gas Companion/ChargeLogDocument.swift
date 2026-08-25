//
//  ChargeLogDocument.swift
//  MyKWh Companion
//
//  🔧 FIX: KWChargeLogEntry → ChargeLogEntry throughout.
//  KWChargeLogEntry was never defined in the project — this caused a compile error.
//  The actual type declared in ChargeLogEntry.swift is `ChargeLogEntry`.
//
//  Swift 6 / iOS 17+
//

import SwiftUI
import UniformTypeIdentifiers

/// A FileDocument wrapper around an array of ChargeLogEntry,
/// for JSON-based import/export and document-based persistence.
struct ChargeLogDocument: FileDocument {
    /// Declare that this document reads and writes JSON
    static var readableContentTypes: [UTType] { [UTType.json] }

    /// The array of charge log entries stored in this document
    var entries: [ChargeLogEntry]

    /// Default initializer for creating a new, empty document
    init(entries: [ChargeLogEntry] = []) {
        self.entries = entries
    }

    /// Load from disk: decode JSON into the entries array
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            self.entries = []
            return
        }
        self.entries = try JSONDecoder().decode([ChargeLogEntry].self, from: data)
    }

    /// Save to disk: encode the entries array as JSON
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(entries)
        return FileWrapper(regularFileWithContents: data)
    }
}
