//
//  TeslaMateProClientView.swift
//  KWh Gas Companion
//
//  Pro-only TeslaMate client shell (direct-to-user server, no middleman).
//

import SwiftUI
import Foundation

@MainActor
final class TeslaMateConnectionStore: ObservableObject {
    static let shared = TeslaMateConnectionStore()

    @Published var baseURL: String = ""
    @Published var accessToken: String = ""
    @Published var useProxyToken: Bool = false
    @Published private(set) var lastSavedAt: Date? = nil

    private let baseURLKey = "teslamate.base_url"
    private let tokenKey = "teslamate.access_token"
    private let proxyKey = "teslamate.use_proxy"
    private let savedAtKey = "teslamate.saved_at"

    private init() {
        let defaults = UserDefaults.standard
        baseURL = defaults.string(forKey: baseURLKey) ?? ""
        accessToken = defaults.string(forKey: tokenKey) ?? ""
        useProxyToken = defaults.bool(forKey: proxyKey)
        if let ts = defaults.object(forKey: savedAtKey) as? Date { lastSavedAt = ts }
    }

    var isConfigured: Bool {
        !normalizedBaseURL.isEmpty && !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var normalizedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(normalizedBaseURL, forKey: baseURLKey)
        defaults.set(accessToken, forKey: tokenKey)
        defaults.set(useProxyToken, forKey: proxyKey)
        let now = Date()
        defaults.set(now, forKey: savedAtKey)
        lastSavedAt = now
    }

    func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: baseURLKey)
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: proxyKey)
        defaults.removeObject(forKey: savedAtKey)
        baseURL = ""
        accessToken = ""
        useProxyToken = false
        lastSavedAt = nil
    }
}

@MainActor
struct TeslaMateProClientView: View {
    @StateObject private var proStore = TeslaMateProStore.shared
    @StateObject private var connection = TeslaMateConnectionStore.shared
    @StateObject private var dataStore = TeslaMateDataStore()

    var body: some View {
        Group {
            if proStore.isProActive {
                TeslaMateProHomeView(dataStore: dataStore)
            } else {
                PaywallView()
            }
        }
        .navigationTitle("TeslaMate Client")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await proStore.load()
            await proStore.refreshEntitlements()
        }
    }
}

@MainActor
private struct TeslaMateProHomeView: View {
    @StateObject private var connection = TeslaMateConnectionStore.shared
    @ObservedObject var dataStore: TeslaMateDataStore
    @State private var showSavedToast = false
    @State private var lastRefreshAt: Date? = nil
    @AppStorage("teslamate.live_activities.enabled") private var liveActivitiesEnabled: Bool = false
    @AppStorage("teslamate.selected_car_id") private var selectedCarID: Int = -1

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Direct TeslaMate Connection")
                        .font(.headline)
                    Text("Connect to your own TeslaMate instance. No middleman service, no data relay.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Connection") {
                TextField("Base URL (e.g., https://teslamate.yourdomain.com)", text: $connection.baseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                SecureField("Access Token / API Key", text: $connection.accessToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Toggle("Use MyTeslaMate Proxy (token in URL)", isOn: $connection.useProxyToken)

                HStack {
                    Button("Save") {
                        connection.save()
                        showSavedToast = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Clear") {
                        connection.clear()
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    Task {
                        await dataStore.refreshAll(
                            baseURL: connection.normalizedBaseURL,
                            token: connection.accessToken,
                            useProxyToken: connection.useProxyToken,
                            selectedCarID: selectedCarID >= 0 ? selectedCarID : nil
                        )
                        lastRefreshAt = Date()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if dataStore.isLoading {
                            ProgressView().scaleEffect(0.9)
                        }
                        Text(dataStore.isLoading ? "Testing…" : "Test Connection")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!connection.isConfigured || dataStore.isLoading)

                if let saved = connection.lastSavedAt {
                    Text("Saved \(saved.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let last = lastRefreshAt {
                    Text("Last test \(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = dataStore.lastError, !error.isEmpty {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if !dataStore.cars.isEmpty {
                    Picker("Vehicle", selection: $selectedCarID) {
                        ForEach(dataStore.cars) { car in
                            Text(car.name).tag(car.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedCarID) { _, newID in
                        Task {
                            await dataStore.refreshAll(
                                baseURL: connection.normalizedBaseURL,
                                token: connection.accessToken,
                                useProxyToken: connection.useProxyToken,
                                selectedCarID: newID
                            )
                        }
                    }
                }
            }

            Section("Dashboards") {
                NavigationLink("Overview Dashboard") { TeslaMateDashboardView(dataStore: dataStore) }
                NavigationLink("Activities & Stats") { TeslaMateActivityStatsView(dataStore: dataStore) }
                NavigationLink("Geofence Charging Costs") { TeslaMateGeofenceCostView(dataStore: dataStore) }
            }

            Section("Setup Wizard") {
                NavigationLink("Start TeslaMate Setup Wizard") { TeslaMateOnboardingWizardView() }
                Text("Not sure if you already have TeslaMate? The wizard will guide you.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Widgets & Live Activities") {
                NavigationLink("Charging Status Widgets") { TeslaMateWidgetsView() }
                Text("Widgets and Live Activities use your TeslaMate data to show charge status and cost in real time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Toggle("Enable Live Activities", isOn: $liveActivitiesEnabled)
                    .onChange(of: liveActivitiesEnabled) { _, enabled in
                        if !enabled {
                            Task { await TeslaMateLiveActivityManager.shared.end() }
                        }
                    }

                Button("Preview Live Activity") {
                    Task {
                        await TeslaMateLiveActivityManager.shared.startOrUpdate(
                            vehicleName: "Tesla Model 3",
                            batteryLevel: 64,
                            chargingState: "Charging",
                            energyAddedKWh: 12.4,
                            cost: 3.86
                        )
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .listStyle(.insetGrouped)
        .overlay(alignment: .bottom) {
            if showSavedToast {
                Text("TeslaMate connection saved")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeInOut(duration: 0.2)) { showSavedToast = false }
                        }
                    }
            }
        }
    }
}

@MainActor
private struct TeslaMateDashboardView: View {
    @StateObject private var connection = TeslaMateConnectionStore.shared
    @ObservedObject var dataStore: TeslaMateDataStore
    @AppStorage("teslamate.selected_car_id") private var selectedCarID: Int = -1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(
                    title: "Dashboard",
                    subtitle: "Summary metrics, charging overview, efficiency, and costs."
                )

                if !connection.isConfigured {
                    emptyState(
                        title: "Connect TeslaMate to See Live Data",
                        detail: "Add your TeslaMate URL and API token to begin."
                    )
                } else {
                    if dataStore.cars.isEmpty {
                        placeholderCard("No vehicles found", "Check your API URL + token.")
                    } else {
                        ForEach(dataStore.cars) { car in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(car.name).font(.headline)
                                if let model = car.model {
                                    Text(model).font(.footnote).foregroundStyle(.secondary)
                                }
                                if let vin = car.vin {
                                    Text("VIN \(vin)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.thinMaterial)
                            )
                        }
                    }

                    if let status = dataStore.lastStatus?.object {
                        let battery = status["battery_level"]?.double
                        let charging = status["charging_state"]?.string
                        let range = status["rated_battery_range"]?.double ?? status["battery_range"]?.double

                        placeholderCard("Battery Level", battery.map { "\($0.rounded())%" } ?? "—")
                        placeholderCard("Charging State", charging ?? "—")
                        placeholderCard("Range", range.map { String(format: "%.1f", $0) } ?? "—")
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if connection.isConfigured {
                await dataStore.refreshAll(
                    baseURL: connection.normalizedBaseURL,
                    token: connection.accessToken,
                    useProxyToken: connection.useProxyToken,
                    selectedCarID: selectedCarID >= 0 ? selectedCarID : nil
                )
            }
        }
    }
}

@MainActor
private struct TeslaMateActivityStatsView: View {
    @StateObject private var connection = TeslaMateConnectionStore.shared
    @ObservedObject var dataStore: TeslaMateDataStore
    @AppStorage("teslamate.selected_car_id") private var selectedCarID: Int = -1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(
                    title: "Activities & Stats",
                    subtitle: "Trips, charging sessions, idle time, and weekly/monthly summaries."
                )

                if !connection.isConfigured {
                    emptyState(
                        title: "Connect TeslaMate to See Activities",
                        detail: "Add your TeslaMate URL and API token to begin."
                    )
                } else {
                    if dataStore.drives.isEmpty {
                        placeholderCard("Trips", "No trips in the last 30 days")
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recent Trips").font(.headline)
                            ForEach(dataStore.drives.prefix(10)) { drive in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(drive.startedAt ?? "Start —")
                                            .font(.footnote.weight(.semibold))
                                        Text(drive.endedAt ?? "End —")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(drive.distance.map { String(format: "%.1f", $0) } ?? "—")
                                        .font(.footnote.weight(.semibold))
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(.thinMaterial)
                                )
                            }
                        }
                    }

                    if dataStore.charges.isEmpty {
                        placeholderCard("Charging Sessions", "No charges in the last 30 days")
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recent Charges").font(.headline)
                            ForEach(dataStore.charges.prefix(10)) { charge in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(charge.startedAt ?? "Start —")
                                            .font(.footnote.weight(.semibold))
                                        Text(charge.location ?? "Unknown location")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(charge.energyKWh.map { String(format: "%.1f kWh", $0) } ?? "—")
                                        .font(.footnote.weight(.semibold))
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(.thinMaterial)
                                )
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Activities & Stats")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if connection.isConfigured {
                await dataStore.refreshAll(
                    baseURL: connection.normalizedBaseURL,
                    token: connection.accessToken,
                    useProxyToken: connection.useProxyToken,
                    selectedCarID: selectedCarID >= 0 ? selectedCarID : nil
                )
            }
        }
    }
}

@MainActor
private struct TeslaMateGeofenceCostView: View {
    @StateObject private var connection = TeslaMateConnectionStore.shared
    @ObservedObject var dataStore: TeslaMateDataStore
    @AppStorage("teslamate.selected_car_id") private var selectedCarID: Int = -1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(
                    title: "Geofence Charging Costs",
                    subtitle: "Breakdown by home, work, and other geofenced locations."
                )

                if !connection.isConfigured {
                    emptyState(
                        title: "Connect TeslaMate to See Costs",
                        detail: "Add your TeslaMate URL and API token to begin."
                    )
                } else {
                    let grouped = Dictionary(grouping: dataStore.charges) { $0.location ?? "Unknown" }
                    if grouped.isEmpty {
                        placeholderCard("No charging data", "Connect TeslaMate or expand date range.")
                    } else {
                        ForEach(grouped.keys.sorted(), id: \.self) { key in
                            let charges = grouped[key] ?? []
                            let totalKWh = charges.compactMap(\.energyKWh).reduce(0, +)
                            let totalCost = charges.compactMap(\.cost).reduce(0, +)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(key).font(.headline)
                                Text("\(String(format: "%.1f", totalKWh)) kWh")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text("$\(String(format: "%.2f", totalCost))")
                                    .font(.title3.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.thinMaterial)
                            )
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Geofence Costs")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if connection.isConfigured {
                await dataStore.refreshAll(
                    baseURL: connection.normalizedBaseURL,
                    token: connection.accessToken,
                    useProxyToken: connection.useProxyToken,
                    selectedCarID: selectedCarID >= 0 ? selectedCarID : nil
                )
            }
        }
    }
}

@MainActor
private struct TeslaMateWidgetsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(
                    title: "Widgets & Live Activities",
                    subtitle: "Show charging status and cost on your Home Screen and Lock Screen."
                )

                placeholderCard("Small Widget", "Charge status + cost")
                placeholderCard("Medium Widget", "Session details + ETA")
                placeholderCard("Live Activity", "Real-time charging progress")
            }
            .padding(16)
        }
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func header(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.title3.bold())
        Text(subtitle).font(.footnote).foregroundStyle(.secondary)
    }
}

private func placeholderCard(_ title: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(.headline)
        Text(value)
            .font(.title2.weight(.semibold))
        Text("Connect TeslaMate to populate this section.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.thinMaterial)
    )
}

private func emptyState(title: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.headline)
        Text(detail).font(.footnote).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.thinMaterial)
    )
}
