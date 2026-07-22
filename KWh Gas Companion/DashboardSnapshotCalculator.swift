import Foundation

struct DashboardSnapshot {
    let entriesThisMonth: [ExpenseEntry]
    let energyEntries: [ExpenseEntry]
    let importedSessionsThisMonth: [TeslaFiSession]
    let spending: DashboardSpending
    let monthEnergyKWh: Double
    let monthEnergyCost: Double
    let averageCostPerKWh: Double?
    let missingImportedCostCount: Int
    let missingEntryCostCount: Int
    let dataQualityIssueCount: Int
    let trackedEnergyMonths: Int
    let latestCharge: DashboardLatestChargeSnapshot?
    let tripInsights: TripInsightsSnapshot

    /// Previous-month totals, used for month-over-month trend deltas.
    let previousMonthSpentTotal: Double
    let previousMonthEnergyKWh: Double

    static let empty = DashboardSnapshot(
        entriesThisMonth: [],
        energyEntries: [],
        importedSessionsThisMonth: [],
        spending: .zero,
        monthEnergyKWh: 0,
        monthEnergyCost: 0,
        averageCostPerKWh: nil,
        missingImportedCostCount: 0,
        missingEntryCostCount: 0,
        dataQualityIssueCount: 0,
        trackedEnergyMonths: 0,
        latestCharge: nil,
        tripInsights: .empty,
        previousMonthSpentTotal: 0,
        previousMonthEnergyKWh: 0
    )
}

struct DashboardSpending {
    let superchargingTeslaFi: Double
    let superchargingEntries: Double
    let lease: Double
    let insurance: Double
    let misc: Double

    static let zero = DashboardSpending(
        superchargingTeslaFi: 0,
        superchargingEntries: 0,
        lease: 0,
        insurance: 0,
        misc: 0
    )

    var superchargingTotal: Double { superchargingTeslaFi + superchargingEntries }
    var totalBuckets: Double { superchargingTotal + lease + insurance + misc }
    var hasPossibleOverlap: Bool { superchargingTeslaFi > 0 && superchargingEntries > 0 }
}

struct DashboardLatestChargeSnapshot: Equatable {
    let date: Date
    let title: String
    let subtitle: String
    let energyKWh: Double?
    let cost: Double?
    let endSOC: Double?
    let isFastCharge: Bool
}

enum DashboardSnapshotCalculator {
    static func make(
        entries: [ExpenseEntry],
        energyEntries: [ExpenseEntry],
        importedSessions: [TeslaFiSession],
        selectedVehicle: VehicleProfile?,
        includeImportedSessions: Bool,
        now: Date = .now
    ) -> DashboardSnapshot {
        let window = monthWindow(containing: now)
        let entriesThisMonth = entries
            .filter { window.contains($0.date) }
            .sorted { $0.date > $1.date }
        let energyEntriesThisMonth = entriesThisMonth.filter(\.isEnergyEffective)
        let sessions = includeImportedSessions
            ? importedSessions
                .filter { $0.startDate <= window.upperBound && $0.endDate >= window.lowerBound }
                .sorted { $0.startDate > $1.startDate }
            : []

        let energyKWh = energyEntriesThisMonth.reduce(0.0) { $0 + max(0, $1.energyAddedKWh ?? 0) }
        let energyCost = energyEntriesThisMonth.reduce(0.0) { $0 + max(0, $1.amount) }

        var superchargingEntries = 0.0
        var lease = 0.0
        var insurance = 0.0
        var misc = 0.0
        for entry in entriesThisMonth {
            switch DashboardEntryClassifier.bucket(for: entry) {
            case .supercharging: superchargingEntries += entry.amount
            case .lease: lease += entry.amount
            case .insurance: insurance += entry.amount
            case .misc: misc += entry.amount
            }
        }

        let superchargingImported = sessions
            .filter(DashboardEntryClassifier.isFastCharge)
            .compactMap(\.cost)
            .reduce(0.0, +)
        let quality = DataQualityAnalyzer.summarize(
            entries: energyEntries,
            sessions: includeImportedSessions ? importedSessions : []
        )

        // Previous-month totals for month-over-month trend deltas.
        let prevWindow = previousMonthWindow(before: now)
        let prevEntries = entries.filter { prevWindow.contains($0.date) }
        let prevSpentTotal = prevEntries.reduce(0.0) { $0 + max(0, $1.amount) }
        let prevEnergyKWh = prevEntries
            .filter(\.isEnergyEffective)
            .reduce(0.0) { $0 + max(0, $1.energyAddedKWh ?? 0) }

        return DashboardSnapshot(
            entriesThisMonth: entriesThisMonth,
            energyEntries: energyEntriesThisMonth,
            importedSessionsThisMonth: sessions,
            spending: DashboardSpending(
                superchargingTeslaFi: superchargingImported,
                superchargingEntries: superchargingEntries,
                lease: lease,
                insurance: insurance,
                misc: misc
            ),
            monthEnergyKWh: energyKWh,
            monthEnergyCost: energyCost,
            averageCostPerKWh: energyKWh > 0 && energyCost > 0 ? energyCost / energyKWh : nil,
            missingImportedCostCount: sessions.filter { $0.cost == nil }.count,
            missingEntryCostCount: energyEntriesThisMonth.filter { ($0.energyAddedKWh ?? 0) > 0 && $0.amount <= 0 }.count,
            dataQualityIssueCount: quality.costSpikes.count
                + quality.idleFeeRisk.count
                + quality.outliers.count
                + quality.duplicates.count,
            trackedEnergyMonths: trackedEnergyMonths(from: energyEntries),
            latestCharge: latestCharge(
                selectedVehicle: selectedVehicle,
                entries: entries,
                sessions: includeImportedSessions ? importedSessions : []
            ),
            tripInsights: TripInsightsSnapshot.build(from: sessions),
            previousMonthSpentTotal: prevSpentTotal,
            previousMonthEnergyKWh: prevEnergyKWh
        )
    }

    private static func monthWindow(containing date: Date) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let end = calendar.date(byAdding: DateComponents(month: 1), to: start)?
            .addingTimeInterval(-1) ?? date
        return start...end
    }

    private static func previousMonthWindow(before date: Date) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let startOfPrevMonth = calendar.date(byAdding: DateComponents(month: -1), to: startOfThisMonth) ?? date
        let endOfPrevMonth = startOfThisMonth.addingTimeInterval(-1)
        return startOfPrevMonth...endOfPrevMonth
    }

    private static func trackedEnergyMonths(from entries: [ExpenseEntry]) -> Int {
        let calendar = Calendar.current
        let months = Set(entries.filter(\.isEnergy).map { entry in
            calendar.date(from: calendar.dateComponents([.year, .month], from: entry.date)) ?? entry.date
        })
        return months.count
    }

    private static func latestCharge(
        selectedVehicle: VehicleProfile?,
        entries: [ExpenseEntry],
        sessions: [TeslaFiSession]
    ) -> DashboardLatestChargeSnapshot? {
        let energyEntries = entries.filter(\.isEnergyEffective)
        let matchedEntries = matchingEntries(energyEntries, for: selectedVehicle)
        let preferredEntries = matchedEntries.isEmpty ? energyEntries : matchedEntries

        if let entry = preferredEntries.max(by: { $0.date < $1.date }) {
            return DashboardLatestChargeSnapshot(
                date: entry.date,
                title: entry.location ?? entry.charging?.siteName ?? entry.category,
                subtitle: entry.energyAddedKWh.map { "\(formattedNumber($0)) kWh" } ?? "Saved entry",
                energyKWh: entry.energyAddedKWh,
                cost: entry.amount > 0 ? entry.amount : nil,
                endSOC: entry.charging?.endSOC ?? entry.stateOfCharge,
                isFastCharge: DashboardEntryClassifier.isFastCharge(entry)
            )
        }

        if let session = sessions.max(by: { $0.endDate < $1.endDate }) {
            return DashboardLatestChargeSnapshot(
                date: session.endDate,
                title: session.displayLocation,
                subtitle: "\(formattedNumber(session.energyAddedKWh)) kWh",
                energyKWh: session.energyAddedKWh,
                cost: session.cost,
                endSOC: nil,
                isFastCharge: DashboardEntryClassifier.isFastCharge(session)
            )
        }

        return nil
    }

    private static func matchingEntries(_ entries: [ExpenseEntry], for vehicle: VehicleProfile?) -> [ExpenseEntry] {
        guard let vehicle else { return entries }

        let vehicleVIN = normalized(vehicle.vin)
        let vehicleName = normalized(vehicle.displayName)
        return entries.filter { entry in
            if entry.vehicleID == vehicle.id { return true }
            let entryVIN = normalized(entry.vin ?? entry.charging?.vin)
            if !vehicleVIN.isEmpty, !entryVIN.isEmpty, entryVIN == vehicleVIN { return true }
            let entryName = normalized(entry.vehicleName ?? entry.charging?.vehicleName)
            return !vehicleName.isEmpty && !entryName.isEmpty && entryName == vehicleName
        }
    }

    private static func formattedNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private static func normalized(_ text: String?) -> String {
        (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum DashboardEntryClassifier {
    enum Bucket {
        case supercharging
        case lease
        case insurance
        case misc
    }

    static func bucket(for entry: ExpenseEntry) -> Bucket {
        if isFastCharge(entry) { return .supercharging }
        if isLeaseOrCarPayment(entry) { return .lease }
        if isInsurance(entry) { return .insurance }
        return .misc
    }

    static func isFastCharge(_ entry: ExpenseEntry) -> Bool {
        if entry.charging?.isSupercharger == true { return true }
        let category = normalized(entry.category)
        let type = normalized(entry.chargeType)
        let location = normalized(entry.location) + " " + normalized(entry.charging?.siteName)
        let notes = normalized(entry.notes)
        return type.contains("supercharg") || category.contains("supercharg") || location.contains("supercharg")
            || notes.contains("supercharg") || category.contains("dcfc") || category.contains("fast")
            || type.contains("dcfc") || type.contains("fast")
            || location.contains("electrify america") || location.contains("evgo") || location.contains("chargepoint")
    }

    static func isFastCharge(_ session: TeslaFiSession) -> Bool {
        let location = normalized(session.location) + " " + normalized(session.displayLocation)
        return location.contains("supercharg") || location.contains("super charger") || location.contains("dcfc")
            || location.contains("electrify america") || location.contains("evgo") || location.contains("chargepoint")
    }

    static func isLeaseOrCarPayment(_ entry: ExpenseEntry) -> Bool {
        if isFastCharge(entry) { return false }
        let category = normalized(entry.category)
        let notes = normalized(entry.notes)
        let location = normalized(entry.location)
        let categoryHit = category.contains("lease") || category.contains("car payment") || category.contains("auto payment")
            || category.contains("vehicle payment") || category.contains("auto loan") || category.contains("car loan")
            || category.contains("vehicle loan") || category.contains("finance") || category.contains("financing")
            || category.contains("lender") || category.contains("installment")
        let notesHit = notes.contains("lease") || notes.contains("car payment") || notes.contains("auto payment")
            || notes.contains("vehicle payment") || notes.contains("auto loan") || notes.contains("car loan")
            || notes.contains("vehicle loan") || notes.contains("finance") || notes.contains("financing")
            || notes.contains("lender") || notes.contains("installment")
        let locationHit = location.contains("toyota financial") || location.contains("tesla finance")
            || location.contains("honda financial") || location.contains("ford credit") || location.contains("gm financial")
            || location.contains("capital one auto") || location.contains("ally auto") || location.contains("santander")
            || location.contains("chase auto") || location.contains("wells fargo auto")
        return categoryHit || notesHit || locationHit
    }

    static func isInsurance(_ entry: ExpenseEntry) -> Bool {
        let category = normalized(entry.category)
        let notes = normalized(entry.notes)
        let location = normalized(entry.location)
        return category.contains("insurance") || notes.contains("insurance")
            || location.contains("geico") || location.contains("progressive")
            || location.contains("state farm") || location.contains("allstate")
    }

    private static func normalized(_ text: String?) -> String {
        (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
