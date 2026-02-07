//
//  CSVDecoder.swift
//  KWh Gas Companion
//
//  Created by ChatGPT on 2025-08-11.
//  A lightweight RFC-4180 style CSV parser + row model.
//

import Foundation

// MARK: - Errors

enum CSVError: Error, LocalizedError {
    case emptyInput
    case inconsistentFieldCount(expected: Int, got: Int, row: Int)
    case missingHeader(index: Int)
    case invalidColumn(name: String)
    case unableToDecodeDate(value: String, column: String)
    case custom(message: String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "CSV input is empty."
        case let .inconsistentFieldCount(expected, got, row):
            return "Inconsistent field count on row \(row). Expected \(expected), got \(got)."
        case let .missingHeader(index):
            return "Missing header for column index \(index)."
        case let .invalidColumn(name):
            return "Invalid column '\(name)'."
        case let .unableToDecodeDate(value, column):
            return "Could not parse date '\(value)' in column '\(column)'."
        case let .custom(message):
            return message
        }
    }
}

// MARK: - Row Model

struct CSVRow {
    let index: Int
    let fields: [String]
    let header: [String]?
    private let headerIndex: [String: Int]

    /// Explicit initializer so it's accessible and we precompute header index (no lazy/mutation).
    init(index: Int, fields: [String], header: [String]?) {
        self.index = index
        self.fields = fields
        self.header = header

        if let header {
            var dict: [String: Int] = [:]
            for (i, name) in header.enumerated() {
                let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !key.isEmpty { dict[key] = i }
            }
            self.headerIndex = dict
        } else {
            self.headerIndex = [:]
        }
    }

    // Index-based access
    subscript(_ column: Int) -> String? {
        guard column >= 0 && column < fields.count else { return nil }
        return fields[column]
    }

    // Name-based access (case-insensitive; header required)
    subscript(_ column: String) -> String? {
        guard let idx = headerIndex[column.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] else {
            return nil
        }
        return self[idx]
    }

    // Typed accessors
    func string(_ column: String, default defaultValue: String? = nil) -> String? {
        self[column]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? defaultValue
    }

    func int(_ column: String) -> Int? {
        guard let s = self[column]?.trimmed, !s.isEmpty else { return nil }
        return Int(s)
    }

    func double(_ column: String) -> Double? {
        guard let s = self[column]?.trimmed, !s.isEmpty else { return nil }
        return Double(s.replacingOccurrences(of: ",", with: ""))
    }

    func bool(_ column: String) -> Bool? {
        guard let s = self[column]?.trimmed.lowercased(), !s.isEmpty else { return nil }
        switch s {
        case "1", "true", "yes", "y": return true
        case "0", "false", "no", "n": return false
        default: return nil
        }
    }

    func date(_ column: String, using formatter: DateFormatter) throws -> Date {
        let col = column
        guard let raw = self[col]?.trimmed, !raw.isEmpty else {
            throw CSVError.unableToDecodeDate(value: "", column: col)
        }
        if let d = formatter.date(from: raw) { return d }
        throw CSVError.unableToDecodeDate(value: raw, column: col)
    }
}

// MARK: - Options

struct CSVDecodingOptions {
    var delimiter: Character = ","
    var quote: Character = "\""
    var hasHeaderRow: Bool = true
    var trimsFields: Bool = true
    var allowInconsistentLines: Bool = false

    init(delimiter: Character = ",",
         quote: Character = "\"",
         hasHeaderRow: Bool = true,
         trimsFields: Bool = true,
         allowInconsistentLines: Bool = false) {
        self.delimiter = delimiter
        self.quote = quote
        self.hasHeaderRow = hasHeaderRow
        self.trimsFields = trimsFields
        self.allowInconsistentLines = allowInconsistentLines
    }
}

// MARK: - Decoder

final class CSVDecoder {
    let options: CSVDecodingOptions

    init(options: CSVDecodingOptions = CSVDecodingOptions()) {
        self.options = options
    }

    func decodeRows(from string: String) throws -> [CSVRow] {
        let records = try parse(string)
        guard !records.isEmpty else { throw CSVError.emptyInput }

        var header: [String]? = nil
        var startIndex = 0

        if options.hasHeaderRow {
            header = records.first?.map { $0.strip(options.trimsFields) } ?? []
            startIndex = 1
        }

        let expectedCount = header?.count ?? (records.first?.count ?? 0)

        var rows: [CSVRow] = []
        rows.reserveCapacity(max(0, records.count - startIndex))

        for (i, fields) in records.enumerated() where i >= startIndex {
            if fields.count != expectedCount {
                if options.allowInconsistentLines {
                    continue
                } else {
                    throw CSVError.inconsistentFieldCount(expected: expectedCount, got: fields.count, row: i - startIndex)
                }
            }
            let processed = options.trimsFields ? fields.map { $0.trimmed } : fields
            rows.append(CSVRow(index: i - startIndex, fields: processed, header: header))
        }

        return rows
    }

    func decodeDictionaries(from string: String) throws -> [[String: String]] {
        let rows = try decodeRows(from: string)
        guard let header = rows.first?.header else {
            throw CSVError.custom(message: "decodeDictionaries requires a header row.")
        }
        var result: [[String: String]] = []
        result.reserveCapacity(rows.count)
        for row in rows {
            var dict: [String: String] = [:]
            for (i, key) in header.enumerated() {
                dict[key] = row.fields[safe: i] ?? ""
            }
            result.append(dict)
        }
        return result
    }

    func decode<T>(from string: String, map: (CSVRow) throws -> T) throws -> [T] {
        let rows = try decodeRows(from: string)
        return try rows.map(map)
    }

    // MARK: - Core Parser

    private func parse(_ raw: String) throws -> [[String]] {
        var s = raw
        // Strip BOM if present
        if s.unicodeScalars.first == "\u{feff}" {
            s = String(s.unicodeScalars.dropFirst())
        }

        let delimiter = options.delimiter
        let quote = options.quote

        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = String()
        currentRow.reserveCapacity(16)

        var it = CharIter(s)
        var cOpt = it.next()

        var inQuotes = false
        while let c = cOpt {
            if inQuotes {
                if c == quote {
                    // Lookahead: doubled quote?
                    if it.peek() == quote {
                        _ = it.next() // consume the peeked quote
                        currentField.append(quote)
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(c)
                }
            } else {
                if c == quote {
                    inQuotes = true
                } else if c == delimiter {
                    currentRow.append(currentField)
                    currentField.removeAll(keepingCapacity: true)
                } else if c.isNewline {
                    // End of record (handle CRLF)
                    currentRow.append(currentField)
                    currentField.removeAll(keepingCapacity: true)
                    rows.append(currentRow)
                    currentRow.removeAll(keepingCapacity: true)

                    if c == "\r", it.peek() == "\n" { _ = it.next() }
                } else {
                    currentField.append(c)
                }
            }
            cOpt = it.next()
        }

        if inQuotes {
            // Unterminated quote: tolerate by finalizing current field/row
        }
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }
}

// MARK: - Utilities

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    func strip(_ shouldTrim: Bool) -> String { shouldTrim ? self.trimmed : self }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension Character {
    var isNewline: Bool { self == "\n" || self == "\r" }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

// A small iterator wrapper with non-mutating peek.
private struct CharIter {
    private let s: String
    private var idx: String.Index

    init(_ s: String) {
        self.s = s
        self.idx = s.startIndex
    }

    mutating func next() -> Character? {
        guard idx < s.endIndex else { return nil }
        let c = s[idx]
        s.formIndex(after: &idx)
        return c
    }

    func peek() -> Character? {
        guard idx < s.endIndex else { return nil }
        return s[idx]
    }
}
