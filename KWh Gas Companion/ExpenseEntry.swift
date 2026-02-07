//
//  ExpenseEntry.swift
//  My KWh Companion
//
//  Unified model with nested ChargingDetails and resilient Codable for back-compat.
//  Includes VAT support, invoice reference, and optional repeating rule.
//  NOTE: Ensure this is the only definition of ExpenseEntry in the project.
//

import Foundation

// MARK: - ChargingDetails

struct ChargingDetails: Codable, Hashable {
    // Timing / energy
    var startDate: Date?
    var endDate: Date?
    var energyAddedKWh: Double?

    // Session analytics
    var startSOC: Double?
    var endSOC: Double?
    var durationMinutes: Int?
    var odometerStart: Double?
    var odometerEnd: Double?

    // Site / location
    var isSupercharger: Bool?
    var siteName: String?
    var latitude: Double?
    var longitude: Double?

    // Pricing / weather / id
    var pricePerKWh: Double?
    var outsideTempC: Double?
    var chargeId: String?

    // Electrical / provider
    var chargerPowerkW: Double?
    var chargerVolts: Double?
    var chargerAmps: Double?
    var chargerPhases: Int?
    var fastChargerBrand: String?

    // Vehicle identity
    var vehicleName: String?
    var vin: String?

    // Free-form notes about this session (separate from entry.notes)
    var notes: String?
}

// MARK: - ExpenseEntry

struct ExpenseEntry: Identifiable, Codable, Hashable {
    // Identity & core
    var id: UUID = UUID()
    var date: Date
    var amount: Double                          // gross (includes VAT if present)
    var currencyCode: String? = nil             // e.g. "USD"

    // Metadata
    var category: String = "Charging"
    /// Legacy kWh field; kept in sync with charging.energyAddedKWh via alias.
    var energyKWh: Double? = nil
    var odometer: Double? = nil
    var location: String? = nil
    var notes: String? = nil
    var vehicleName: String? = nil
    var stateOfCharge: Double? = nil
    var chargeType: String? = nil
    var vehicleID: UUID? = nil
    var isBusiness: Bool = false
    var vin: String? = nil

    /// UI/analytics flag: true for energy/charging entries
    var isEnergy: Bool = true

    /// Rich charging payload (nil for non-charging expenses)
    var charging: ChargingDetails? = nil

    // VAT / invoice
    var vatAmount: Double? = nil
    var invoiceNumber: String? = nil

    // Repeating expenses
    var repeatRule: ExpenseRepeatRule? = nil

    // MARK: - Bridging Aliases

    /// Alias to legacy `energyKWh`, but prefers nested payload if present.
    var energyAddedKWh: Double? {
        get { charging?.energyAddedKWh ?? energyKWh }
        set {
            if charging == nil { charging = ChargingDetails() }
            charging?.energyAddedKWh = newValue
            energyKWh = newValue
        }
    }

    /// Alias to `notes` so newer code can use `note`.
    var note: String? {
        get { notes }
        set { notes = newValue }
    }

    /// Alias to `invoiceNumber` so newer code can use `invoice`.
    var invoice: String? {
        get { invoiceNumber }
        set { invoiceNumber = newValue }
    }

    // MARK: - Derived

    /// Prefer explicit pricePerKWh; else infer from amount/kWh (gross).
    var costPerKWh: Double? {
        if let explicit = charging?.pricePerKWh { return explicit }
        guard let kWh = energyAddedKWh, kWh > 0 else { return nil }
        return amount / kWh
    }

    /// Amount excluding VAT (falls back to gross if `vatAmount` is nil).
    var amountExVAT: Double {
        guard let vat = vatAmount else { return amount }
        return max(0, amount - vat)
    }

    /// Net cost per kWh (excluding VAT) when kWh is known.
    var costPerKWhNet: Double? {
        guard let kWh = energyAddedKWh, kWh > 0 else { return nil }
        return amountExVAT / kWh
    }

    var summaryLabel: String {
        let f = DateFormatter(); f.dateStyle = .short
        return "\(category.capitalized) – \(f.string(from: date))"
    }

    /// Heuristic based on category text for older/foreign data.
    var isEnergyByCategory: Bool {
        let lc = category.lowercased()
        return lc.contains("charge") || lc.contains("energy") || lc.contains("supercharger") || lc.contains("dcfc")
    }

    /// Effective energy flag that considers stored flag, payload presence, and category heuristics.
    var isEnergyEffective: Bool { isEnergy || charging != nil || isEnergyByCategory }

    /// Computed duration in minutes (prefers explicit value, else derives from dates).
    var chargeDurationMinutes: Int? {
        if let m = charging?.durationMinutes { return m }
        guard let s = charging?.startDate, let e = charging?.endDate else { return nil }
        let dt = e.timeIntervalSince(s)
        return dt > 0 ? Int(dt / 60.0) : nil
    }

    var socDelta: Double? {
        guard let s = charging?.startSOC, let e = charging?.endSOC else { return nil }
        return e - s
    }

    var odometerDelta: Double? {
        guard let s = charging?.odometerStart, let e = charging?.odometerEnd else { return nil }
        return e - s
    }

    /// Stable dedupe key used by importers.
    func dedupeKey() -> String {
        let ts = (charging?.startDate ?? date).timeIntervalSinceReferenceDate
        let startMinute = Int(ts / 60.0) // minute granularity
        let kwh = energyAddedKWh ?? -1
        let site = charging?.siteName ?? location ?? "?"
        return "\(startMinute)|kWh=\(String(format: "%.3f", kwh))|site=\(site)"
    }

    /// Merge incoming charging details, filling only missing fields; keeps mirrors in sync.
    mutating func mergeCharging(_ incoming: ChargingDetails) {
        if charging == nil { charging = ChargingDetails() }
        func fill<T>(_ kp: WritableKeyPath<ChargingDetails, T?>, _ v: T?) {
            guard let v else { return }
            if charging?[keyPath: kp] == nil { charging?[keyPath: kp] = v }
        }
        fill(\.startDate, incoming.startDate)
        fill(\.endDate, incoming.endDate)
        fill(\.energyAddedKWh, incoming.energyAddedKWh)
        fill(\.startSOC, incoming.startSOC)
        fill(\.endSOC, incoming.endSOC)
        fill(\.durationMinutes, incoming.durationMinutes)
        fill(\.odometerStart, incoming.odometerStart)
        fill(\.odometerEnd, incoming.odometerEnd)
        fill(\.isSupercharger, incoming.isSupercharger)
        fill(\.siteName, incoming.siteName)
        fill(\.latitude, incoming.latitude)
        fill(\.longitude, incoming.longitude)
        fill(\.pricePerKWh, incoming.pricePerKWh)
        fill(\.outsideTempC, incoming.outsideTempC)
        fill(\.chargeId, incoming.chargeId)
        fill(\.chargerPowerkW, incoming.chargerPowerkW)
        fill(\.chargerVolts, incoming.chargerVolts)
        fill(\.chargerAmps, incoming.chargerAmps)
        fill(\.chargerPhases, incoming.chargerPhases)
        fill(\.fastChargerBrand, incoming.fastChargerBrand)
        fill(\.vehicleName, incoming.vehicleName)
        fill(\.vin, incoming.vin)
        fill(\.notes, incoming.notes)

        // Promote mirrors
        if location == nil, let site = charging?.siteName { location = site }
        if odometer == nil, let endOdo = charging?.odometerEnd { odometer = endOdo }
        if let end = charging?.endDate { date = end } // canonicalize to end-of-charge when known
        if vin == nil { vin = charging?.vin }
        if let k = charging?.energyAddedKWh { energyKWh = k }
    }

    /// Convenience factory for building an energy/charging entry in one go.
    static func fromCharging(
        amount: Double,
        currencyCode: String?,
        category: String = "Fast DCFC",
        location: String? = nil,
        notes: String? = nil,
        baseDate: Date? = nil,
        details: ChargingDetails,
        vatAmount: Double? = nil,
        invoiceNumber: String? = nil,
        repeatRule: ExpenseRepeatRule? = nil
    ) -> ExpenseEntry {
        let canonicalDate = details.endDate ?? details.startDate ?? baseDate ?? Date()
        var entry = ExpenseEntry(
            date: canonicalDate,
            amount: amount,
            currencyCode: currencyCode,
            category: category,
            energyKWh: details.energyAddedKWh,
            odometer: details.odometerEnd,
            location: location ?? details.siteName,
            notes: notes ?? details.notes,
            vehicleName: details.vehicleName,
            stateOfCharge: details.endSOC,
            chargeType: (details.isSupercharger == true) ? "Supercharger" : nil,
            vehicleID: nil,
            isBusiness: false,
            vin: details.vin,
            isEnergy: true,
            charging: details,
            vatAmount: vatAmount,
            invoiceNumber: invoiceNumber,
            repeatRule: repeatRule
        )
        if entry.charging?.pricePerKWh == nil, let kWh = details.energyAddedKWh, kWh > 0 {
            entry.charging?.pricePerKWh = amount / kWh
        }
        return entry
    }

    // Repeat sugar
    var isRepeating: Bool { repeatRule != nil }
    func nextRepeat(after date: Date = Date()) -> Date? {
        guard let r = repeatRule else { return nil }
        return RepeatEngine.nextOccurrence(after: date, rule: r)
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, date, amount, currencyCode, category, energyKWh, odometer, location, notes,
             vehicleName, stateOfCharge, chargeType, vehicleID, isBusiness, vin, isEnergy,
             charging, vatAmount, invoiceNumber, repeatRule
    }

    /// Older exports may have used these alternative top-level keys.
    private enum AltKeys: String, CodingKey {
        case energyAddedKWh  // alias for energyKWh
        case note            // alias for notes
        case invoice         // alias for invoiceNumber
    }

    init(
        id: UUID = UUID(),
        date: Date,
        amount: Double,
        currencyCode: String? = nil,
        category: String = "Charging",
        energyKWh: Double? = nil,
        odometer: Double? = nil,
        location: String? = nil,
        notes: String? = nil,
        vehicleName: String? = nil,
        stateOfCharge: Double? = nil,
        chargeType: String? = nil,
        vehicleID: UUID? = nil,
        isBusiness: Bool = false,
        vin: String? = nil,
        isEnergy: Bool = true,
        charging: ChargingDetails? = nil,
        vatAmount: Double? = nil,
        invoiceNumber: String? = nil,
        repeatRule: ExpenseRepeatRule? = nil
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.currencyCode = currencyCode
        self.category = category
        self.energyKWh = energyKWh
        self.odometer = odometer
        self.location = location
        self.notes = notes
        self.vehicleName = vehicleName
        self.stateOfCharge = stateOfCharge
        self.chargeType = chargeType
        self.vehicleID = vehicleID
        self.isBusiness = isBusiness
        self.vin = vin
        self.isEnergy = isEnergy
        self.charging = charging
        self.vatAmount = vatAmount
        self.invoiceNumber = invoiceNumber
        self.repeatRule = repeatRule
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // ID
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()

        // Date (flexible)
        self.date = try Self.decodeDateFlex(c, forKey: .date)

        // Required
        self.amount = try c.decode(Double.self, forKey: .amount)

        // Optionals / defaults
        self.currencyCode = try? c.decode(String.self, forKey: .currencyCode)
        self.category = (try? c.decode(String.self, forKey: .category)) ?? "Charging"
        self.energyKWh = try? c.decode(Double.self, forKey: .energyKWh)
        self.odometer = try? c.decode(Double.self, forKey: .odometer)
        self.location = try? c.decode(String.self, forKey: .location)
        self.notes = try? c.decode(String.self, forKey: .notes)
        self.vehicleName = try? c.decode(String.self, forKey: .vehicleName)
        self.stateOfCharge = try? c.decode(Double.self, forKey: .stateOfCharge)
        self.chargeType = try? c.decode(String.self, forKey: .chargeType)
        self.vehicleID = try? c.decode(UUID.self, forKey: .vehicleID)
        self.isBusiness = (try? c.decode(Bool.self, forKey: .isBusiness)) ?? false
        self.vin = try? c.decode(String.self, forKey: .vin)
        self.charging = try? c.decode(ChargingDetails.self, forKey: .charging)
        self.vatAmount = try? c.decode(Double.self, forKey: .vatAmount)
        self.invoiceNumber = try? c.decode(String.self, forKey: .invoiceNumber)
        self.repeatRule = try? c.decode(ExpenseRepeatRule.self, forKey: .repeatRule)

        // Back-compat promotions from nested payload
        if energyKWh == nil, let k = charging?.energyAddedKWh { energyKWh = k }
        if location == nil, let site = charging?.siteName { location = site }
        if vin == nil, let v = charging?.vin { vin = v }

        // Alt top-level keys (older exports)
        if (energyKWh == nil) || (notes == nil) || (invoiceNumber == nil) {
            if let alt = try? decoder.container(keyedBy: AltKeys.self) {
                if energyKWh == nil { energyKWh = try? alt.decode(Double.self, forKey: .energyAddedKWh) }
                if notes == nil { notes = try? alt.decode(String.self, forKey: .note) }
                if invoiceNumber == nil { invoiceNumber = try? alt.decode(String.self, forKey: .invoice) }
            }
        }

        // Infer isEnergy if absent
        if let explicit = try? c.decode(Bool.self, forKey: .isEnergy) {
            self.isEnergy = explicit
        } else {
            self.isEnergy = (charging != nil) || (energyKWh != nil) || category.lowercased().contains("charge")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(amount, forKey: .amount)
        try c.encodeIfPresent(currencyCode, forKey: .currencyCode)
        try c.encode(category, forKey: .category)
        try c.encodeIfPresent(energyKWh, forKey: .energyKWh)
        try c.encodeIfPresent(odometer, forKey: .odometer)
        try c.encodeIfPresent(location, forKey: .location)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encodeIfPresent(vehicleName, forKey: .vehicleName)
        try c.encodeIfPresent(stateOfCharge, forKey: .stateOfCharge)
        try c.encodeIfPresent(chargeType, forKey: .chargeType)
        try c.encodeIfPresent(vehicleID, forKey: .vehicleID)
        try c.encode(isBusiness, forKey: .isBusiness)
        try c.encodeIfPresent(vin, forKey: .vin)
        try c.encode(isEnergy, forKey: .isEnergy)
        try c.encodeIfPresent(charging, forKey: .charging)
        try c.encodeIfPresent(vatAmount, forKey: .vatAmount)
        try c.encodeIfPresent(invoiceNumber, forKey: .invoiceNumber)
        try c.encodeIfPresent(repeatRule, forKey: .repeatRule)
    }

    // Flexible date helper
    private static func decodeDateFlex(_ c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Date {
        // 1) Date
        if let d = try? c.decode(Date.self, forKey: key) { return d }
        // 2) Seconds since 1970 as Double
        if let secs = try? c.decode(Double.self, forKey: key) { return Date(timeIntervalSince1970: secs) }
        // 3) String (epoch seconds or ISO8601)
        if let s = try? c.decode(String.self, forKey: key) {
            if let secs = Double(s) { return Date(timeIntervalSince1970: secs) }
            let isoFS = ISO8601DateFormatter()
            isoFS.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = isoFS.date(from: s) { return d }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            if let d = iso.date(from: s) { return d }
        }
        // Fallback
        return Date()
    }
}
