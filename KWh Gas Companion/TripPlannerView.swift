//
//  TripPlannerView.swift
//  KWh Gas Companion
//
//  Refined Trip Planner UI (Swift 6 / iOS 17+)
//  - Map-first layout with a draggable bottom sheet (Apple Maps-ish)
//  - Route builder + via stops + settings in a segmented panel
//  - Search suggestions show as an overlay (no “layout jumping”)
//  - Via stops are reorderable with drag-and-drop
//  - Fixes: WaypointEntry manual Equatable (CLLocationCoordinate2D isn’t Equatable)
//

import SwiftUI
import MapKit
import CoreLocation
import UniformTypeIdentifiers

// MARK: - Waypoint model used in the view

private struct WaypointEntry: Identifiable, Equatable {
    let id: UUID
    var text: String
    var coord: CLLocationCoordinate2D?

    init(id: UUID = UUID(), text: String = "", coord: CLLocationCoordinate2D? = nil) {
        self.id = id
        self.text = text
        self.coord = coord
    }

    static func == (lhs: WaypointEntry, rhs: WaypointEntry) -> Bool {
        lhs.id == rhs.id &&
        lhs.text == rhs.text &&
        coordsEqual(lhs.coord, rhs.coord)
    }

    private static func coordsEqual(_ a: CLLocationCoordinate2D?, _ b: CLLocationCoordinate2D?) -> Bool {
        switch (a, b) {
        case (nil, nil):
            return true
        case (let x?, let y?):
            return abs(x.latitude - y.latitude) < 0.0000005 &&
                   abs(x.longitude - y.longitude) < 0.0000005
        default:
            return false
        }
    }
}

private enum PlannerTab: String, CaseIterable, Identifiable {
    case route = "Route"
    case settings = "Settings"
    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .route: return "arrow.triangle.turn.up.right.diamond"
        case .settings: return "slider.horizontal.3"
        }
    }
}

@MainActor
struct TripPlannerView: View {

    // THEME
    @Environment(\.appThemeBox) private var themeBox
    private var T: any AppThemeSpec { themeBox.base }

    // Engine
    @StateObject private var engine: TPTripPlannerEngine

    // Inputs (text + resolved coords)
    @State private var originText: String = ""
    @State private var destinationText: String = ""
    @State private var originCoord: CLLocationCoordinate2D?
    @State private var destinationCoord: CLLocationCoordinate2D?

    // Waypoints (ordered + identifiable)
    @State private var waypoints: [WaypointEntry] = []
    @State private var draggingWaypointID: UUID?

    // Vehicle / Environment
    @AppStorage("tp_vehicle_name") private var vehicleName: String = "Model Y LR"
    @AppStorage("tp_vehicle_kwh") private var vehicleKWh: Double = 75
    @AppStorage("tp_vehicle_baseline") private var baselineWhMi: Double = 280
    @AppStorage("tp_vehicle_maxdc") private var maxDCPowerKW: Double = 250
    @AppStorage("tp_arrival_buffer") private var arrivalBuffer: Double = 0.08
    @AppStorage("tp_depart_target") private var targetDepartSOC: Double = 0.70
    @AppStorage("tp_start_soc") private var startSOC: Double = 0.85

    @AppStorage("tp_temp_f") private var tempF: Double = 65
    @AppStorage("tp_speed") private var speedMPH: Double = 68
    @AppStorage("tp_wind") private var windDelta: Double = 0
    @AppStorage("tp_elevation_on") private var elevationOn: Bool = true
    @AppStorage("tp_corridor_m") private var corridorM: Double = 12_000

    // Map state
    @State private var mapPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var routePolyline: [CLLocationCoordinate2D] = []
    @State private var stopAnnotations: [TPChargingStop] = []
    @State private var selectedStop: TPChargingStop?

    // Panel state
    @State private var tab: PlannerTab = .route
    @State private var sheetHeight: CGFloat = 520
    @State private var sheetDragStartHeight: CGFloat?

    // UI state
    @State private var editMode: EditMode = .inactive
    @StateObject private var loc = LocationProvider()

    init() {
        let router = TPOpenRouterProvider()
        let chargers = TPOpenChargeMapProvider()
        _engine = StateObject(wrappedValue: TPTripPlannerEngine(router: router, chargers: chargers))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {

                // Theme background
                Rectangle()
                    .fill(T.screenBackground)
                    .ignoresSafeArea()

                // MARK: Map (primary)
                Map(position: $mapPosition, interactionModes: [.pan, .zoom, .rotate]) {

                    // Route polyline
                    if routePolyline.count >= 2 {
                        let mk = MKPolyline(coordinates: routePolyline, count: routePolyline.count)
                        MapPolyline(mk)
                            .stroke(T.accent, style: .init(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    }

                    // Origin / destination pins
                    if let o = originCoord {
                        Annotation("Origin", coordinate: o) {
                            SmallPin(title: "O", accent: .green)
                        }
                    }
                    if let d = destinationCoord {
                        Annotation("Destination", coordinate: d) {
                            SmallPin(title: "D", accent: .blue)
                        }
                    }

                    // Planned charging stops
                    ForEach(stopAnnotations) { stop in
                        Annotation(stop.charger.name, coordinate: stop.charger.coordinate) {
                            StopPin(stop: stop, accent: T.accent)
                                .onTapGesture { selectedStop = stop }
                        }
                    }
                }
                .ignoresSafeArea()
                .sheet(item: $selectedStop) { stop in
                    StopDetailSheet(stop: stop)
                }

                // MARK: Top bar
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.quaternary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, safeTopInset(geo) + 6)

                // MARK: Bottom sheet
                VStack(spacing: 0) {
                    Spacer()
                    bottomSheet(maxHeight: maxSheetHeight(geo))
                        .frame(height: sheetHeight)
                        .transition(.move(edge: .bottom))
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .environment(\.editMode, $editMode)
            .onAppear {
                let maxH = maxSheetHeight(geo)
                sheetHeight = min(max(520, maxH * 0.70), maxH)
            }
            .onReceive(engine.$lastPlan) { newPlan in
                guard let plan = newPlan else { return }
                routePolyline = plan.route.fullPolyline
                stopAnnotations = plan.stops

                if let region = regionToFit(routePolyline) {
                    mapPosition = .region(region)
                }
            }
            .alert(
                "Trip Planning Error",
                isPresented: Binding(
                    get: { engine.errorMessage != nil },
                    set: { newValue in
                        if newValue == false { engine.clearError() }
                    }
                ),
                actions: { Button("OK") { engine.clearError() } },
                message: { Text(engine.errorMessage ?? "") }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "map")
                    .font(.headline)
                    .foregroundStyle(T.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Trip Planner")
                        .font(.headline)
                    Text(statusLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            EditButton()
                .buttonStyle(.plain)
                .padding(.horizontal, 6)

            Menu {
                Button {
                    useUserLocationAsOrigin()
                } label: {
                    Label("Use Current Location as Origin", systemImage: "location.fill")
                }

                Button {
                    swapEnds()
                } label: {
                    Label("Swap Origin & Destination", systemImage: "arrow.left.arrow.right")
                }

                Button {
                    addWaypoint()
                    tab = .route
                } label: {
                    Label("Add Via Stop", systemImage: "plus")
                }

                Divider()

                Button(role: .destructive) {
                    resetAll()
                } label: {
                    Label("Reset Planner", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
    }

    private var statusLine: String {
        let o = originCoord != nil ? "Origin ✓" : "Origin…"
        let d = destinationCoord != nil ? "Dest ✓" : "Dest…"
        let s = stopAnnotations.isEmpty ? "" : " • \(stopAnnotations.count) stops"
        return "\(o) • \(d)\(s)"
    }

    // MARK: - Bottom sheet

    private func bottomSheet(maxHeight: CGFloat) -> some View {
        let minH: CGFloat = 170
        let maxH: CGFloat = max(380, maxHeight)

        return VStack(spacing: 0) {

            // Grabber
            Capsule()
                .fill(.secondary.opacity(0.35))
                .frame(width: 44, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 10)

            // Tabs
            Picker("", selection: $tab) {
                ForEach(PlannerTab.allCases) { t in
                    Label(t.rawValue, systemImage: t.systemImage).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            // Content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {

                    if tab == .route {
                        routeSection
                        if !waypoints.isEmpty { viaStopsSection }
                    } else {
                        settingsSection
                    }

                    if !stopAnnotations.isEmpty {
                        plannedStopsSection
                    }

                    Color.clear.frame(height: 6)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 16)
            }

            Divider()

            // CTA bar
            HStack(spacing: 12) {
                if engine.isPlanning {
                    ProgressView()
                }

                Button {
                    Task { await runPlan() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.car")
                        Text(engine.isPlanning ? "Planning…" : "Plan Trip")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(T.onAccent)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(T.accent, in: Capsule())
                }
                .disabled(engine.isPlanning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.quaternary)
        }
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: -2)
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { v in
                    if sheetDragStartHeight == nil { sheetDragStartHeight = sheetHeight }
                    let start = sheetDragStartHeight ?? sheetHeight
                    let proposed = start - v.translation.height
                    sheetHeight = clamp(proposed, minH, maxH)
                }
                .onEnded { v in
                    let start = sheetDragStartHeight ?? sheetHeight
                    sheetDragStartHeight = nil
                    let predicted = start - v.predictedEndTranslation.height
                    let mid = (minH + maxH) / 2
                    let target = predicted < mid ? minH : maxH
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        sheetHeight = target
                    }
                }
        )
    }

    // MARK: - Sections

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Route", systemImage: "point.topleft.down.to.point.bottomright.curvepath")

            RouteFieldRow(
                dotColor: .green,
                label: "Origin",
                placeholder: "Search origin",
                text: $originText,
                coordinate: $originCoord,
                regionHint: regionHint,
                trailing: AnyView(
                    Button {
                        useUserLocationAsOrigin()
                    } label: {
                        Label("GPS", systemImage: "location.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                )
            )

            RouteFieldRow(
                dotColor: .blue,
                label: "Destination",
                placeholder: "Search destination",
                text: $destinationText,
                coordinate: $destinationCoord,
                regionHint: regionHint,
                trailing: AnyView(
                    Button {
                        swapEnds()
                    } label: {
                        Label("Swap", systemImage: "arrow.left.arrow.right")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                )
            )

            HStack(spacing: 10) {
                Button {
                    addWaypoint()
                } label: {
                    Label("Add Via Stop", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(T.onAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(T.accent, in: Capsule())
                }
                .buttonStyle(.plain)

                if !waypoints.isEmpty {
                    Text(editMode == .active ? "Drag to reorder" : "Tap Edit to reorder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.top, 2)
        }
        .panelCard()
    }

    private var viaStopsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Via Stops", systemImage: "point.toplevel.leading.to.point.bottom.trailing.curvepath")

            VStack(spacing: 10) {
                ForEach($waypoints) { $wp in
                    ViaStopRow(
                        index: (waypoints.firstIndex(where: { $0.id == wp.id }) ?? 0) + 1,
                        waypoint: $wp,
                        regionHint: regionHint,
                        accent: T.accent,
                        onRemove: { removeWaypoint(id: wp.id) },
                        isEditing: (editMode == .active),
                        draggingID: $draggingWaypointID,
                        items: $waypoints
                    )
                }
            }
        }
        .panelCard()
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Settings", systemImage: "slider.horizontal.3")

            // Vehicle / Charging targets
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Vehicle")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(vehicleName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                TPKnobRow(title: "Battery", valueText: "\(Int(vehicleKWh)) kWh") {
                    Slider(value: $vehicleKWh, in: 30...150, step: 1)
                }
                TPKnobRow(title: "Baseline", valueText: "\(Int(baselineWhMi)) Wh/mi") {
                    Slider(value: $baselineWhMi, in: 180...450, step: 5)
                }
                TPKnobRow(title: "Max DC", valueText: "\(Int(maxDCPowerKW)) kW") {
                    Slider(value: $maxDCPowerKW, in: 50...350, step: 5)
                }

                Divider().opacity(0.5)

                TPKnobRow(title: "Start SOC", valueText: "\(Int(startSOC * 100))%") {
                    Slider(value: $startSOC, in: 0.10...1.0, step: 0.01)
                }
                TPKnobRow(title: "Arrive Buffer", valueText: "\(Int(arrivalBuffer * 100))%") {
                    Slider(value: $arrivalBuffer, in: 0.05...0.15, step: 0.005)
                }
                TPKnobRow(title: "Depart Target", valueText: "\(Int(targetDepartSOC * 100))%") {
                    Slider(value: $targetDepartSOC, in: 0.55...0.85, step: 0.01)
                }
            }
            .subpanelCard()

            // Conditions
            VStack(alignment: .leading, spacing: 12) {
                Text("Conditions")
                    .font(.subheadline.weight(.semibold))

                TPKnobRow(title: "Temperature", valueText: "\(Int(tempF)) °F") {
                    Slider(value: $tempF, in: 0...110, step: 1)
                }
                TPKnobRow(title: "Cruise Speed", valueText: "\(Int(speedMPH)) mph") {
                    Slider(value: $speedMPH, in: 45...85, step: 1)
                }
                TPKnobRow(title: "Wind Δ", valueText: "\(Int(windDelta)) mph") {
                    Slider(value: $windDelta, in: -25...25, step: 1)
                }

                Toggle(isOn: $elevationOn) {
                    Text("Consider elevation")
                        .font(.subheadline)
                }
                .tint(T.accent)

                TPKnobRow(title: "Search corridor", valueText: "\(Int(corridorM / 1000)) km") {
                    Slider(
                        value: Binding(get: { corridorM / 1000 }, set: { corridorM = $0 * 1000 }),
                        in: 2...30,
                        step: 1
                    )
                }
            }
            .subpanelCard()
        }
        .panelCard()
    }

    private var plannedStopsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Planned Stops", systemImage: "bolt.circle")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(stopAnnotations) { stop in
                        StopCard(stop: stop)
                            .onTapGesture { selectedStop = stop }
                    }
                }
                .padding(.vertical, 2)
            }

            Text("Tap a stop to see details.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .panelCard()
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(T.accent)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }

    private var regionHint: MKCoordinateRegion {
        if let c = loc.lastCoordinate {
            return MKCoordinateRegion(center: c, span: .init(latitudeDelta: 0.75, longitudeDelta: 0.75))
        }
        if let c = routePolyline.first {
            return MKCoordinateRegion(center: c, span: .init(latitudeDelta: 2.0, longitudeDelta: 2.0))
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39, longitude: -98),
            span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 120)
        )
    }

    private func resetAll() {
        originText = ""
        destinationText = ""
        originCoord = nil
        destinationCoord = nil
        waypoints.removeAll()
        engine.resetPlan()
        routePolyline.removeAll()
        stopAnnotations.removeAll()
        selectedStop = nil
    }

    private func addWaypoint() { waypoints.append(WaypointEntry()) }

    private func removeWaypoint(id: UUID) {
        waypoints.removeAll(where: { $0.id == id })
    }

    private func runPlan() async {
        // Resolve origin/destination if user typed but didn't pick a suggestion
        var o = originCoord
        var d = destinationCoord

        if o == nil, !originText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            o = await Geocoder.resolve(text: originText, region: regionHint)
        }
        if d == nil, !destinationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            d = await Geocoder.resolve(text: destinationText, region: regionHint)
        }

        guard let origin = o, let dest = d else {
            engine.setError("Pick an origin and destination by search, GPS, or suggestions.")
            return
        }

        // Resolve each waypoint’s coord if missing
        var resolvedStops: [CLLocationCoordinate2D] = []
        for wp in waypoints {
            if let c = wp.coord {
                resolvedStops.append(c)
            } else if !wp.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let c = await Geocoder.resolve(text: wp.text, region: regionHint) {
                resolvedStops.append(c)
            }
        }

        let vehicle = TPVehicleProfile(
            name: vehicleName,
            batteryKWh: vehicleKWh,
            baselineWhPerMile: baselineWhMi,
            maxDCPowerKW: maxDCPowerKW,
            arrivalBuffer: arrivalBuffer,
            targetDepartSOC: targetDepartSOC
        )

        let env = TPEnvironmentProfile(
            temperatureF: tempF,
            cruiseMPH: speedMPH,
            windDeltaMPH: windDelta,
            considerElevation: elevationOn
        )

        let req = TPTripRequest(
            origin: origin,
            destination: dest,
            startSOC: startSOC,
            vehicle: vehicle,
            env: env,
            corridorMeters: corridorM,
            waypoints: resolvedStops
        )

        await engine.plan(req)
    }

    private func useUserLocationAsOrigin() {
        loc.request()
        if let c = loc.lastCoordinate {
            originCoord = c
            originText = "Current Location"
            mapPosition = .region(MKCoordinateRegion(center: c, span: .init(latitudeDelta: 0.5, longitudeDelta: 0.5)))
        } else {
            engine.setError("Location not available yet—try again in a moment.")
        }
    }

    private func swapEnds() {
        (originText, destinationText) = (destinationText, originText)
        (originCoord, destinationCoord) = (destinationCoord, originCoord)
    }

    private func regionToFit(_ coords: [CLLocationCoordinate2D], padding: Double = 1.25) -> MKCoordinateRegion? {
        guard !coords.isEmpty else { return nil }

        var minLat = coords[0].latitude
        var maxLat = coords[0].latitude
        var minLon = coords[0].longitude
        var maxLon = coords[0].longitude

        for c in coords {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let latDelta = max((maxLat - minLat) * padding, 0.02)
        let lonDelta = max((maxLon - minLon) * padding, 0.02)

        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), hi) }

    private func safeTopInset(_ geo: GeometryProxy) -> CGFloat {
        (geo.safeAreaInsets.top == 0 ? 12 : geo.safeAreaInsets.top)
    }

    private func maxSheetHeight(_ geo: GeometryProxy) -> CGFloat {
        let h = geo.size.height
        let top = safeTopInset(geo)
        return max(420, min(h * 0.80, h - top - 40))
    }
}

// MARK: - UI building blocks

private struct RouteFieldRow: View {
    var dotColor: Color
    var label: String
    var placeholder: String
    @Binding var text: String
    @Binding var coordinate: CLLocationCoordinate2D?
    var regionHint: MKCoordinateRegion
    var trailing: AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle().fill(dotColor).frame(width: 9, height: 9)
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if coordinate != nil {
                    Label("Picked", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                PlaceSearchField(
                    placeholder: placeholder,
                    text: $text,
                    coordinate: $coordinate,
                    regionHint: regionHint
                )
                trailing
            }
        }
    }
}

private struct SmallPin: View {
    let title: String
    let accent: Color
    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.white)
            .frame(width: 28, height: 28)
            .background(accent, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
            .shadow(radius: 6, y: 3)
    }
}

private struct StopPin: View {
    let stop: TPChargingStop
    let accent: Color

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: "bolt.circle.fill")
                .font(.title2)
                .foregroundStyle(accent)
            Text("\(Int(stop.charger.maxPowerKW))kW")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.quaternary) }
        .contentShape(Rectangle())
    }
}

private struct TPKnobRow<Content: View>: View {
    let title: String
    let valueText: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(valueText).font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
            content
        }
    }
}

private extension View {
    func panelCard() -> some View {
        self
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.quaternary) }
    }

    func subpanelCard() -> some View {
        self
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.quaternary) }
    }
}

// MARK: - Via stop row with drag-to-reorder (DropDelegate)

private struct ViaStopRow: View {
    let index: Int
    @Binding var waypoint: WaypointEntry
    var regionHint: MKCoordinateRegion
    var accent: Color
    var onRemove: () -> Void
    var isEditing: Bool

    @Binding var draggingID: UUID?
    @Binding var items: [WaypointEntry]

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(accent.opacity(0.15)).frame(width: 30, height: 30)
                Text("\(index)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(accent)
            }

            PlaceSearchField(
                placeholder: "Stop \(index)",
                text: $waypoint.text,
                coordinate: $waypoint.coord,
                regionHint: regionHint
            )

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)

            if isEditing {
                Image(systemName: "line.3.horizontal")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.quaternary) }
        .onDrag {
            draggingID = waypoint.id
            return NSItemProvider(object: waypoint.id.uuidString as NSString)
        }
        .onDrop(of: [UTType.text], delegate: WaypointDropDelegate(
            item: waypoint,
            items: $items,
            draggingID: $draggingID
        ))
    }
}

private struct WaypointDropDelegate: DropDelegate {
    let item: WaypointEntry
    @Binding var items: [WaypointEntry]
    @Binding var draggingID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              draggingID != item.id,
              let from = items.firstIndex(where: { $0.id == draggingID }),
              let to = items.firstIndex(where: { $0.id == item.id })
        else { return }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            let moved = items.remove(at: from)
            items.insert(moved, at: to)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Stop UI

private struct StopCard: View {
    let stop: TPChargingStop
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stop.charger.name).font(.subheadline.bold()).lineLimit(1)
            Text("\(Int(stop.charger.maxPowerKW)) kW • \(stop.charger.network.rawValue.capitalized)")
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            HStack {
                Label("\(Int(stop.arriveSOC * 100))% → \(Int(stop.departSOC * 100))%",
                      systemImage: "gauge.with.dots.needle.bottom.50percent")
                Label("\(Int(stop.chargeSeconds / 60)) min", systemImage: "clock")
            }
            .font(.caption2)
        }
        .padding(10)
        .frame(width: 240, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.quaternary) }
    }
}

private struct StopDetailSheet: View {
    let stop: TPChargingStop
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(stop.charger.name).font(.title2.bold())
            Text("\(Int(stop.charger.maxPowerKW)) kW • \(stop.charger.network.rawValue.capitalized)")
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                Label("Arrive \(Int(stop.arriveSOC * 100))%", systemImage: "arrow.down.circle")
                Label("Depart \(Int(stop.departSOC * 100))%", systemImage: "arrow.up.circle")
                Label("\(Int(stop.chargeSeconds / 60)) min", systemImage: "clock")
            }
            .font(.subheadline)

            if let price = stop.charger.priceNote, !price.isEmpty {
                Text(price).font(.footnote)
            }

            Spacer()
        }
        .padding()
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Search & Geocoding helpers

@MainActor
enum Geocoder {
    static func resolve(text: String, region: MKCoordinateRegion) async -> CLLocationCoordinate2D? {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = text
        req.region = region
        do {
            let resp = try await MKLocalSearch(request: req).start()
            if let c = resp.mapItems.first?.placemark.location?.coordinate { return c }
        } catch { }
        return nil
    }
}

/// Overlay-style suggestions (does NOT change layout height)
struct PlaceSearchField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var coordinate: CLLocationCoordinate2D?
    var regionHint: MKCoordinateRegion

    @State private var suggestions: [MKLocalSearchCompletion] = []
    @State private var completer = MKLocalSearchCompleter()
    @State private var delegate: CompleterDelegate? = nil
    @State private var showList = false
    @State private var applyingSelection = false

    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextField(placeholder, text: $text)
                .focused($focused)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text) { _, newValue in
                    guard applyingSelection == false else { return }
                    coordinate = nil
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    completer.queryFragment = trimmed
                    showList = focused && !trimmed.isEmpty
                }
                .onChange(of: focused) { _, isFocused in
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    showList = isFocused && !trimmed.isEmpty && !suggestions.isEmpty
                }
                .onAppear {
                    completer.resultTypes = [.address, .pointOfInterest]
                    completer.region = regionHint
                    let d = CompleterDelegate { results in
                        self.suggestions = results
                        let trimmed = self.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.showList = self.focused && !trimmed.isEmpty && !results.isEmpty
                    }
                    delegate = d
                    completer.delegate = d
                }

            if showList && !suggestions.isEmpty {
                VStack(spacing: 0) {
                    let shown = Array(suggestions.prefix(6).enumerated())
                    ForEach(shown, id: \.offset) { idx, comp in
                        Button {
                            select(completion: comp)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(comp.title).font(.subheadline)
                                if !comp.subtitle.isEmpty {
                                    Text(comp.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)

                        if idx < shown.count - 1 { Divider() }
                    }
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.quaternary) }
                .offset(y: 44)
                .zIndex(999)
            }
        }
    }

    private func select(completion: MKLocalSearchCompletion) {
        let req = MKLocalSearch.Request(completion: completion)
        Task {
            let search = MKLocalSearch(request: req)
            if let item = try? await search.start().mapItems.first,
               let coord = item.placemark.location?.coordinate {
                await MainActor.run {
                    applyingSelection = true
                    text = item.name ?? completion.title
                    coordinate = coord
                    showList = false
                    completer.queryFragment = ""
                    focused = false
                    applyingSelection = false
                }
            }
        }
    }
}

fileprivate final class CompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    let onUpdate: ([MKLocalSearchCompletion]) -> Void
    init(onUpdate: @escaping ([MKLocalSearchCompletion]) -> Void) { self.onUpdate = onUpdate }
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) { onUpdate(completer.results) }
}

// MARK: - Minimal location helper for the GPS button

final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastCoordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastCoordinate = locations.last?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // ignore; the view shows a friendly message if needed
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TripPlannerView()
    }
}
#endif
