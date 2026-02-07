//
//  TeslaFiSessionManager.swift
//  KWh Gas Companion
//
//  Manager for TeslaFiSession aligned to the current model:
//  - startDate / endDate
//  - energyAddedKWh
//  - cost (optional)
//  - location (optional)
//  - fingerprint (dedupe key) OR sessionHash (if you added compat)
//
//  IMPORTANT: This file does NOT redeclare sessionHash/costUSD to avoid conflicts.
//

import Foundation
import SwiftUI

@MainActor
final class TeslaFiSessionManager: ObservableObject {

    @Published private(set) var sessions: [TeslaFiSession] = []

    init(sessions: [TeslaFiSession] = []) {
        replaceAll(with: sessions)
    }

    // MARK: - Public API

    func replaceAll(with list: [TeslaFiSession], dedupe: Bool = true) {
        sessions = dedupe ? deduped(list) : list
        stableSort()
    }

    /// Merge imported sessions (deduped). Returns (added, skippedDuplicates).
    @discardableResult
    func merge(_ imported: [TeslaFiSession]) -> (added: Int, skipped: Int) {
        guard !imported.isEmpty else { return (0, 0) }

        var existing = Set(sessions.map { dedupeKey(for: $0) })
        var toAdd: [TeslaFiSession] = []
        var skipped = 0

        for s in imported {
            let key = dedupeKey(for: s)
            if existing.insert(key).inserted {
                toAdd.append(s)
            } else {
                skipped += 1
            }
        }

        if !toAdd.isEmpty {
            sessions.append(contentsOf: toAdd)
            stableSort()
        }

        return (toAdd.count, skipped)
    }

    /// Add one session if unique.
    @discardableResult
    func add(_ s: TeslaFiSession) -> Bool {
        let key = dedupeKey(for: s)
        if sessions.contains(where: { dedupeKey(for: $0) == key }) { return false }
        sessions.append(s)
        stableSort()
        return true
    }

    func remove(id: UUID) {
        sessions.removeAll { $0.id == id }
    }

    /// Remove by dedupe key (fingerprint/sessionHash).
    func remove(key: String) {
        sessions.removeAll { dedupeKey(for: $0) == key }
    }

    func clear() {
        sessions.removeAll()
    }

    // MARK: - Convenience

    var totalEnergyAddedKWh: Double {
        sessions.reduce(into: 0.0) { sum, s in
            let e = s.energyAddedKWh
            if e > 0 { sum += e }
        }
    }

    var totalCostUSD: Double {
        sessions.reduce(into: 0.0) { sum, s in
            let c = s.cost ?? 0
            if c > 0 { sum += c }
        }
    }

    var missingCostCount: Int {
        sessions.filter { ($0.cost ?? 0) <= 0 }.count
    }

    // MARK: - Private

    private func dedupeKey(for s: TeslaFiSession) -> String {
        // Prefer fingerprint if present in your model. If your model uses sessionHash,
        // your TeslaFiSession.swift can alias fingerprint = sessionHash.
        return s.fingerprint
    }

    private func deduped(_ list: [TeslaFiSession]) -> [TeslaFiSession] {
        var seen = Set<String>()
        var out: [TeslaFiSession] = []
        out.reserveCapacity(list.count)
        for s in list {
            let key = dedupeKey(for: s)
            if seen.insert(key).inserted {
                out.append(s)
            }
        }
        return out
    }

    private func stableSort() {
        sessions.sort { a, b in
            if a.startDate != b.startDate { return a.startDate > b.startDate }
            return a.endDate > b.endDate
        }
    }
}
