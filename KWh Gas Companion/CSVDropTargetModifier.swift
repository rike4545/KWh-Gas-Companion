//
//  CSVDropTargetModifier.swift
//  My KWh Companion
//
//  Drag-and-drop CSV support for CSVChargingWizardView and
//  TeslaFiCSVImportView on iOS 17+.
//
//  🔧 FIX: CSVDropTargetModifier previously used @EnvironmentObject for
//  AppAppearance, which crashes if the modifier is applied to a view that
//  doesn't have AppAppearance in its environment (e.g. inside Form sections).
//  Changed to accept accent color as a parameter, eliminating the crash.
//
//  Swift 6 / iOS 17+
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - CSVDropTargetModifier

struct CSVDropTargetModifier: ViewModifier {
    /// Binding driven to `true` while a compatible item hovers over the view.
    @Binding var isTargeted: Bool
    /// Called on successful drop with the first resolved file URL.
    var onDrop: (URL) -> Void

    // 🔧 FIX: Was @EnvironmentObject AppAppearance — crashes if not in env.
    // Accept accent color as a plain parameter instead.
    var accentColor: Color = .accentColor

    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        isTargeted
                            ? accentColor
                            : Color.clear,
                        style: StrokeStyle(lineWidth: 3, dash: [8, 5])
                    )
                    .animation(.easeInOut(duration: 0.2), value: isTargeted)
            )
            .overlay(
                Group {
                    if isTargeted {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(accentColor.opacity(scheme == .dark ? 0.18 : 0.10))
                            .overlay(
                                VStack(spacing: 10) {
                                    Image(systemName: "arrow.down.doc.fill")
                                        .font(.system(size: 36))
                                    Text("Drop CSV here")
                                        .font(.headline)
                                }
                                .foregroundStyle(accentColor)
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isTargeted)
            )
            .dropDestination(
                for: URL.self,
                action: { items, _ in
                    guard let url = items.first else { return false }
                    let ext = url.pathExtension.lowercased()
                    let accepted = ["csv", "txt", ""].contains(ext)
                    if accepted { onDrop(url) }
                    return accepted
                },
                isTargeted: { isTargeted = $0 }
            )
    }
}

extension View {
    /// Adds CSV drag-and-drop support with a visual hover indicator.
    /// - Parameters:
    ///   - isTargeted: Binding set to `true` while a CSV is hovering.
    ///   - accentColor: Highlight color; defaults to `.accentColor`.
    ///   - onDrop: Called with the resolved file URL on successful drop.
    func csvDropTarget(
        isTargeted: Binding<Bool>,
        accentColor: Color = .accentColor,
        onDrop: @escaping (URL) -> Void
    ) -> some View {
        modifier(CSVDropTargetModifier(
            isTargeted: isTargeted,
            onDrop: onDrop,
            accentColor: accentColor
        ))
    }
}

// MARK: - SelectCSVStepWithDrop
//
// Drop-in replacement for SelectCSVStep that adds drag-and-drop.
// Wire it the same way: pass selectAction (opens file picker) and
// onFileDrop (called with the dropped URL, same as loadCSV(from:)).

struct SelectCSVStepWithDrop: View {
    var selectAction: () -> Void
    var onFileDrop: (URL) -> Void
    /// Optional: name of the currently selected file to display feedback.
    var selectedFileName: String? = nil
    /// Accent color — pass from parent rather than requiring EnvironmentObject.
    var accentColor: Color = .accentColor

    @Environment(\.colorScheme) private var scheme
    @State private var isDragTargeted = false

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [
                        accentColor.opacity(isDragTargeted
                                           ? (scheme == .dark ? 0.35 : 0.25)
                                           : (scheme == .dark ? 0.14 : 0.09)),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                VStack(spacing: 16) {
                    // Icon — swaps while dragging
                    ZStack {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(accentColor.opacity(0.7))
                            .opacity(isDragTargeted ? 0 : 1)
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(accentColor)
                            .opacity(isDragTargeted ? 1 : 0)
                    }
                    .animation(.easeInOut(duration: 0.18), value: isDragTargeted)

                    VStack(spacing: 6) {
                        Text(isDragTargeted
                             ? "Release to import"
                             : "Import your Supercharging CSV")
                            .font(.title3.weight(.bold))

                        if !isDragTargeted {
                            Text("From the Tesla app, download your charging billing history as a CSV, then select it below.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .animation(.easeInOut(duration: 0.18), value: isDragTargeted)

                    // Selected file chip
                    if let name = selectedFileName, !isDragTargeted {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(name)
                                .lineLimit(1)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(scheme == .dark ? 0.18 : 0.10))
                        )
                        .transition(.scale.combined(with: .opacity))
                    }

                    if !isDragTargeted {
                        VStack(spacing: 10) {
                            // Steps
                            HStack(spacing: 0) {
                                stepBadge("1", "Download from Tesla app")
                                stepConnector
                                stepBadge("2", "Tap Select CSV or drag here")
                                stepConnector
                                stepBadge("3", "Match columns & import")
                            }
                            .padding(.horizontal, 8)

                            // Drag hint chip
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.to.line.compact")
                                    .font(.caption)
                                Text("Or drag & drop a CSV anywhere on this card")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(scheme == .dark ? 0.15 : 0.10))
                            )
                        }
                        .transition(.opacity)
                    }

                    Button(action: selectAction) {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.badge.plus")
                            Text(selectedFileName == nil ? "Select CSV" : "Choose Different File")
                        }
                        .frame(maxWidth: 220)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                    .padding(.top, 4)
                    .accessibilityLabel("Select CSV file")
                    .opacity(isDragTargeted ? 0.4 : 1)
                }
                .padding(28)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDragTargeted)
            )
            .overlay(
                // Dashed border while hovering
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        accentColor,
                        style: StrokeStyle(lineWidth: 2.5, dash: [8, 5])
                    )
                    .opacity(isDragTargeted ? 1 : 0)
                    .animation(.easeInOut(duration: 0.18), value: isDragTargeted)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.18), lineWidth: 1)
                    .opacity(isDragTargeted ? 0 : 1)
            )
            .frame(maxWidth: .infinity, minHeight: 320)
            .padding(.horizontal)
            .padding(.top, 16)
            .dropDestination(
                for: URL.self,
                action: { items, _ in
                    guard let url = items.first else { return false }
                    let ext = url.pathExtension.lowercased()
                    guard ["csv", "txt", ""].contains(ext) else { return false }
                    onFileDrop(url)
                    return true
                },
                isTargeted: { isDragTargeted = $0 }
            )
    }

    private func stepBadge(_ number: String, _ label: String) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(scheme == .dark ? 0.22 : 0.14))
                    .frame(width: 28, height: 28)
                Text(number)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accentColor)
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 70)
        }
    }

    private var stepConnector: some View {
        Rectangle()
            .fill(accentColor.opacity(0.18))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SelectCSVStepWithDrop") {
    ScrollView {
        VStack(spacing: 20) {
            SelectCSVStepWithDrop(
                selectAction: { },
                onFileDrop: { _ in },
                selectedFileName: nil,
                accentColor: .blue
            )

            SelectCSVStepWithDrop(
                selectAction: { },
                onFileDrop: { _ in },
                selectedFileName: "Tesla_Charging_2024.csv",
                accentColor: .blue
            )
        }
        .padding(.bottom, 80)
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
#endif
