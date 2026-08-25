//
//  TeslaFiCSVImportView.swift
//  My KWh Companion
//
//  Swift 6 / iOS 17+
//
//  Wired: CSVDropSupport -- drag a CSV onto the import card to trigger import.
//
//  🔧 FIX: Removed inner NavigationStack wrapper. This view is always pushed
//  via NavigationLink inside ChargingImportHubView's NavigationStack. Wrapping
//  in a second NavigationStack killed the back button and caused layout glitches.
//

import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct TeslaFiCSVImportView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore
    @EnvironmentObject private var appearance: AppAppearance

    // MARK: - Local UI state

    @State private var showingFileImporter = false
    @State private var selectedFileName: String?
    @State private var filePickerError: String?
    @State private var showHeaderDetails = false
    @State private var showFailures = false

    // Drag-and-drop hover state
    @State private var isDragTargeted = false

    // MARK: - Body

    // 🔧 FIX: No NavigationStack here — ChargingImportHubView owns the stack.
    // Adding one here created a double-navigation-stack hierarchy that broke
    // the back button and produced incorrect title bar behavior.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statsSection
                importCard
                if teslaFiStore.lastImportReport != nil { reportSection }
                if teslaFiStore.lastImportReport?.hasFailures == true { failuresSection }
                footerHint
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle("TeslaFi CSV Import")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [
                .commaSeparatedText,
                .plainText,
                .data
            ],
            allowsMultipleSelection: false,
            onCompletion: handleFileImporterResult(_:)
        )
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            LinearGradient(
                colors: [
                    appearance.accentColor.opacity(scheme == .dark ? 0.10 : 0.05),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        let accent = appearance.accentColor

        return Group {
            if teslaFiStore.sessionCount > 0 {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Current Data", systemImage: "chart.bar.fill")
                        .font(.headline)

                    HStack(spacing: 12) {
                        statChip(
                            title: "Sessions",
                            value: "\(teslaFiStore.sessionCount)",
                            icon: "bolt.fill",
                            color: accent
                        )
                        statChip(
                            title: "Total kWh",
                            value: String(format: "%.1f", teslaFiStore.totalKWh),
                            icon: "gauge.with.dots.needle.67percent",
                            color: .green
                        )
                        if teslaFiStore.totalCost > 0 {
                            statChip(
                                title: "Total Cost",
                                value: currency(teslaFiStore.totalCost),
                                icon: "dollarsign",
                                color: .orange
                            )
                        }
                    }

                    if let latest = teslaFiStore.latestSession {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text("Latest: \(dateFormatter.string(from: latest.startDate))")
                                .font(.caption)
                            if let loc = latest.location {
                                Text("·")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text(loc)
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(glassCard)
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No imported sessions yet")
                            .font(.headline)
                        Text("Export a compatible charging-session CSV and import it below.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(glassCard)
            }
        }
    }

    // MARK: - Import Card

    private var importCard: some View {
        let accent = appearance.accentColor

        return VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(accent.opacity(scheme == .dark ? 0.22 : 0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: teslaFiStore.isImporting ? "arrow.down.circle" : "tray.and.arrow.down.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                        .symbolEffect(.pulse, isActive: teslaFiStore.isImporting)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Select Charging CSV")
                        .font(.headline)
                    Text("Export from your source, save to Files, then choose below — or drag & drop.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if teslaFiStore.isImporting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                }
            }

            // Selected file chip
            if let name = selectedFileName {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(accent)
                    Text(name)
                        .lineLimit(1)
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(scheme == .dark ? 0.18 : 0.08))
                )
            }

            // Progress bar when importing
            if teslaFiStore.isImporting {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(accent)
                    Text("Parsing charging CSV… This can take a moment for large imports.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Choose button
            Button {
                filePickerError = nil
                showingFileImporter = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                    Text(selectedFileName == nil ? "Choose CSV from Files" : "Choose Different File")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .disabled(teslaFiStore.isImporting)

            // Drag hint
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.to.line.compact")
                    .font(.caption)
                Text("Or drag & drop a CSV directly onto this card")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            // Error banners
            if let pickerError = filePickerError { errorBanner(text: pickerError) }
            if let importError = teslaFiStore.lastError { errorBanner(text: importError) }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(uiColor: .secondarySystemBackground),
                            accent.opacity(scheme == .dark ? 0.12 : 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isDragTargeted ? accent : Color.primary.opacity(0.07),
                    style: isDragTargeted
                        ? StrokeStyle(lineWidth: 2.5, dash: [8, 5])
                        : StrokeStyle(lineWidth: 0.8)
                )
                .animation(.easeInOut(duration: 0.18), value: isDragTargeted)
        )
        .overlay(alignment: .center) {
            if isDragTargeted {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(accent.opacity(scheme == .dark ? 0.15 : 0.08))
                    .overlay(
                        VStack(spacing: 10) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 32))
                            Text("Release to Import")
                                .font(.headline)
                        }
                        .foregroundStyle(accent)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDragTargeted)
        .dropDestination(
            for: URL.self,
            action: { items, _ in
                guard let url = items.first else { return false }
                let ext = url.pathExtension.lowercased()
                guard ["csv", "txt", ""].contains(ext) else { return false }
                selectedFileName = url.lastPathComponent
                filePickerError = nil
                Task { await teslaFiStore.importFromCSV(at: url) }
                return true
            },
            isTargeted: { isDragTargeted = $0 }
        )
    }

    // MARK: - Report Section

    private var reportSection: some View {
        Group {
            if let report = teslaFiStore.lastImportReport {
                ImportReportCard(report: report, showHeaderDetails: $showHeaderDetails)
            }
        }
    }

    private var failuresSection: some View {
        Group {
            if let report = teslaFiStore.lastImportReport, report.hasFailures {
                TFIFailuresCard(report: report, showFailures: $showFailures)
            }
        }
    }

    private var footerHint: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("Stays on Your Device")
                    .font(.subheadline.weight(.semibold))
                Text("Imported data is stored locally and used across analytics, forecasts, and budgeting. Nothing is uploaded to a server.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(glassCard)
        .padding(.top, 4)
    }

    // MARK: - Reusable sub-views

    private var glassCard: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07))
            )
    }

    private func statChip(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemBackground))
        )
    }

    private func errorBanner(text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.medium)
            Text(text)
                .font(.footnote)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red.opacity(0.10))
        )
        .foregroundStyle(.red)
    }

    // MARK: - Handlers

    private func handleFileImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            filePickerError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else {
                filePickerError = "No file was selected."
                return
            }
            selectedFileName = url.lastPathComponent
            filePickerError = nil
            Task { await teslaFiStore.importFromCSV(at: url) }
        }
    }

    private func currency(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        return f.string(from: amount as NSNumber) ?? String(format: "$%.2f", amount)
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }
}

// MARK: - ImportReportCard

private struct ImportReportCard: View {
    let report: TFIImportReport
    @Binding var showHeaderDetails: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Last Import Summary", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)

            // Stat row
            HStack(spacing: 0) {
                resultStat(label: "Processed", value: "\(report.rowCount)", icon: "doc.text")
                Divider().frame(height: 36).padding(.horizontal, 12)
                resultStat(label: "Inserted", value: "\(report.insertedCount)", icon: "plus.circle.fill", color: .green)
                Divider().frame(height: 36).padding(.horizontal, 12)
                resultStat(label: "Skipped", value: "\(report.skippedDuplicates)", icon: "minus.circle", color: .secondary)
            }

            // File info
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.caption)
                Text(report.filename)
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)

            if report.columnMismatchRowCount > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(report.columnMismatchRowCount) rows had mismatched column counts")
                            .font(.caption.weight(.medium))
                        if !report.columnMismatchSampleLines.isEmpty {
                            Text("Sample lines: \(report.columnMismatchSampleLines.map(String.init).joined(separator: ", "))")
                                .font(.caption2)
                        }
                    }
                }
                .foregroundStyle(.orange)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.orange.opacity(0.08))
                )
            }

            if !report.headerUsage.isEmpty {
                DisclosureGroup(isExpanded: $showHeaderDetails) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(report.headerUsage, id: \.index) { usage in
                            HeaderUsageRow(usage: usage)
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Label("Header mapping details", systemImage: "list.bullet.rectangle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.green.opacity(scheme == .dark ? 0.25 : 0.15))
                )
        )
    }

    private func resultStat(
        label: String,
        value: String,
        icon: String,
        color: Color = .primary
    ) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - HeaderUsageRow

private struct HeaderUsageRow: View {
    let usage: TFIHeaderUsage

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("#\(usage.index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
            Text(usage.name)
                .font(.caption)
            Spacer(minLength: 8)
            if usage.mappedTo.isEmpty {
                Text("not mapped")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text(usage.mappedTo.joined(separator: ", "))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 1)
    }
}

// MARK: - TFIFailuresCard

private struct TFIFailuresCard: View {
    let report: TFIImportReport
    @Binding var showFailures: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup(isExpanded: $showFailures) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(report.failures, id: \.lineNumber) { failure in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Line \(failure.lineNumber)")
                                .font(.caption.weight(.semibold))
                            Text(failure.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.red.opacity(0.07))
                        )
                    }
                }
                .padding(.top, 6)
            } label: {
                Label("Rows with issues (\(report.failures.count))", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
            }

            Text("These rows were skipped. Review them in the original CSV if needed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.red.opacity(scheme == .dark ? 0.10 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.red.opacity(0.2))
                )
        )
    }
}
