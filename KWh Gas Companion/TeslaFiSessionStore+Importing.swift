//  TeslaFiSessionStore+Importing.swift
//  My KWh Companion
//
//  Collision-safe CSV importer utilities for TeslaFiSession.
//
//  IMPORTANT:
//  - This file does NOT mutate your store’s `sessions` (avoids private(set) issues).
//  - Use the returned `[TeslaFiSession]` to append/merge in your caller.
//
//  Usage:
//      let (newSessions, report) = try TeslaFiSessionStore.parseTeslaFiCSV(from: url, existing: store.sessions)
//      store.append(newSessions) // or a merge function you own
//
//  This version additionally:
//  - Normalizes each data row to the header column count (pads or trims), so every header
//    always has a corresponding value in TeslaFiSession.raw.
//  - Tracks how many rows had column-count mismatches + sample line numbers.
//  - Exposes header + headerUsage in TFIImportReport so you can verify mapping / data integrity.
//

import Foundation

// MARK: - Parse helpers (namespaced on TeslaFiSessionStore)

extension TeslaFiSessionStore {

    /// Parse a CSV file from disk. Does NOT mutate the store.
    /// - Parameters:
    ///   - url: Source URL for a CSV file.
    ///   - existing: Existing sessions for duplicate detection (optional).
    /// - Returns: New sessions parsed + an import report.
    static func parseTeslaFiCSV(
        from url: URL,
        existing: [TeslaFiSession] = []
    ) throws -> ([TeslaFiSession], TFIImportReport) {
        let data = try Data(contentsOf: url)
        return try parseTeslaFiCSV(
            data: data,
            filenameHint: url.lastPathComponent,
            existing: existing
        )
    }

    /// Parse a CSV blob. Does NOT mutate the store.
    /// - Parameters:
    ///   - data: CSV contents.
    ///   - filenameHint: Optional display name for the report.
    ///   - existing: Existing sessions for duplicate detection (optional).
    /// - Returns: New sessions parsed + an import report.
    static func parseTeslaFiCSV(
        data: Data,
        filenameHint: String? = nil,
        existing: [TeslaFiSession] = []
    ) throws -> ([TeslaFiSession], TFIImportReport) {

        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .ascii) else {
            throw TFIImportError.unreadableText
        }

        let rows = TFICSV.rows(from: text)
        guard let header = rows.first else {
            throw TFIImportError.empty
        }
        let body = Array(rows.dropFirst())
        let headerCount = header.count

        // Normalize every row to the header length (pads or trims),
        // and track column-count mismatches to report later.
        var normalizedBody: [[String]] = []
        normalizedBody.reserveCapacity(body.count)

        var mismatchCount = 0
        var mismatchSampleLines: [Int] = []  // 1-based file line numbers

        for (idx, originalFields) in body.enumerated() {
            var fields = originalFields
            if fields.count != headerCount {
                mismatchCount += 1
                if mismatchSampleLines.count < 5 {
                    // +1 for header row, +1 to convert 0-based to 1-based
                    mismatchSampleLines.append(idx + 2)
                }

                if fields.count < headerCount {
                    // Pad missing columns with empty strings
                    fields.append(contentsOf: Array(repeating: "", count: headerCount - fields.count))
                } else if fields.count > headerCount {
                    // Trim extra columns; they have no header name to map to
                    fields = Array(fields.prefix(headerCount))
                }
            }
            normalizedBody.append(fields)
        }

        let map = TFIHeaderMap(header: header)

        var inserted = 0
        var skippedDup = 0
        var failures: [TFIImportFailure] = []
        var out: [TeslaFiSession] = []
        out.reserveCapacity(normalizedBody.count)

        for (lineIndex, fields) in normalizedBody.enumerated() {
            do {
                // Build raw dictionary for traceability: every header gets a value,
                // thanks to the normalization above.
                var rawDict: [String: String] = [:]
                for (i, key) in header.enumerated() {
                    let value = i < fields.count ? fields[i] : ""
                    rawDict[key] = value
                }

                // Dates
                let startStr = map.get(.startDate, in: fields)
                let endStr   = map.get(.endDate, in: fields)
                guard let start = TFIDateParser.parse(startStr),
                      let end   = TFIDateParser.parse(endStr) else {
                    throw TFIImportError.badDate(startStr ?? "?", endStr ?? "?")
                }

                // Energy (kWh)
                let kwhStr = map.get(.energyAdded, in: fields)
                    ?? map.get(.kwhAdded, in: fields)
                let kwh = kwhStr.flatMap {
                    Double($0.replacingOccurrences(of: ",", with: ""))
                } ?? 0

                // Cost (optional)
                let costStr = map.get(.cost, in: fields)
                let cost = costStr.flatMap {
                    Double(
                        $0.replacingOccurrences(of: "$", with: "")
                            .replacingOccurrences(of: ",", with: "")
                    )
                }

                // Location (optional)
                let location = map.get(.location, in: fields).flatMap { s -> String? in
                    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    return t.isEmpty ? nil : t
                }

                let session = TeslaFiSession(
                    startDate: start,
                    endDate: end,
                    energyAddedKWh: kwh,
                    cost: cost,
                    location: location,
                    raw: rawDict
                )

                // Duplicate detection against existing + local new
                let isDup: (TeslaFiSession) -> Bool = {
                    $0.startDate == session.startDate &&
                    $0.endDate == session.endDate &&
                    $0.energyAddedKWh == session.energyAddedKWh
                }
                if existing.contains(where: isDup) || out.contains(where: isDup) {
                    skippedDup += 1
                    continue
                }

                out.append(session)
                inserted += 1

            } catch {
                failures.append(
                    TFIImportFailure(
                        lineNumber: lineIndex + 2, // +1 for header, +1 for human 1-based
                        message: String(describing: error)
                    )
                )
            }
        }

        let report = TFIImportReport(
            filename: filenameHint ?? "CSV",
            insertedCount: inserted,
            skippedDuplicates: skippedDup,
            failures: failures,
            header: header,
            headerUsage: map.usageSummary(),
            rowCount: normalizedBody.count,
            columnMismatchRowCount: mismatchCount,
            columnMismatchSampleLines: mismatchSampleLines
        )

        return (out, report)
    }
}

// MARK: - Report / Errors (internal, app-wide)

struct TFIImportReport: Sendable {
    let filename: String
    let insertedCount: Int
    let skippedDuplicates: Int
    let failures: [TFIImportFailure]

    /// Raw header row from the CSV (every column name).
    let header: [String]

    /// Per-header usage information (which logical fields each header was mapped to).
    let headerUsage: [TFIHeaderUsage]

    /// Number of data rows processed (excluding header).
    let rowCount: Int

    /// How many rows had a different column count than the header before normalization.
    let columnMismatchRowCount: Int

    /// Sample 1-based line numbers for rows with column-count mismatches (up to 5).
    let columnMismatchSampleLines: [Int]

    var hasFailures: Bool { !failures.isEmpty }

    init(
        filename: String,
        insertedCount: Int,
        skippedDuplicates: Int,
        failures: [TFIImportFailure],
        header: [String],
        headerUsage: [TFIHeaderUsage],
        rowCount: Int,
        columnMismatchRowCount: Int,
        columnMismatchSampleLines: [Int]
    ) {
        self.filename = filename
        self.insertedCount = insertedCount
        self.skippedDuplicates = skippedDuplicates
        self.failures = failures
        self.header = header
        self.headerUsage = headerUsage
        self.rowCount = rowCount
        self.columnMismatchRowCount = columnMismatchRowCount
        self.columnMismatchSampleLines = columnMismatchSampleLines
    }
}

struct TFIImportFailure: Sendable {
    let lineNumber: Int
    let message: String
}

enum TFIImportError: LocalizedError {
    case unreadableText
    case empty
    case badDate(String, String)

    var errorDescription: String? {
        switch self {
        case .unreadableText:
            return "Could not read CSV text (encoding issue)."
        case .empty:
            return "CSV appears empty."
        case .badDate(let s, let e):
            return "Unrecognized date(s): start='\(s)' end='\(e)'."
        }
    }
}

/// Describes how a single CSV header is used by the importer.
struct TFIHeaderUsage: Sendable {
    let index: Int
    let name: String
    let normalizedName: String
    /// Logical roles this header was mapped to, e.g. ["startDate", "energyAdded"].
    let mappedTo: [String]
}

// MARK: - Minimal CSV parser (handles quotes/commas, CRLF normalization)

fileprivate enum TFICSV {
    static func rows(from text: String) -> [[String]] {
        // Normalize CRLF / CR → LF to avoid phantom blank rows on Windows exports
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var rows: [[String]] = []
        normalized.enumerateLines { line, _ in
            // Keep even empty lines if needed; let parseLine handle empties
            rows.append(parseLine(line))
        }
        return rows
    }

    private static func parseLine(_ line: String) -> [String] {
        var out: [String] = []
        var cur = ""
        var inQ = false

        var i = line.startIndex
        while i < line.endIndex {
            let ch = line[i]
            if ch == "\"" {
                if inQ {
                    let next = line.index(after: i)
                    if next < line.endIndex && line[next] == "\"" {
                        // Escaped quote ("")
                        cur.append("\"")
                        i = next
                    } else {
                        inQ = false
                    }
                } else {
                    inQ = true
                }
            } else if ch == "," && !inQ {
                out.append(cur)
                cur = ""
            } else {
                cur.append(ch)
            }
            i = line.index(after: i)
        }
        out.append(cur)
        return out
    }
}

// MARK: - Header mapping

fileprivate struct TFIHeaderMap {
    enum Key: CaseIterable {
        case startDate, endDate, energyAdded, kwhAdded, cost, location
    }

    private let header: [String]
    private var indexMap: [Key: Int] = [:]

    init(header: [String]) {
        self.header = header
        for (idx, raw) in header.enumerated() {
            let h = TFIHeaderMap.normalize(raw)
            switch h {
            case "start", "startdate", "start time", "date", "date start", "begin", "begin time":
                indexMap[.startDate] = idx
            case "end", "enddate", "end time", "date end", "finish", "finish time":
                indexMap[.endDate] = idx
            case "energyadded", "energy added", "kwh", "kwhadded", "kwh added":
                indexMap[.energyAdded] = idx
                indexMap[.kwhAdded] = idx
            case "cost", "price", "totalcost", "total cost", "sessioncost", "session cost", "usd":
                indexMap[.cost] = idx
            case "location", "site", "place", "address":
                indexMap[.location] = idx
            default:
                break
            }
        }
    }

    func get(_ key: Key, in row: [String]) -> String? {
        guard let i = indexMap[key], i < row.count else { return nil }
        let val = row[i].trimmingCharacters(in: .whitespacesAndNewlines)
        return val.isEmpty ? nil : val
    }

    /// Summarize how each header is used so the UI can show mapping integrity.
    func usageSummary() -> [TFIHeaderUsage] {
        var result: [TFIHeaderUsage] = []
        for (idx, name) in header.enumerated() {
            let normalized = TFIHeaderMap.normalize(name)
            var roles: [String] = []
            for key in Key.allCases {
                if indexMap[key] == idx {
                    roles.append(Self.keyWireName(key))
                }
            }
            result.append(
                TFIHeaderUsage(
                    index: idx,
                    name: name,
                    normalizedName: normalized,
                    mappedTo: roles
                )
            )
        }
        return result
    }

    private static func keyWireName(_ key: Key) -> String {
        switch key {
        case .startDate:   return "startDate"
        case .endDate:     return "endDate"
        case .energyAdded: return "energyAdded"
        case .kwhAdded:    return "kwhAdded"
        case .cost:        return "cost"
        case .location:    return "location"
        }
    }

    static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Date parsing

fileprivate enum TFIDateParser {
    /// Tries multiple common TeslaFi/export formats.
    static func parse(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        let candidates: [String] = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "M/d/yyyy H:mm",
            "M/d/yy H:mm",
            "MM/dd/yyyy HH:mm",
            "dd/MM/yyyy HH:mm",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mmXXXXX"
        ]
        let tz = TimeZone.current
        let locale = Locale(identifier: "en_US_POSIX")
        for fmt in candidates {
            let df = DateFormatter()
            df.dateFormat = fmt
            df.timeZone = tz
            df.locale = locale
            if let d = df.date(from: s) { return d }
        }
        return ISO8601DateFormatter().date(from: s)
    }
}
