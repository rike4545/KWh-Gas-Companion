//
//  DeliveryChecklistView.swift
//  KWh Gas Companion
//
//  Delivery-day inspection — saved runs, section-by-section walkthrough, and
//  the export you hand to a delivery advisor.
//
//  Built for standing next to a car with one hand free: status is one tap,
//  notes and photos expand in place, and nothing needs a network.
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Hub

@MainActor
struct DeliveryChecklistView: View {

    @Environment(\.appThemeBox) private var themeBox
    @EnvironmentObject private var profileStore: ProfileStore
    @StateObject private var store = DeliveryChecklistStore()

    @State private var showingNew = false

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing) {
                headerCard

                if store.runs.isEmpty {
                    emptyState
                } else {
                    ForEach(store.sortedRuns) { run in
                        NavigationLink {
                            DeliveryChecklistRunView(runID: run.id, store: store)
                        } label: {
                            runCard(run)
                        }
                        .buttonStyle(.plain)
                    }
                }

                sectionsPreviewCard
                disclaimerCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .navigationTitle("Delivery Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .background(Rectangle().fill(theme.screenBackground).ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNew = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Start a new inspection")
            }
        }
        .sheet(isPresented: $showingNew) {
            NewDeliveryRunSheet(defaultVehicleName: selectedVehicleName) { run in
                store.add(run)
            }
        }
    }

    /// Saves typing when the garage already has a vehicle selected.
    private var selectedVehicleName: String {
        guard let selectedID = profileStore.selectedVehicleID,
              let match = profileStore.vehicles.first(where: { $0.id == selectedID })
        else { return "" }
        return match.displayName
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Inspect before you sign", systemImage: "checklist")
                .font(.headline)

            Text("\(DeliveryChecklistTemplate.count) checks across eight sections, with a photo and a timestamped note on anything that isn't right. Export the result as PDF or text and hand it to your advisor.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(prominent: true)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ContentUnavailableView(
                "No inspections yet",
                systemImage: "checklist",
                description: Text("Start one the morning of delivery — or the night before, to read through it.")
            )
            Button { showingNew = true } label: {
                Label("Start an inspection", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }

    private func runCard(_ run: DeliveryChecklistRun) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(run.displayTitle).font(.headline)
                Spacer()
                if run.flaggedCount > 0 {
                    Label("\(run.flaggedCount)", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                } else if run.isFinished {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }

            ProgressView(value: run.progress)
                .tint(run.flaggedCount > 0 ? .orange : theme.accent)

            HStack(spacing: 10) {
                Text("\(run.checkedCount)/\(run.totalCount) checked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if run.photoCount > 0 {
                    Label("\(run.photoCount)", systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(run.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
        .contentShape(Rectangle())
    }

    private var sectionsPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("What's covered", systemImage: "square.grid.2x2")
                .font(.headline)

            ForEach(DeliveryChecklistCategory.allCases) { category in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: category.systemImage)
                        .font(.caption)
                        .foregroundStyle(theme.accent)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(category.rawValue).font(.footnote.weight(.semibold))
                            Text("\(DeliveryChecklistTemplate.items(in: category).count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(category.blurb)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private var disclaimerCard: some View {
        Text(DeliveryChecklistTemplate.disclaimer)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
    }
}

// MARK: - Run detail

@MainActor
struct DeliveryChecklistRunView: View {

    let runID: UUID
    @ObservedObject var store: DeliveryChecklistStore

    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteConfirm = false
    @State private var exportDocument: DeliveryExportDocument?
    @State private var isBuildingExport = false

    private var theme: any AppThemeSpec { themeBox.base }
    private var run: DeliveryChecklistRun? { store.run(id: runID) }

    var body: some View {
        Group {
            if let run {
                content(run)
            } else {
                ContentUnavailableView(
                    "Inspection removed",
                    systemImage: "checklist",
                    description: Text("This inspection is no longer saved.")
                )
            }
        }
        .navigationTitle(run?.displayTitle ?? "Inspection")
        .navigationBarTitleDisplayMode(.inline)
        .background(Rectangle().fill(theme.screenBackground).ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { exportPDF() } label: {
                        Label("Export PDF", systemImage: "doc.richtext")
                    }
                    Button { exportText() } label: {
                        Label("Export text", systemImage: "doc.plaintext")
                    }
                    Divider()
                    Button(role: .destructive) { showingDeleteConfirm = true } label: {
                        Label("Delete inspection", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Delete this inspection?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                store.delete(id: runID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its notes and photos are deleted too.")
        }
        .sheet(item: $exportDocument) { document in
            ShareSheet(items: [document.url])
        }
    }

    private func content(_ run: DeliveryChecklistRun) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing) {
                progressCard(run)

                if run.flaggedCount > 0 {
                    flaggedCard(run)
                }

                ForEach(DeliveryChecklistCategory.allCases) { category in
                    NavigationLink {
                        DeliveryChecklistCategoryView(runID: runID, category: category, store: store)
                    } label: {
                        categoryCard(run, category)
                    }
                    .buttonStyle(.plain)
                }

                exportCard(run)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    private func progressCard(_ run: DeliveryChecklistRun) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(run.progress * 100))%")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(run.checkedCount) of \(run.totalCount)")
                        .font(.subheadline.weight(.semibold))
                    Text("items checked").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            ProgressView(value: run.progress)
                .tint(theme.accent)

            HStack(spacing: 14) {
                statChip("\(run.passCount)", "good", .green)
                statChip("\(run.flaggedCount)", "flagged", .orange)
                statChip("\(run.photoCount)", "photos", theme.accent)
            }

            if !run.vin.isEmpty || !run.vehicle.isEmpty {
                Text([run.vehicle, run.vin].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(prominent: true)
    }

    private func statChip(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func flaggedCard(_ run: DeliveryChecklistRun) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Needs attention", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(run.flaggedItems, id: \.item.id) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.item.category.rawValue) — \(entry.item.title)")
                        .font(.footnote.weight(.semibold))
                    let note = entry.state.note.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            Text("Get every one of these onto a written due bill, with the VIN on it, before you sign.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func categoryCard(_ run: DeliveryChecklistRun, _ category: DeliveryChecklistCategory) -> some View {
        let total = run.totalCount(in: category)
        let checked = run.checkedCount(in: category)
        let flagged = run.flaggedCount(in: category)

        return HStack(spacing: 12) {
            Image(systemName: category.systemImage)
                .font(.title3)
                .foregroundStyle(theme.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(category.rawValue).font(.subheadline.weight(.semibold))
                    if category.isPreSignature {
                        Text("before signing")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(theme.pillTint.opacity(0.45), in: Capsule())
                    }
                    Spacer()
                    if flagged > 0 {
                        Label("\(flagged)", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }

                ProgressView(value: total > 0 ? Double(checked) / Double(total) : 0)
                    .tint(checked == total && total > 0 ? .green : theme.accent)

                Text("\(checked)/\(total)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
        .contentShape(Rectangle())
    }

    private func exportCard(_ run: DeliveryChecklistRun) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Export", systemImage: "square.and.arrow.up")
                .font(.headline)

            Text("The PDF leads with everything flagged, photos included, then lists every item and its result.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button { exportPDF() } label: {
                    Label("PDF", systemImage: "doc.richtext")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBuildingExport)

                Button { exportText() } label: {
                    Label("Text", systemImage: "doc.plaintext")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func exportPDF() {
        guard let run else { return }
        isBuildingExport = true
        defer { isBuildingExport = false }
        #if canImport(UIKit)
        if let url = DeliveryChecklistExport.pdfFileURL(run, store: store) {
            exportDocument = DeliveryExportDocument(url: url)
        }
        #endif
    }

    private func exportText() {
        guard let run else { return }
        if let url = DeliveryChecklistExport.textFileURL(run) {
            exportDocument = DeliveryExportDocument(url: url)
        }
    }
}

/// Wrapper so an export file can drive `.sheet(item:)` without a retroactive
/// `Identifiable` conformance on `URL`.
private struct DeliveryExportDocument: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Category walkthrough

@MainActor
struct DeliveryChecklistCategoryView: View {

    let runID: UUID
    let category: DeliveryChecklistCategory
    @ObservedObject var store: DeliveryChecklistStore

    @Environment(\.appThemeBox) private var themeBox

    @State private var expandedItemID: String?
    @State private var showingAddItem = false
    @State private var hideCompleted = false

    private var theme: any AppThemeSpec { themeBox.base }
    private var run: DeliveryChecklistRun? { store.run(id: runID) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if let run {
                    headerCard(run)

                    ForEach(visibleItems(run)) { item in
                        DeliveryChecklistItemRow(
                            item: item,
                            state: run.state(for: item.id),
                            runID: runID,
                            store: store,
                            theme: theme,
                            isExpanded: expandedItemID == item.id,
                            onToggleExpand: {
                                withAnimation(.snappy(duration: 0.2)) {
                                    expandedItemID = expandedItemID == item.id ? nil : item.id
                                }
                            }
                        )
                    }

                    Button {
                        showingAddItem = true
                    } label: {
                        Label("Add your own check", systemImage: "plus.circle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .background(Rectangle().fill(theme.screenBackground).ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Hide completed", isOn: $hideCompleted)
                    Divider()
                    Button {
                        store.resetCategory(category, runID: runID)
                    } label: {
                        Label("Reset this section", systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddCustomCheckSheet(category: category) { item in
                store.addCustomItem(item, runID: runID)
            }
        }
    }

    private func visibleItems(_ run: DeliveryChecklistRun) -> [DeliveryChecklistResolvedItem] {
        let items = run.items(in: category)
        guard hideCompleted else { return items }
        return items.filter { run.state(for: $0.id).status != .pass }
    }

    private func headerCard(_ run: DeliveryChecklistRun) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.blurb)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ProgressView(value: run.progress(in: category))
                .tint(theme.accent)

            HStack {
                Text("\(run.checkedCount(in: category)) of \(run.totalCount(in: category)) checked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if category.isPreSignature {
                    Label("Do this before signing", systemImage: "signature")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(prominent: true)
        .padding(.bottom, 4)
    }
}

// MARK: - Item row

@MainActor
struct DeliveryChecklistItemRow: View {

    let item: DeliveryChecklistResolvedItem
    let state: DeliveryChecklistItemState
    let runID: UUID
    @ObservedObject var store: DeliveryChecklistStore
    let theme: any AppThemeSpec
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @State private var noteDraft: String = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingCamera = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onToggleExpand) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: state.status.systemImage)
                        .font(.title3)
                        .foregroundStyle(statusColor)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)

                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if !state.note.isEmpty && !isExpanded {
                            Label(state.note, systemImage: "note.text")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .lineLimit(2)
                                .padding(.top, 2)
                        }

                        if !state.photoFilenames.isEmpty && !isExpanded {
                            Label("\(state.photoFilenames.count) photo\(state.photoFilenames.count == 1 ? "" : "s")", systemImage: "photo")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            statusPicker

            if isExpanded {
                expandedSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
        .onAppear { noteDraft = state.note }
        .onChange(of: pickerItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    store.addPhoto(data, itemID: item.id, runID: runID)
                }
                pickerItem = nil
            }
        }
        #if canImport(UIKit)
        .fullScreenCover(isPresented: $showingCamera) {
            DeliveryPhotoCamera { data in
                store.addPhoto(data, itemID: item.id, runID: runID)
            }
            .ignoresSafeArea()
        }
        #endif
    }

    private var statusColor: Color {
        switch state.status {
        case .unchecked: return .secondary
        case .pass:      return .green
        case .attention: return .orange
        case .recheck:   return .blue
        }
    }

    private var statusPicker: some View {
        HStack(spacing: 6) {
            ForEach([DeliveryItemStatus.pass, .attention, .recheck], id: \.self) { candidate in
                Button {
                    let next: DeliveryItemStatus = state.status == candidate ? .unchecked : candidate
                    store.setStatus(next, itemID: item.id, runID: runID)
                    // A problem needs a note more often than not — open the row.
                    if next.isFlagged && !isExpanded { onToggleExpand() }
                } label: {
                    Text(candidate.title)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            state.status == candidate
                                ? color(for: candidate).opacity(0.24)
                                : theme.pillTint.opacity(0.22),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(
                                    state.status == candidate ? color(for: candidate).opacity(0.6) : .clear,
                                    lineWidth: 1
                                )
                        )
                        .foregroundStyle(state.status == candidate ? color(for: candidate) : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func color(for status: DeliveryItemStatus) -> Color {
        switch status {
        case .unchecked: return .secondary
        case .pass:      return .green
        case .attention: return .orange
        case .recheck:   return .blue
        }
    }

    @ViewBuilder
    private var expandedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            TextField("Note — what you saw, where on the car", text: $noteDraft, axis: .vertical)
                .font(.footnote)
                .lineLimit(2...6)
                .onChange(of: noteDraft) { _, newValue in
                    store.setNote(newValue, itemID: item.id, runID: runID)
                }

            if !state.photoFilenames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(state.photoFilenames, id: \.self) { filename in
                            photoThumb(filename)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                #if canImport(UIKit)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
                #endif

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Photo", systemImage: "photo.on.rectangle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Spacer()

                if let updated = state.updatedAt {
                    Text(updated, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if item.isCustom, let uuid = UUID(uuidString: item.id) {
                Button(role: .destructive) {
                    store.removeCustomItem(id: uuid, runID: runID)
                } label: {
                    Label("Remove this check", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
    }

    private func photoThumb(_ filename: String) -> some View {
        let url = store.photoURL(filename, runID: runID)

        return Group {
            #if canImport(UIKit)
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 78, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            store.removePhoto(filename, itemID: item.id, runID: runID)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white, .black.opacity(0.55))
                        }
                        .buttonStyle(.plain)
                        .padding(3)
                    }
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.pillTint.opacity(0.3))
                    .frame(width: 78, height: 78)
            }
            #else
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.pillTint.opacity(0.3))
                .frame(width: 78, height: 78)
            #endif
        }
    }
}

// MARK: - New run

@MainActor
struct NewDeliveryRunSheet: View {

    @Environment(\.dismiss) private var dismiss

    let defaultVehicleName: String
    let onCreate: (DeliveryChecklistRun) -> Void

    @State private var title = ""
    @State private var vehicle = ""
    @State private var vin = ""
    @State private var hasDeliveryDate = false
    @State private var deliveryDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title (optional)", text: $title)
                    TextField("Vehicle", text: $vehicle)
                    TextField("VIN (optional)", text: $vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                } footer: {
                    Text("The VIN goes on the export, which is what makes it useful as a due-bill attachment.")
                }

                Section {
                    Toggle("Delivery date", isOn: $hasDeliveryDate)
                    if hasDeliveryDate {
                        DatePicker("Date", selection: $deliveryDate, displayedComponents: .date)
                    }
                }

                Section {
                    Text("\(DeliveryChecklistTemplate.count) checks will be created across \(DeliveryChecklistCategory.allCases.count) sections. You can hide the ones that don't apply and add your own.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(
                            DeliveryChecklistRun(
                                title: title,
                                vehicle: vehicle,
                                vin: vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                                deliveryDate: hasDeliveryDate ? deliveryDate : nil
                            )
                        )
                        dismiss()
                    }
                }
            }
            .onAppear {
                if vehicle.isEmpty { vehicle = defaultVehicleName }
            }
        }
    }
}

// MARK: - Custom check

@MainActor
struct AddCustomCheckSheet: View {

    @Environment(\.dismiss) private var dismiss

    let category: DeliveryChecklistCategory
    let onAdd: (DeliveryChecklistCustomItem) -> Void

    @State private var title = ""
    @State private var detail = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What to check", text: $title)
                    TextField("What to look for (optional)", text: $detail, axis: .vertical)
                        .lineLimit(2...5)
                } footer: {
                    Text("Added to \(category.rawValue) for this inspection only.")
                }
            }
            .navigationTitle("Add a Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(
                            DeliveryChecklistCustomItem(
                                category: category,
                                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Camera

#if canImport(UIKit)
/// Straight to the camera — on delivery day the defect is in front of you, not
/// in your photo library.
struct DeliveryPhotoCamera: UIViewControllerRepresentable {

    let onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onFinish: { dismiss() })
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (Data) -> Void
        private let onFinish: () -> Void

        init(onCapture: @escaping (Data) -> Void, onFinish: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onFinish = onFinish
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.7) {
                onCapture(data)
            }
            onFinish()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish()
        }
    }
}
#endif
