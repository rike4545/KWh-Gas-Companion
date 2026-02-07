//
//  KWhGasCompanionAppModel.swift
//  My KWh Companion
//
//  Swift 6 / iOS 17+
//
//  App-level model: orchestrates TeslaFi CSV imports and exposes import state.
//  - Uses TeslaFiSessionStore (not Manager)
//  - Does not auto-merge imports into teslaFiStore.sessions (caller owns merge)
//  - Main-actor safe updates for UI
//

import Foundation
import SwiftUI

@MainActor
final class KWhGasCompanionAppModel: ObservableObject {

    // MARK: - Dependencies (injected)
    let teslaFiStore: TeslaFiSessionStore
    let profileStore: ProfileStore
    let entriesStore: EntriesStore

    // MARK: - Import state (UI-facing)
    enum ImportState {
        case idle
        case importing(filename: String?)
        case finished(report: TFIImportReport, newSessionsCount: Int)
        case failed(message: String)
    }

    @Published private(set) var importState: ImportState = .idle

    /// Newly parsed sessions from the last import (not yet merged into teslaFiStore.sessions).
    @Published private(set) var pendingImportedSessions: [TeslaFiSession] = []

    /// Most recent import report (filename, inserted, skipped, failures).
    @Published private(set) var lastImportReport: TFIImportReport?

    // Convenience
    var hasPendingImport: Bool { !pendingImportedSessions.isEmpty }

    // MARK: - Init
    init(
        teslaFiStore: TeslaFiSessionStore,
        profileStore: ProfileStore,
        entriesStore: EntriesStore
    ) {
        self.teslaFiStore = teslaFiStore
        self.profileStore = profileStore
        self.entriesStore = entriesStore
    }

    // MARK: - TeslaFi CSV Import (from file URL)

    /// Import TeslaFi CSV from a file URL.
    /// Parses off the main thread (inside parser) and updates state on the main actor.
    func importTeslaFiCSV(from url: URL) async {
        importState = .importing(filename: url.lastPathComponent)
        do {
            let (newSessions, report) = try TeslaFiSessionStore.parseTeslaFiCSV(
                from: url,
                existing: teslaFiStore.sessions
            )
            pendingImportedSessions = newSessions
            lastImportReport = report
            importState = .finished(report: report, newSessionsCount: newSessions.count)
        } catch {
            pendingImportedSessions = []
            lastImportReport = nil
            importState = .failed(message: error.localizedDescription)
        }
    }

    // MARK: - TeslaFi CSV Import (from Data blob)

    /// Import TeslaFi CSV from raw data (e.g., Share Sheet).
    func importTeslaFiCSV(data: Data, filenameHint: String? = nil) async {
        importState = .importing(filename: filenameHint)
        do {
            let (newSessions, report) = try TeslaFiSessionStore.parseTeslaFiCSV(
                data: data,
                filenameHint: filenameHint,
                existing: teslaFiStore.sessions
            )
            pendingImportedSessions = newSessions
            lastImportReport = report
            importState = .finished(report: report, newSessionsCount: newSessions.count)
        } catch {
            pendingImportedSessions = []
            lastImportReport = nil
            importState = .failed(message: error.localizedDescription)
        }
    }

    // MARK: - Post-import helpers (owned by caller/feature)

    /// Clear pending state (use after a merge flow completes).
    func clearPendingImport() {
        pendingImportedSessions.removeAll()
        importState = .idle
    }
}

// MARK: - Manual Equatable conformance for ImportState
// (We intentionally ignore the report object to avoid requiring it to be Equatable.)
extension KWhGasCompanionAppModel.ImportState: Equatable {
    static func == (lhs: KWhGasCompanionAppModel.ImportState,
                    rhs: KWhGasCompanionAppModel.ImportState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case let (.importing(a), .importing(b)):
            return a == b
        case let (.finished(_, aCount), .finished(_, bCount)):
            return aCount == bCount
        case let (.failed(aMsg), .failed(bMsg)):
            return aMsg == bMsg
        default:
            return false
        }
    }
}
