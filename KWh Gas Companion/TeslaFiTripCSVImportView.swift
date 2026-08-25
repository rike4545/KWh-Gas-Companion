import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct TeslaFiTripCSVImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appearance: AppAppearance
    @Environment(\.colorScheme) private var scheme

    @StateObject private var tripStore = TeslaFiTripStore(persistToDisk: true)

    @State private var showingFileImporter = false
    @State private var selectedFileName: String?
    @State private var filePickerError: String?
    @State private var importError: String?
    @State private var lastReport: TeslaFiRawTripImportReport?
    @State private var isImporting = false
    @State private var isDragTargeted = false

    private var allTrips: [TeslaFiTrip] { _tripStore.wrappedValue.trips.sorted(by: { $0.startDate > $1.startDate }) }
    private var tripSegments: [TripSegment] { _tripStore.wrappedValue.segments() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                currentStatsSection
                importCard
                reportSection
                recentTripsSection
                footerHint
            }
            .padding()
        }
        .navigationTitle("Import Trip Logs")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText, .data],
            allowsMultipleSelection: false,
            onCompletion: handleFileImporterResult(_:)
        )
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TeslaFi Raw Trip Log Import")
                .font(.title2.weight(.semibold))
            Text("Import raw TeslaFi polling logs and derive trips from movement windows using speed, shift state, odometer, and battery changes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var currentStatsSection: some View {
        let trips = allTrips
        let totalMiles = trips.compactMap(\.distanceMiles).reduce(0, +)
        return VStack(alignment: .leading, spacing: 8) {
            Text(trips.isEmpty ? "No imported trips yet" : "Current Imported Trips")
                .font(.headline)
            if trips.isEmpty {
                Text("Start by choosing one of your TeslaFi raw CSV exports.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 16) {
                    statChip(title: "Trips", value: "\(trips.count)")
                    statChip(title: "Miles", value: String(format: "%.1f", totalMiles))
                    statChip(title: "Days", value: "\(tripSegments.count)")
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(appearance.accentColor.opacity(scheme == .dark ? 0.18 : 0.10))
        )
    }

    private var importCard: some View {
        let accent = appearance.accentColor
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Select TeslaFi Raw CSV", systemImage: "road.lanes")
                    .font(.headline)
                Spacer()
                if isImporting {
                    ProgressView().progressViewStyle(.circular)
                }
            }

            Text("These files are minute-by-minute TeslaFi state logs, not the summarized Trips export. The importer derives trip boundaries automatically.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let name = selectedFileName {
                HStack {
                    Image(systemName: "doc.text")
                    Text(name).lineLimit(1)
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
            .disabled(isImporting)

            HStack(spacing: 6) {
                Image(systemName: "arrow.down.to.line.compact").font(.caption)
                Text("Or drag & drop a CSV onto this card").font(.caption)
            }
            .foregroundStyle(.secondary)

            if let filePickerError { errorBanner(text: filePickerError) }
            if let importError { errorBanner(text: importError) }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(.systemBackground), accent.opacity(scheme == .dark ? 0.25 : 0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(scheme == .dark ? 0.30 : 0.20), lineWidth: 0.7)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(accent, style: StrokeStyle(lineWidth: 2.5, dash: [8, 5]))
                .opacity(isDragTargeted ? 1 : 0)
                .animation(.easeInOut(duration: 0.18), value: isDragTargeted)
        )
        .dropDestination(for: URL.self, action: { items, _ in
            guard let url = items.first else { return false }
            selectedFileName = url.lastPathComponent
            filePickerError = nil
            Task { await importTrips(from: url) }
            return true
        }, isTargeted: { isDragTargeted = $0 })
    }

    private var reportSection: some View {
        Group {
            if let lastReport {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Import Summary")
                        .font(.headline)
                    reportRow("File", lastReport.filename)
                    reportRow("Rows processed", "\(lastReport.rowCount)")
                    reportRow("Moving rows", "\(lastReport.movementRowCount)")
                    reportRow("Stationary rows", "\(lastReport.stationaryRowCount)")
                    reportRow("Inserted trips", "\(lastReport.insertedCount)")
                    reportRow("Skipped duplicates", "\(lastReport.skippedDuplicates)")
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
    }

    private var recentTripsSection: some View {
        let trips = Array(allTrips.prefix(8))
        return Group {
            if !trips.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Derived Trips")
                        .font(.headline)
                    ForEach(trips) { trip in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(trip.startDate.formatted(date: .abbreviated, time: .shortened)) to \(trip.endDate.formatted(date: .omitted, time: .shortened))")
                                .font(.subheadline.weight(.semibold))
                            Text([
                                trip.distanceMiles.map { String(format: "%.1f mi", $0) },
                                trip.averageSpeedMPH.map { String(format: "%.0f mph avg", $0) },
                                trip.maxSpeedMPH.map { String(format: "%.0f mph max", $0) },
                                batteryDeltaText(for: trip)
                            ].compactMap { $0 }.joined(separator: " • "))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                }
            }
        }
    }

    private var footerHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How this import works")
                .font(.headline)
            Text("Trips are derived locally on-device from movement windows in the raw TeslaFi log. Energy usage is left blank for now unless a future parser can infer it confidently.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private func importTrips(from url: URL) async {
        isImporting = true
        importError = nil
        defer { isImporting = false }
        do {
            let (newTrips, report) = try TeslaFiTripStore.parseTeslaFiRawTripCSV(from: url, existing: allTrips)
            _ = tripStore.ingest(newTrips)
            lastReport = report
        } catch {
            importError = error.localizedDescription
        }
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
            Task { await importTrips(from: url) }
        }
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit())
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
        )
    }

    private func reportRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private func errorBanner(text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").imageScale(.medium)
            Text(text).font(.footnote).multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red.opacity(0.12))
        )
        .foregroundStyle(.red)
    }

    private func batteryDeltaText(for trip: TeslaFiTrip) -> String? {
        guard let start = trip.startBatteryLevel, let end = trip.endBatteryLevel else { return nil }
        return "\(Int(start))% to \(Int(end))%"
    }
}
