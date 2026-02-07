//
//  ServiceInvoicesStore.swift
//  My KWh Companion
//
//  Minimal, compile-safe store for Tesla Service Invoices.
//  - Read-only invoices array exposed to views
//  - Loads/saves JSON per-vehicle in Documents/ServiceInvoices/{vehicleKey}/invoices.json
//  - Copies imported PDFs into that folder and tracks filename + sha256
//  - No direct calls to ExpenseEntryWriter (linking is handled by UI)
//  - Implements optional delete/update protocols used by the list view.
//
//  Swift 6 / iOS 17+
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers
import CryptoKit

@MainActor
public final class ServiceInvoicesStore: ObservableObject {
    // Public read-only invoices feed
    @Published public private(set) var invoices: [ServiceInvoice] = []

    // Optional: UI may set this so it can be passed along (but this store does not call it)
    public var expenseWriter: (any ExpenseEntryWriter)?

    public init() {}

    // MARK: - Public API

    public func load(vehicleKey: String) {
        do {
            self.invoices = try loadInvoicesJSON(vehicleKey: vehicleKey)
        } catch {
            #if DEBUG
            print("ServiceInvoicesStore.load error:", error)
            #endif
            self.invoices = []
        }
    }

    /// Import PDFs, copy into app Documents, and append invoices. Returns number imported.
    @discardableResult
    public func importPDFs(urls: [URL], vehicleKey: String) async -> Int {
        var added: [ServiceInvoice] = []
        do {
            for src in urls {
                guard src.startAccessingSecurityScopedResource() else {
                    continue
                }
                defer { src.stopAccessingSecurityScopedResource() }

                // Copy to app container
                let dir = try ensureVehicleDir(vehicleKey: vehicleKey)
                let id = UUID()
                let filename = "\(id.uuidString).pdf"
                let dst = dir.appendingPathComponent(filename, conformingTo: .pdf)

                // Read data once to compute hash then write
                let data = try Data(contentsOf: src)
                try data.write(to: dst, options: [.atomic])

                let sha = sha256Hex(data)

                // Build invoice model
                let created = Date()
                let inv = ServiceInvoice(
                    id: id,
                    vehicleKey: vehicleKey,
                    title: src.deletingPathExtension().lastPathComponent,
                    serviceDate: fileDateGuess(url: src) ?? created,
                    amount: nil,
                    filename: filename,
                    sha256: sha,
                    createdAt: created,
                    updatedAt: created,
                    invoiceNumber: nil,
                    advisor: nil,
                    odometerIn: nil,
                    odometerOut: nil,
                    parsedVIN: nil,
                    location: nil,
                    linkedExpenseID: nil
                )
                added.append(inv)
            }

            guard !added.isEmpty else { return 0 }

            // Merge, de-dupe by id, persist
            var current = try loadInvoicesJSON(vehicleKey: vehicleKey)
            current.append(contentsOf: added)
            current = dedupByID(current)
            try saveInvoicesJSON(current, vehicleKey: vehicleKey)
            self.invoices = current
            return added.count
        } catch {
            #if DEBUG
            print("importPDFs error:", error)
            #endif
            return 0
        }
    }

    /// File URL for a given invoice PDF (may not exist if deleted externally).
    public func url(for invoice: ServiceInvoice) -> URL {
        vehicleDir(vehicleKey: invoice.vehicleKey)
            .appendingPathComponent(invoice.filename, conformingTo: .pdf)
    }
}

// MARK: - Optional capabilities used by the UI

extension ServiceInvoicesStore: _InvoicesStoreDeleting {
    public func delete(invoice: ServiceInvoice) async -> Bool {
        do {
            // Remove file (ignore if missing)
            let fileURL = url(for: invoice)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }

            // Remove from JSON and persist
            var list = try loadInvoicesJSON(vehicleKey: invoice.vehicleKey)
            list.removeAll { $0.id == invoice.id }
            try saveInvoicesJSON(list, vehicleKey: invoice.vehicleKey)
            self.invoices = list
            return true
        } catch {
            #if DEBUG
            print("delete(invoice:) error:", error)
            #endif
            return false
        }
    }
}

extension ServiceInvoicesStore: _InvoicesStoreUpdating {
    public func update(linkedExpenseID: UUID?, for invoiceID: UUID) async {
        guard let idx = invoices.firstIndex(where: { $0.id == invoiceID }) else { return }
        var inv = invoices[idx]
        inv.linkedExpenseID = linkedExpenseID
        inv.updatedAt = Date()

        // Commit into backing JSON
        do {
            var list = try loadInvoicesJSON(vehicleKey: inv.vehicleKey)
            if let j = list.firstIndex(where: { $0.id == invoiceID }) {
                list[j] = inv
                try saveInvoicesJSON(list, vehicleKey: inv.vehicleKey)
                self.invoices = list
            }
        } catch {
            #if DEBUG
            print("update(linkedExpenseID:) error:", error)
            #endif
        }
    }
}

// MARK: - Persistence

private extension ServiceInvoicesStore {
    func documentsDir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    func rootDir() -> URL {
        documentsDir().appendingPathComponent("ServiceInvoices", isDirectory: true)
    }

    func vehicleDir(vehicleKey: String) -> URL {
        rootDir().appendingPathComponent(safeKey(vehicleKey), isDirectory: true)
    }

    @discardableResult
    func ensureVehicleDir(vehicleKey: String) throws -> URL {
        let dir = vehicleDir(vehicleKey: vehicleKey)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func indexURL(vehicleKey: String) -> URL {
        vehicleDir(vehicleKey: vehicleKey).appendingPathComponent("invoices.json")
    }

    func loadInvoicesJSON(vehicleKey: String) throws -> [ServiceInvoice] {
        let url = indexURL(vehicleKey: vehicleKey)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601OrUnixOrApple
        return try dec.decode([ServiceInvoice].self, from: data)
    }

    func saveInvoicesJSON(_ items: [ServiceInvoice], vehicleKey: String) throws {
        try ensureVehicleDir(vehicleKey: vehicleKey)
        let url = indexURL(vehicleKey: vehicleKey)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        let data = try enc.encode(items)
        try data.write(to: url, options: [.atomic])
    }

    func dedupByID(_ items: [ServiceInvoice]) -> [ServiceInvoice] {
        var seen = Set<UUID>()
        var out: [ServiceInvoice] = []
        for x in items {
            if !seen.contains(x.id) {
                seen.insert(x.id)
                out.append(x)
            }
        }
        return out
    }

    func safeKey(_ s: String) -> String {
        let bad = CharacterSet.alphanumerics.union(.init(charactersIn: "-_.")).inverted
        return s.components(separatedBy: bad).joined(separator: "_")
    }

    func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    func fileDateGuess(url: URL) -> Date? {
        // Try metadata times; fallback to nil so caller uses Date()
        if let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
           let d = values.contentModificationDate {
            return d
        }
        return nil
    }
}

// MARK: - Date strategies

private extension JSONDecoder.DateDecodingStrategy {
    static let iso8601OrUnixOrApple: JSONDecoder.DateDecodingStrategy = .custom { decoder in
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) {
            // ISO 8601
            let iso = ISO8601DateFormatter()
            if let d = iso.date(from: s) { return d }
            // Fallback: RFC 3339-ish
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            if let d = f.date(from: s) { return d }
        }
        if let secs = try? c.decode(Double.self) {
            return Date(timeIntervalSince1970: secs)
        }
        if let intSecs = try? c.decode(Int.self) {
            return Date(timeIntervalSince1970: TimeInterval(intSecs))
        }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported date format")
    }
}
