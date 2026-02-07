//
//  ServiceRemindersView.swift
//  MyKwH Companion
//
//  Smarter, data-driven service reminders for Tesla & Rivian.
//  - Brand picker (persisted) + brand tint
//  - Tasks with mile/month intervals, environment adjustments
//  - Per-task history (last miles/date) persisted locally
//  - Status chips: Overdue / Due soon / OK
//  - Search + "Due soon only" filter
//  - Add to Calendar via EventKitUI
//  - Official resources links
//

import SwiftUI
import EventKit
import EventKitUI

// MARK: - Model

private enum Brand: String, CaseIterable, Identifiable, Codable {
    case tesla = "Tesla"
    case rivian = "Rivian"
    var id: String { rawValue }
}

private struct ServiceTask: Identifiable, Hashable, Codable {
    enum Kind: String, Codable { case rotation, filter, hepa, brakeFluid, desiccant, caliperCare, coolant, driveUnitFluid, alignment, cameraClean, configReset, hvBattery, multipoint, generic }
    let id: String                // stable key (brand|title)
    let brand: Brand
    let title: String
    let details: String
    let kind: Kind
    let mileInterval: Int?
    let monthInterval: Int?
    let symbol: String
    let adjustsForSaltedRoads: Bool
    let adjustsForHeavyUse: Bool

    init(brand: Brand, title: String, details: String, kind: Kind, mileInterval: Int?, monthInterval: Int?, symbol: String, adjustsForSaltedRoads: Bool = false, adjustsForHeavyUse: Bool = false) {
        self.brand = brand
        self.title = title
        self.details = details
        self.kind = kind
        self.mileInterval = mileInterval
        self.monthInterval = monthInterval
        self.symbol = symbol
        self.adjustsForSaltedRoads = adjustsForSaltedRoads
        self.adjustsForHeavyUse = adjustsForHeavyUse
        self.id = "\(brand.rawValue)|\(title)"
    }
}

private enum ServiceStatus { case ok, dueSoon, overdue }

private struct ServiceHistory: Codable, Equatable {
    var lastMiles: Int?
    var lastDate: Date?
}

private struct ServiceEnv: Codable, Equatable {
    var currentOdometer: Int?
    var saltedRoads: Bool
    var heavyUse: Bool
}

// MARK: - Persistence (UserDefaults-backed store)

private final class HistoryStore: ObservableObject {
    private let key = "ServiceHistoryStore_v1"
    @Published private(set) var dict: [String: ServiceHistory] = [:]

    init() {
        load()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: ServiceHistory].self, from: data) {
            dict = decoded
        } else {
            dict = [:]
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func history(for task: ServiceTask) -> ServiceHistory {
        dict[task.id] ?? ServiceHistory(lastMiles: nil, lastDate: nil)
    }

    func setHistory(_ history: ServiceHistory, for task: ServiceTask) {
        dict[task.id] = history
        save()
    }
}

// MARK: - Shared logic

fileprivate func adjustedIntervals(for task: ServiceTask, env: ServiceEnv) -> (miles: Int?, months: Int?) {
    var mi = task.mileInterval
    var mo = task.monthInterval
    if env.saltedRoads && task.adjustsForSaltedRoads {
        mi = mi.map { max(1000, Int(Double($0) * 0.85)) }
        mo = mo.map { max(6, Int(Double($0) * 0.85)) }
    }
    if env.heavyUse && task.adjustsForHeavyUse {
        mi = mi.map { max(1000, Int(Double($0) * 0.80)) }
        mo = mo.map { max(6, Int(Double($0) * 0.80)) }
    }
    return (mi, mo)
}

fileprivate func nextDueStatus(task: ServiceTask, history: ServiceHistory, env: ServiceEnv, now: Date = Date()) -> (ServiceStatus, String, Date?) {
    let intervals = adjustedIntervals(for: task, env: env)
    var flags: [ServiceStatus] = []
    var nextDate: Date? = nil

    if let intMiles = intervals.miles, let current = env.currentOdometer, let last = history.lastMiles {
        let delta = max(0, current - last)
        let remain = intMiles - delta
        if remain <= 0 { flags.append(.overdue) }
        else if remain <= max(500, intMiles / 10) { flags.append(.dueSoon) }
        else { flags.append(.ok) }
    }

    if let intMonths = intervals.months, let lastDate = history.lastDate {
        nextDate = Calendar.current.date(byAdding: .month, value: intMonths, to: lastDate)
        let months = Calendar.current.dateComponents([.month], from: lastDate, to: now).month ?? 0
        let remain = intMonths - max(0, months)
        if remain <= 0 { flags.append(.overdue) }
        else if remain <= max(1, intMonths / 10) { flags.append(.dueSoon) }
        else { flags.append(.ok) }
    }

    let status: ServiceStatus = flags.contains(.overdue) ? .overdue : (flags.contains(.dueSoon) ? .dueSoon : .ok)

    var parts: [String] = []
    if let intMiles = intervals.miles, let current = env.currentOdometer, let last = history.lastMiles {
        let remain = intMiles - max(0, current - last)
        let milesStr = remain <= 0 ? "now" : formattedMiles(remain)
        parts.append("Miles: \(milesStr)")
    }
    if let next = nextDate {
        parts.append("By: \(dateMedium(next))")
    }
    return (status, parts.isEmpty ? "See details" : parts.joined(separator: " • "), nextDate)
}

fileprivate func formattedMiles(_ miles: Int) -> String {
    if Locale.current.measurementSystem == .metric {
        let km = Double(miles) * 1.60934
        let mf = MeasurementFormatter()
        mf.unitOptions = .providedUnit
        mf.numberFormatter.maximumFractionDigits = 0
        return mf.string(from: Measurement(value: km, unit: UnitLength.kilometers))
    } else {
        let mf = MeasurementFormatter()
        mf.unitOptions = .providedUnit
        mf.numberFormatter.maximumFractionDigits = 0
        return mf.string(from: Measurement(value: Double(miles), unit: UnitLength.miles))
    }
}

fileprivate func dateMedium(_ d: Date) -> String {
    let df = DateFormatter(); df.dateStyle = .medium; return df.string(from: d)
}

fileprivate func parseInt(_ text: String) -> Int? {
    let digits = text.filter { $0.isNumber }
    return Int(digits)
}

// MARK: - View

struct ServiceRemindersView: View {
    @AppStorage("ServicePreferredBrand") private var preferredBrandRaw: String = Brand.tesla.rawValue
    @State private var selectedBrand: Brand = .tesla

    @AppStorage("ServiceEnv_SaltedRoads") private var saltedRoads: Bool = false
    @AppStorage("ServiceEnv_HeavyUse") private var heavyUse: Bool = false
    @AppStorage("ServiceEnv_CurrentOdometer") private var currentOdometerString: String = ""

    @State private var searchText: String = ""
    @State private var showDueSoonOnly: Bool = false
    @State private var editingTask: ServiceTask?
    @State private var showCalendarEditor: CalendarEditPayload?

    @StateObject private var historyStore = HistoryStore()
    @StateObject private var adsStore = AdsEntitlementStore.shared

    var body: some View {
        NavigationStack {
            List {
                // Brand + environment
                Section {
                    Picker("Brand", selection: $selectedBrand) {
                        ForEach(Brand.allCases) { b in
                            Text(b.rawValue).tag(b)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(brandTint)

                    HStack {
                        Text("Odometer")
                        Spacer()
                        TextField("e.g. 38,250", text: $currentOdometerString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 160)
                    }

                    Toggle("Salted winter roads", isOn: $saltedRoads)
                    Toggle("Frequent off-road / towing", isOn: $heavyUse)
                }

                // At-a-glance
                if !filteredTasks.isEmpty {
                    Section("At-a-glance") {
                        ForEach(Array(filteredTasks.prefix(3))) { task in
                            TaskRow(task: task,
                                    history: historyStore.history(for: task),
                                    env: currentEnv,
                                    addToCalendar: { date in
                                        showCalendarEditor = CalendarEditPayload(title: task.title, notes: task.details, due: date)
                                    },
                                    edit: { editingTask = task })
                        }
                    }
                }

                // All tasks
                Section("Tasks") {
                    ForEach(filteredTasks) { task in
                        TaskRow(task: task,
                                history: historyStore.history(for: task),
                                env: currentEnv,
                                addToCalendar: { date in
                                    showCalendarEditor = CalendarEditPayload(title: task.title, notes: task.details, due: date)
                                },
                                edit: { editingTask = task })
                    }
                    .animation(.default, value: searchText)
                    .animation(.default, value: showDueSoonOnly)
                }

                // Official links
                Section("Official resources") {
                    ForEach(officialLinks(for: selectedBrand), id: \.0) { item in
                        Link(destination: item.1) {
                            Label(item.0, systemImage: "link")
                        }
                    }
                    Text("Always defer to your vehicle’s on-screen prompts and the official documentation. This screen is informational only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !adsStore.hasRemovedAds {
                    Section {
                        AdBannerCard(adsStore: adsStore)
                    }
                }
            }
            .navigationTitle("Service Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle(isOn: $showDueSoonOnly) {
                            Label("Due soon only", systemImage: "flag.badge.waveform.fill")
                        }
                        Button {
                            preferredBrandRaw = selectedBrand.rawValue
                        } label: {
                            Label("Set as default brand", systemImage: "star")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More actions")
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: Text("Search tasks"))
            .onAppear {
                if let b = Brand(rawValue: preferredBrandRaw) { selectedBrand = b }
            }
            .task { await adsStore.load() }
            .sheet(item: $editingTask) { task in
                EditHistorySheet(task: task,
                                 history: historyStore.history(for: task),
                                 env: currentEnv,
                                 onSave: { newHist in
                                     historyStore.setHistory(newHist, for: task)
                                 })
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $showCalendarEditor) { payload in
                EVServiceCalendarEditor(payload: payload)
            }
        }
    }

    // MARK: Derived

    private var brandTint: Color {
        switch selectedBrand {
        case .tesla:  return Color(red: 0.85, green: 0.08, blue: 0.10)
        case .rivian: return Color(red: 0.18, green: 0.45, blue: 0.28)
        }
    }

    private var currentEnv: ServiceEnv {
        ServiceEnv(currentOdometer: parseInt(currentOdometerString),
                   saltedRoads: saltedRoads,
                   heavyUse: heavyUse)
    }

    private var tasks: [ServiceTask] {
        switch selectedBrand {
        case .tesla:  return teslaTasks
        case .rivian: return rivianTasks
        }
    }

    // Explicit loops to avoid Predicate<ServiceTask> inference pitfalls
    private var filteredTasks: [ServiceTask] {
        var list = tasks

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            var tmp: [ServiceTask] = []
            for t in list {
                if t.title.lowercased().contains(q) || t.details.lowercased().contains(q) {
                    tmp.append(t)
                }
            }
            list = tmp
        }

        if showDueSoonOnly {
            var tmp: [ServiceTask] = []
            for t in list {
                let (status, _, _) = nextDueStatus(task: t,
                                                   history: historyStore.history(for: t),
                                                   env: currentEnv)
                if status == .dueSoon || status == .overdue {
                    tmp.append(t)
                }
            }
            list = tmp
        }

        return list
    }

    // MARK: Catalogs

    private func officialLinks(for brand: Brand) -> [(String, URL)] {
        switch brand {
        case .tesla:
            return [
                ("Tesla Support", URL(string: "https://www.tesla.com/support")!),
                ("Owner’s Manual (web)", URL(string: "https://www.tesla.com/ownersmanual")!)
            ]
        case .rivian:
            return [
                ("Rivian Support", URL(string: "https://rivian.com/support")!),
                ("Owner’s Guide (web)", URL(string: "https://rivian.com/support/owners-guide")!)
            ]
        }
    }

    private var teslaTasks: [ServiceTask] {
        [
            ServiceTask(brand: .tesla,
                        title: "Cabin Air Filter",
                        details: "Replace based on on-screen guidance; typical: Model 3/Y every 2 yrs, S/X every 3 yrs. Cybertruck: varies.",
                        kind: .filter, mileInterval: nil, monthInterval: 24,
                        symbol: "wind", adjustsForSaltedRoads: false, adjustsForHeavyUse: true),
            ServiceTask(brand: .tesla,
                        title: "HEPA/Carbon Filter",
                        details: "If equipped: replace every 3 yrs (Cybertruck: ~2 yrs, or more often with heavy off-road/dust).",
                        kind: .hepa, mileInterval: nil, monthInterval: 36,
                        symbol: "aqi.medium", adjustsForSaltedRoads: false, adjustsForHeavyUse: true),
            ServiceTask(brand: .tesla,
                        title: "Tire Rotation",
                        details: "Rotate every 6,250 mi or when tread diff ≥ 2/32\".",
                        kind: .rotation, mileInterval: 6250, monthInterval: nil,
                        symbol: "arrow.triangle.2.circlepath", adjustsForSaltedRoads: false, adjustsForHeavyUse: true),
            ServiceTask(brand: .tesla,
                        title: "Wheel Balance & Alignment",
                        details: "As needed: vibrations, uneven wear, after tire changes or curb strikes.",
                        kind: .alignment, mileInterval: nil, monthInterval: nil,
                        symbol: "steeringwheel", adjustsForSaltedRoads: false, adjustsForHeavyUse: false),
            ServiceTask(brand: .tesla,
                        title: "Brake Fluid Test",
                        details: "Test every 4 yrs; more often with heavy braking or mountain use.",
                        kind: .brakeFluid, mileInterval: nil, monthInterval: 48,
                        symbol: "drop.fill", adjustsForSaltedRoads: false, adjustsForHeavyUse: true),
            ServiceTask(brand: .tesla,
                        title: "A/C Desiccant",
                        details: "Replace per on-screen guidance; Cybertruck ~8 yrs typical.",
                        kind: .desiccant, mileInterval: nil, monthInterval: 96,
                        symbol: "snowflake", adjustsForSaltedRoads: false, adjustsForHeavyUse: false),
            ServiceTask(brand: .tesla,
                        title: "Windshield Camera Area",
                        details: "Clean inside camera area as needed when prompted.",
                        kind: .cameraClean, mileInterval: nil, monthInterval: nil,
                        symbol: "camera.metering.center.weighted", adjustsForSaltedRoads: false, adjustsForHeavyUse: false),
            ServiceTask(brand: .tesla,
                        title: "Caliper Clean & Lube (winter)",
                        details: "In salted environments, clean/lube brake calipers annually or ~12,500 mi.",
                        kind: .caliperCare, mileInterval: 12500, monthInterval: 12,
                        symbol: "wrench.adjustable", adjustsForSaltedRoads: true, adjustsForHeavyUse: false),
            ServiceTask(brand: .tesla,
                        title: "Wheel/Tire Config Reset",
                        details: "After tire/wheel changes: Controls → Service → Wheel & Tire.",
                        kind: .configReset, mileInterval: nil, monthInterval: nil,
                        symbol: "gearshape", adjustsForSaltedRoads: false, adjustsForHeavyUse: false),
            ServiceTask(brand: .tesla,
                        title: "High-Voltage Battery",
                        details: "Follow on-screen prompts; service by trained technicians only.",
                        kind: .hvBattery, mileInterval: nil, monthInterval: nil,
                        symbol: "bolt.batteryblock", adjustsForSaltedRoads: false, adjustsForHeavyUse: false),
        ]
    }

    private var rivianTasks: [ServiceTask] {
        [
            ServiceTask(brand: .rivian,
                        title: "Tire Rotation & Multi-Point Inspection",
                        details: "Rotate all 4 wheels (rearward cross). Inspect pressures, tread, brakes, suspension, windows, fluids, wipers.",
                        kind: .rotation, mileInterval: 7500, monthInterval: nil,
                        symbol: "arrow.triangle.2.circlepath", adjustsForSaltedRoads: false, adjustsForHeavyUse: true),
            ServiceTask(brand: .rivian,
                        title: "Brake Fluid Flush",
                        details: "Replace hydraulic fluid; bleed all 4 calipers.",
                        kind: .brakeFluid, mileInterval: nil, monthInterval: 36,
                        symbol: "drop.fill", adjustsForSaltedRoads: false, adjustsForHeavyUse: true),
            ServiceTask(brand: .rivian,
                        title: "Coolant Change",
                        details: "Drain/refill using vacuum procedure.",
                        kind: .coolant, mileInterval: 112_500, monthInterval: nil,
                        symbol: "thermometer.snowflake", adjustsForSaltedRoads: false, adjustsForHeavyUse: false),
            ServiceTask(brand: .rivian,
                        title: "Drive Unit Fluid (Quad-Motor 2022–2024)",
                        details: "Change at ~112,500 mi. Not required for Dual-Motor AWD or 2025+.",
                        kind: .driveUnitFluid, mileInterval: 112_500, monthInterval: nil,
                        symbol: "gearshape.2.fill", adjustsForSaltedRoads: false, adjustsForHeavyUse: false),
            ServiceTask(brand: .rivian,
                        title: "Multi-Point Inspection",
                        details: "General inspection of critical systems; bundled with tire rotation in most services.",
                        kind: .multipoint, mileInterval: 7500, monthInterval: nil,
                        symbol: "checkmark.seal", adjustsForSaltedRoads: false, adjustsForHeavyUse: false),
        ]
    }
}

// MARK: - Row

private struct TaskRow: View {
    let task: ServiceTask
    let history: ServiceHistory
    let env: ServiceEnv
    let addToCalendar: (Date) -> Void
    let edit: () -> Void

    var body: some View {
        let info = nextDueStatus(task: task, history: history, env: env)
        HStack(spacing: 12) {
            Image(systemName: task.symbol).frame(width: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title).font(.body.weight(.semibold))
                Text(info.1).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            ServiceDueChip(status: info.0)
            if let date = info.2 {
                Button {
                    addToCalendar(date)
                } label: {
                    Image(systemName: "calendar.badge.plus")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Add to Calendar")
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .imageScale(.small)
        }
        .contentShape(Rectangle())
        .onTapGesture { edit() }
    }
}

// MARK: - Edit Sheet

private struct EditHistorySheet: View {
    let task: ServiceTask
    @State var history: ServiceHistory
    let env: ServiceEnv
    var onSave: (ServiceHistory) -> Void

    @State private var milesText: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: task.symbol).frame(width: 24)
                        Text(task.title).font(.headline)
                    }
                    Text(task.details).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Last done") {
                    HStack {
                        Text("Odometer")
                        Spacer()
                        TextField("e.g. 32,500", text: $milesText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 180)
                    }
                    DatePicker("Date", selection: Binding(get: {
                        history.lastDate ?? Date()
                    }, set: {
                        history.lastDate = $0
                    }), displayedComponents: .date)
                }

                if (task.mileInterval ?? 0) > 0 || (task.monthInterval ?? 0) > 0 {
                    Section("Next due (est.)") {
                        let (_, hint, _) = nextDueStatus(task: task, history: history, env: env)
                        Label(hint, systemImage: "clock.arrow.circlepath")
                    }
                }
            }
            .navigationTitle("Edit Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        history.lastMiles = parseInt(milesText)
                        onSave(history)
                        dismiss()
                    }
                }
            }
            .onAppear {
                milesText = history.lastMiles.map { "\($0)" } ?? ""
            }
        }
    }
}

// MARK: - Status Chip

private struct ServiceDueChip: View {
    let status: ServiceStatus
    var body: some View {
        let bg: Color = {
            switch status {
            case .ok: return .green.opacity(0.18)
            case .dueSoon: return .orange.opacity(0.18)
            case .overdue: return .red.opacity(0.18)
            }
        }()
        let fg: Color = {
            switch status {
            case .ok: return .green
            case .dueSoon: return .orange
            case .overdue: return .red
            }
        }()
        return Text(label)
            .font(.caption.bold())
            .foregroundStyle(fg)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(bg, in: Capsule())
            .accessibilityLabel("Status: \(label)")
    }

    private var label: String {
        switch status {
        case .ok: return "OK"
        case .dueSoon: return "Due soon"
        case .overdue: return "Overdue"
        }
    }
}

// MARK: - Calendar Integration

private struct CalendarEditPayload: Identifiable {
    let id = UUID()
    let title: String
    let notes: String?
    let due: Date
}

private struct EVServiceCalendarEditor: UIViewControllerRepresentable {
    let payload: CalendarEditPayload

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let vc = EKEventEditViewController()
        vc.eventStore = store
        vc.editViewDelegate = context.coordinator

        store.requestFullAccessToEvents { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    let event = EKEvent(eventStore: store)
                    event.title = payload.title
                    event.notes = payload.notes
                    event.startDate = payload.due
                    event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: payload.due) ?? payload.due
                    event.calendar = store.defaultCalendarForNewEvents
                    vc.event = event
                }
            }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ServiceRemindersView_Previews: PreviewProvider {
    static var previews: some View {
        ServiceRemindersView()
    }
}
#endif
