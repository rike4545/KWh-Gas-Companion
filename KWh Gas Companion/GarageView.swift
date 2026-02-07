//
//  GarageView.swift
//  KWh Gas Companion
//
//  User-facing Garage
//  - No developer/protocol injection messaging
//  - Add/Edit/Delete vehicles
//  - Persist locally (Documents JSON)
//  - Choose a default vehicle
//
//  Swift 6 • iOS 17+
//

import SwiftUI

// MARK: - Public Entry

@MainActor
struct GarageView: View {

    @Environment(\.appThemeBox) private var themeBox
    @EnvironmentObject private var appearance: AppAppearance
    @Environment(\.colorScheme) private var scheme

    @AppStorage("uiStyle") private var uiStyleRaw: String = "teslaGlass"
    @AppStorage("garage.defaultVehicleId") private var defaultVehicleId: String = ""

    @StateObject private var store = KWhGarageStore()

    @State private var showingAdd = false
    @State private var editingVehicle: KWhGarageVehicle? = nil

    private var theme: any AppThemeSpec { themeBox.base }
    private var uiStyle: KWhGarageUIStyle {
        switch uiStyleRaw.lowercased() {
        case "glass", "teslaglass": return .glass
        default: return .classic
        }
    }

    private var defaultVehicle: KWhGarageVehicle? {
        store.vehicles.first(where: { $0.id == defaultVehicleId })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing + 8) {

                header
                storySection

                if store.vehicles.isEmpty {
                    emptyState
                } else {
                    vehiclesSection
                    defaultsSection
                }

                tipsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .navigationTitle("Garage")
        .navigationBarTitleDisplayMode(.inline)
        .background(backgroundView)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingVehicle = nil
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add vehicle")
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                KWhGarageAddEditVehicleView(
                    theme: theme,
                    uiStyle: uiStyle,
                    appearance: appearance,
                    existing: editingVehicle,
                    onSave: { v in
                        if let _ = editingVehicle {
                            store.upsert(v)
                        } else {
                            store.add(v)
                        }
                        // If no default yet, set it.
                        if defaultVehicleId.isEmpty { defaultVehicleId = v.id }
                        showingAdd = false
                        editingVehicle = nil
                    },
                    onCancel: {
                        showingAdd = false
                        editingVehicle = nil
                    }
                )
            }
            .presentationDetents([.large])
        }
        .onAppear {
            store.load()
            if defaultVehicleId.isEmpty, let first = store.vehicles.first {
                defaultVehicleId = first.id
            }
        }
    }

    // MARK: - UI

    private var backgroundView: some View {
        let accent = appearance.accentColor
        return ZStack {
            Rectangle()
                .fill(theme.screenBackground)
                .ignoresSafeArea()

            RadialGradient(
                colors: [accent.opacity(scheme == .dark ? 0.26 : 0.14), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 540
            )
            .blur(radius: 28)
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your vehicles")
                .font(.largeTitle.weight(.bold))
            Text("Add vehicles you own so tools can use the right assumptions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
    }

    private var storySection: some View {
        KWhGarageCard(theme: theme, uiStyle: uiStyle) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Story & Care")
                    .font(.headline)

                Text("Build a timeline, log DIY part installs, and baseline maintenance.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    NavigationLink {
                        VehicleStoryTimelineView()
                    } label: {
                        garageActionRow(
                            title: "Vehicle Story timeline",
                            subtitle: "Expenses + DIY service in one feed",
                            systemImage: "clock.arrow.circlepath"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        DIYServiceVaultView()
                    } label: {
                        garageActionRow(
                            title: "DIY part install log",
                            subtitle: "Save receipts, photos, and notes",
                            systemImage: "wrench.and.screwdriver"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ServiceRemindersView()
                            .navigationTitle("Service Reminders")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        garageActionRow(
                            title: "Baseline checklist",
                            subtitle: "Track recurring service tasks",
                            systemImage: "checklist"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ChargingDataHubView()
                    } label: {
                        garageActionRow(
                            title: "Import / Export",
                            subtitle: "Keep charging history portable",
                            systemImage: "tray.and.arrow.down"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        KWhGarageCard(theme: theme, uiStyle: uiStyle) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(appearance.accentColor.opacity(0.18))
                        Image(systemName: "car.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(appearance.accentColor)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No vehicles added yet")
                            .font(.headline)
                        Text("Add one to unlock better cost, range, and budget estimates.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                Button {
                    editingVehicle = nil
                    showingAdd = true
                } label: {
                    HStack(spacing: 8) {
                        Text("Add a vehicle")
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.pillTint.opacity(0.30), in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }

    private var vehiclesSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing) {
            HStack {
                Text("Vehicles")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 2)

            VStack(spacing: theme.spacing) {
                ForEach(store.vehicles) { v in
                    KWhGarageVehicleRow(
                        theme: theme,
                        uiStyle: uiStyle,
                        appearance: appearance,
                        vehicle: v,
                        isDefault: v.id == defaultVehicleId,
                        onMakeDefault: { defaultVehicleId = v.id },
                        onEdit: {
                            editingVehicle = v
                            showingAdd = true
                        },
                        onDelete: {
                            let wasDefault = (defaultVehicleId == v.id)
                            store.delete(v)
                            if wasDefault {
                                defaultVehicleId = store.vehicles.first?.id ?? ""
                            }
                        }
                    )
                }
            }
        }
        .padding(.top, 4)
    }

    private var defaultsSection: some View {
        KWhGarageCard(theme: theme, uiStyle: uiStyle) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Default vehicle")
                    .font(.headline)

                if let dv = defaultVehicle {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(appearance.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dv.displayName)
                                .font(.subheadline.weight(.semibold))
                            Text("Used by tools when a vehicle isn’t chosen explicitly.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                } else {
                    Text("Pick a default vehicle from your list.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var tipsSection: some View {
        KWhGarageCard(theme: theme, uiStyle: uiStyle) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tip")
                    .font(.headline)
                Text("Battery size and efficiency help estimates feel “right” across forecasts, charging, and cost tools.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Models + Store (local persistence)

fileprivate enum KWhGarageUIStyle { case classic, glass }

fileprivate struct KWhGarageVehicle: Identifiable, Codable, Hashable, Sendable {
    var id: String = UUID().uuidString

    var nickname: String
    var make: String
    var model: String
    var year: Int?

    /// Optional assumptions (used by other tools if you hook it up later)
    var batteryKWh: Double?
    var efficiencyWhPerMile: Double?

    var notes: String?

    var displayName: String {
        let y = year.map(String.init) ?? ""
        let base = [y, make, model].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " ")
        if nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return base }
        return "\(nickname) • \(base)"
    }
}

@MainActor
fileprivate final class KWhGarageStore: ObservableObject {

    @Published private(set) var vehicles: [KWhGarageVehicle] = []

    private let filename = "kwh_garage_vehicles_v1.json"

    func load() {
        do {
            let url = try fileURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([KWhGarageVehicle].self, from: data)
            vehicles = decoded
        } catch {
            // If corrupt, fail silently (don’t break the UI).
            vehicles = vehicles
        }
    }

    func save() {
        do {
            let url = try fileURL()
            let data = try JSONEncoder().encode(vehicles)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Ignore; persistence failure should not crash UI.
        }
    }

    func add(_ v: KWhGarageVehicle) {
        vehicles.append(v)
        vehicles.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        save()
    }

    func upsert(_ v: KWhGarageVehicle) {
        if let idx = vehicles.firstIndex(where: { $0.id == v.id }) {
            vehicles[idx] = v
        } else {
            vehicles.append(v)
        }
        vehicles.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        save()
    }

    func delete(_ v: KWhGarageVehicle) {
        vehicles.removeAll { $0.id == v.id }
        save()
    }

    private func fileURL() throws -> URL {
        let dir = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return dir.appendingPathComponent(filename)
    }
}

// MARK: - Components

fileprivate struct KWhGarageCard<Content: View>: View {
    let theme: any AppThemeSpec
    let uiStyle: KWhGarageUIStyle
    @ViewBuilder var content: Content

    private var backgroundStyle: AnyShapeStyle {
        switch uiStyle {
        case .classic: return AnyShapeStyle(theme.cardBackground)
        case .glass: return AnyShapeStyle(.thinMaterial)
        }
    }

    var body: some View {
        content
            .padding(theme.spacing)
            .background(backgroundStyle, in: RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                    .strokeBorder(theme.separator.opacity(0.85), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: theme.elevation, x: 0, y: 2)
    }
}

fileprivate struct KWhGarageVehicleRow: View {
    let theme: any AppThemeSpec
    let uiStyle: KWhGarageUIStyle
    let appearance: AppAppearance

    let vehicle: KWhGarageVehicle
    let isDefault: Bool

    let onMakeDefault: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        KWhGarageCard(theme: theme, uiStyle: uiStyle) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle().fill(appearance.accentColor.opacity(0.16))
                        Image(systemName: "car.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(appearance.accentColor)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(vehicle.displayName)
                                .font(.headline)
                                .lineLimit(2)

                            if isDefault {
                                Text("Default")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(appearance.accentColor.opacity(0.18)))
                            }
                        }

                        let detail = detailsLine(vehicle)
                        if !detail.isEmpty {
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(theme.pillTint.opacity(0.26), in: Capsule(style: .continuous))

                    Button(action: onMakeDefault) {
                        Label("Make default", systemImage: "checkmark.seal")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(theme.pillTint.opacity(0.26), in: Capsule(style: .continuous))

                    Spacer()

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.10), in: Capsule(style: .continuous))
                    .accessibilityLabel("Delete vehicle")
                }
            }
        }
    }

    private func detailsLine(_ v: KWhGarageVehicle) -> String {
        var parts: [String] = []
        if let kwh = v.batteryKWh, kwh > 0 { parts.append("\(format(kwh)) kWh") }
        if let wh = v.efficiencyWhPerMile, wh > 0 { parts.append("\(format(wh)) Wh/mi") }
        if parts.isEmpty { return "" }
        return parts.joined(separator: " · ")
    }

    private func format(_ x: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = (x < 100) ? 1 : 0
        return f.string(from: NSNumber(value: x)) ?? "\(x)"
    }
}

fileprivate extension GarageView {
    func garageActionRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.pillTint.opacity(0.30))
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(appearance.accentColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Add/Edit Sheet

fileprivate struct KWhGarageAddEditVehicleView: View {
    let theme: any AppThemeSpec
    let uiStyle: KWhGarageUIStyle
    let appearance: AppAppearance

    let existing: KWhGarageVehicle?
    let onSave: (KWhGarageVehicle) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var nickname: String = ""
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var yearText: String = ""

    @State private var batteryText: String = ""
    @State private var efficiencyText: String = ""

    @State private var notes: String = ""

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Nickname (optional)", text: $nickname)
                    .textInputAutocapitalization(.words)

                TextField("Make", text: $make)
                    .textInputAutocapitalization(.words)

                TextField("Model", text: $model)
                    .textInputAutocapitalization(.words)

                TextField("Year (optional)", text: $yearText)
                    .keyboardType(.numberPad)
            }

            Section("Assumptions (optional)") {
                TextField("Battery (kWh)", text: $batteryText)
                    .keyboardType(.decimalPad)
                TextField("Efficiency (Wh/mi)", text: $efficiencyText)
                    .keyboardType(.decimalPad)

                Text("These improve forecasts and cost estimates.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Notes") {
                TextField("Anything helpful…", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
        }
        .navigationTitle(existing == nil ? "Add Vehicle" : "Edit Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let v = buildVehicle()
                    onSave(v)
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
        .onAppear {
            if let v = existing {
                nickname = v.nickname
                make = v.make
                model = v.model
                yearText = v.year.map(String.init) ?? ""
                batteryText = v.batteryKWh.map { String($0) } ?? ""
                efficiencyText = v.efficiencyWhPerMile.map { String($0) } ?? ""
                notes = v.notes ?? ""
            }
        }
    }

    private var canSave: Bool {
        !make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func buildVehicle() -> KWhGarageVehicle {
        var v = existing ?? KWhGarageVehicle(nickname: "", make: "", model: "", year: nil, batteryKWh: nil, efficiencyWhPerMile: nil, notes: nil)

        v.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        v.make = make.trimmingCharacters(in: .whitespacesAndNewlines)
        v.model = model.trimmingCharacters(in: .whitespacesAndNewlines)

        if let y = Int(yearText.trimmingCharacters(in: .whitespacesAndNewlines)), y > 1900, y < 2200 {
            v.year = y
        } else {
            v.year = nil
        }

        if let k = Double(batteryText.trimmingCharacters(in: .whitespacesAndNewlines)), k > 0 {
            v.batteryKWh = k
        } else {
            v.batteryKWh = nil
        }

        if let e = Double(efficiencyText.trimmingCharacters(in: .whitespacesAndNewlines)), e > 0 {
            v.efficiencyWhPerMile = e
        } else {
            v.efficiencyWhPerMile = nil
        }

        let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        v.notes = n.isEmpty ? nil : n

        return v
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        GarageView()
            .environmentObject(AppAppearance())
            .environment(\.appThemeBox, AppThemeBox(base: SystemTheme(accentColor: .red, scheme: .light)))
    }
}
#endif
