//
//  DragToken.swift
//  My KWh Companion
//
//  Updated 2025-11-04 (iOS 17 / Swift 6)
//  - Uses built-in UTType.json for Transferable (no Info.plist UTI required)
//  - Keeps undo/redo helper with class-based target
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Drag Token

/// Lightweight payload for in-app drag & drop plus kind-based gating.
/// `kind` is your namespace (e.g., "dashboard.tile", "expense", "route.stop").
public struct DragToken: Hashable, Codable, Transferable {
    public var id: String
    public var kind: String

    public init(id: String, kind: String) {
        self.id = id
        self.kind = kind
    }

    public static var transferRepresentation: some TransferRepresentation {
        // Encode as JSON for NSItemProvider; no custom UTI needed.
        CodableRepresentation(contentType: .json)
        // Nice fallback if dropped to text-only targets:
        ProxyRepresentation(exporting: \.id)
    }
}

// MARK: - Undo infrastructure (class target required by UndoManager)

fileprivate final class _UndoArrayApplier<Element>: NSObject {
    private let setter: ([Element]) -> Void
    init(setter: @escaping ([Element]) -> Void) { self.setter = setter }
    func apply(_ value: [Element]) { setter(value) }
}

// MARK: - DnD utilities

@MainActor
public enum DnD {
    /// Convert any Identifiable to a stable string id.
    public static func idString<I: Identifiable>(_ item: I) -> String {
        String(describing: item.id)
    }

    /// Register an undo/redo for a *pending* move. Call BEFORE mutating the array.
    public static func registerUndoMove<T>(
        _ items: Binding<[T]>,
        from: Int,
        to: Int,
        undoManager: UndoManager?
    ) {
        guard let undo = undoManager else { return }
        let before = items.wrappedValue
        let applier = _UndoArrayApplier<T>(setter: { items.wrappedValue = $0 })

        undo.registerUndo(withTarget: applier) { target in
            let current = items.wrappedValue
            target.apply(before)     // UNDO → restore "before"
            undo.registerUndo(withTarget: applier) { target in
                target.apply(current) // REDO → restore pre-undo state
            }
            undo.setActionName("Reorder")
        }
    }

    /// Perform the move now (clamped). Pair with `registerUndoMove` for undo/redo.
    public static func applyMove<T>(_ items: Binding<[T]>, from: Int, to: Int) {
        var array = items.wrappedValue
        guard !array.isEmpty else { return }
        let src = max(0, min(from, array.count - 1))
        let dst = max(0, min(to,   array.count - 1))
        guard src != dst else { return }
        let element = array.remove(at: src)
        array.insert(element, at: dst)
        items.wrappedValue = array
    }
}
