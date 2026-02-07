//  TeslaFiCSVImportView.swift
//  My KWh Companion
//
//  Swift 6 / iOS 17+
//
//  Dedicated TeslaFi CSV import screen.
//
//  - Uses `.fileImporter` with proper security-scoped URL handling
//  - Shows a clear loading state while parsing large CSVs
//  - Surfaces `TFIImportReport` details (inserted, duplicates, failures, header mapping)
//  - Relies on `TeslaFiSessionStore.importFromCSV(at:)` for the heavy lifting
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
    @StateObject private var teslaFiUnlock = TeslaFiEntitlementStore.shared

    // MARK: - Local UI state

    @State private var showingFileImporter = false
    @State private var selectedFileName: String?
    @State private var filePickerError: String?
    @State private var showHeaderDetails = false
    @State private var showFailures = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    if teslaFiUnlock.hasTeslaFiUnlock {
                        currentStatsSection
                        importCard
                        reportSection
                        failuresSection
                        footerHint
                    } else {
                        TeslaFiUnlockCard(
                            title: "TeslaFi Import Locked",
                            subtitle: "Unlock TeslaFi CSV import and analytics for a one‑time purchase."
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Import from TeslaFi")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
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
        .task { await teslaFiUnlock.load() }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TeslaFi CSV Import")
                .font(.title2.weight(.semibold))

            Text("Bring in your TeslaFi charging sessions so My KWh Companion can use them in analytics, dashboards, and budgeting. This importer is separate from the official Tesla CSV wizard.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var currentStatsSection: some View {
        let accent = appearance.accentColor

        return Group {
            if teslaFiStore.sessionCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current TeslaFi Data")
                        .font(.headline)

                    HStack(spacing: 16) {
                        statChip(
                            title: "Sessions",
                            value: "\(teslaFiStore.sessionCount)"
                        )
                        statChip(
                            title: "Total kWh",
                            value: String(format: "%.1f", teslaFiStore.totalKWh)
                        )
                        if teslaFiStore.totalCost > 0 {
                            statChip(
                                title: "Total Cost",
                                value: currency(teslaFiStore.totalCost)
                            )
                        }
                    }

                    if let latest = teslaFiStore.latestSession {
                        Text("Latest session: \(dateFormatter.string(from: latest.startDate)) at \(latest.location ?? "Unknown")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No TeslaFi sessions yet")
                        .font(.headline)
                    Text("Start by exporting a CSV from TeslaFi (Charging Sessions export) and then import it below.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accent.opacity(scheme == .dark ? 0.18 : 0.10))
        )
    }

    private var importCard: some View {
        let accent = appearance.accentColor

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Select TeslaFi CSV", systemImage: "tray.and.arrow.down")
                    .font(.headline)
                Spacer()
                if teslaFiStore.isImporting {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }

            Text("From TeslaFi, export your charging sessions as CSV (typically via **Tools → Export → Charging**). Save it into the Files app, then tap the button below to select it.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let selectedFileName {
                HStack {
                    Image(systemName: "doc.text")
                    Text(selectedFileName)
                        .lineLimit(1)
                    Spacer()
                }
                .font(.subheadline)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(scheme == .dark ? 0.28 : 0.12))
                )
            }

            Button {
                filePickerError = nil
                showingFileImporter = true
            } label: {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text("Choose CSV from Files")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .disabled(teslaFiStore.isImporting)

            if teslaFiStore.isImporting {
                Text("Parsing TeslaFi CSV… This can take a little while for large exports. You can leave this screen open while it works.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let pickerError = filePickerError {
                errorBanner(text: pickerError)
            }

            if let importError = teslaFiStore.lastError {
                errorBanner(text: importError)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            appearance.accentColor.opacity(scheme == .dark ? 0.25 : 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    Color.white.opacity(scheme == .dark ? 0.30 : 0.20),
                    lineWidth: 0.7
                )
        )
    }

    private var reportSection: some View {
        Group {
            if let report = teslaFiStore.lastImportReport {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Last Import Summary")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("File")
                            Spacer()
                            Text(report.filename)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Rows processed")
                            Spacer()
                            Text("\(report.rowCount)")
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Inserted sessions")
                            Spacer()
                            Text("\(report.insertedCount)")
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Skipped duplicates")
                            Spacer()
                            Text("\(report.skippedDuplicates)")
                                .foregroundStyle(.secondary)
                        }

                        if report.columnMismatchRowCount > 0 {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Column mismatches")
                                Spacer()
                                Text("\(report.columnMismatchRowCount)")
                                    .foregroundStyle(.secondary)
                            }
                            if !report.columnMismatchSampleLines.isEmpty {
                                Text("Sample rows with mismatched column counts: \(report.columnMismatchSampleLines.map(String.init).joined(separator: ", ")).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .font(.subheadline)

                    if !report.headerUsage.isEmpty {
                        DisclosureGroup(
                            isExpanded: $showHeaderDetails,
                            content: {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(report.headerUsage, id: \.index) { usage in
                                        HStack(alignment: .firstTextBaseline) {
                                            Text("#\(usage.index + 1)")
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                            Text("“\(usage.name)”")
                                            Spacer(minLength: 8)
                                            if usage.mappedTo.isEmpty {
                                                Text("— not mapped")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            } else {
                                                Text(usage.mappedTo.joined(separator: ", "))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            },
                            label: {
                                Label("Header mapping details", systemImage: "list.bullet.rectangle")
                                    .font(.subheadline)
                            }
                        )
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
    }

    private var failuresSection: some View {
        Group {
            if let report = teslaFiStore.lastImportReport,
               report.hasFailures {
                VStack(alignment: .leading, spacing: 8) {
                    DisclosureGroup(
                        isExpanded: $showFailures,
                        content: {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(report.failures, id: \.lineNumber) { failure in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Line \(failure.lineNumber)")
                                            .font(.caption.weight(.semibold))
                                        Text(failure.message)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.red.opacity(0.07))
                                    )
                                }
                            }
                            .padding(.top, 4)
                        },
                        label: {
                            Label(
                                "Rows with issues (\(report.failures.count))",
                                systemImage: "exclamationmark.triangle"
                            )
                            .foregroundStyle(.red)
                        }
                    )

                    Text("These rows were skipped during import. You can review them in the original CSV if needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
        }
    }

    private var footerHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How this data is used")
                .font(.headline)
            Text("Imported TeslaFi sessions stay on this device and can be reused across My KWh Companion’s analytics dashboards, forecasts, and budgeting tools. No data is uploaded to a server.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
    }

    // MARK: - Helpers

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
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
                .fill(Color.red.opacity(0.12))
        )
        .foregroundStyle(.red)
    }

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

            Task {
                await teslaFiStore.importFromCSV(at: url)
            }
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
