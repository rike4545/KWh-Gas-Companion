//
//  FileDropZone.swift
//  My KWh Companion
//
//  Fixed 2025-11-04 (iOS 17 / Swift 6)
//  - Replace .quaternary/.accent with explicit Color.*
//  - Use .dropDestination(for:action:isTargeted:) signature
//  - Keep CSV/PDF filtering and simple styling
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - FileDropZone

@MainActor
public struct FileDropZone: View {
    public enum Accept { case csvAndPdf, anyFile, urlsOnly }

    private let accept: Accept
    private let onURLs: ([URL]) -> Void

    @State private var isHovering = false

    public init(accept: Accept = .csvAndPdf, onURLs: @escaping ([URL]) -> Void) {
        self.accept = accept
        self.onURLs = onURLs
    }

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
                .font(.largeTitle)
            Text(title)
                .font(.headline)
            Text("Drag from Files, Mail, Safari…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isHovering ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 2, dash: [6, 6])
                )
        )
        .contentShape(Rectangle())
        .dropDestination(for: URL.self) { urls, _ in
            onURLs(filtered(urls))
            return true
        } isTargeted: { hovering in
            isHovering = hovering
        }
        .padding(.horizontal)
    }

    private var title: String {
        switch accept {
        case .csvAndPdf: return "Drop CSV or PDF"
        case .anyFile:   return "Drop Files"
        case .urlsOnly:  return "Drop Links"
        }
    }

    private func filtered(_ urls: [URL]) -> [URL] {
        switch accept {
        case .urlsOnly:
            return urls
        case .anyFile:
            return urls
        case .csvAndPdf:
            return urls.filter { $0.pathExtension.lowercased() == "csv" || $0.pathExtension.lowercased() == "pdf" }
        }
    }
}

// MARK: - DropPill

@MainActor
public struct DropPill<Payload: Transferable>: View {
    public let title: String
    public let systemImage: String
    public let onDrop: ([Payload]) -> Void

    @State private var isHovering = false

    public init(title: String, systemImage: String, onDrop: @escaping ([Payload]) -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.onDrop = onDrop
    }

    public var body: some View {
        Label(title, systemImage: systemImage)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isHovering ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .dropDestination(for: Payload.self) { items, _ in
                onDrop(items)
                return true
            } isTargeted: { hovering in
                isHovering = hovering
            }
    }
}
