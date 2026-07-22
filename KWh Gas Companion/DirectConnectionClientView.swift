//
//  DirectConnectionClientView.swift
//  KWh Gas Companion
//
//  Direct-to-user dashboard connection shell.
//

import SwiftUI
import Foundation

@MainActor
final class DirectConnectionConfigStore: ObservableObject {
    static let shared = DirectConnectionConfigStore()

    @Published var baseURL = ""
    @Published var accessToken = ""
    @Published var useProxyToken = false
    @Published private(set) var lastSavedAt: Date? = nil

    private let baseURLKey = "direct_connection.base_url"
    private let tokenKey = "direct_connection.access_token"
    private let proxyKey = "direct_connection.use_proxy"
    private let savedAtKey = "direct_connection.saved_at"

    private init() {
        let defaults = UserDefaults.standard
        baseURL = defaults.string(forKey: baseURLKey) ?? ""
        accessToken = defaults.string(forKey: tokenKey) ?? ""
        useProxyToken = defaults.bool(forKey: proxyKey)
        if let saved = defaults.object(forKey: savedAtKey) as? Date {
            lastSavedAt = saved
        }
    }

    var isConfigured: Bool {
        !normalizedBaseURL.isEmpty && !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var normalizedBaseURL: String {
        baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
struct DirectConnectionClientView: View {
    @StateObject private var connection = DirectConnectionConfigStore.shared
    @StateObject private var dataStore = DirectConnectionDataStore()

    var body: some View {
        DirectConnectionHomeView(dataStore: dataStore)
            .navigationTitle("Direct Connection")
            .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
private struct DirectConnectionHomeView: View {
    @StateObject private var connection = DirectConnectionConfigStore.shared
    @EnvironmentObject private var importedSessionStore: TeslaFiSessionStore
    @ObservedObject var dataStore: DirectConnectionDataStore
    @State private var showSavedToast = false
    @State private var showImportToast = false
    @State private var lastRefreshAt: Date? = nil
    @AppStorage("direct_connection.live_activities.enabled") private var liveActivitiesEnabled = false
    @AppStorage("direct_connection.selected_car_id") private var selectedCarID: Int = -1
    @AppStorage("direct_connection.distance_unit") private var distanceUnit: String = "mi"

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TeslaMate connection")
                        .font(.headline)
                    Text("Connect to your self-hosted TeslaMate API, or a compatible proxy, to view vehicles, charges, drives, geofences, and live charging status.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Connection") {
                TextField("Base URL (for example: https://your-dashboard.example.com)", text: $connection.baseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                SecureField("Access token / API key", text: $connection.accessToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Toggle("Pass token in query string", isOn: $connection.useProxyToken)

                Picker("Distance unit", selection: $distanceUnit) {
                    Text("Miles").tag("mi")
                    Text("Kilometers").tag("km")
                }
                .pickerStyle(.segmented)

                HStack {
                    Button {
                        connection.save()
                        showSavedToast = true
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        connection.clear()
                    } label: {
                        Label("Clear", systemImage: "trash")
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
                        Text(dataStore.isLoading ? "Testing…" : "Test connection")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!connection.isConfigured || dataStore.isLoading)

                if let saved = connection.lastSavedAt {
                    Text("Saved \(saved.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let lastRefreshAt {
                    Text("Last test \(lastRefreshAt.formatted(date: .abbreviated, time: .shortened))")
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
                NavigationLink("Overview Dashboard") { DirectConnectionDashboardView(dataStore: dataStore) }
                NavigationLink("Activities & Stats") { DirectConnectionActivityStatsView(dataStore: dataStore) }
                NavigationLink("Geofence Charging Costs") { DirectConnectionGeofenceCostView(dataStore: dataStore) }
            }

            Section("Import to charging history") {
                Button {
                    dataStore.importFetchedCharges(into: importedSessionStore)
                    showImportToast = true
                } label: {
                    Label("Import fetched TeslaMate charges", systemImage: "tray.and.arrow.down.fill")
                }
                .disabled(dataStore.charges.isEmpty)

                Text(dataStore.charges.isEmpty ? "Fetch TeslaMate charges first, then import them into the app’s charging analytics." : "Imports \(dataStore.charges.count) fetched TeslaMate charge rows into the existing imported-session history with duplicate skipping.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("TeslaMate mobile features") {
                Label("Drive history with distance, energy, cost, efficiency, and savings fields when your endpoint provides them.", systemImage: "road.lanes")
                Label("Charging history with charge rates, energy added, costs, and geofence grouping.", systemImage: "bolt.car")
                Label("Widgets and Live Activities can use TeslaMate status data from your connected endpoint.", systemImage: "bolt.badge.clock")
                Label("Your token is stored on this device and sent only to the endpoint you configure.", systemImage: "lock.shield")
            }
            .font(.footnote)

            Section("Setup") {
                NavigationLink("Open TeslaMate Setup Guide") { DirectConnectionSetupWizardView() }
                Text("Use the setup guide if you need help with TeslaMate, TeslaMateApi, a compatible dashboard API, or a hosted proxy flow.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Widgets & Live Activities") {
                NavigationLink("Charging Status Widgets") { DirectConnectionWidgetsView() }
                Text("Widgets and Live Activities use your connected dashboard data to show charge status and cost in real time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Toggle("Enable Live Activities", isOn: $liveActivitiesEnabled)
                    .onChange(of: liveActivitiesEnabled) { _, enabled in
                        if !enabled {
                            Task { await ChargeLiveActivityManager.shared.end() }
                        }
                    }

                Button("Preview Live Activity") {
                    Task {
                        await ChargeLiveActivityManager.shared.startOrUpdate(
                            vehicleName: "Current Vehicle",
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
                Text("Connection saved")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showSavedToast = false
                            }
                        }
                    }
            }

            if showImportToast {
                Text("Imported \(dataStore.lastImportedCount) TeslaMate charges")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showImportToast = false
                            }
                        }
                    }
            }
        }
    }
}

@MainActor
private struct DirectConnectionDashboardView: View {
    @StateObject private var connection = DirectConnectionConfigStore.shared
    @ObservedObject var dataStore: DirectConnectionDataStore
    @AppStorage("direct_connection.selected_car_id") private var selectedCarID: Int = -1
    @AppStorage("direct_connection.distance_unit") private var distanceUnit: String = "mi"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                directConnectionHeader(
                    title: "Dashboard",
                    subtitle: "TeslaMate summary metrics, charging overview, efficiency, and costs."
                )

                if !connection.isConfigured {
                    directConnectionEmptyState(
                        title: "Connect TeslaMate to see live data",
                        detail: "Add your endpoint URL and API token to begin."
                    )
                } else {
                    if dataStore.cars.isEmpty {
                        directConnectionPlaceholderCard("No vehicles found", "Check your API URL and token.")
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
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.thinMaterial))
                        }
                    }

                    if let status = dataStore.lastStatus?.object {
                        let battery = status["battery_level"]?.double
                        let charging = status["charging_state"]?.string
                        let range = status["rated_battery_range"]?.double ?? status["battery_range"]?.double
                        let vehicleState = status["state"]?.string ?? status["vehicle_state"]?.string
                        let locked = status["locked"]?.bool ?? status["df"]?.bool.map { !$0 }
                        let sentry = status["sentry_mode"]?.bool ?? status["sentry_mode_available"]?.bool
                        let climate = status["is_climate_on"]?.bool ?? status["climate_on"]?.bool
                        let software = status["car_version"]?.string ?? status["software_version"]?.string
                        let chargeLimit = status["charge_limit_soc"]?.double ?? status["charge_limit"]?.double
                        let usableBattery = status["usable_battery_level"]?.double ?? status["usable_battery"]?.double
                        let idealRange = status["ideal_battery_range"]?.double
                        let tpms = [
                            status["tpms_pressure_fl"]?.double,
                            status["tpms_pressure_fr"]?.double,
                            status["tpms_pressure_rl"]?.double,
                            status["tpms_pressure_rr"]?.double
                        ].compactMap { $0 }

                        directConnectionPlaceholderCard("Battery Level", battery.map { "\($0.rounded())%" } ?? "—")
                        directConnectionPlaceholderCard("Charging State", charging ?? "—")
                        directConnectionPlaceholderCard("Range", range.map { formatDistance($0, unit: distanceUnit) } ?? "—")

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Live Vehicle Status")
                                .font(.headline)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                directConnectionMetricCard("State", vehicleState ?? "Unknown")
                                directConnectionMetricCard("Locked", locked.map { $0 ? "Yes" : "No" } ?? "Unknown")
                                directConnectionMetricCard("Sentry", sentry.map { $0 ? "On" : "Off" } ?? "Unknown")
                                directConnectionMetricCard("Climate", climate.map { $0 ? "On" : "Off" } ?? "Unknown")
                                directConnectionMetricCard("Charge limit", chargeLimit.map { "\(Int($0))%" } ?? "Unknown")
                                directConnectionMetricCard("Usable battery", usableBattery.map { "\(Int($0))%" } ?? "Unknown")
                                directConnectionMetricCard("Ideal range", idealRange.map { formatDistance($0, unit: distanceUnit) } ?? "Unknown")
                                directConnectionMetricCard("Software", software ?? "Unknown")
                            }

                            if !tpms.isEmpty {
                                directConnectionPlaceholderCard(
                                    "Tire Pressure",
                                    tpms.map { String(format: "%.1f", $0) }.joined(separator: " / ")
                                )
                            }
                        }
                    }

                    let totalDistance = dataStore.drives.compactMap(\.distance).reduce(0, +)
                    let totalDriveEnergy = dataStore.drives.compactMap(\.energyKWh).reduce(0, +)
                    let totalDriveCost = dataStore.drives.compactMap(\.cost).reduce(0, +)
                    let totalGasSavings = dataStore.drives.compactMap(\.gasSavings).reduce(0, +)
                    let totalChargeEnergy = dataStore.charges.compactMap(\.energyKWh).reduce(0, +)
                    let totalChargeCost = dataStore.charges.compactMap(\.cost).reduce(0, +)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        directConnectionMetricCard("Trips", "\(dataStore.drives.count)")
                        directConnectionMetricCard("Distance", formatDistance(totalDistance, unit: distanceUnit))
                        directConnectionMetricCard("Drive energy", String(format: "%.1f kWh", totalDriveEnergy))
                        directConnectionMetricCard("Drive cost", formatCurrency(totalDriveCost))
                        directConnectionMetricCard("Gas savings", formatCurrency(totalGasSavings))
                        directConnectionMetricCard("Charging", "\(dataStore.charges.count)")
                        directConnectionMetricCard("Energy added", String(format: "%.1f kWh", totalChargeEnergy))
                        directConnectionMetricCard("Charge cost", formatCurrency(totalChargeCost))
                    }

                    let maxChargePower = dataStore.charges.compactMap(\.powerKW).max()
                    let batteryGain = dataStore.charges.compactMap { charge -> Double? in
                        guard let start = charge.startBatteryLevel, let end = charge.endBatteryLevel else { return nil }
                        return max(0, end - start)
                    }.reduce(0, +)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Battery & Charge Health")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            directConnectionMetricCard("Peak charge power", maxChargePower.map { String(format: "%.0f kW", $0) } ?? "Unknown")
                            directConnectionMetricCard("Battery gained", batteryGain > 0 ? "\(Int(batteryGain))%" : "Unknown")
                            directConnectionMetricCard("Battery trend", "Ready for history")
                            directConnectionMetricCard("Data source", "TeslaMate API")
                        }
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
private struct DirectConnectionActivityStatsView: View {
    @StateObject private var connection = DirectConnectionConfigStore.shared
    @ObservedObject var dataStore: DirectConnectionDataStore
    @AppStorage("direct_connection.selected_car_id") private var selectedCarID: Int = -1
    @AppStorage("direct_connection.distance_unit") private var distanceUnit: String = "mi"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                directConnectionHeader(
                    title: "Activities & Stats",
                    subtitle: "TeslaMate trips, charging sessions, idle time, and rolling summaries."
                )

                if !connection.isConfigured {
                    directConnectionEmptyState(
                        title: "Connect TeslaMate to see activities",
                        detail: "Add your endpoint URL and API token to begin."
                    )
                } else {
                    if dataStore.drives.isEmpty {
                        directConnectionPlaceholderCard("Trips", "No trips in the last 30 days")
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
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(drive.distance.map { formatDistance($0, unit: distanceUnit) } ?? "—")
                                            .font(.footnote.weight(.semibold))
                                        Text(drive.efficiencyWhPerMile.map { String(format: "%.0f Wh/mi", $0) } ?? drive.energyKWh.map { String(format: "%.1f kWh", $0) } ?? "")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.thinMaterial))
                            }
                        }
                    }

                    if dataStore.charges.isEmpty {
                        directConnectionPlaceholderCard("Charging Sessions", "No charges in the last 30 days")
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
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(charge.energyKWh.map { String(format: "%.1f kWh", $0) } ?? "—")
                                            .font(.footnote.weight(.semibold))
                                        Text(chargeDetailText(charge))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.thinMaterial))
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
private struct DirectConnectionGeofenceCostView: View {
    @StateObject private var connection = DirectConnectionConfigStore.shared
    @ObservedObject var dataStore: DirectConnectionDataStore
    @AppStorage("direct_connection.selected_car_id") private var selectedCarID: Int = -1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                directConnectionHeader(
                    title: "Geofence Charging Costs",
                    subtitle: "TeslaMate breakdown by home, work, and other saved geofences."
                )

                if !connection.isConfigured {
                    directConnectionEmptyState(
                        title: "Connect a dashboard to see costs",
                        detail: "Add your endpoint URL and API token to begin."
                    )
                } else {
                    let grouped = Dictionary(grouping: dataStore.charges) { $0.location ?? "Unknown" }
                    if grouped.isEmpty {
                        directConnectionPlaceholderCard("No charging data", "Connect a dashboard or expand the date range.")
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
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.thinMaterial))
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
private struct DirectConnectionWidgetsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                directConnectionHeader(
                    title: "Widgets & Live Activities",
                    subtitle: "Show TeslaMate charging status and cost on your Home Screen and Lock Screen."
                )

                directConnectionPlaceholderCard("Small Widget", "Charge status and cost")
                directConnectionPlaceholderCard("Medium Widget", "Session details and ETA")
                directConnectionPlaceholderCard("Live Activity", "Real-time charging progress")
            }
            .padding(16)
        }
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func directConnectionHeader(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.title3.bold())
        Text(subtitle).font(.footnote).foregroundStyle(.secondary)
    }
}

private func directConnectionPlaceholderCard(_ title: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(.headline)
        Text(value)
            .font(.title2.weight(.semibold))
        Text("Connect a compatible dashboard to populate this section.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.thinMaterial))
}

private func directConnectionMetricCard(_ title: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
        Text(value)
            .font(.headline.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.thinMaterial))
}

private func formatDistance(_ miles: Double, unit: String) -> String {
    if unit == "km" {
        return String(format: "%.1f km", miles * 1.60934)
    }
    return String(format: "%.1f mi", miles)
}

private func formatCurrency(_ value: Double) -> String {
    value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
}

private func chargeRateText(_ charge: DirectConnectionDataStore.ChargeSummary) -> String {
    guard let cost = charge.cost, let energy = charge.energyKWh, energy > 0 else { return "" }
    return String(format: "$%.2f/kWh", cost / energy)
}

private func chargeDetailText(_ charge: DirectConnectionDataStore.ChargeSummary) -> String {
    var parts: [String] = []
    if let cost = charge.cost {
        parts.append(formatCurrency(cost))
    } else {
        let rate = chargeRateText(charge)
        if !rate.isEmpty { parts.append(rate) }
    }
    if let power = charge.powerKW {
        parts.append(String(format: "%.0f kW", power))
    }
    if let start = charge.startBatteryLevel, let end = charge.endBatteryLevel {
        parts.append("\(Int(start))% to \(Int(end))%")
    }
    return parts.joined(separator: " · ")
}

private func directConnectionEmptyState(title: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.headline)
        Text(detail).font(.footnote).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.thinMaterial))
}
