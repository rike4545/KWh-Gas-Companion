//
//  ReorderableList.swift
//  KWh Gas Companion
//
//  Created by Bryan on 11/4/25.
//


//
//  ReorderableList.swift
//

import SwiftUI

/// A simple, strongly-typed reorderable list using DragToken.
/// Reorders when you DROP on a specific row (no hover placeholder).
@MainActor
public struct ReorderableList<Item: Identifiable, Row: View>: View {
    @Binding private var items: [Item]
    private let kind: String
    private let row: (Item) -> Row
    private let canReorder: (Item) -> Bool
    private let onMove: ((Int, Int) -> Void)?

    @Environment(\.undoManager) private var undo

    public init(
        items: Binding<[Item]>,
        kind: String,
        canReorder: @escaping (Item) -> Bool = { _ in true },
        onMove: ((Int, Int) -> Void)? = nil,
        @ViewBuilder row: @escaping (Item) -> Row
    ) {
        self._items = items
        self.kind = kind
        self.row = row
        self.canReorder = canReorder
        self.onMove = onMove
    }

    public var body: some View {
        List {
            ForEach(items) { item in
                row(item)
                    .contentShape(Rectangle())
                    .draggable(DragToken(id: DnD.idString(item), kind: kind))
                    .dropDestination(for: DragToken.self) { tokens, _ in
                        guard let token = tokens.first, token.kind == kind else { return false }
                        guard let from = items.firstIndex(where: { DnD.idString($0) == token.id }),
                              let to   = items.firstIndex(where: { DnD.idString($0) == DnD.idString(item) }),
                              from != to,
                              canReorder(items[from]), canReorder(items[to])
                        else { return false }

                        var copy = items
                        let moving = copy.remove(at: from)
                        copy.insert(moving, at: to)
                        withAnimation(.snappy) { items = copy }

                        // Undo support
                        DnD.registerUndoMove($items, from: to, to: from, undoManager: undo)

                        onMove?(from, to)
                        return true
                    }
            }
        }
        .listStyle(.plain)
    }
}
