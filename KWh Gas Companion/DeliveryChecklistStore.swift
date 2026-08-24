//
//  DeliveryChecklistStore.swift
//  KWh Gas Companion
//
//  Saved inspection runs — per-item status, timestamped notes, and photos.
//  Fully offline; a delivery center is exactly where you can't count on signal.
//
//  Swift 6 • iOS 17+
//

import Foundation
import Combine

// MARK: - Per-item state

public struct DeliveryChecklistItemState: Codable, Hashable, Sendable {
    public var status: DeliveryItemStatus
    public var note: String
    public var photoFilenames: [String]
    public var updatedAt: Date?

    public init(
        status: DeliveryItemStatus = .unchecked,
        note: String = "",
        photoFilenames: [String] = [],
        updatedAt: Date? = nil
    ) {
        self.status = status
        self.note = note
        self.photoFilenames = photoFilenames
        self.updatedAt = updatedAt
    }

    public var isEmpty: Bool {
        status == .unchecked && note.isEmpty && photoFilenames.isEmpty
    }
}

// MARK: - Custom items

public struct DeliveryChecklistCustomItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var category: DeliveryChecklistCategory
    public var title: String
    public var detail: String

    public init(id: UUID = UUID(), category: DeliveryChecklistCategory, title: String, detail: String = "") {
        self.id = id
        self.category = category
        self.title = title
        self.detail = detail
    }
}

/// A template item and a user-added item, flattened into one thing the UI can
/// render without caring which it is.
public struct DeliveryChecklistResolvedItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let category: DeliveryChecklistCategory
    public let title: String
    public let detail: String
    public let isCustom: Bool
}

// MARK: - Run

public struct DeliveryChecklistRun: Identifiable, Codable, Hashable, Sendable {

    public var id: UUID
    public var title: String
    public var vehicle: String
    public var vin: String
    public var deliveryDate: Date?
    public var createdAt: Date
    public var completedAt: Date?

    public var states: [String: DeliveryChecklistItemState]
    public var customItems: [DeliveryChecklistCustomItem]
    /// Template items hidden for this run — the "customizable template" knob.
    public var hiddenItemIDs: [String]

    public init(
        id: UUID = UUID(),
        title: String = "",
        vehicle: String = "",
        vin: String = "",
        deliveryDate: Date? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        states: [String: DeliveryChecklistItemState] = [:],
        customItems: [DeliveryChecklistCustomItem] = [],
        hiddenItemIDs: [String] = []
    ) {
        self.id = id
        self.title = title
        self.vehicle = vehicle
        self.vin = vin
        self.deliveryDate = deliveryDate
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.states = states
        self.customItems = customItems
        self.hiddenItemIDs = hiddenItemIDs
    }
}

public extension DeliveryChecklistRun {

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let vehicleName = vehicle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !vehicleName.isEmpty { return vehicleName }
        return "Delivery inspection"
    }

    func state(for itemID: String) -> DeliveryChecklistItemState {
        states[itemID] ?? DeliveryChecklistItemState()
    }

    /// Template items (minus hidden) plus custom items, per category.
    func items(in category: DeliveryChecklistCategory) -> [DeliveryChecklistResolvedItem] {
        let hidden = Set(hiddenItemIDs)
        let template = DeliveryChecklistTemplate.items(in: category)
            .filter { !hidden.contains($0.id) }
            .map {
                DeliveryChecklistResolvedItem(
                    id: $0.id,
                    category: $0.category,
                    title: $0.title,
                    detail: $0.detail,
                    isCustom: false
                )
            }

        let custom = customItems
            .filter { $0.category == category }
            .map {
                DeliveryChecklistResolvedItem(
                    id: $0.id.uuidString,
                    category: $0.category,
                    title: $0.title,
                    detail: $0.detail,
                    isCustom: true
                )
            }

        return template + custom
    }

    var allItems: [DeliveryChecklistResolvedItem] {
        DeliveryChecklistCategory.allCases.flatMap { items(in: $0) }
    }

    // MARK: Progress

    func checkedCount(in category: DeliveryChecklistCategory) -> Int {
        items(in: category).filter { state(for: $0.id).status != .unchecked }.count
    }

    func totalCount(in category: DeliveryChecklistCategory) -> Int {
        items(in: category).count
    }

    func flaggedCount(in category: DeliveryChecklistCategory) -> Int {
        items(in: category).filter { state(for: $0.id).status.isFlagged }.count
    }

    var checkedCount: Int { allItems.filter { state(for: $0.id).status != .unchecked }.count }
    var totalCount: Int { allItems.count }
    var flaggedCount: Int { allItems.filter { state(for: $0.id).status.isFlagged }.count }
    var passCount: Int { allItems.filter { state(for: $0.id).status == .pass }.count }

    var photoCount: Int { states.values.reduce(0) { $0 + $1.photoFilenames.count } }

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(checkedCount) / Double(totalCount)
    }

    func progress(in category: DeliveryChecklistCategory) -> Double {
        let total = totalCount(in: category)
        guard total > 0 else { return 0 }
        return Double(checkedCount(in: category)) / Double(total)
    }

    var isFinished: Bool { totalCount > 0 && checkedCount == totalCount }

    /// Everything flagged, for the summary and the export.
    var flaggedItems: [(item: DeliveryChecklistResolvedItem, state: DeliveryChecklistItemState)] {
        allItems.compactMap { item in
            let itemState = state(for: item.id)
            guard itemState.status.isFlagged else { return nil }
            return (item, itemState)
        }
    }
}

// MARK: - Store

@MainActor
final class DeliveryChecklistStore: ObservableObject {

    @Published private(set) var runs: [DeliveryChecklistRun] = [] {
        didSet { persist() }
    }

    private let filename: String
    private var isHydrating = true
    private var hasPendingSave = false

    init(filename: String = "delivery_checklist_runs.json") {
        self.filename = filename
        hydrate()
        isHydrating = false
    }

    var sortedRuns: [DeliveryChecklistRun] {
        runs.sorted { $0.createdAt > $1.createdAt }
    }

    func run(id: UUID) -> DeliveryChecklistRun? {
        runs.first { $0.id == id }
    }

    // MARK: Mutation

    func add(_ run: DeliveryChecklistRun) {
        runs.append(run)
    }

    func update(_ run: DeliveryChecklistRun) {
        guard let index = runs.firstIndex(where: { $0.id == run.id }) else { return }
        runs[index] = run
    }

    func delete(id: UUID) {
        deletePhotoDirectory(runID: id)
        runs.removeAll { $0.id == id }
    }

    func setStatus(_ status: DeliveryItemStatus, itemID: String, runID: UUID) {
        mutate(runID) { run in
            var state = run.state(for: itemID)
            state.status = status
            state.updatedAt = Date()
            run.states[itemID] = state
        }
    }

    func setNote(_ note: String, itemID: String, runID: UUID) {
        mutate(runID) { run in
            var state = run.state(for: itemID)
            state.note = note
            state.updatedAt = Date()
            // A note on an untouched item almost always means something's wrong.
            if state.status == .unchecked && !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                state.status = .attention
            }
            run.states[itemID] = state
        }
    }

    func addPhoto(_ data: Data, itemID: String, runID: UUID) {
        guard let filename = savePhoto(data, runID: runID) else { return }
        mutate(runID) { run in
            var state = run.state(for: itemID)
            state.photoFilenames.append(filename)
            state.updatedAt = Date()
            run.states[itemID] = state
        }
    }

    func removePhoto(_ filename: String, itemID: String, runID: UUID) {
        try? FileManager.default.removeItem(at: photoURL(filename, runID: runID))
        mutate(runID) { run in
            var state = run.state(for: itemID)
            state.photoFilenames.removeAll { $0 == filename }
            state.updatedAt = Date()
            run.states[itemID] = state
        }
    }

    func addCustomItem(_ item: DeliveryChecklistCustomItem, runID: UUID) {
        mutate(runID) { $0.customItems.append(item) }
    }

    func setHidden(_ hidden: Bool, itemID: String, runID: UUID) {
        mutate(runID) { run in
            if hidden {
                if !run.hiddenItemIDs.contains(itemID) { run.hiddenItemIDs.append(itemID) }
            } else {
                run.hiddenItemIDs.removeAll { $0 == itemID }
            }
        }
    }

    func removeCustomItem(id: UUID, runID: UUID) {
        mutate(runID) { run in
            run.customItems.removeAll { $0.id == id }
            run.states[id.uuidString] = nil
        }
    }

    func markComplete(runID: UUID) {
        mutate(runID) { $0.completedAt = Date() }
    }

    func resetCategory(_ category: DeliveryChecklistCategory, runID: UUID) {
        mutate(runID) { run in
            for item in run.items(in: category) {
                run.states[item.id] = nil
            }
        }
    }

    private func mutate(_ runID: UUID, _ body: (inout DeliveryChecklistRun) -> Void) {
        guard let index = runs.firstIndex(where: { $0.id == runID }) else { return }
        var run = runs[index]
        body(&run)
        runs[index] = run
    }

    // MARK: Photos

    private var documentsDirectory: URL {
        (try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
    }

    private func photoDirectory(runID: UUID) -> URL {
        documentsDirectory
            .appendingPathComponent("DeliveryChecklist")
            .appendingPathComponent(runID.uuidString)
    }

    func photoURL(_ filename: String, runID: UUID) -> URL {
        photoDirectory(runID: runID).appendingPathComponent(filename)
    }

    private func savePhoto(_ data: Data, runID: UUID) -> String? {
        let dir = photoDirectory(runID: runID)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: dir.appendingPathComponent(filename), options: [.atomic])
            return filename
        } catch {
            return nil
        }
    }

    private func deletePhotoDirectory(runID: UUID) {
        try? FileManager.default.removeItem(at: photoDirectory(runID: runID))
    }

    // MARK: Persistence

    private var saveURL: URL {
        documentsDirectory.appendingPathComponent(filename)
    }

    private func hydrate() {
        guard let data = try? Data(contentsOf: saveURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([DeliveryChecklistRun].self, from: data) else { return }
        runs = decoded
    }

    /// Coalesced: typing a note mutates `runs` on every keystroke, and writing
    /// the whole file each time is enough I/O to be felt on the main thread.
    private func persist() {
        guard !isHydrating, !hasPendingSave else { return }
        hasPendingSave = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.hasPendingSave = false
            self.flush(self.runs)
        }
    }

    private func flush(_ snapshot: [DeliveryChecklistRun]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: saveURL, options: [.atomic])
    }
}
