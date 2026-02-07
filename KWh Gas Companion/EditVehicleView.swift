//
//  EditVehicleView.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//
//  FIXES + REQUIREMENTS:
//  ✅ Plate/Marker field added (end user can enter License Plate / Marker Number)
//  ✅ Custom photo always wins; if custom exists, ignore automatic Tesla/Rivian photo
//  ✅ Automatic Tesla/Rivian photos use your asset names:
//     Tesla: roadster, model 3, model y, model x, model s
//     Rivian: RivianR1S, RivianR1T, RivianR2, RivianR3
//  ✅ Removes try/catch around non-throwing delete()
//  ✅ AppThemeSpec-driven background/surfaces + AppAppearance tint
//

import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct EditVehicleView: View {

    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var appearance: AppAppearance
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.dismiss) private var dismiss

    // Supports both call sites:
    // 1) EditVehicleView(profileID: someUUID)
    // 2) EditVehicleView(initial: vehicle, onSave: { ... })
    private let profileID: UUID
    private let providedInitial: VehicleProfile?
    private let externalOnSave: ((VehicleProfile) -> Void)?

    @State private var draft: VehicleProfile?
    @State private var pickedItem: PhotosPickerItem?

    #if canImport(UIKit)
    @State private var previewImage: UIImage?
    @State private var storedImage: UIImage?
    #endif

    private var theme: any AppThemeSpec { themeBox.base }

    init(profileID: UUID) {
        self.profileID = profileID
        self.providedInitial = nil
        self.externalOnSave = nil
    }

    init(initial: VehicleProfile, onSave: @escaping (VehicleProfile) -> Void) {
        self.profileID = initial.id
        self.providedInitial = initial
        self.externalOnSave = onSave
    }

    var body: some View {
        Group {
            if let d = draft {
                Form {
                    headerSection(draft: d)
                        .listRowBackground(theme.cardBackground)

                    Section("Basics") {
                        TextField("Name (optional)", text: bindString(\.name))
                            .textInputAutocapitalization(.words)

                        TextField("Make", text: bindString(\.make))
                            .textInputAutocapitalization(.words)

                        TextField("Model", text: bindString(\.model))
                            .textInputAutocapitalization(.words)

                        yearField

                        Toggle("This is an EV", isOn: bindBool(\.isEV))
                    }
                    .listRowBackground(theme.cardBackground)

                    Section("IDs") {
                        TextField("VIN", text: bindString(\.vin))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of: readString(\.vin)) { _, newValue in
                                let cleaned = normalizeVIN(newValue)
                                if cleaned != newValue { writeString(\.vin, cleaned) }
                            }

                        TextField("Plate / Marker Number", text: bindString(\.plateOrMarker))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                    .listRowBackground(theme.cardBackground)
                }
                .scrollContentBackground(.hidden)
            } else {
                ContentUnavailableView(
                    "Vehicle not found",
                    systemImage: "car",
                    description: Text("This vehicle profile could not be loaded.")
                )
            }
        }
        .navigationTitle("Edit Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .tint(appearance.accentColor)
        .background(
            Rectangle()
                .fill(theme.screenBackground)
                .ignoresSafeArea()
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveAndDismiss() }
                    .disabled(!canSave)
            }
        }
        .onAppear { loadDraftIfNeeded() }
        .onChange(of: pickedItem) { _, newValue in
            guard let newValue else { return }
            Task { await loadPickedImage(newValue) }
        }
    }

    // MARK: - Header / Photo

    @ViewBuilder
    private func headerSection(draft: VehicleProfile) -> some View {
        Section {
            HStack(spacing: 12) {
                vehicleImage(draft: draft)

                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.displayName)
                        .font(.headline)

                    Text(draft.summarySubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            PhotosPicker(selection: $pickedItem, matching: .images) {
                Label("Choose Custom Photo", systemImage: "photo")
            }

            if hasCustomPhoto {
                Button(role: .destructive) {
                    deleteCustomPhoto(for: draft.id)
                } label: {
                    Label("Remove Custom Photo", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func vehicleImage(draft: VehicleProfile) -> some View {
        let corner = theme.smallCorner

        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(theme.separator.opacity(0.85), lineWidth: 1)
                )

            #if canImport(UIKit)
            // ✅ Custom always wins (preview first, then stored custom).
            if let ui = previewImage ?? storedImage {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            } else if let auto = automaticVehicleImage(for: draft) {
                Image(uiImage: auto)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            } else {
                Image(systemName: draft.isEV ? "bolt.car.fill" : "car.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            #else
            Image(systemName: "car.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.secondary)
            #endif
        }
        .frame(width: 62, height: 62)
        .clipped()
    }

    private var hasCustomPhoto: Bool {
        #if canImport(UIKit)
        return previewImage != nil || storedImage != nil
        #else
        return false
        #endif
    }

    private func deleteCustomPhoto(for id: UUID) {
        // ✅ delete() does not throw — no try/catch.
        VehicleImageStore.delete(id: id)

        #if canImport(UIKit)
        previewImage = nil
        storedImage = nil
        #endif
        pickedItem = nil
    }

    private func loadPickedImage(_ item: PhotosPickerItem) async {
        #if canImport(UIKit)
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let ui = UIImage(data: data) else { return }

            previewImage = ui

            // save is throwing; keep try/catch here.
            try await VehicleImageStore.save(ui, id: profileID)

            storedImage = ui
        } catch {
            // non-fatal
        }
        #endif
    }

    // MARK: - Automatic images (Tesla/Rivian assets)

    #if canImport(UIKit)
    private func automaticVehicleImage(for v: VehicleProfile) -> UIImage? {
        // If a custom exists, ignore automatic (requirement).
        if hasCustomPhoto { return nil }

        let make = v.make.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let model = v.model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name  = v.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let vin   = v.vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        let combined = "\(make) \(model) \(name)"

        // Rivian
        if make.contains("rivian") || vin.hasPrefix("7FC") || combined.contains("rivian") {
            if combined.contains("r1s") { return UIImage(named: "RivianR1S") }
            if combined.contains("r1t") { return UIImage(named: "RivianR1T") }
            if combined.contains("r2")  { return UIImage(named: "RivianR2") }
            if combined.contains("r3")  { return UIImage(named: "RivianR3") }

            // If user just typed Rivian with no model, choose a reasonable default:
            return UIImage(named: "RivianR1S") ?? UIImage(named: "RivianR1T")
        }

        // Tesla
        let isTeslaByMakeOrVIN =
            make.contains("tesla") || combined.contains("tesla") ||
            vin.hasPrefix("5YJ") || vin.hasPrefix("7SA") || vin.hasPrefix("LRW")

        if isTeslaByMakeOrVIN {
            if combined.contains("roadster") { return UIImage(named: "roadster") }
            if combined.contains("model 3") || combined.contains("model3") { return UIImage(named: "model 3") }
            if combined.contains("cybertruck") || combined.contains("cybertruck") { return UIImage(named: "cybertruck") }
            if combined.contains("model y") || combined.contains("modely") { return UIImage(named: "model y") }
            if combined.contains("model x") || combined.contains("modelx") { return UIImage(named: "model x") }
            if combined.contains("model s") || combined.contains("models") { return UIImage(named: "model s") }

            // If user typed Tesla but not a specific model, pick a default.
            return UIImage(named: "model y") ?? UIImage(named: "model 3") ?? UIImage(named: "model s")
        }

        return nil
    }
    #endif

    // MARK: - Load / Save

    private func loadDraftIfNeeded() {
        if draft != nil { return }

        if let providedInitial {
            draft = providedInitial
        } else {
            draft = profileStore.vehicles.first(where: { $0.id == profileID })
        }

        #if canImport(UIKit)
        if let d = draft {
            // sync load (VehicleImageStore.load is sync in your project)
            storedImage = VehicleImageStore.load(id: d.id)
        }
        #endif
    }

    private var canSave: Bool {
        guard let d = draft else { return false }
        return !d.make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !d.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveAndDismiss() {
        guard var d = draft else { return }
        d.updatedAt = Date()
        draft = d

        // If caller provided an onSave, use it
        if let externalOnSave {
            externalOnSave(d)
            dismiss()
            return
        }

        // Otherwise, write back into ProfileStore directly
        if let idx = profileStore.vehicles.firstIndex(where: { $0.id == d.id }) {
            profileStore.vehicles[idx] = d
        } else {
            profileStore.vehicles.append(d)
        }

        // Keep list tidy
        profileStore.vehicles.sort {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        dismiss()
    }

    // MARK: - Year field (VehicleProfile.year is Int?)

    private var yearField: some View {
        TextField("Year (optional)", text: Binding(
            get: { draft?.year.map(String.init) ?? "" },
            set: { newValue in
                let t = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty {
                    mutateDraft { $0.year = nil }
                } else if let y = Int(t), y > 1900, y < 2200 {
                    mutateDraft { $0.year = y }
                }
            }
        ))
        .keyboardType(.numberPad)
    }

    // MARK: - VIN normalize

    private func normalizeVIN(_ input: String) -> String {
        let upper = input.uppercased()
        let filtered = upper.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return String(filtered.prefix(17))
    }

    // MARK: - Draft mutation + bindings

    private func mutateDraft(_ mutate: (inout VehicleProfile) -> Void) {
        guard var d = draft else { return }
        mutate(&d)
        draft = d
    }

    private func readString(_ keyPath: KeyPath<VehicleProfile, String>) -> String {
        draft?[keyPath: keyPath] ?? ""
    }

    private func writeString(_ keyPath: WritableKeyPath<VehicleProfile, String>, _ value: String) {
        mutateDraft { $0[keyPath: keyPath] = value }
    }

    private func bindString(_ keyPath: WritableKeyPath<VehicleProfile, String>) -> Binding<String> {
        Binding(
            get: { draft?[keyPath: keyPath] ?? "" },
            set: { newValue in mutateDraft { $0[keyPath: keyPath] = newValue } }
        )
    }

    private func bindBool(_ keyPath: WritableKeyPath<VehicleProfile, Bool>) -> Binding<Bool> {
        Binding(
            get: { draft?[keyPath: keyPath] ?? false },
            set: { newValue in mutateDraft { $0[keyPath: keyPath] = newValue } }
        )
    }
}
