//
//  VehicleProfileView.swift
//  KWh Gas Companion
//
//  🔧 CRASH FIX: `.environment(\.editMode, .constant(...))` applied to a Form
//     causes a crash on iOS 16/17. Form wraps a List internally and the injected
//     editMode conflicts with the List's own internal edit-mode tracking, leading
//     to a "Multiple environments with the same key" assertion failure.
//     Fix: apply editMode only to the specific gallery ForEach section, not the
//     entire Form. Restructured to use `.environment(\.editMode)` on just the
//     gallery rows inside the Section, not on the Form itself.
//
//  🔧 FIX: bindText(String?) setter stored untrimmed `$0` instead of `t`.
//     `t.isEmpty ? nil : $0` preserved leading/trailing whitespace in saved data.
//     Corrected to `t.isEmpty ? nil : t`.
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct VehicleProfileView: View {

    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var appearance: AppAppearance
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.dismiss) private var dismiss

    let profileID: UUID
    let setSelected: Bool

    @State private var draft: VehicleProfile = .init()
    @State private var galleryPickerItems: [PhotosPickerItem] = []
    @State private var galleryItems: [VehicleGalleryItem] = []
    @State private var registrationExpiryEnabled: Bool = false
    @State private var galleryReorderMode: Bool = false

    init(profileID: UUID, setSelected: Bool = false) {
        self.profileID = profileID
        self.setSelected = setSelected
    }

    private var theme: any AppThemeSpec { themeBox.base }

    #if canImport(UIKit)
    private var automaticPhoto: UIImage? { VehicleImageStore.automaticImage(for: draft) }
    private var coverPhoto: UIImage? {
        if let coverId = draft.coverPhotoId,
           let found = galleryItems.first(where: { $0.id == coverId })?.image {
            return found
        }
        if let first = galleryItems.first?.image { return first }
        return automaticPhoto
    }
    private var photoSourceLabel: String {
        if !galleryItems.isEmpty { return "Gallery cover" }
        if automaticPhoto != nil { return "Automatic photo" }
        return "No photo"
    }
    #endif

    var body: some View {
        // 🔧 CRASH FIX: .environment(\.editMode) removed from Form.
        // Applying it to Form crashes iOS 16/17 (assertion failure in List internals).
        // editMode is now applied only to the gallery ForEach inside gallerySection.
        Form {
            photoSection
            gallerySection
            basicsSection
            idsSection
            registrationSection
            appearanceSection
            evSection
            notesSection
            actionsSection
        }
        .navigationTitle("Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .tint(appearance.accentColor)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .task(id: profileID) {
            load()
            await loadGallery()
        }
        .onChange(of: galleryPickerItems) { _, newValue in
            guard !newValue.isEmpty else { return }
            Task { await importGalleryPhotos() }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section("Photo") {
            HStack(spacing: 12) {
                #if canImport(UIKit)
                VehicleEditorAvatar(theme: theme, accent: appearance.accentColor, uiImage: coverPhoto)
                    .frame(width: 64, height: 64)
                #else
                VehicleEditorAvatarFallback(theme: theme, accent: appearance.accentColor)
                    .frame(width: 64, height: 64)
                #endif

                VStack(alignment: .leading, spacing: 3) {
                    Text(draft.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    #if canImport(UIKit)
                    Text(photoSourceLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    #else
                    Text("Optional")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    #endif
                }
                Spacer()
            }

            PhotosPicker(selection: $galleryPickerItems, matching: .images) {
                Label("Add Photos", systemImage: "photo.on.rectangle")
            }
            .photosPickerStyle(.presentation)
        }
    }

    // Gallery section is split into three separate vars so no single
    // @ViewBuilder closure contains more than one structural branch.
    // Swift's type checker times out when a Section/ForEach closure
    // combines if/else + ternary modifiers + #if blocks simultaneously.
    private var gallerySection: some View {
        Section("Gallery") { galleryEmptyOrList }
    }

    @ViewBuilder
    private var galleryEmptyOrList: some View {
        if galleryItems.isEmpty {
            Text("No photos yet. Add a few to personalize this vehicle.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            galleryReorderButton
            galleryList
        }
    }

    private var galleryReorderButton: some View {
        Button(galleryReorderMode ? "Done Reordering" : "Reorder Photos") {
            galleryReorderMode.toggle()
        }
        .font(.footnote.weight(.semibold))
    }

    @ViewBuilder
    private var galleryList: some View {
        if galleryReorderMode {
            ForEach(galleryItems, id: \.id) { item in
                galleryItemRow(item)
            }
            .onMove(perform: moveGalleryItems)
            .environment(\.editMode, .constant(.active))
        } else {
            ForEach(galleryItems, id: \.id) { item in
                galleryItemRow(item)
            }
            .environment(\.editMode, .constant(.inactive))
        }
    }

    private func galleryItemRow(_ item: VehicleGalleryItem) -> some View {
        GalleryItemRow(
            item: item,
            isCover: draft.coverPhotoId == item.id,
            theme: theme,
            accent: appearance.accentColor,
            onSetCover: { draft.coverPhotoId = item.id },
            onDelete: { Task { await deleteGalleryPhoto(id: item.id) } }
        )
    }

    private var basicsSection: some View {
        Section("Basics") {
            TextField("Name (e.g., Model 3)", text: bindText(\.name))
            TextField("Make", text: bindText(\.make))
                .textInputAutocapitalization(.words)
            TextField("Model", text: bindText(\.model))
                .textInputAutocapitalization(.words)
            TextField("Year (optional)", text: bindYear(\.year))
                .keyboardType(.numberPad)
            Toggle("This is an EV", isOn: bindBool(\.isEV))
        }
    }

    private var idsSection: some View {
        Section("IDs") {
            TextField("VIN", text: bindText(\.vin))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .onChange(of: draft.vin) { _, newValue in
                    let cleaned = normalizeVIN(newValue)
                    if cleaned != newValue { draft.vin = cleaned }
                }
            TextField("Plate / Marker Number", text: bindText(\.plateOrMarker))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
        }
    }

    private var registrationSection: some View {
        Section("Registration") {
            TextField("Plate State", text: bindText(\.plateState))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
            TextField("Plate Style (optional)", text: bindText(\.plateStyle))
                .textInputAutocapitalization(.words)
            Toggle("Track registration expiry", isOn: $registrationExpiryEnabled)
                .onChange(of: registrationExpiryEnabled) { _, newValue in
                    if !newValue { draft.registrationExpires = nil }
                    if newValue, draft.registrationExpires == nil {
                        draft.registrationExpires = Calendar.current.date(
                            byAdding: .year, value: 1, to: Date()
                        )
                    }
                }
            if registrationExpiryEnabled {
                DatePicker(
                    "Registration expires",
                    selection: bindDate(\.registrationExpires, fallbackDays: 365),
                    displayedComponents: .date
                )
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            TextField("Color (e.g., Midnight Silver)", text: bindText(\.colorName))
                .textInputAutocapitalization(.words)
            TextField("Trim (e.g., Performance)", text: bindText(\.trim))
                .textInputAutocapitalization(.words)
            TextField("Badge (optional)", text: bindText(\.badge))
                .textInputAutocapitalization(.words)
            ColorPicker("Accent Color", selection: bindAccentColor())
        }
    }

    private var evSection: some View {
        Section("EV Assumptions (optional)") {
            LabeledContent("Battery (kWh)") {
                TextField("e.g., 75", text: bindDouble(\.batteryCapacityKWh))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Efficiency (Wh/mi)") {
                TextField("e.g., 260", text: bindDouble(\.efficiencyWhPerMile, digits: 0))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Est. Range (mi)") {
                TextField("optional", text: bindDouble(\.estimatedRangeMiles, digits: 0))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Odometer (mi)") {
                TextField("optional", text: bindDouble(\.odometerMiles, digits: 0))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Anything helpful…", text: bindText(\.notes), axis: .vertical)
                .lineLimit(3, reservesSpace: true)
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                setAsCurrentVehicle()
                dismiss()
            } label: {
                Label("Set as Current Vehicle", systemImage: "checkmark.seal.fill")
            }
            if isCurrentlySelected {
                Text("This vehicle is currently selected.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Validation

    private var canSave: Bool {
        let makeOk  = !draft.make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let modelOk = !draft.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return makeOk || modelOk || !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isCurrentlySelected: Bool {
        profileStore.selectedVehicleID == draft.id
    }

    // MARK: - Store IO

    private func load() {
        if let existing = profileStore.vehicles.first(where: { $0.id == profileID }) {
            draft = existing
        } else {
            draft = VehicleProfile(id: profileID)
        }
        registrationExpiryEnabled = (draft.registrationExpires != nil)
    }

    private func save() {
        draft.updatedAt = Date()
        if let idx = profileStore.vehicles.firstIndex(where: { $0.id == draft.id }) {
            profileStore.vehicles[idx] = draft
        } else {
            profileStore.vehicles.append(draft)
        }
        profileStore.vehicles.sort {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        if setSelected { setAsCurrentVehicle() }
        dismiss()
    }

    private func setAsCurrentVehicle() {
        profileStore.selectedVehicleID = draft.id
    }

    // MARK: - Photo handling

    private func loadGallery() async {
        #if canImport(UIKit)
        if draft.galleryPhotoIds.isEmpty,
           let legacy = await VehicleImageStore.load(id: draft.id) {
            let newId = UUID()
            do {
                try await VehicleImageStore.save(legacy, vehicleId: draft.id, photoId: newId)
                await VehicleImageStore.delete(id: draft.id)
                draft.galleryPhotoIds = [newId]
                draft.coverPhotoId = newId
            } catch { /* migration error — ignore */ }
        }
        var loaded: [VehicleGalleryItem] = []
        for id in draft.galleryPhotoIds {
            if let img = await VehicleImageStore.loadThumbnail(
                vehicleId: draft.id, photoId: id, maxPixel: 240
            ) {
                loaded.append(VehicleGalleryItem(id: id, image: img))
            }
        }
        galleryItems = loaded
        #endif
    }

    private func importGalleryPhotos() async {
        #if canImport(UIKit)
        let items = galleryPickerItems
        galleryPickerItems = []
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    let id = UUID()
                    try await VehicleImageStore.save(img, vehicleId: draft.id, photoId: id)
                    draft.galleryPhotoIds.append(id)
                    if draft.coverPhotoId == nil { draft.coverPhotoId = id }
                    let thumb = await VehicleImageStore.loadThumbnail(
                        vehicleId: draft.id, photoId: id, maxPixel: 240
                    ) ?? img
                    galleryItems.append(VehicleGalleryItem(id: id, image: thumb))
                }
            } catch { /* ignore bad items */ }
        }
        #endif
    }

    private func deleteGalleryPhoto(id: UUID) async {
        #if canImport(UIKit)
        await VehicleImageStore.delete(vehicleId: draft.id, photoId: id)
        draft.galleryPhotoIds.removeAll { $0 == id }
        galleryItems.removeAll { $0.id == id }
        if draft.coverPhotoId == id {
            draft.coverPhotoId = draft.galleryPhotoIds.first
        }
        #endif
    }

    private func moveGalleryItems(from source: IndexSet, to destination: Int) {
        galleryItems.move(fromOffsets: source, toOffset: destination)
        draft.galleryPhotoIds = galleryItems.map(\.id)
    }

    // MARK: - Utilities

    private func normalizeVIN(_ input: String) -> String {
        String(
            input.uppercased()
                .filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
                .prefix(17)
        )
    }

    private func bindText(_ keyPath: WritableKeyPath<VehicleProfile, String>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { draft[keyPath: keyPath] = $0 }
        )
    }

    private func bindText(_ keyPath: WritableKeyPath<VehicleProfile, String?>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] ?? "" },
            set: {
                let t = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                // 🔧 FIX: was `t.isEmpty ? nil : $0` — stored untrimmed value.
                draft[keyPath: keyPath] = t.isEmpty ? nil : t
            }
        )
    }

    private func bindBool(_ keyPath: WritableKeyPath<VehicleProfile, Bool>) -> Binding<Bool> {
        Binding(get: { draft[keyPath: keyPath] }, set: { draft[keyPath: keyPath] = $0 })
    }

    private func bindYear(_ keyPath: WritableKeyPath<VehicleProfile, Int?>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath].map(String.init) ?? "" },
            set: { newValue in
                let t = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty { draft[keyPath: keyPath] = nil; return }
                if let y = Int(t), y > 1900, y < 2200 { draft[keyPath: keyPath] = y }
            }
        )
    }

    private func bindDouble(_ keyPath: WritableKeyPath<VehicleProfile, Double?>, digits: Int = 2) -> Binding<String> {
        Binding(
            get: {
                guard let v = draft[keyPath: keyPath] else { return "" }
                return formatNumber(v, digits: digits)
            },
            set: { s in
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty { draft[keyPath: keyPath] = nil; return }
                draft[keyPath: keyPath] = Double(t.replacingOccurrences(of: ",", with: "."))
            }
        )
    }

    private func formatNumber(_ v: Double, digits: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = digits
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    private func bindDate(_ keyPath: WritableKeyPath<VehicleProfile, Date?>, fallbackDays: Int) -> Binding<Date> {
        Binding(
            get: { draft[keyPath: keyPath] ?? Calendar.current.date(byAdding: .day, value: fallbackDays, to: Date()) ?? Date() },
            set: { draft[keyPath: keyPath] = $0 }
        )
    }

    private func bindAccentColor() -> Binding<Color> {
        Binding(
            get: {
                if let hex = draft.accentHex, let color = Color.fromHex(hex) { return color }
                return appearance.accentColor
            },
            set: { newValue in
                if let hex = newValue.toHex() { draft.accentHex = hex }
            }
        )
    }
}

// MARK: - Gallery item row (isolated struct so type checker has no parent state to resolve)

#if canImport(UIKit)
private struct GalleryItemRow: View {
    let item: VehicleGalleryItem
    let isCover: Bool
    let theme: any AppThemeSpec
    let accent: Color
    let onSetCover: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(uiImage: item.image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 44)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.id.uuidString.prefix(8))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isCover {
                    Text("Cover photo")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onSetCover) {
                Text("Set Cover").font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
    }
}
#else
private struct GalleryItemRow: View {
    let item: VehicleGalleryItem
    let isCover: Bool
    let theme: any AppThemeSpec
    let accent: Color
    let onSetCover: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 56, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.id.uuidString.prefix(8))
                    .font(.caption).foregroundStyle(.secondary)
                if isCover {
                    Text("Cover photo")
                        .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onSetCover) {
                Text("Set Cover").font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
    }
}
#endif

// MARK: - Gallery item model

#if canImport(UIKit)
private struct VehicleGalleryItem: Identifiable {
    let id: UUID
    let image: UIImage
}
#endif

#if canImport(UIKit)
private struct VehicleEditorAvatar: View {
    let theme: any AppThemeSpec
    let accent: Color
    let uiImage: UIImage?

    var body: some View {
        ZStack {
            if let uiImage {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else {
                VehicleEditorAvatarFallback(theme: theme, accent: accent)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.smallCorner + 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.smallCorner + 6, style: .continuous)
                .strokeBorder(theme.separator.opacity(0.85), lineWidth: 1)
        )
    }
}
#endif

private struct VehicleEditorAvatarFallback: View {
    let theme: any AppThemeSpec
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.smallCorner + 6, style: .continuous)
                .fill(theme.cardBackground)
            Image(systemName: "car.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
        }
        .overlay(
            RoundedRectangle(cornerRadius: theme.smallCorner + 6, style: .continuous)
                .strokeBorder(theme.separator.opacity(0.85), lineWidth: 1)
        )
    }
}
