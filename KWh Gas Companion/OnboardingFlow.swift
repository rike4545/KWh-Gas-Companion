//  OnboardingFlow.swift — clean, view-only (no @main)
//  My KWh Companion
//
//  Drop-in onboarding flow (Swift 6 / iOS 17+)
//  ✅ No @main, no MetricKit, no BGTask definitions here
//  ✅ VIN field fixed (no UITextContentType.vehicleIdentificationNumber)
//  ✅ Callbacks via initializer (wire to ProfileStore / stores in App file)
//
//  Use from your @main app:
//  OnboardingFlowView(
//      onFinish: { hasCompletedOnboarding = true },
//      onRequestLocation: { /* return CLAuthorizationStatus */ .notDetermined },
//      onRequestNotifications: { /* return UNAuthorizationStatus */ .notDetermined },
//      onSaveVehicle: { make, model, year, nick in /* persist */ },
//      onSaveRates: { daily, summer, winter, isSummer in /* persist */ },
//      onImportTeslaFi: { url in /* return imported count */ 0 }
//  )

import SwiftUI
import CoreLocation
import UserNotifications
import UniformTypeIdentifiers

// MARK: - Shared onboarding state
@MainActor
final class OnboardingState: ObservableObject {
    // Vehicle
    @Published var vehicleMake: String = "Tesla"
    @Published var vehicleModel: String = "Model Y"
    @Published var vehicleNick: String = ""
    @Published var vehicleYear: Int = Calendar.current.component(.year, from: .now)
    @Published var vin: String = ""

    // Home Energy (defaults shown for LI example; tune later in Settings)
    @AppStorage("home.dailyServiceCharge") var dailyServiceCharge: Double = 0.5400
    @AppStorage("home.deliveryPerKWh.summer") var deliverySummer: Double = 0.1049
    @AppStorage("home.deliveryPerKWh.winter") var deliveryWinter: Double = 0.0891
    @Published var isSummer: Bool = true

    // Permissions
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var notificationsStatus: UNAuthorizationStatus = .notDetermined

    // Imports
    @Published var importedTeslaFiSessionsCount: Int = 0
    @Published var lastImportedFilename: String? = nil
    @Published var importedTeslaChargingCount: Int = 0
    @Published var lastImportedChargingFilename: String? = nil

    // Consent
    @Published var acceptedTerms: Bool = false
    @Published var shareDiagnostics: Bool = false
}

// MARK: - Flow entry
public struct OnboardingFlowView: View {
    // MARK: Callbacks
    /// Called after the final step completes.
    public typealias FinishHandler = () -> Void
    /// Provide current location permission status (request if needed) and return the new status.
    public typealias LocationRequest = () async -> CLAuthorizationStatus
    /// Provide current notification permission status (request if needed) and return the new status.
    public typealias NotificationRequest = () async -> UNAuthorizationStatus
    /// Persist the selected vehicle (Make, Model, Year, Nickname).
    public typealias SaveVehicle = (String, String, Int, String) -> Void
    /// Persist the home energy rates (daily, summer, winter) and the active season flag.
    public typealias SaveRates = (Double, Double, Double, Bool) -> Void
    /// Handle a TeslaFi CSV import and return the number of imported rows.
    public typealias ImportTeslaFi = (URL) async throws -> Int

    // MARK: Init
    public init(
        onFinish: @escaping FinishHandler = {},
        onRequestLocation: @escaping LocationRequest = { .notDetermined },
        onRequestNotifications: @escaping NotificationRequest = { .notDetermined },
        onSaveVehicle: @escaping SaveVehicle = { _,_,_,_ in },
        onSaveRates: @escaping SaveRates = { _,_,_,_ in },
        onImportTeslaFi: @escaping ImportTeslaFi = { _ in 0 }
    ) {
        self.onFinish = onFinish
        self.onRequestLocation = onRequestLocation
        self.onRequestNotifications = onRequestNotifications
        self.onSaveVehicle = onSaveVehicle
        self.onSaveRates = onSaveRates
        self.onImportTeslaFi = onImportTeslaFi
        _state = StateObject(wrappedValue: OnboardingState())
    }

    // MARK: Dependencies
    private let onFinish: FinishHandler
    private let onRequestLocation: LocationRequest
    private let onRequestNotifications: NotificationRequest
    private let onSaveVehicle: SaveVehicle
    private let onSaveRates: SaveRates
    private let onImportTeslaFi: ImportTeslaFi

    // MARK: Local State
    @StateObject private var state: OnboardingState
    @State private var stepIndex: Int = 0

    // Keep step labels centralized for accessibility and analytics hooks.
    private let stepTitles: [String] = [
        "Welcome",
        "What you’ll get",
        "Your vehicle",
        "Home rates",
        "Permissions",
        "TeslaFi import",
        "Privacy",
        "Finish"
    ]

    // MARK: Body
    public var body: some View {
        VStack(spacing: 0) {
            header
            steps[stepIndex]
                .id(stepIndex)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
                .animation(.easeInOut(duration: 0.25), value: stepIndex)
        }
        .background(
            LinearGradient(colors: [Color.black.opacity(0.95), Color.gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Onboarding step \(stepIndex + 1) of \(steps.count): \(stepTitles[stepIndex])"))
    }

    // MARK: Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: Double(stepIndex + 1), total: Double(steps.count))
                .accessibilityLabel(Text("Progress"))
                .accessibilityValue(Text("\(stepIndex + 1) of \(steps.count)"))
            Text(stepTitles[stepIndex])
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }

    // MARK: Steps
    private var steps: [AnyView] {
        [
            AnyView(WelcomeStep(next: next)),
            AnyView(ValuePropStep(next: next)),
            AnyView(VehicleStep(state: state, next: next)),
            AnyView(RatePlanStep(state: state, onSave: { saveRates() }, next: next)),
            AnyView(PermissionsStep(state: state, next: next, requestLocation: requestLocation, requestNotifications: requestNotifications)),
            AnyView(TeslaFiImportStep(state: state, next: next, onImport: handleImport)),
            AnyView(PrivacyStep(state: state, next: next)),
            AnyView(FinishStep(finish: finish))
        ]
    }

    // MARK: Navigation
    private func next() { stepIndex = min(stepIndex + 1, steps.count - 1) }
    private func back() { stepIndex = max(stepIndex - 1, 0) }

    private func finish() {
        onSaveVehicle(state.vehicleMake, state.vehicleModel, state.vehicleYear, state.vehicleNick)
        saveRates()
        requestProvisionalNotificationsIfNeeded()
        onFinish()
    }

    private func saveRates() {
        onSaveRates(state.dailyServiceCharge, state.deliverySummer, state.deliveryWinter, state.isSummer)
    }

    // MARK: Permissions
    private func requestLocation() async {
        state.locationStatus = await onRequestLocation()
    }

    private func requestNotifications() async {
        let provided = await onRequestNotifications()
        if provided != .notDetermined {
            state.notificationsStatus = provided
            return
        }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            state.notificationsStatus = granted ? .authorized : .denied
        } catch {
            state.notificationsStatus = .denied
        }
    }

    private func requestProvisionalNotificationsIfNeeded() {
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.provisional])
            }
        }
    }

    // MARK: Import
    private func handleImport(_ url: URL) async {
        do {
            let count = try await onImportTeslaFi(url)
            state.importedTeslaFiSessionsCount = count
            state.lastImportedFilename = url.lastPathComponent
        } catch {
            state.importedTeslaFiSessionsCount = 0
            state.lastImportedFilename = nil
        }
    }
}

// MARK: - Step 0 — Welcome
private struct WelcomeStep: View {
    let next: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(.white.opacity(0.12))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "bolt.car")
                            .font(.system(size: 56, weight: .bold))
                            .symbolRenderingMode(.hierarchical)
                        Text("My EV Companion")
                            .font(.largeTitle.weight(.semibold))
                        Text("Your comprehensive tool kit for EV ownership insights.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                )
                .padding(.horizontal)
            Spacer()
            PrimaryButton(title: "Let’s get set up", action: next)
                .padding(.bottom, 24)
        }
    }
}

// MARK: - Step 1 — Value Prop
private struct ValuePropStep: View {
    let next: () -> Void
    private struct Card: Identifiable { let id = UUID(); let title: String; let subtitle: String; let symbol: String }
    private let cards: [Card] = [
        .init(title: "Know your real costs", subtitle: "Home, Supercharger, and public charging costs modeled by season and habit.", symbol: "dollarsign.circle"),
        .init(title: "See and predict usage", subtitle: "Trends, forecasts, and anomalies across months.", symbol: "chart.line.uptrend.xyaxis"),
        .init(title: "Make smarter stops", subtitle: "Near‑me map with accurate pricing and site details.", symbol: "mappin.and.ellipse")
    ]
    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)
            Text("What you’ll get")
                .font(.title2.weight(.semibold))
            VStack(spacing: 12) {
                ForEach(cards) { c in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: c.symbol).font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(c.title).font(.headline)
                            Text(c.subtitle).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.08)))
                    .padding(.horizontal)
                }
            }
            Spacer()
            PrimaryButton(title: "Continue", action: next)
                .padding(.bottom, 24)
        }
    }
}

// MARK: - Step 2 — Vehicle
private struct VehicleStep: View {
    @ObservedObject var state: OnboardingState
    let next: () -> Void

    private let makes = ["Tesla", "Rivian"]

    private var models: [String] {
        switch state.vehicleMake {
        case "Rivian":
            return ["R1T", "R1S", "Other"]
        default: // Tesla
            return ["Model 3", "Model Y", "Model S", "Model X", "Cybertruck", "Other"]
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Your vehicle")
                    .font(.title2.weight(.semibold))
                VStack(spacing: 12) {
                    PickerRow(title: "Make") {
                        Picker("Make", selection: $state.vehicleMake) {
                            ForEach(makes, id: \ .self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    PickerRow(title: "Model") {
                        Picker("Model", selection: $state.vehicleModel) {
                            ForEach(models, id: \ .self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    .onChange(of: state.vehicleMake) { _, _ in
                        // Ensure model stays valid when make changes
                        if !models.contains(state.vehicleModel) {
                            state.vehicleModel = models.first ?? ""
                        }
                    }
                    PickerRow(title: "Year") {
                        Stepper(value: $state.vehicleYear, in: 2008...(Calendar.current.component(.year, from: .now) + 1)) {
                            Text(String(state.vehicleYear))
                        }
                    }
                    LabeledContent("Nickname (optional)") {
                        TextField("e.g., Falcon", text: $state.vehicleNick)
                            .textInputAutocapitalization(.words)
                    }
                    LabeledContent("VIN (optional)") {
                        TextField("17-character VIN", text: $state.vin)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)
                            .keyboardType(.asciiCapable)
                            .onChange(of: state.vin) { _, newValue in
                                // Uppercase, trim, clamp to 17 chars
                                let upper = newValue.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                                if upper != state.vin { state.vin = String(upper.prefix(17)) }
                            }
                            .font(.system(.body, design: .monospaced))
                    }
                    Text("Currently supported makes: Tesla and Rivian.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .cardStyle()
                .padding(.horizontal)
            }
        }
        .safeAreaInset(edge: .bottom) { FooterBar(primaryTitle: "Save & continue", primaryAction: next) }
    }
}

// MARK: - Step 3 — Home Rate Plan
private struct RatePlanStep: View {
    @ObservedObject var state: OnboardingState
    let onSave: () -> Void
    let next: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Home electricity rates")
                .font(.title2.weight(.semibold))
            VStack(spacing: 12) {
                Toggle(isOn: $state.isSummer) {
                    Text(state.isSummer ? "Summer rates (Jun–Sep)" : "Winter rates (Oct–May)")
                }
                .toggleStyle(.switch)

                LabeledDecimalField(title: "Daily service charge ($/day)", value: $state.dailyServiceCharge)
                LabeledDecimalField(title: "Delivery per kWh — Summer ($/kWh)", value: $state.deliverySummer)
                LabeledDecimalField(title: "Delivery per kWh — Winter ($/kWh)", value: $state.deliveryWinter)
                Text("You can fine‑tune these later in Settings → Home Energy Rates.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .cardStyle()
            .padding(.horizontal)
            Spacer()
            FooterBar(primaryTitle: "Save & continue", primaryAction: { onSave(); next() })
        }
    }
}

// MARK: - Step 4 — Permissions
private struct PermissionsStep: View {
    @ObservedObject var state: OnboardingState
    let next: () -> Void
    let requestLocation: () async -> Void
    let requestNotifications: () async -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Permissions")
                .font(.title2.weight(.semibold))
            VStack(spacing: 12) {
                PermissionRow(icon: "location", title: "Location", detail: locDetail, actionTitle: "Enable") {
                    await requestLocation()
                }
                PermissionRow(icon: "bell.badge", title: "Notifications", detail: notiDetail, actionTitle: "Enable") {
                    await requestNotifications()
                }
            }
            .cardStyle()
            .padding(.horizontal)

            Spacer()
            FooterBar(primaryTitle: "Continue", primaryAction: next)
        }
    }

    private var locDetail: String {
        switch state.locationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return "Enabled"
        case .denied: return "Denied — enable in Settings"
        case .restricted: return "Restricted"
        case .notDetermined: return "Used to show nearby chargers and price estimates"
        @unknown default: return "Unknown"
        }
    }

    private var notiDetail: String {
        switch state.notificationsStatus {
        case .authorized, .provisional, .ephemeral: return "Enabled"
        case .denied: return "Denied — enable in Settings"
        case .notDetermined: return "Get reminders and charging summaries"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Step 5 — TeslaFi CSV Import (optional)
private struct TeslaFiImportStep: View {
    @ObservedObject var state: OnboardingState
    let next: () -> Void
    let onImport: (URL) async -> Void

    @State private var showingImporter = false
    @State private var showingChargingImporter = false
    @StateObject private var teslaFiUnlock = TeslaFiEntitlementStore.shared

    var body: some View {
        VStack(spacing: 16) {
            Text("Import data (optional)")
                .font(.title2.weight(.semibold))
            VStack(spacing: 12) {
                // TeslaFi import
                Text("If you use TeslaFi, import your CSV to pre‑populate sessions and analytics. You can always do this later.")
                    .foregroundStyle(.secondary)
                if teslaFiUnlock.hasTeslaFiUnlock {
                    Button { showingImporter = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "tray.and.arrow.down")
                            Text("Choose TeslaFi CSV…")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    TeslaFiUnlockCard(
                        title: "TeslaFi Import Locked",
                        subtitle: "Unlock TeslaFi CSV import and analytics for $0.99."
                    )
                }

                if let name = state.lastImportedFilename {
                    Label("Imported \(state.importedTeslaFiSessionsCount) sessions from \(name)", systemImage: state.importedTeslaFiSessionsCount > 0 ? "checkmark.circle" : "xmark.octagon")
                        .foregroundStyle(state.importedTeslaFiSessionsCount > 0 ? .green : .red)
                        .padding(.top, 6)
                }

                Divider().padding(.vertical, 4)

                // Tesla Charging History import (official Tesla app/site export)
                Text("Alternatively, you can import your **Tesla Charging History** CSV exported from your Tesla app or Tesla account.")
                    .foregroundStyle(.secondary)
                Button { showingChargingImporter = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        Text("Choose Tesla Charging CSV…")
                    }
                }
                .buttonStyle(.bordered)

                if let name = state.lastImportedChargingFilename {
                    Label("Imported \(state.importedTeslaChargingCount) charges from \(name)", systemImage: state.importedTeslaChargingCount > 0 ? "checkmark.circle" : "xmark.octagon")
                        .foregroundStyle(state.importedTeslaChargingCount > 0 ? .green : .red)
                        .padding(.top, 6)
                }
            }
            .cardStyle()
            .padding(.horizontal)
            Spacer()
            FooterBar(primaryTitle: "Continue", primaryAction: next)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [UTType.commaSeparatedText, UTType.text, UTType.data]
        ) { result in
            switch result {
            case .success(let url):
                Task { await onImport(url) }
            case .failure:
                state.importedTeslaFiSessionsCount = 0
                state.lastImportedFilename = nil
            }
        }
        .fileImporter(
            isPresented: $showingChargingImporter,
            allowedContentTypes: [UTType.commaSeparatedText, UTType.text, UTType.data]
        ) { result in
            switch result {
            case .success(let url):
                // Simple row counter fallback. Replace with your real importer when ready.
                do {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    let rows = text.split(whereSeparator: { $0.isNewline })
                    state.importedTeslaChargingCount = max(0, rows.dropFirst().count)
                    state.lastImportedChargingFilename = url.lastPathComponent
                    NotificationCenter.default.post(name: .init("TeslaChargingImportRequested"), object: url)
                } catch {
                    state.importedTeslaChargingCount = 0
                    state.lastImportedChargingFilename = nil
                }
            case .failure:
                state.importedTeslaChargingCount = 0
                state.lastImportedChargingFilename = nil
            }
        }
        .task { await teslaFiUnlock.load() }
    }
}

// MARK: - Step 6 — Privacy & Analytics
private struct PrivacyStep: View {
    @ObservedObject var state: OnboardingState
    let next: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Privacy")
                .font(.title2.weight(.semibold))
            VStack(alignment: .leading, spacing: 12) {
                Text("We respect your privacy. We do not collect any data.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("Diagnostics, if enabled later in Settings Panel, are anonymous and help us improve performance and reliability of this app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .cardStyle()
            .padding(.horizontal)
            Spacer()
            FooterBar(primaryTitle: "Continue", primaryAction: next)
        }
    }
}

// MARK: - Step 7 — Finish
private struct FinishStep: View {
    let finish: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)
            Image(systemName: "checkmark.seal.fill").font(.system(size: 56, weight: .bold))
            Text("All set").font(.largeTitle.weight(.semibold))
            Text("You can change any of this later in Settings.").foregroundStyle(.secondary)
            Spacer()
            PrimaryButton(title: "Let's Go!", action: finish)
                .padding(.bottom, 24)
        }
    }
}

// MARK: - UI Building Blocks
private struct PrimaryButton: View {
    let title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

private struct FooterBar: View {
    var primaryTitle: String
    var primaryAction: () -> Void
    var isDisabled: Bool = false
    var body: some View {
        HStack { Spacer(); Button(primaryTitle, action: primaryAction).buttonStyle(.borderedProminent).disabled(isDisabled); Spacer() }
            .padding(.vertical, 12)
            .background(.thinMaterial)
    }
}

private struct PickerRow<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        LabeledContent(title) { content }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.06)))
    }
}

private struct LabeledDecimalField: View {
    let title: String
    @Binding var value: Double
    @FocusState private var focused: Bool
    var body: some View {
        LabeledContent(title) {
            TextField("0.0000", value: $value, format: .number.precision(.fractionLength(4)))
                .keyboardType(.decimalPad)
                .focused($focused)
                .multilineTextAlignment(.trailing)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.06)))
    }
}

// MARK: - PermissionRow
private struct PermissionRow: View {
    let icon: String
    let title: String
    let detail: String
    let actionTitle: String
    let action: () async -> Void

    @State private var busy = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                if showSettingsButton {
                    Button("Settings") { openSettings() }.buttonStyle(.bordered)
                }
                Button(actionTitle) {
                    Task { @MainActor in
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        busy = true
                        await action()
                        busy = false
                        #if canImport(UIKit)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        #endif
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(busy || isEnabled)
                .overlay { if busy { ProgressView().controlSize(.small) } }
            }
        }
        .padding(12)
    }

    private var isEnabled: Bool { detail.localizedCaseInsensitiveContains("enabled") }
    private var isDenied: Bool { detail.localizedCaseInsensitiveContains("denied") }
    private var showSettingsButton: Bool { isDenied }

    private func openSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}

// MARK: - Shared card style
extension View {
    func cardStyle() -> some View {
        self.padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.08)))
    }
}
