// TeslaFiLogEntry.swift
// MyKwH Companion – Raw model for TeslaFi CSV row

import Foundation

/// Represents one entry from a TeslaFi CSV export
public struct TeslaFiLogEntry: Identifiable, Hashable {
    public let id: UUID
    public let date: Date
    public let kWhAdded: Double
    public let cost: Double
    public let location: String?
    public let odometer: Double?

    public init(
        id: UUID = UUID(),
        date: Date,
        kWhAdded: Double,
        cost: Double,
        location: String? = nil,
        odometer: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.kWhAdded = kWhAdded
        self.cost = cost
        self.location = location
        self.odometer = odometer
    }

    /// Parses a row dictionary from CSV into a TeslaFiLogEntry
    public static func fromCSVRow(_ row: [String: String]) -> TeslaFiLogEntry? {
        // Mandatory fields
        guard let dateStr = row["Date"],
              let kWhStr = row["kWh Added"],
              let costStr = row["Cost"]
        else {
            return nil
        }

        // Parse date (ISO8601 or fallback)
        let date: Date
        if let isoDate = ISO8601DateFormatter().date(from: dateStr) {
            date = isoDate
        } else {
            let fallbackFmt = DateFormatter()
            fallbackFmt.dateFormat = "MM/dd/yyyy HH:mm:ss"
            guard let fallbackDate = fallbackFmt.date(from: dateStr) else {
                return nil
            }
            date = fallbackDate
        }

        // Parse numeric values
        guard let kWh = Double(kWhStr), kWh > 0 else { return nil }
        let cleanedCost = costStr.replacingOccurrences(of: "$", with: "")
        guard let cost = Double(cleanedCost) else { return nil }

        // Optional fields
        let location = row["Location"]
        let odometer: Double?
        if let odoStr = row["Odometer"], let odoVal = Double(odoStr) {
            odometer = odoVal
        } else {
            odometer = nil
        }

        return TeslaFiLogEntry(
            date: date,
            kWhAdded: kWh,
            cost: cost,
            location: location,
            odometer: odometer
        )
    }
}
