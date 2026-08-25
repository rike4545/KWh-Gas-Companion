//
//  AddEditEntryView.swift
//  KWh Gas Companion
//
//  ProfileStore-wired Add/Edit form.
//  Swift 6 • iOS 17+
//
//  Assumptions (matches the corrected ProfileStore):
//  - VehicleProfile.id              == UUID
//  - ProfileStore.selectedVehicleID == UUID?
//  - ExpenseEntry.vehicleID         == UUID?
//
//  This file:
//  - Never uses $profileStore dynamic-member bindings
//  - Async-safe vehicle selection: re-primes when vehicles load
//  - Prefers entry.vehicleID/VIN/name for display + selection
//

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct AddEditEntryView: View {
    // MARK: Theme
    @Environment(\.appThemeBox) private var _themeBox
    private var T: any AppThemeSpec { _themeBox.base }

    // MARK: Environment
    @EnvironmentObject private var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    // MARK: External Inputs
    let initial: ExpenseEntry
    let onSave: (ExpenseEntry) -> Void
    let onCancel: (() -> Void)?
    let isDuplicate: ((ExpenseEntry) -> Bool)?

    // MARK: Local State
    @State private var entry: ExpenseEntry
    @State private var showCharging: Bool

    @AppStorage("addedit_isAdvanced") private var isAdvanced: Bool = false
    @AppStorage("categorize.enabled") private var autoCategorizeEnabled: Bool = true
    @AppStorage("categorize.autoApply") private var autoCategorizeAutoApply: Bool = true
    @AppStorage("categorize.learn") private var autoCategorizeLearn: Bool = true
    @FocusState private var focused: Field?
    @State private var showCurrencyPicker: Bool = false
    @State private var currencySearch: String = ""

    @State private var isFreeSession: Bool
    @State private var showDuplicateAlert: Bool = false

    // ✅ Vehicle priming / async loading support
    @State private var didPrimeVehicle: Bool = false
    @State private var lastVehicleIDsSnapshot: [UUID] = []
    @StateObject private var adsStore = AdsEntitlementStore.shared

    @State private var suggestedCategory: ExpenseCategory? = nil

    enum Field: Hashable { case amount, energy, location, notes, invoice }

    // MARK: Init
    init(
        entry: ExpenseEntry? = nil,
        onSave: @escaping (ExpenseEntry) -> Void,
        onCancel: (() -> Void)? = nil,
        isDuplicate: ((ExpenseEntry) -> Bool)? = nil
    ) {
        let seed = entry ?? ExpenseEntry(
            date: Date(),
            amount: 0,
            currencyCode: Locale.current.currency?.identifier ?? "USD",
            category: ExpenseCategory.energy.rawValue,
            energyKWh: nil,
            odometer: nil,
            location: nil,
            notes: nil,
            vehicleName: nil,
            stateOfCharge: nil,
            chargeType: nil,
            vehicleID: nil, // UUID?
            isBusiness: false,
            vin: nil,
            isEnergy: true,
            charging: ChargingDetails(),
            vatAmount: nil,
            invoiceNumber: nil,
            repeatRule: nil
        )

        self.initial = seed
        self._entry = State(initialValue: seed)
        self.onSave = onSave
        self.onCancel = onCancel
        self.isDuplicate = isDuplicate

        let isChargingCat = [.energy, .homeCharging, .publicCharging, .fastDCFC].contains(seed.categoryEnum)
        self._showCharging = State(initialValue: isChargingCat && seed.isEnergyEffective)

        let approxZeroAmount = abs(seed.amount) < 0.0001
        let zeroPPK = (seed.charging?.pricePerKWh ?? -1) == 0
        let isNewEntry = (entry == nil)
        self._isFreeSession = State(initialValue: !isNewEntry && isChargingCat && (approxZeroAmount || zeroPPK))
    }

    // MARK: Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: T.spacing) {

                    // Mode
                    KGCCard {
                        KGCSectionHeader("Mode", systemImage: "slider.horizontal.3")
                        Picker("", selection: $isAdvanced) {
                            Text("Basic").tag(false)
                            Text("Advanced").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 280)
                    }

                    // Basics
                    KGCCard {
                        KGCSectionHeader("Basics", systemImage: "list.bullet.rectangle")

                        if autoCategorizeEnabled, let suggestion = suggestedCategory, suggestion.rawValue != entry.category {
                            KGCLabeledRow(label: "Suggested") {
                                HStack(spacing: 8) {
                                    Image(systemName: suggestion.icon)
                                    Text(suggestion.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Button("Apply") {
                                        entry.category = suggestion.rawValue
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }

                        KGCLabeledRow(label: "Vehicle") { vehicleBlock }

                        KGCLabeledRow(label: "Date") {
                            DatePicker("", selection: $entry.date, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }

                        KGCLabeledRow(label: "Amount") {
                            HStack(spacing: 10) {
                                TextField("0", value: $entry.amount, format: currencyFormatStyle)
                                    .keyboardType(.decimalPad)
                                    .focused($focused, equals: .amount)
                                    .disabled(isChargingCategory && isFreeSession)
                                    .opacity(isChargingCategory && isFreeSession ? 0.5 : 1)
                                    .onChange(of: entry.amount) { _, newValue in
                                        if newValue > 0.0001 { isFreeSession = false }
                                    }

                                Spacer(minLength: 4)
                                KGCChip(text: currencyForFormat)
                            }
                            .modifier(KGCInputPillChrome())
                        }

                        KGCLabeledRow(label: "Currency") {
                            Button { showCurrencyPicker = true } label: {
                                KGCCurrencyButtonLabel(display: currencyDisplayString(code: currencyForFormat))
                            }
                            .buttonStyle(.plain)
                        }

                        KGCLabeledRow(label: "Category") {
                            KGCCategoryPickerRow(
                                selection: categoryBinding,
                                badge: KGCCategoryBadge(category: entry.categoryEnum)
                            )
                        }

                        KGCLabeledRow(label: "Business") {
                            Toggle("", isOn: $entry.isBusiness).labelsHidden()
                        }
                    }

                    // Energy section (charging categories)
                    if isChargingCategory {
                        KGCCard {
                            KGCSectionHeader("Energy", systemImage: "bolt.fill")

                            KGCLabeledRow(label: "Energy Entry") {
                                Toggle("", isOn: $entry.isEnergy)
                                    .labelsHidden()
                                    .onChange(of: entry.isEnergy) { _, newVal in
                                        withAnimation(.snappy) {
                                            showCharging = newVal || entry.charging != nil || entry.isEnergyByCategory
                                        }
                                    }
                            }

                            KGCLabeledRow(label: "kWh") {
                                HStack(spacing: 10) {
                                    TextField("Energy Added (kWh)", value: $entry.energyKWh.nilCoalescing(0), format: .number)
                                        .keyboardType(.decimalPad)
                                        .focused($focused, equals: .energy)

                                    Spacer(minLength: 4)

                                    if let p = entry.costPerKWh {
                                        KGCChip(text: "\(currencyFormat(p))/kWh")
                                    }
                                }
                                .modifier(KGCInputPillChrome())
                            }

                            KGCLabeledRow(label: "Location") {
                                TextField("Site name or address", text: Binding(
                                    get: { entry.location ?? "" },
                                    set: { entry.location = $0.isEmpty ? nil : $0 }
                                ))
                                .focused($focused, equals: .location)
                            }

                            KGCLabeledRow(label: "Notes") {
                                TextField("Optional notes", text: Binding(
                                    get: { entry.notes ?? "" },
                                    set: { entry.notes = $0.isEmpty ? nil : $0 }
                                ), axis: .vertical)
                                .lineLimit(2...(isAdvanced ? 6 : 3))
                                .focused($focused, equals: .notes)
                            }
                        }
                    }

                    // Charging details
                    if isChargingCategory, showCharging {
                        KGCCard {
                            KGCSectionHeader("Charging Details", systemImage: "battery.100")

                            KGCFreeSessionButton(isFree: $isFreeSession) {
                                applyFreeSession(isFreeSession)
                            }
                            .padding(.bottom, 4)

                            if !isAdvanced {
                                KGCLabeledRow(label: "Start") {
                                    DatePicker(
                                        "",
                                        selection: chargingDateBinding(\.startDate, fallback: entry.date),
                                        displayedComponents: [.date, .hourAndMinute]
                                    ).labelsHidden()
                                }
                                KGCLabeledRow(label: "End") {
                                    DatePicker(
                                        "",
                                        selection: chargingDateBinding(\.endDate, fallback: entry.date, syncEntryDate: true),
                                        displayedComponents: [.date, .hourAndMinute]
                                    ).labelsHidden()
                                }

                                KGCLabeledRow(label: "Price/kWh") {
                                    TextField("0.00", value: nestedBinding(\.pricePerKWh, 0.0), format: .number)
                                        .keyboardType(.decimalPad)
                                        .disabled(isFreeSession)
                                        .opacity(isFreeSession ? 0.5 : 1)
                                        .onChange(of: entry.charging?.pricePerKWh ?? 0) { _, newValue in
                                            if newValue > 0.0001 { isFreeSession = false }
                                        }
                                }

                                KGCLabeledRow(label: "kWh") {
                                    TextField("Energy Added", value: nestedBinding(\.energyAddedKWh, 0.0), format: .number)
                                        .keyboardType(.decimalPad)
                                }

                                KGCLabeledRow(label: "Site") {
                                    TextField("Site Name", text: nestedBinding(\.siteName, ""))
                                }
                            } else {
                                KGCLabeledRow(label: "Start") {
                                    DatePicker(
                                        "",
                                        selection: chargingDateBinding(\.startDate, fallback: entry.date),
                                        displayedComponents: [.date, .hourAndMinute]
                                    ).labelsHidden()
                                }
                                KGCLabeledRow(label: "End") {
                                    DatePicker(
                                        "",
                                        selection: chargingDateBinding(\.endDate, fallback: entry.date, syncEntryDate: true),
                                        displayedComponents: [.date, .hourAndMinute]
                                    ).labelsHidden()
                                }

                                HStack(spacing: T.spacing) {
                                    KGCLabeledRow(label: "SOC % (Start)") {
                                        TextField("0", value: nestedBinding(\.startSOC, 0.0), format: .number)
                                            .keyboardType(.decimalPad)
                                    }
                                    KGCLabeledRow(label: "SOC % (End)") {
                                        TextField("0", value: nestedBinding(\.endSOC, 0.0), format: .number)
                                            .keyboardType(.decimalPad)
                                    }
                                }

                                HStack(spacing: T.spacing) {
                                    KGCLabeledRow(label: "Odo Start") {
                                        TextField("0", value: nestedBinding(\.odometerStart, 0.0), format: .number)
                                            .keyboardType(.decimalPad)
                                    }
                                    KGCLabeledRow(label: "Odo End") {
                                        TextField("0", value: nestedBinding(\.odometerEnd, 0.0), format: .number)
                                            .keyboardType(.decimalPad)
                                    }
                                }

                                KGCLabeledRow(label: "Site") {
                                    TextField("Site Name", text: nestedBinding(\.siteName, ""))
                                }

                                HStack(spacing: T.spacing) {
                                    KGCLabeledRow(label: "Lat") {
                                        TextField("0", value: nestedBinding(\.latitude, 0.0), format: .number)
                                            .keyboardType(.decimalPad)
                                    }
                                    KGCLabeledRow(label: "Lng") {
                                        TextField("0", value: nestedBinding(\.longitude, 0.0), format: .number)
                                            .keyboardType(.decimalPad)
                                    }
                                }

                                HStack(spacing: T.spacing) {
                                    KGCLabeledRow(label: "Price/kWh") {
                                        TextField("0.00", value: nestedBinding(\.pricePerKWh, 0.0), format: .number)
                                            .keyboardType(.decimalPad)
                                            .disabled(isFreeSession)
                                            .opacity(isFreeSession ? 0.5 : 1)
                                            .onChange(of: entry.charging?.pricePerKWh ?? 0) { _, newValue in
                                                if newValue > 0.0001 { isFreeSession = false }
                                            }
                                    }
                                    KGCLabeledRow(label: "kWh") {
                                        TextField("0", value: nestedBinding(\.energyAddedKWh, 0.0), format: .number)
                                            .keyboardType(.decimalPad)
                                    }
                                }

                                HStack(spacing: T.spacing) {
                                    KGCLabeledRow(label: "Power kW") {
                                        TextField("0", value: nestedBinding(\.chargerPowerkW, 0.0), format: .number)
                                            .keyboardType(.decimalPad)
                                    }
                                    KGCLabeledRow(label: "Volts") {
                                        TextField("0", value: nestedBinding(\.chargerVolts, 0.0), format: .number)
                                            .keyboardType(.decimalPad)
                                    }
                                }

                                HStack(spacing: T.spacing) {
                                    KGCLabeledRow(label: "Amps") {
                                        TextField("0", value: nestedBinding(\.chargerAmps, 0.0), format: .number)
                                            .keyboardType(.decimalPad)
                                    }
                                    KGCLabeledRow(label: "Phases") {
                                        TextField("1", value: nestedBinding(\.chargerPhases, 1), format: .number)
                                            .keyboardType(.numberPad)
                                    }
                                }

                                KGCLabeledRow(label: "Supercharger") {
                                    Toggle("", isOn: nestedBinding(\.isSupercharger, false)).labelsHidden()
                                }
                                KGCLabeledRow(label: "Brand") {
                                    TextField("e.g., Tesla, EVgo, EA", text: nestedBinding(\.fastChargerBrand, ""))
                                }
                                KGCLabeledRow(label: "Outside °C") {
                                    TextField("0", value: nestedBinding(\.outsideTempC, 0.0), format: .number)
                                        .keyboardType(.decimalPad)
                                }
                                KGCLabeledRow(label: "Vehicle") {
                                    TextField("Vehicle Name", text: nestedBinding(\.vehicleName, ""))
                                }
                                KGCLabeledRow(label: "VIN") {
                                    TextField("Last 6 or full", text: nestedBinding(\.vin, ""))
                                }
                                KGCLabeledRow(label: "Session ID") {
                                    TextField("Charge Session ID", text: nestedBinding(\.chargeId, ""))
                                }
                                KGCLabeledRow(label: "Charge Notes") {
                                    TextField("Notes about the session", text: nestedBinding(\.notes, ""))
                                }
                            }
                        }
                        .contentTransition(.opacity)
                        .animation(.snappy, value: showCharging)
                    }

                    // VAT & Invoice (Advanced)
                    if isAdvanced {
                        KGCCard {
                            KGCSectionHeader("VAT & Invoice", systemImage: "doc.text")

                            KGCLabeledRow(label: "VAT") {
                                TextField("0.00", value: $entry.vatAmount.nilCoalescing(0), format: currencyFormatStyle)
                                    .keyboardType(.decimalPad)
                                    .disabled(isChargingCategory && isFreeSession)
                                    .opacity(isChargingCategory && isFreeSession ? 0.5 : 1)
                            }

                            KGCLabeledRow(label: "Invoice #") {
                                TextField("Reference / Invoice Number", text: $entry.invoiceNumber.nilCoalescing(""))
                                    .focused($focused, equals: .invoice)
                            }
                        }
                    }

                    // Derived
                    KGCCard {
                        KGCSectionHeader("Derived Metrics", systemImage: "gauge.with.dots.needle.bottom.50percent")
                        VStack(spacing: 8) {
                            if let net = entry.costPerKWhNet {
                                KGCMetricRow(title: "Net Cost per kWh", value: "\(currencyFormat(net))/kWh")
                            }
                            if let gross = entry.costPerKWh {
                                KGCMetricRow(title: "Gross Cost per kWh", value: "\(currencyFormat(gross))/kWh")
                            }
                            if let d = entry.chargeDurationMinutes {
                                KGCMetricRow(title: "Charge Duration", value: "\(d) min")
                            }
                            if let delta = entry.socDelta {
                                KGCMetricRow(title: "SOC Δ", value: String(format: "%.0f%%", delta))
                            }
                            if let odo = entry.odometerDelta {
                                KGCMetricRow(title: "Odometer Δ", value: String(format: "%.0f", odo))
                            }
                        }
                    }

                    if !adsStore.hasRemovedAds {
                        AdBannerCard(adsStore: adsStore)
                    }

                    // Footer
                    HStack(spacing: T.spacing) {
                        Button("Cancel") { handleCancelTapped() }
                            .buttonStyle(KGCSecondaryButtonStyle())
                        Spacer()
                        Button("Save") { handleSaveTapped() }
                            .buttonStyle(KGCPrimaryButtonStyle(accent: T.accent, onAccent: T.onAccent))
                            .keyboardShortcut(.defaultAction)
                    }
                    .padding(.top, 4)
                }
                .padding()
            }
            .background(T.screenBackground, ignoresSafeAreaEdges: .all)
            .navigationTitle(entry.summaryLabel)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCurrencyPicker) {
                KGCCurrencyPickerSheet(
                    selectedCode: currencyForFormat,
                    searchText: $currencySearch,
                    onSelect: { code in
                        entry.currencyCode = code
                        currencySearch = ""
                        showCurrencyPicker = false
                    },
                    onCancel: {
                        currencySearch = ""
                        showCurrencyPicker = false
                    }
                )
            }
            .alert("Duplicate entry", isPresented: $showDuplicateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This looks like a duplicate of an existing entry. If you still want to save it, tweak the date, amount, or notes.")
            }
            .onAppear {
                // Prime once on appear
                primeVehicleSelectionIfNeeded(force: true)
                lastVehicleIDsSnapshot = profileStore.vehicles.map(\.id)
            }
            .onChange(of: profileStore.vehicles.map(\.id)) { _, newIDs in
                // Re-prime if vehicles arrive later (async load)
                if newIDs != lastVehicleIDsSnapshot {
                    lastVehicleIDsSnapshot = newIDs
                    primeVehicleSelectionIfNeeded(force: false)
                }
            }
            .onChange(of: profileStore.selectedVehicleID) { _, _ in
                if let v = resolvedSelectedVehicle { applyVehicleSelection(v) }
            }
            .onChange(of: entry.location) { _, _ in
                updateSuggestedCategory()
            }
            .onChange(of: entry.notes) { _, _ in
                updateSuggestedCategory()
            }
            .onChange(of: entry.charging?.siteName) { _, _ in
                updateSuggestedCategory()
            }
            .onChange(of: entry.category) { _, newValue in
                if autoCategorizeLearn, let cat = ExpenseCategory(rawValue: newValue) {
                    ExpenseAutoCategorizer.shared.remember(entry: entry, category: cat)
                }
            }
            .task {
                await adsStore.load()
                updateSuggestedCategory()
            }
        }
    }

    private func updateSuggestedCategory() {
        guard autoCategorizeEnabled else {
            suggestedCategory = nil
            return
        }
        let suggestion = ExpenseAutoCategorizer.shared.suggestCategory(for: entry)
        suggestedCategory = suggestion
        if autoCategorizeAutoApply, let s = suggestion {
            entry.category = s.rawValue
        }
    }
}

// MARK: - Vehicle UI (UUID selection)

private extension AddEditEntryView {

    private func normalizeVIN(_ vin: String) -> String {
        vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func isSelected(_ v: VehicleProfile) -> Bool {
        profileStore.selectedVehicleID == v.id
    }

    private var resolvedSelectedVehicle: VehicleProfile? {
        guard let sid = profileStore.selectedVehicleID else { return nil }
        return profileStore.vehicles.first(where: { $0.id == sid })
    }

    private func selectVehicle(_ v: VehicleProfile) {
        profileStore.selectedVehicleID = v.id
        applyVehicleSelection(v)
        didPrimeVehicle = true // user explicitly chose
    }

    @ViewBuilder
    var vehicleBlock: some View {
        let vehicles = profileStore.vehicles

        if vehicles.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "car.fill")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
                Text("No vehicles saved")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .modifier(KGCInputPillChrome())

        } else if vehicles.count == 1, let v = vehicles.first {
            HStack(spacing: 10) {
                Image(systemName: "car.fill")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(v.displayName).font(.body.weight(.semibold))
                    Text(v.vin).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .modifier(KGCInputPillChrome())
            .onAppear {
                if profileStore.selectedVehicleID != v.id {
                    profileStore.selectedVehicleID = v.id
                }
                applyVehicleSelection(v)
                didPrimeVehicle = true
            }

        } else {
            Menu {
                ForEach(vehicles) { v in
                    Button { selectVehicle(v) } label: {
                        HStack {
                            Text(v.displayName)
                            Text("(\(v.vin))").foregroundStyle(.secondary)
                            if isSelected(v) { Spacer(); Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                // Prefer entry.vehicleID for display if present; else fall back to store selection
                let selectedFromEntry: VehicleProfile? = {
                    if let vid = entry.vehicleID {
                        return vehicles.first(where: { $0.id == vid })
                    }
                    if let vin = entry.vin {
                        return vehicles.first(where: { normalizeVIN($0.vin) == normalizeVIN(vin) })
                    }
                    if let name = entry.vehicleName?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !name.isEmpty {
                        return vehicles.first(where: {
                            $0.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                                .caseInsensitiveCompare(name) == .orderedSame
                        })
                    }
                    return nil
                }()

                let selected = selectedFromEntry ?? resolvedSelectedVehicle

                HStack(spacing: 10) {
                    Image(systemName: "car.fill")
                        .font(.body.weight(.semibold))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selected?.displayName ?? "Select vehicle")
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if let vin = selected?.vin {
                            Text(vin).font(.footnote).foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 6)
                    Image(systemName: "chevron.down")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.quaternary, lineWidth: 0.6))
                .contentShape(Rectangle())
            }
            .menuActionDismissBehavior(.automatic)
            .onChange(of: profileStore.selectedVehicleID) { _, _ in
                if let v = resolvedSelectedVehicle { applyVehicleSelection(v) }
            }
        }
    }

    func primeVehicleSelectionIfNeeded(force: Bool) {
        let vehicles = profileStore.vehicles
        guard !vehicles.isEmpty else { return }

        // Don’t clobber user choice repeatedly.
        if didPrimeVehicle && !force { return }

        // A) If entry already has vehicleID, select by UUID
        if let vid = entry.vehicleID, let match = vehicles.first(where: { $0.id == vid }) {
            if profileStore.selectedVehicleID != match.id {
                profileStore.selectedVehicleID = match.id
            }
            applyVehicleSelection(match)
            didPrimeVehicle = true
            return
        }

        // B) If entry has VIN, try matching by VIN
        if let vin = entry.vin,
           let match = vehicles.first(where: { normalizeVIN($0.vin) == normalizeVIN(vin) }) {
            if profileStore.selectedVehicleID != match.id {
                profileStore.selectedVehicleID = match.id
            }
            applyVehicleSelection(match)
            didPrimeVehicle = true
            return
        }

        // C) If entry has vehicleName, try matching by displayName
        if let name = entry.vehicleName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty,
           let match = vehicles.first(where: {
               $0.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                   .caseInsensitiveCompare(name) == .orderedSame
           }) {
            if profileStore.selectedVehicleID != match.id {
                profileStore.selectedVehicleID = match.id
            }
            applyVehicleSelection(match)
            didPrimeVehicle = true
            return
        }

        // D) Use store selection if present
        if let current = resolvedSelectedVehicle {
            applyVehicleSelection(current)
            didPrimeVehicle = true
            return
        }

        // E) If exactly one vehicle exists, select it
        if vehicles.count == 1, let v = vehicles.first {
            profileStore.selectedVehicleID = v.id
            applyVehicleSelection(v)
            didPrimeVehicle = true
        }
    }

    func applyVehicleSelection(_ v: VehicleProfile) {
        entry.vehicleID = v.id
        entry.vehicleName = v.displayName
        entry.vin = v.vin
    }
}

// MARK: - Save / Cancel

private extension AddEditEntryView {

    func handleSaveTapped() {
        // Prefer VIN match
        if let vin = entry.vin,
           let match = profileStore.vehicles.first(where: { normalizeVIN($0.vin) == normalizeVIN(vin) }) {
            profileStore.selectedVehicleID = match.id
            applyVehicleSelection(match)
        }

        // If still missing vehicleID, attach currently-selected vehicle
        if entry.vehicleID == nil, let current = resolvedSelectedVehicle {
            applyVehicleSelection(current)
        }

        let prepared = preparedEntryForSave()

        if let isDuplicate, isDuplicate(prepared) {
            showDuplicateAlert = true
            return
        }

        onSave(prepared)
        dismiss()
    }

    func preparedEntryForSave() -> ExpenseEntry {
        var e = entry

        if isFreeSession {
            if e.charging == nil { e.charging = ChargingDetails() }
            e.amount = 0
            e.vatAmount = 0
            e.isEnergy = true
            e.charging?.pricePerKWh = 0
        } else if isChargingCategory {
            if let k = e.energyKWh {
                e.charging = e.charging ?? ChargingDetails()
                e.charging?.energyAddedKWh = k
            } else if let ck = e.charging?.energyAddedKWh {
                e.energyKWh = ck
            }

            if e.charging?.pricePerKWh == nil,
               let k = e.energyKWh,
               k > 0 {
                e.charging = e.charging ?? ChargingDetails()
                e.charging?.pricePerKWh = e.amount / k
            }
        }

        if isFreeSession, (e.categoryEnum == .fastDCFC || e.categoryEnum == .publicCharging) {
            if e.charging?.isSupercharger == nil { e.charging?.isSupercharger = true }
            if (e.charging?.fastChargerBrand ?? "").isEmpty { e.charging?.fastChargerBrand = "Tesla" }
        }

        return e
    }

    func handleCancelTapped() {
        entry = initial

        let initialIsChargingCat = [.energy, .homeCharging, .publicCharging, .fastDCFC].contains(initial.categoryEnum)
        showCharging = initialIsChargingCat && initial.isEnergyEffective

        let approxZeroAmount = abs(initial.amount) < 0.0001
        let zeroPPK = (initial.charging?.pricePerKWh ?? -1) == 0
        isFreeSession = initialIsChargingCat && (approxZeroAmount || zeroPPK)

        onCancel?()
        dismiss()
    }
}

// MARK: - Category/Charging gating & bindings

private extension AddEditEntryView {

    var isChargingCategory: Bool {
        [.energy, .homeCharging, .publicCharging, .fastDCFC].contains(entry.categoryEnum)
    }

    var categoryBinding: Binding<ExpenseCategory> {
        Binding<ExpenseCategory>(
            get: { entry.categoryEnum },
            set: { newCat in
                entry.setCategory(newCat)

                let isChargingCat = [.energy, .homeCharging, .publicCharging, .fastDCFC].contains(newCat)
                withAnimation(.snappy) {
                    showCharging = isChargingCat && (entry.isEnergy || entry.isEnergyByCategory || entry.charging != nil)
                }

                if !isChargingCat {
                    entry.isEnergy = false
                    isFreeSession = false
                }
            }
        )
    }

    var currencyForFormat: String {
        entry.currencyCode ?? (Locale.current.currency?.identifier ?? "USD")
    }

    var currencyFormatStyle: FloatingPointFormatStyle<Double>.Currency {
        .init(code: currencyForFormat)
    }

    func currencyFormat(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = currencyForFormat
        return nf.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    func currencyDisplayString(code: String) -> String {
        let name = Locale.current.localizedString(forCurrencyCode: code) ?? code
        let symbol = KGCCurrencyOption.symbol(for: code)
        return "\(code) \(symbol) — \(name)"
    }

    func chargingDateBinding(
        _ keyPath: WritableKeyPath<ChargingDetails, Date?>,
        fallback: Date,
        syncEntryDate: Bool = false
    ) -> Binding<Date> {
        Binding<Date>(
            get: { entry.charging?[keyPath: keyPath] ?? fallback },
            set: { newVal in
                if entry.charging == nil { entry.charging = ChargingDetails() }
                entry.charging?[keyPath: keyPath] = newVal
                if syncEntryDate { entry.date = newVal }
            }
        )
    }

    func nestedBinding<T>(_ keyPath: WritableKeyPath<ChargingDetails, T?>, _ defaultValue: T) -> Binding<T> {
        Binding<T>(
            get: { entry.charging?[keyPath: keyPath] ?? defaultValue },
            set: { newVal in
                if entry.charging == nil { entry.charging = ChargingDetails() }
                entry.charging?[keyPath: keyPath] = newVal
                syncMirrorsFromCharging(fillIfMissingOnly: true)
            }
        )
    }

    func syncMirrorsFromCharging(fillIfMissingOnly: Bool) {
        guard let c = entry.charging else { return }

        if let site = c.siteName, !site.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !fillIfMissingOnly || (entry.location ?? "").isEmpty { entry.location = site }
        }
        if let odo = c.odometerEnd {
            if !fillIfMissingOnly || entry.odometer == nil { entry.odometer = odo }
        }
        if let kwh = c.energyAddedKWh {
            if !fillIfMissingOnly || entry.energyKWh == nil { entry.energyKWh = kwh }
        }
        if let vin = c.vin, !vin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !fillIfMissingOnly || (entry.vin ?? "").isEmpty { entry.vin = vin }
        }
        if let name = c.vehicleName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !fillIfMissingOnly || (entry.vehicleName ?? "").isEmpty { entry.vehicleName = name }
        }
    }

    // ✅ Fixed: toggling OFF no longer leaves forced “free” sentinel values behind.
    func applyFreeSession(_ isFree: Bool) {
        if isFree {
            entry.amount = 0
            entry.vatAmount = 0
            entry.isEnergy = true
            if entry.charging == nil { entry.charging = ChargingDetails() }
            entry.charging?.pricePerKWh = 0

            if entry.categoryEnum == .fastDCFC || entry.categoryEnum == .publicCharging {
                if entry.charging?.isSupercharger == nil { entry.charging?.isSupercharger = true }
                if (entry.charging?.fastChargerBrand ?? "").isEmpty { entry.charging?.fastChargerBrand = "Tesla" }
            }
        } else {
            // Clear forced markers; user can enter real values
            if entry.vatAmount == 0 { entry.vatAmount = nil }
            if entry.charging?.pricePerKWh == 0 { entry.charging?.pricePerKWh = nil }
        }
    }
}

// MARK: - Small Views / Helpers (self-contained)

fileprivate struct KGCCard<Content: View>: View {
    @Environment(\.appThemeBox) private var _themeBox
    private var T: any AppThemeSpec { _themeBox.base }
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(T.separator, lineWidth: 1)
            )
    }
}

fileprivate struct KGCInputPillChrome: ViewModifier {
    @Environment(\.appThemeBox) private var _themeBox
    private var T: any AppThemeSpec { _themeBox.base }
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.thinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(T.separator, lineWidth: 0.6))
    }
}

fileprivate struct KGCSectionHeader: View {
    @Environment(\.appThemeBox) private var _themeBox
    private var T: any AppThemeSpec { _themeBox.base }
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title).font(.headline.weight(.semibold))
            Spacer()
        }
        .tint(T.accent)
        .padding(.bottom, 6)
    }
}

fileprivate struct KGCChip: View {
    @Environment(\.appThemeBox) private var _themeBox
    private var T: any AppThemeSpec { _themeBox.base }
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(T.onAccent)
            .background(T.pillTint, in: Capsule())
            .overlay(Capsule().stroke(T.separator, lineWidth: 0.7))
    }
}

fileprivate struct KGCMetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).foregroundStyle(.primary)
        }
        .font(.callout)
        .padding(.vertical, 2)
        .overlay(Divider(), alignment: .bottom)
    }
}

fileprivate struct KGCLabeledRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    init(label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(label.uppercased())
                    .font(.caption2.weight(.semibold))
                    .kerning(0.5)
                    .foregroundStyle(.secondary)
                    .frame(width: 96, alignment: .trailing)
                    .accessibilityHidden(true)

                content()
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
        }
        .padding(.vertical, 2)
    }
}

fileprivate struct KGCCategoryPickerRow<Badge: View>: View {
    @Environment(\.appThemeBox) private var _themeBox
    private var T: any AppThemeSpec { _themeBox.base }
    @Binding var selection: ExpenseCategory
    let badge: Badge

    var body: some View {
        ViewThatFits {
            HStack(spacing: 12) {
                KGCCategoryMenu(selection: $selection)
                Spacer(minLength: 8)
                badge.fixedSize()
            }
            VStack(alignment: .leading, spacing: 8) {
                KGCCategoryMenu(selection: $selection)
                badge.fixedSize()
            }
        }
        .tint(T.accent)
    }
}

fileprivate struct KGCCategoryMenu: View {
    @Binding var selection: ExpenseCategory

    var body: some View {
        Menu {
            ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                Button {
                    selection = cat
                } label: {
                    HStack {
                        Label(cat.rawValue, systemImage: cat.icon)
                        if cat == selection { Spacer(); Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selection.icon).font(.body.weight(.semibold))
                Text(selection.rawValue)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.quaternary, lineWidth: 0.6))
            .contentShape(Rectangle())
        }
        .menuActionDismissBehavior(.automatic)
    }
}

fileprivate struct KGCCategoryBadge: View {
    @Environment(\.appThemeBox) private var _themeBox
    private var T: any AppThemeSpec { _themeBox.base }
    let category: ExpenseCategory

    var body: some View {
        Text(category.rawValue)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(Color.white)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [T.accent, T.accent.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.6))
            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
    }
}

fileprivate struct KGCFreeSessionButton: View {
    @Environment(\.appThemeBox) private var _themeBox
    private var T: any AppThemeSpec { _themeBox.base }
    @Binding var isFree: Bool
    var onToggle: () -> Void

    var body: some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            #endif
            isFree.toggle()
            onToggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isFree ? "checkmark.seal.fill" : "bolt.circle")
                    .symbolRenderingMode(.hierarchical)
                Text(isFree ? "Free Supercharging — On" : "Mark Free Supercharging")
                    .fontWeight(.semibold)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isFree ? T.accent.opacity(0.22) : T.pillTint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(T.separator, lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isFree)
    }
}

fileprivate struct KGCCurrencyButtonLabel: View {
    @Environment(\.appThemeBox) private var _themeBox
    private var T: any AppThemeSpec { _themeBox.base }
    let display: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "banknote")
                .imageScale(.medium)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(display).font(.body.weight(.semibold))
                Text("Tap to change").font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(T.separator, lineWidth: 0.6))
        .contentShape(Rectangle())
    }
}

fileprivate struct KGCCurrencyPickerSheet: View {
    let selectedCode: String
    @Binding var searchText: String
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    private var filtered: [KGCCurrencyOption] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return KGCCurrencyOption.all }
        return KGCCurrencyOption.all.filter { opt in
            opt.code.lowercased().contains(q) ||
            opt.name.lowercased().contains(q) ||
            opt.symbol.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { opt in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(opt.code) \(opt.symbol)").font(.body.weight(.semibold))
                            Text(opt.name).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if opt.code == selectedCode {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(opt.code) }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search code, name, or symbol")
            .navigationTitle("Choose Currency")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
            }
        }
    }
}

fileprivate struct KGCCurrencyOption: Identifiable {
    let id: String
    let code: String
    let symbol: String
    let name: String

    static let all: [KGCCurrencyOption] = {
        let codes = Set(Locale.commonISOCurrencyCodes)
        let loc = Locale.current
        let nf = NumberFormatter()
        nf.numberStyle = .currency

        let options = codes.compactMap { code -> KGCCurrencyOption? in
            nf.currencyCode = code
            let name = loc.localizedString(forCurrencyCode: code) ?? code
            let symbol = nf.currencySymbol ?? code
            return KGCCurrencyOption(id: code, code: code, symbol: symbol, name: name)
        }
        return options.sorted { l, r in
            if l.name == r.name { return l.code < r.code }
            return l.name < r.name
        }
    }()

    static func symbol(for code: String) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = code
        return nf.currencySymbol ?? code
    }
}

// MARK: - Binding helpers

fileprivate extension Binding where Value == Double? {
    func nilCoalescing(_ defaultValue: Double) -> Binding<Double> {
        Binding<Double>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}

fileprivate extension Binding where Value == String? {
    func nilCoalescing(_ defaultValue: String) -> Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

// MARK: - Button styles

fileprivate struct KGCPrimaryButtonStyle: ButtonStyle {
    let accent: Color
    let onAccent: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(onAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(accent, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

fileprivate struct KGCSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.quaternary, lineWidth: 0.6))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
