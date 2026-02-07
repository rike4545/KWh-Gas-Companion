// ExpenseDocument.swift
// Manages reading and writing expense entries as a JSON document

import SwiftUI
import UniformTypeIdentifiers

struct ExpenseDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType.json] }
    var entries: [ExpenseEntry]

    init(entries: [ExpenseEntry] = []) {
        self.entries = entries
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            self.entries = []
            return
        }
        self.entries = try JSONDecoder().decode([ExpenseEntry].self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(entries)
        return FileWrapper(regularFileWithContents: data)
    }
}
