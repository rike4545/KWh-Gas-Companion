//
//  ImportError.swift
//  KWh Gas Companion
//
//  A focused, user-friendly error model for file & CSV imports.
//
//  Created by ChatGPT on 2025-08-11.
//

import Foundation

/// Errors that can occur while importing files (CSV, JSON, etc.).
/// Designed to be UI-friendly and safe to use with `Alert` via `Identifiable`.
public enum ImportError: Error, LocalizedError, Identifiable, Equatable, Hashable, Sendable {

    // MARK: - Primary cases

    case fileNotFound(url: URL?)
    case unreadableData(underlying: String? = nil)
    case unsupportedEncoding
    case invalidFormat(reason: String? = nil)
    case missingRequiredColumns(missing: [String])
    case parseError(line: Int?, column: Int?, reason: String? = nil)
    case emptyFile
    case noRows
    case duplicate(reason: String? = nil)
    case permissionDenied
    case iCloudUnavailable
    case cancelled
    case storageError(reason: String? = nil)
    case networkError(statusCode: Int?, reason: String? = nil)
    case mappingError(reason: String? = nil)
    case unknown(underlying: String? = nil)

    // MARK: - Identifiable

    public var id: String {
        // Stable string for SwiftUI alerts/sheets
        switch self {
        case .fileNotFound(let url):              return "fileNotFound:\(url?.absoluteString ?? "nil")"
        case .unreadableData(let u):              return "unreadableData:\(u ?? "nil")"
        case .unsupportedEncoding:                return "unsupportedEncoding"
        case .invalidFormat(let r):               return "invalidFormat:\(r ?? "nil")"
        case .missingRequiredColumns(let cols):   return "missingRequiredColumns:\(cols.joined(separator: ","))"
        case .parseError(let l, let c, let r):    return "parseError:\(l.map(String.init) ?? "nil"):\(c.map(String.init) ?? "nil"):\(r ?? "nil")"
        case .emptyFile:                          return "emptyFile"
        case .noRows:                             return "noRows"
        case .duplicate(let r):                   return "duplicate:\(r ?? "nil")"
        case .permissionDenied:                   return "permissionDenied"
        case .iCloudUnavailable:                  return "iCloudUnavailable"
        case .cancelled:                          return "cancelled"
        case .storageError(let r):                return "storageError:\(r ?? "nil")"
        case .networkError(let code, let r):      return "networkError:\(code.map(String.init) ?? "nil"):\(r ?? "nil")"
        case .mappingError(let r):                return "mappingError:\(r ?? "nil")"
        case .unknown(let u):                     return "unknown:\(u ?? "nil")"
        }
    }

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:               return "File not found"
        case .unreadableData:             return "Couldn’t read file data"
        case .unsupportedEncoding:        return "Unsupported text encoding"
        case .invalidFormat:              return "Invalid file format"
        case .missingRequiredColumns:     return "The CSV is missing required columns"
        case .parseError:                 return "Unable to parse the CSV"
        case .emptyFile:                  return "The file is empty"
        case .noRows:                     return "No rows were found"
        case .duplicate:                  return "Duplicate data detected"
        case .permissionDenied:           return "Permission denied"
        case .iCloudUnavailable:          return "iCloud is unavailable"
        case .cancelled:                  return "Operation cancelled"
        case .storageError:               return "Couldn’t save imported data"
        case .networkError:               return "Network error"
        case .mappingError:               return "Couldn’t map values to fields"
        case .unknown:                    return "Unknown error"
        }
    }

    public var failureReason: String? {
        switch self {
        case .fileNotFound(let url):
            return url?.lastPathComponent ?? "The file could not be located."
        case .unreadableData(let underlying):
            return underlying
        case .unsupportedEncoding:
            return "The file appears to use a text encoding that can’t be read."
        case .invalidFormat(let reason),
             .duplicate(let reason),
             .storageError(let reason),
             .mappingError(let reason),
             .unknown(let reason):
            return reason
        case .missingRequiredColumns(let missing):
            return "Missing: " + missing.joined(separator: ", ")
        case .parseError(let line, let col, let reason):
            var parts: [String] = []
            if let line { parts.append("line \(line)") }
            if let col { parts.append("col \(col)") }
            if let reason, !reason.isEmpty { parts.append(reason) }
            return parts.isEmpty ? nil : parts.joined(separator: " • ")
        case .emptyFile:
            return "No content found."
        case .noRows:
            return "There were headers but no data rows."
        case .permissionDenied:
            return "The app lacks permission to access the file."
        case .iCloudUnavailable:
            return "Ensure you’re signed into iCloud and the file is downloaded."
        case .cancelled:
            return nil
        case .networkError(let code, let reason):
            var out = [String]()
            if let code { out.append("HTTP \(code)") }
            if let reason { out.append(reason) }
            return out.isEmpty ? nil : out.joined(separator: " • ")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Verify the file location or pick it again."
        case .unreadableData:
            return "Try re-exporting the file or opening it in another app to ensure it’s valid."
        case .unsupportedEncoding:
            return "Save the file as UTF-8 and try again."
        case .invalidFormat:
            return "Make sure you selected the correct export type."
        case .missingRequiredColumns:
            return "Include all required columns in the export and try again."
        case .parseError:
            return "Check for stray quotes or commas and try again."
        case .emptyFile, .noRows:
            return "Re-export with data rows included."
        case .duplicate:
            return "Remove duplicates or choose a different date range."
        case .permissionDenied:
            return "Allow file access for this app in Settings."
        case .iCloudUnavailable:
            return "Open the file in Files and wait for it to download."
        case .cancelled:
            return nil
        case .storageError:
            return "Free up space and try again."
        case .networkError:
            return "Check your connection, then retry."
        case .mappingError:
            return "Confirm column headers match expected fields."
        case .unknown:
            return "Try again. If it persists, contact support."
        }
    }

    // MARK: - Convenience

    /// Map any `Error` to a best-guess `ImportError`.
    public static func from(_ error: Error) -> ImportError {
        // If already ImportError, just return it.
        if let ie = error as? ImportError { return ie }

        // Common Cocoa / URL errors
        let ns = error as NSError
        switch (ns.domain, ns.code) {
        case (NSCocoaErrorDomain, NSFileReadNoSuchFileError):
            return .fileNotFound(url: ns.userInfo[NSFilePathErrorKey].flatMap { URL(fileURLWithPath: "\($0)") })
        case (NSCocoaErrorDomain, NSFileReadNoPermissionError):
            return .permissionDenied
        case (NSCocoaErrorDomain, NSFileReadUnknownStringEncodingError):
            return .unsupportedEncoding
        case (NSURLErrorDomain, _):
            return .networkError(statusCode: nil, reason: ns.localizedDescription)
        default:
            return .unknown(underlying: ns.localizedDescription)
        }
    }

    /// Hint for UI: most of these are recoverable via retry or different file.
    public var isRecoverable: Bool {
        switch self {
        case .storageError, .permissionDenied, .iCloudUnavailable:
            return true
        case .cancelled:
            return true
        default:
            return true
        }
    }
}
