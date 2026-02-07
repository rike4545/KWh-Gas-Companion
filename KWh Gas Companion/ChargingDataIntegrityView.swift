//
//  ChargingDataIntegrityView.swift
//  My KWh Companion
//
//  Integrity dashboard for TeslaFi session data.
//  FIXES:
//  - Uses [TeslaFiIntegrityIssue] directly (no TeslaFiSessionIssue bridging)
//  - Displays severity safely without assuming enum cases or String severity storage
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import Foundation

@MainActor
struct ChargingDataIntegrityView: View {

    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore

    @State private var showAllDetails: Bool = false

    private var issues: [TeslaFiIntegrityIssue] {
        teslaFiStore.integrityIssues
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {

                summaryCard

                controlsCard

                issuesCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("Data Integrity")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Cards

    private var summaryCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Integrity Overview", systemImage: "checkmark.seal")
                    .font(.headline)

                if issues.isEmpty {
                    Text("No integrity warnings detected.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(issues.count) issue(s) detected.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("These checks help you spot duplicates, missing timestamps, or suspiciously short sessions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var controlsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Display", systemImage: "slider.horizontal.3")
                    .font(.headline)

                Toggle("Show all details", isOn: $showAllDetails)
            }
        }
    }

    private var issuesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Issues", systemImage: issues.isEmpty ? "checkmark.circle" : "exclamationmark.triangle")
                    .font(.headline)

                if issues.isEmpty {
                    Text("Everything looks good.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                        issueRow(issue)
                        Divider().opacity(0.35)
                    }
                }
            }
        }
    }

    // MARK: - Rows

    private func issueRow(_ issue: TeslaFiIntegrityIssue) -> some View {
        let sevText = describeSeverity(issue.severity)
        let sevIcon = iconForSeverityText(sevText)
        let sevColor = colorForSeverityText(sevText)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: sevIcon)
                    .foregroundStyle(sevColor)
                    .font(.system(size: 16, weight: .semibold))

                Text(issue.title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(sevText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if showAllDetails {
                Text(issue.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Severity formatting (no assumptions about enum cases)

    private func describeSeverity(_ severity: TeslaFiIntegrityIssue.Severity) -> String {
        // Avoid switching on unknown cases; just stringify.
        let raw = String(describing: severity)
        let cleaned = raw
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Title-case-ish for display
        return cleaned.isEmpty ? "Unknown" : cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }

    private func iconForSeverityText(_ text: String) -> String {
        let t = text.lowercased()
        if t.contains("error") || t.contains("critical") || t.contains("fatal") { return "xmark.octagon.fill" }
        if t.contains("warn") || t.contains("warning") { return "exclamationmark.triangle.fill" }
        return "info.circle.fill"
    }

    private func colorForSeverityText(_ text: String) -> Color {
        let t = text.lowercased()
        if t.contains("error") || t.contains("critical") || t.contains("fatal") { return .red }
        if t.contains("warn") || t.contains("warning") { return .orange }
        return .blue
    }

    // MARK: - Card chrome

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            )
    }
}
