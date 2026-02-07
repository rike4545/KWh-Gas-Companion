//
//  ChargeLogDocument 2.swift
//  KWh Gas Companion
//
//  Created by Bryan on 7/15/25.
//


// ChargeLogDocument.swift
// MyKwH Companion
// Created by Bryan on 7/15/25.

import SwiftUI
import UniformTypeIdentifiers

/// A FileDocument wrapper around an array of KWChargeLogEntry,
/// for JSON-based import/export and document-based persistence.
struct ChargeLogDocument: FileDocument {
    /// Declare that this document reads and writes JSON
    static var readableContentTypes: [UTType] { [UTType.json] }

    /// The array of charge log entries stored in this document
    var entries: [KWChargeLogEntry]

    /// Default initializer for creating a new, empty document
    init(entries: [KWChargeLogEntry] = []) {
        self.entries = entries
    }

    /// Load from disk: decode JSON into the entries array
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            self.entries = []
            return
        }
        self.entries = try JSONDecoder().decode([KWChargeLogEntry].self, from: data)
    }

    /// Save to disk: encode the entries array as JSON
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(entries)
        return FileWrapper(regularFileWithContents: data)
    }
}
