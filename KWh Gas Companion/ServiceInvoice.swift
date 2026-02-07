//
//  ServiceInvoice.swift
//  KWh Gas Companion
//
//  Created by Bryan on 10/30/25.
//


//
//  ServiceInvoice.swift
//  My KWh Companion
//
//  Canonical model for Tesla service invoices.
//  Codable/Identifiable/Hashable/Sendable with Decimal-safe coding.
//

import Foundation

public struct ServiceInvoice: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var vehicleKey: String          // usually VIN (or your chosen key)
    public var title: String
    public var serviceDate: Date
    public var amount: Decimal?            // total due (may be 0 or nil if unknown)
    public var filename: String            // "<UUID>.pdf"
    public var sha256: String              // file content hash
    public var createdAt: Date
    public var updatedAt: Date

    // Parsed/optional metadata
    public var invoiceNumber: String?
    public var advisor: String?
    public var odometerIn: Int?
    public var odometerOut: Int?
    public var parsedVIN: String?
    public var location: String?

    // Expense linking (if created/attached)
    public var linkedExpenseID: UUID?

    // MARK: - Codable (Decimal-safe)

    private enum CodingKeys: String, CodingKey {
        case id, vehicleKey, title, serviceDate, amount, filename, sha256,
             createdAt, updatedAt, invoiceNumber, advisor, odometerIn, odometerOut,
             parsedVIN, location, linkedExpenseID
    }

    public init(
        id: UUID,
        vehicleKey: String,
        title: String,
        serviceDate: Date,
        amount: Decimal?,
        filename: String,
        sha256: String,
        createdAt: Date,
        updatedAt: Date,
        invoiceNumber: String? = nil,
        advisor: String? = nil,
        odometerIn: Int? = nil,
        odometerOut: Int? = nil,
        parsedVIN: String? = nil,
        location: String? = nil,
        linkedExpenseID: UUID? = nil
    ) {
        self.id = id
        self.vehicleKey = vehicleKey
        self.title = title
        self.serviceDate = serviceDate
        self.amount = amount
        self.filename = filename
        self.sha256 = sha256
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.invoiceNumber = invoiceNumber
        self.advisor = advisor
        self.odometerIn = odometerIn
        self.odometerOut = odometerOut
        self.parsedVIN = parsedVIN
        self.location = location
        self.linkedExpenseID = linkedExpenseID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        vehicleKey = try c.decode(String.self, forKey: .vehicleKey)
        title = try c.decode(String.self, forKey: .title)
        serviceDate = try c.decode(Date.self, forKey: .serviceDate)
        // Decimal: read as String or Double fallback
        if let s = try? c.decode(String.self, forKey: .amount), let d = Decimal(string: s) {
            amount = d
        } else if let n = try? c.decode(Double.self, forKey: .amount) {
            amount = Decimal(string: String(n))
        } else {
            amount = nil
        }
        filename = try c.decode(String.self, forKey: .filename)
        sha256 = try c.decode(String.self, forKey: .sha256)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        invoiceNumber = try? c.decode(String.self, forKey: .invoiceNumber)
        advisor = try? c.decode(String.self, forKey: .advisor)
        odometerIn = try? c.decode(Int.self, forKey: .odometerIn)
        odometerOut = try? c.decode(Int.self, forKey: .odometerOut)
        parsedVIN = try? c.decode(String.self, forKey: .parsedVIN)
        location = try? c.decode(String.self, forKey: .location)
        linkedExpenseID = try? c.decode(UUID.self, forKey: .linkedExpenseID)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(vehicleKey, forKey: .vehicleKey)
        try c.encode(title, forKey: .title)
        try c.encode(serviceDate, forKey: .serviceDate)
        if let amount {
            try c.encode(amount.description, forKey: .amount)
        }
        try c.encode(filename, forKey: .filename)
        try c.encode(sha256, forKey: .sha256)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(invoiceNumber, forKey: .invoiceNumber)
        try c.encodeIfPresent(advisor, forKey: .advisor)
        try c.encodeIfPresent(odometerIn, forKey: .odometerIn)
        try c.encodeIfPresent(odometerOut, forKey: .odometerOut)
        try c.encodeIfPresent(parsedVIN, forKey: .parsedVIN)
        try c.encodeIfPresent(location, forKey: .location)
        try c.encodeIfPresent(linkedExpenseID, forKey: .linkedExpenseID)
    }
}
