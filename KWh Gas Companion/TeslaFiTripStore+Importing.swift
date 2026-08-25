import Foundation

struct TeslaFiRawTripImportReport: Sendable {
    let filename: String
    let insertedCount: Int
    let rowCount: Int
    let stationaryRowCount: Int
    let movementRowCount: Int
    let skippedDuplicates: Int
}

enum TeslaFiRawTripImportError: LocalizedError {
    case unreadableText
    case empty

    var errorDescription: String? {
        switch self {
        case .unreadableText:
            return "Could not read TeslaFi raw CSV text."
        case .empty:
            return "TeslaFi raw CSV appears empty."
        }
    }
}

extension TeslaFiTripStore {
    static func parseTeslaFiRawTripCSV(
        from url: URL,
        existing: [TeslaFiTrip] = []
    ) throws -> ([TeslaFiTrip], TeslaFiRawTripImportReport) {
        let data = try Data(contentsOf: url)
        return try parseTeslaFiRawTripCSV(
            data: data,
            filenameHint: url.lastPathComponent,
            existing: existing
        )
    }

    static func parseTeslaFiRawTripCSV(
        data: Data,
        filenameHint: String? = nil,
        existing: [TeslaFiTrip] = []
    ) throws -> ([TeslaFiTrip], TeslaFiRawTripImportReport) {
        guard let text = decodedTeslaFiRawCSVText(from: data) else {
            throw TeslaFiRawTripImportError.unreadableText
        }

        let decoder = CSVDecoder()
        let rows = try decoder.decodeRows(from: text)
        guard !rows.isEmpty else { throw TeslaFiRawTripImportError.empty }

        let parsed = rows.compactMap { TeslaFiRawLogRow(csv: $0) }
        let derivedTrips = TeslaFiRawTripDeriver.deriveTrips(from: parsed)

        var newTrips: [TeslaFiTrip] = []
        var skippedDuplicates = 0
        let existingKeys = Set(existing.map(Self.rawTripDedupKey))

        for trip in derivedTrips {
            let key = rawTripDedupKey(trip)
            if existingKeys.contains(key) || newTrips.contains(where: { rawTripDedupKey($0) == key }) {
                skippedDuplicates += 1
            } else {
                newTrips.append(trip)
            }
        }

        let report = TeslaFiRawTripImportReport(
            filename: filenameHint ?? "TeslaFi Raw CSV",
            insertedCount: newTrips.count,
            rowCount: parsed.count,
            stationaryRowCount: parsed.count - parsed.filter(\.isMoving).count,
            movementRowCount: parsed.filter(\.isMoving).count,
            skippedDuplicates: skippedDuplicates
        )

        return (newTrips, report)
    }

    private static func rawTripDedupKey(_ trip: TeslaFiTrip) -> String {
        let start = Int(trip.startDate.timeIntervalSince1970)
        let end = Int(trip.endDate.timeIntervalSince1970)
        let startOdo = trip.startOdometer.map { String(format: "%.1f", $0) } ?? "_"
        let endOdo = trip.endOdometer.map { String(format: "%.1f", $0) } ?? "_"
        return [String(start), String(end), startOdo, endOdo].joined(separator: "|")
    }
}

private struct TeslaFiRawLogRow {
    let timestamp: Date
    let odometer: Double?
    let batteryLevel: Double?
    let latitude: Double?
    let longitude: Double?
    let speedMPH: Double?
    let shiftState: String?
    let outsideTempC: Double?
    let elevationFt: Double?

    init?(csv row: CSVRow) {
        guard let timestamp = CSVParse.date(row.string("Date")) else { return nil }
        self.timestamp = timestamp
        self.odometer = row.double("odometer")
        self.batteryLevel = row.double("battery_level")
        self.latitude = row.double("latitude")
        self.longitude = row.double("longitude")
        self.speedMPH = row.double("speed")
        self.shiftState = row.string("shift_state")
        self.outsideTempC = row.double("outside_temp")
        self.elevationFt = row.double("elevation")
    }

    var isMoving: Bool {
        if let speedMPH, speedMPH > 0.5 { return true }
        guard let shift = shiftState?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return false }
        return !(shift.isEmpty || shift == "none" || shift == "p" || shift == "park")
    }

    var locationString: String? {
        guard let latitude, let longitude else { return nil }
        return String(format: "%.6f, %.6f", latitude, longitude)
    }
}

private enum TeslaFiRawTripDeriver {
    private static let maxGapSeconds: TimeInterval = 10 * 60

    static func deriveTrips(from rows: [TeslaFiRawLogRow]) -> [TeslaFiTrip] {
        let sorted = rows.sorted { $0.timestamp < $1.timestamp }
        guard !sorted.isEmpty else { return [] }

        var trips: [TeslaFiTrip] = []
        var currentRows: [TeslaFiRawLogRow] = []
        var previousRow: TeslaFiRawLogRow?
        var pendingTerminalRow: TeslaFiRawLogRow?

        for row in sorted {
            defer { previousRow = row }

            if row.isMoving {
                if currentRows.isEmpty {
                    if let previousRow,
                       row.timestamp.timeIntervalSince(previousRow.timestamp) <= maxGapSeconds {
                        currentRows.append(previousRow)
                    }
                    currentRows.append(row)
                    pendingTerminalRow = nil
                    continue
                }

                if let last = currentRows.last,
                   row.timestamp.timeIntervalSince(last.timestamp) > maxGapSeconds {
                    if let trip = makeTrip(from: currentRows, terminal: pendingTerminalRow) {
                        trips.append(trip)
                    }
                    currentRows.removeAll(keepingCapacity: true)
                    if let previousRow,
                       row.timestamp.timeIntervalSince(previousRow.timestamp) <= maxGapSeconds {
                        currentRows.append(previousRow)
                    }
                }

                currentRows.append(row)
                pendingTerminalRow = nil
            } else if !currentRows.isEmpty {
                if let last = currentRows.last,
                   row.timestamp.timeIntervalSince(last.timestamp) <= maxGapSeconds {
                    pendingTerminalRow = row
                }
                if let trip = makeTrip(from: currentRows, terminal: pendingTerminalRow) {
                    trips.append(trip)
                }
                currentRows.removeAll(keepingCapacity: true)
                pendingTerminalRow = nil
            }
        }

        if let trip = makeTrip(from: currentRows, terminal: pendingTerminalRow) {
            trips.append(trip)
        }

        return trips
    }

    private static func makeTrip(from drivingRows: [TeslaFiRawLogRow], terminal: TeslaFiRawLogRow?) -> TeslaFiTrip? {
        let movingRows = drivingRows.filter(\.isMoving)
        guard let first = movingRows.first, let lastMoving = movingRows.last else { return nil }
        let last = terminal ?? lastMoving

        let speeds = movingRows.compactMap(\.speedMPH).filter { $0 > 0 }
        let averageSpeed = speeds.isEmpty ? nil : speeds.reduce(0, +) / Double(speeds.count)

        return TeslaFiTrip(
            date: first.timestamp,
            odometer: first.odometer,
            location: first.locationString,
            energyKWh: nil,
            endDate: last.timestamp,
            endOdometer: last.odometer ?? lastMoving.odometer,
            endLocation: last.locationString ?? lastMoving.locationString,
            startBatteryLevel: first.batteryLevel,
            endBatteryLevel: last.batteryLevel ?? lastMoving.batteryLevel,
            averageSpeedMPH: averageSpeed,
            maxSpeedMPH: speeds.max(),
            outsideTempC: first.outsideTempC ?? last.outsideTempC,
            elevationFt: last.elevationFt ?? first.elevationFt
        )
    }
}

private func decodedTeslaFiRawCSVText(from data: Data) -> String? {
    String(data: data, encoding: .utf8)
        ?? String(data: data, encoding: .utf16)
        ?? String(data: data, encoding: .utf16LittleEndian)
        ?? String(data: data, encoding: .utf16BigEndian)
        ?? String(data: data, encoding: .ascii)
}
