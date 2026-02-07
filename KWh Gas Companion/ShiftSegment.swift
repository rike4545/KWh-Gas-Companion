//  ShiftSegment.swift
//  KWh Gas Companion
//
//  Groups TeslaFi trips into time-of-day "shifts" per calendar day.
//  Depends on a single, project-wide TeslaFiTrip (see TeslaFiTrip.swift).

import Foundation

// MARK: - Shift Definition

public struct ShiftDefinition: Identifiable, Equatable, Codable {
    public let id: UUID
    public let name: String
    /// Start time (hour/minute, 24h)
    public let startHour: Int
    public let startMinute: Int
    /// End time (hour/minute, 24h)
    public let endHour: Int
    public let endMinute: Int

    public init(
        id: UUID = UUID(),
        name: String,
        startHour: Int, startMinute: Int = 0,
        endHour: Int, endMinute: Int = 0
    ) {
        self.id = id
        self.name = name
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }

    /// Returns true if the interval crosses midnight (e.g., 22:00 -> 05:00).
    public var wrapsMidnight: Bool {
        endTotalMinutes <= startTotalMinutes
    }

    public var startTotalMinutes: Int { startHour * 60 + startMinute }
    public var endTotalMinutes: Int { endHour * 60 + endMinute }

    /// Whether `date`'s wall-clock time falls inside this shift.
    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let mins = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        if wrapsMidnight {
            // Example: 22:00–05:00  ⇒  mins >= 22:00  OR  mins < 05:00
            return mins >= startTotalMinutes || mins < endTotalMinutes
        } else {
            // Example: 05:00–12:00 ⇒  05:00 <= mins < 12:00
            return mins >= startTotalMinutes && mins < endTotalMinutes
        }
    }

    /// The "owning" day for a timestamp in this shift.
    /// For midnight-wrapping shifts, early-morning times (before `end`) are attached to the *previous* day if `attachWrappedToPreviousDay` is true.
    public func owningDay(
        for date: Date,
        calendar: Calendar = .current,
        attachWrappedToPreviousDay: Bool = true
    ) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        guard wrapsMidnight, attachWrappedToPreviousDay else { return startOfDay }

        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let mins = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        if mins < endTotalMinutes {
            // e.g., 00:30 belongs to yesterday's 22:00–05:00 shift
            return calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
        }
        return startOfDay
    }
}

public extension ShiftDefinition {
    static let morning   = ShiftDefinition(name: "Morning",   startHour: 5,  endHour: 12)
    static let afternoon = ShiftDefinition(name: "Afternoon", startHour: 12, endHour: 17)
    static let evening   = ShiftDefinition(name: "Evening",   startHour: 17, endHour: 22)
    static let night     = ShiftDefinition(name: "Night",     startHour: 22, endHour: 5) // wraps
    static let `default`: [ShiftDefinition] = [.morning, .afternoon, .evening, .night]
}

// MARK: - Shift Segment

public struct ShiftSegment: Identifiable, Equatable, Codable {
    public let id: UUID
    /// Start-of-day (Calendar.current by default when built)
    public let day: Date
    /// Index of the shift in the provided definitions (if known)
    public let shiftIndex: Int?
    /// Human-friendly shift name
    public let shiftName: String
    /// Trips belonging to this day+shift, sorted ascending by time
    public private(set) var trips: [TeslaFiTrip]

    // MARK: Aggregates

    public var startOdometer: Double? { trips.compactMap { $0.odometer }.min() }
    public var endOdometer: Double?   { trips.compactMap { $0.odometer }.max() }

    /// Distance as end - start when available and non-negative
    public var distance: Double? {
        guard let s = startOdometer, let e = endOdometer, e >= s else { return nil }
        return e - s
    }

    /// Sum of kWh across trips
    public var totalEnergyKWh: Double {
        trips.compactMap { $0.energyKWh }.reduce(0, +)
    }

    public var tripCount: Int { trips.count }

    // MARK: Init

    public init(
        id: UUID = UUID(),
        day: Date,
        shiftIndex: Int?,
        shiftName: String,
        trips: [TeslaFiTrip]
    ) {
        self.id = id
        self.day = day
        self.shiftIndex = shiftIndex
        self.shiftName = shiftName
        self.trips = trips.sorted(by: { $0.date < $1.date })
    }

    // MARK: Mutation

    public mutating func append(_ trip: TeslaFiTrip) {
        trips.append(trip)
        trips.sort(by: { $0.date < $1.date })
    }

    public mutating func append(contentsOf newTrips: [TeslaFiTrip]) {
        guard !newTrips.isEmpty else { return }
        trips.append(contentsOf: newTrips)
        trips.sort(by: { $0.date < $1.date })
    }
}

// MARK: - Builders

public enum ShiftSegmentation {
    /// Build day+shift segments from trips using provided shift definitions.
    public static func build(
        from trips: [TeslaFiTrip],
        shifts: [ShiftDefinition] = ShiftDefinition.default,
        calendar: Calendar = .current,
        attachWrappedToPreviousDay: Bool = true
    ) -> [ShiftSegment] {
        guard !trips.isEmpty else { return [] }

        // (day, shiftIndex) -> [trips]
        var buckets: [BucketKey: [TeslaFiTrip]] = [:]

        for t in trips {
            let (idx, def) = matchShift(for: t.date, in: shifts, calendar: calendar)
            let owningDay = def?.owningDay(for: t.date, calendar: calendar, attachWrappedToPreviousDay: attachWrappedToPreviousDay)
                        ?? calendar.startOfDay(for: t.date)
            let key = BucketKey(day: owningDay, shiftIndex: idx)
            buckets[key, default: []].append(t)
        }

        var segments: [ShiftSegment] = []
        for (key, ts) in buckets {
            let name = key.shiftIndex.flatMap { i in shifts.indices.contains(i) ? shifts[i].name : nil } ?? "Unassigned"
            segments.append(
                ShiftSegment(day: key.day, shiftIndex: key.shiftIndex, shiftName: name, trips: ts)
            )
        }

        // Sort newest day first, then by shift index (or name) for stability
        segments.sort {
            if $0.day != $1.day { return $0.day > $1.day }
            switch ($0.shiftIndex, $1.shiftIndex) {
            case let (l?, r?): return l < r
            case (_?, nil):    return true
            case (nil, _?):    return false
            default:           return $0.shiftName < $1.shiftName
            }
        }
        return segments
    }

    /// Merge new trips into existing segments, creating segments as needed.
    public static func merge(
        existing: [ShiftSegment],
        with newTrips: [TeslaFiTrip],
        shifts: [ShiftDefinition] = ShiftDefinition.default,
        calendar: Calendar = .current,
        attachWrappedToPreviousDay: Bool = true
    ) -> [ShiftSegment] {
        guard !newTrips.isEmpty else { return existing }
        if existing.isEmpty { return build(from: newTrips, shifts: shifts, calendar: calendar, attachWrappedToPreviousDay: attachWrappedToPreviousDay) }

        var index: [BucketKey: ShiftSegment] = Dictionary(
            uniqueKeysWithValues: existing.map { (BucketKey(day: $0.day, shiftIndex: $0.shiftIndex), $0) }
        )

        for t in newTrips {
            let (idx, def) = matchShift(for: t.date, in: shifts, calendar: calendar)
            let owningDay = def?.owningDay(for: t.date, calendar: calendar, attachWrappedToPreviousDay: attachWrappedToPreviousDay)
                        ?? calendar.startOfDay(for: t.date)
            let key = BucketKey(day: owningDay, shiftIndex: idx)
            if var seg = index[key] {
                seg.append(t)
                index[key] = seg
            } else {
                let name = idx.flatMap { i in shifts.indices.contains(i) ? shifts[i].name : nil } ?? "Unassigned"
                index[key] = ShiftSegment(day: owningDay, shiftIndex: idx, shiftName: name, trips: [t])
            }
        }

        var merged = Array(index.values)
        merged.sort {
            if $0.day != $1.day { return $0.day > $1.day }
            switch ($0.shiftIndex, $1.shiftIndex) {
            case let (l?, r?): return l < r
            case (_?, nil):    return true
            case (nil, _?):    return false
            default:           return $0.shiftName < $1.shiftName
            }
        }
        return merged
    }

    // MARK: Helpers

    private static func matchShift(
        for date: Date,
        in shifts: [ShiftDefinition],
        calendar: Calendar
    ) -> (Int?, ShiftDefinition?) {
        for (i, def) in shifts.enumerated() where def.contains(date, calendar: calendar) {
            return (i, def)
        }
        return (nil, nil)
    }

    fileprivate struct BucketKey: Hashable {
        let day: Date
        let shiftIndex: Int?
        func hash(into hasher: inout Hasher) {
            hasher.combine(day.timeIntervalSince1970)
            hasher.combine(shiftIndex ?? -1)
        }
        static func == (lhs: BucketKey, rhs: BucketKey) -> Bool {
            lhs.day == rhs.day && lhs.shiftIndex == rhs.shiftIndex
        }
    }
}
