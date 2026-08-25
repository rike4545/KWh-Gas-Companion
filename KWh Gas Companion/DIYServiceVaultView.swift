import SwiftUI
import PhotosUI
import UIKit

struct DIYServiceEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var date: Date
    var cost: Double
    var notes: String
    var photoFilename: String?
    var partNumbers: [String]
    var tags: [String]

    init(
        id: UUID,
        title: String,
        date: Date,
        cost: Double,
        notes: String,
        photoFilename: String?,
        partNumbers: [String] = [],
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.cost = cost
        self.notes = notes
        self.photoFilename = photoFilename
        self.partNumbers = partNumbers
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case id, title, date, cost, notes, photoFilename, partNumbers, tags
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        date = try c.decode(Date.self, forKey: .date)
        cost = try c.decode(Double.self, forKey: .cost)
        notes = try c.decode(String.self, forKey: .notes)
        photoFilename = try c.decodeIfPresent(String.self, forKey: .photoFilename)
        partNumbers = try c.decodeIfPresent([String].self, forKey: .partNumbers) ?? []
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

fileprivate func splitCSV(_ text: String) -> [String] {
    text
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

@MainActor
final class DIYServiceVaultStore: LocalJSONStore<DIYServiceEntry> {
    init() {
        super.init(filename: "diy_service_vault.json")
    }

    private var documentsDirectory: URL {
        (try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
    }

    func imageURL(for filename: String) -> URL {
        documentsDirectory
            .appendingPathComponent("DIYVault")
            .appendingPathComponent(filename)
    }

    func saveImage(_ data: Data, for id: UUID) -> String? {
        let dir = documentsDirectory.appendingPathComponent("DIYVault")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = "\(id.uuidString).jpg"
        let url = dir.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: [.atomic])
            return filename
        } catch {
            return nil
        }
    }
}

@MainActor
struct DIYServiceVaultView: View {
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var store = DIYServiceVaultStore()
    @StateObject private var adsStore = AdsEntitlementStore.shared
    @State private var showingAdd = false

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard

                if store.items.isEmpty {
                    ContentUnavailableView(
                        "No DIY records yet",
                        systemImage: "photo.on.rectangle",
                        description: Text("Save receipts or photos for your DIY service work.")
                    )
                } else {
                    ForEach(store.items.sorted { $0.date > $1.date }) { entry in
                        entryRow(entry)
                    }
                }

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("DIY Service Vault")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            DIYServiceEntryEditor { entry in
                store.items.insert(entry, at: 0)
            }
        }
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Save DIY service receipts and notes")
                .font(.headline)
            Text("Keep a light record of maintenance you did yourself.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private func entryRow(_ entry: DIYServiceEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if let filename = entry.photoFilename,
                   let ui = UIImage(contentsOfFile: store.imageURL(for: filename).path) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 48, height: 48)
                        .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.headline)
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(entry.cost, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.subheadline.weight(.semibold))
            }

            if !entry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(entry.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !entry.partNumbers.isEmpty || !entry.tags.isEmpty {
                HStack(spacing: 6) {
                    if !entry.partNumbers.isEmpty {
                        Label(entry.partNumbers.joined(separator: ", "), systemImage: "number")
                    }
                    if !entry.tags.isEmpty {
                        Label(entry.tags.joined(separator: ", "), systemImage: "tag")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .themedCard()
    }
}

struct DIYServiceEntryEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var cost: Double = 0
    @State private var notes: String = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var partNumbersText: String = ""
    @State private var tagsText: String = ""

    let onSave: (DIYServiceEntry) -> Void

    init(
        prefillTitle: String = "",
        prefillNotes: String = "",
        prefillTags: [String] = [],
        onSave: @escaping (DIYServiceEntry) -> Void
    ) {
        _title = State(initialValue: prefillTitle)
        _notes = State(initialValue: prefillNotes)
        _tagsText = State(initialValue: prefillTags.joined(separator: ", "))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    HStack {
                        Text("Cost")
                        Spacer()
                        TextField("0", value: $cost, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                Section("Photo") {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(imageData == nil ? "Add photo" : "Change photo", systemImage: "photo")
                    }
                    if imageData != nil {
                        Text("Photo selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Parts & Tags") {
                    TextField("Part numbers (comma separated)", text: $partNumbersText)
                        .textInputAutocapitalization(.characters)
                    TextField("Tags (comma separated)", text: $tagsText)
                        .textInputAutocapitalization(.words)
                    NavigationLink {
                        TeslaEPCPartsSearchView()
                    } label: {
                        Label("Open Tesla EPC Parts Search", systemImage: "magnifyingglass")
                    }
                }
            }
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let id = UUID()
                        var filename: String? = nil
                        if let data = imageData {
                            let store = DIYServiceVaultStore()
                            filename = store.saveImage(data, for: id)
                        }
                        let entry = DIYServiceEntry(
                            id: id,
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            date: date,
                            cost: cost,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            photoFilename: filename,
                            partNumbers: splitCSV(partNumbersText),
                            tags: splitCSV(tagsText)
                        )
                        onSave(entry)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: pickerItem) { _, newValue in
                guard let item = newValue else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                }
            }
        }
    }
}
