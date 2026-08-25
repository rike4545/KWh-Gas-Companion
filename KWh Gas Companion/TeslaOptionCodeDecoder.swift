//
//  TeslaOptionCodeDecoder.swift
//  KWh Gas Companion
//
//  Turns Tesla's `mktOptions` codes into a readable build sheet — paint,
//  wheels, interior, seating, drive unit, and Autopilot hardware.
//
//  ACCURACY NOTE
//  ─────────────
//  Tesla has never published this list. Everything here is community-mapped
//  from window stickers and order JSON, and Tesla reuses and retires codes
//  between refreshes. Known codes are named; anything unrecognized is still
//  shown, bucketed by prefix, and labeled as unrecognized rather than guessed
//  at. Treat the build sheet as a strong hint, not as documentation.
//
//  Swift 6 • iOS 17+
//

import Foundation

// MARK: - Categories

public enum TeslaOptionCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case model      = "Model"
    case paint      = "Paint"
    case wheels     = "Wheels"
    case interior   = "Interior"
    case seating    = "Seating"
    case driveUnit  = "Drive Unit"
    case autopilot  = "Autopilot"
    case roof       = "Roof"
    case towing     = "Towing"
    case battery    = "Battery"
    case market     = "Market"
    case other      = "Other"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .model:     return "car.fill"
        case .paint:     return "paintpalette"
        case .wheels:    return "circle.dashed"
        case .interior:  return "carseat.left.fill"
        case .seating:   return "person.3.fill"
        case .driveUnit: return "bolt.car"
        case .autopilot: return "cpu"
        case .roof:      return "rectangle.tophalf.filled"
        case .towing:    return "truck.box"
        case .battery:   return "battery.100percent"
        case .market:    return "globe"
        case .other:     return "square.grid.2x2"
        }
    }

    /// Order the build sheet reads best in.
    public var sortIndex: Int { Self.allCases.firstIndex(of: self) ?? 99 }
}

// MARK: - Decoded item

public struct TeslaOptionItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let code: String
    public let category: TeslaOptionCategory
    public let label: String
    /// False when the code was bucketed by prefix rather than actually known.
    public let isRecognized: Bool

    public init(code: String, category: TeslaOptionCategory, label: String, isRecognized: Bool) {
        self.id = code
        self.code = code
        self.category = category
        self.label = label
        self.isRecognized = isRecognized
    }
}

// MARK: - Spec sheet

public struct TeslaOptionSpec: Hashable, Sendable {

    public let items: [TeslaOptionItem]

    public init(items: [TeslaOptionItem]) {
        self.items = items
    }

    public var isEmpty: Bool { items.isEmpty }

    public var recognizedCount: Int { items.filter(\.isRecognized).count }

    public func items(in category: TeslaOptionCategory) -> [TeslaOptionItem] {
        items.filter { $0.category == category }
    }

    public var categories: [TeslaOptionCategory] {
        Array(Set(items.map(\.category))).sorted { $0.sortIndex < $1.sortIndex }
    }

    public func first(_ category: TeslaOptionCategory) -> String? {
        items.first { $0.category == category && $0.isRecognized }?.label
    }

    /// The headline configuration, for a summary row or a shared post.
    public var oneLine: String {
        let parts = [
            first(.paint),
            first(.wheels),
            first(.interior),
            first(.autopilot)
        ].compactMap { $0 }
        return parts.isEmpty ? "" : parts.joined(separator: " · ")
    }
}

// MARK: - Decoder

public enum TeslaOptionCodeDecoder {

    /// Splits a raw `mktOptions` string. Tesla delivers these comma-separated,
    /// sometimes with a `$` prefix on each code.
    public static func split(_ raw: String) -> [String] {
        raw
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == ";" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "$ \t")).uppercased() }
            .filter { !$0.isEmpty }
    }

    public static func decode(_ raw: String) -> TeslaOptionSpec {
        decode(split(raw))
    }

    public static func decode(_ codes: [String]) -> TeslaOptionSpec {
        var seen = Set<String>()
        let items: [TeslaOptionItem] = codes.compactMap { rawCode in
            let code = rawCode
                .trimmingCharacters(in: CharacterSet(charactersIn: "$ \t"))
                .uppercased()
            guard !code.isEmpty, seen.insert(code).inserted else { return nil }

            if let known = table[code] {
                return TeslaOptionItem(
                    code: code,
                    category: known.category,
                    label: known.label,
                    isRecognized: true
                )
            }
            return TeslaOptionItem(
                code: code,
                category: bucket(for: code),
                label: "Unrecognized code",
                isRecognized: false
            )
        }

        return TeslaOptionSpec(
            items: items.sorted {
                if $0.category.sortIndex != $1.category.sortIndex {
                    return $0.category.sortIndex < $1.category.sortIndex
                }
                if $0.isRecognized != $1.isRecognized { return $0.isRecognized }
                return $0.code < $1.code
            }
        )
    }

    /// Prefix bucketing for codes we don't have a name for. Gets an unknown
    /// code into roughly the right section without inventing a meaning.
    private static func bucket(for code: String) -> TeslaOptionCategory {
        if code.hasPrefix("AP") || code.hasPrefix("AU") { return .autopilot }
        if code.hasPrefix("MDL") || code.hasPrefix("MT") { return .model }
        if code.hasPrefix("P") && code.count == 4 { return .paint }
        if code.hasPrefix("W") { return .wheels }
        if code.hasPrefix("I")  { return .interior }
        if code.hasPrefix("RF") { return .roof }
        if code.hasPrefix("TW") { return .towing }
        if code.hasPrefix("BT") || code.hasPrefix("BC") { return .battery }
        if code.hasPrefix("DV") || code.hasPrefix("MI") { return .driveUnit }
        if code.hasPrefix("SC") || code.hasPrefix("S3") || code.hasPrefix("S4") { return .seating }
        if code.hasPrefix("CN") || code.hasPrefix("DR") { return .market }
        return .other
    }

    // MARK: Known codes

    private static let table: [String: (category: TeslaOptionCategory, label: String)] = [

        // ── Model / trim ─────────────────────────────────────────────
        "MDL3": (.model, "Model 3"),
        "MDLY": (.model, "Model Y"),
        "MDLS": (.model, "Model S"),
        "MDLX": (.model, "Model X"),
        "MT300": (.model, "Model 3 Standard Range"),
        "MT301": (.model, "Model 3 Long Range"),
        "MT302": (.model, "Model 3 Performance"),
        "MT303": (.model, "Model 3 Standard Range Plus"),
        "MT304": (.model, "Model 3 Standard Range Plus"),
        "MT305": (.model, "Model 3 Long Range AWD"),
        "MT306": (.model, "Model 3 Performance AWD"),
        "MT307": (.model, "Model 3 Rear-Wheel Drive"),
        "MT308": (.model, "Model 3 Performance"),
        "MT309": (.model, "Model 3 Long Range RWD"),
        "MT310": (.model, "Model 3 Rear-Wheel Drive"),
        "MT311": (.model, "Model 3 Long Range AWD"),
        "MT312": (.model, "Model 3 Performance AWD"),
        "MTY01": (.model, "Model Y Long Range AWD"),
        "MTY02": (.model, "Model Y Performance AWD"),
        "MTY03": (.model, "Model Y Standard Range"),
        "MTY04": (.model, "Model Y Long Range AWD"),
        "MTY05": (.model, "Model Y Performance AWD"),
        "MTY06": (.model, "Model Y Standard Range RWD"),
        "MTY07": (.model, "Model Y Long Range RWD"),
        "MTY08": (.model, "Model Y Long Range AWD"),
        "MTY09": (.model, "Model Y Performance"),

        // ── Paint ────────────────────────────────────────────────────
        "PBSB": (.paint, "Solid Black"),
        "PMBL": (.paint, "Obsidian Black Metallic"),
        "PPSW": (.paint, "Pearl White Multi-Coat"),
        "PBCW": (.paint, "Catalina White"),
        "PMNG": (.paint, "Midnight Silver Metallic"),
        "PMSS": (.paint, "Silver Metallic"),
        "PMTG": (.paint, "Dolphin Grey Metallic"),
        "PPTI": (.paint, "Titanium Metallic"),
        "PPSB": (.paint, "Deep Blue Metallic"),
        "PPMR": (.paint, "Red Multi-Coat"),
        "PPSR": (.paint, "Signature Red"),
        "PMAB": (.paint, "Anza Brown Metallic"),
        "PMSG": (.paint, "Signature Green"),
        "PN00": (.paint, "Stealth Grey"),
        "PN01": (.paint, "Ultra Red"),
        "PN02": (.paint, "Quicksilver"),
        "PN03": (.paint, "Lunar Silver"),
        "PN04": (.paint, "Glacier Blue"),
        "PN05": (.paint, "Diamond Black"),
        "PR00": (.paint, "Unpainted Stainless"),
        "PR01": (.paint, "Red Multi-Coat"),

        // ── Wheels ───────────────────────────────────────────────────
        "W32P": (.wheels, "20\" Performance Wheels"),
        "W33D": (.wheels, "20\" Warp Wheels"),
        "W38B": (.wheels, "18\" Aero Wheels"),
        "W39B": (.wheels, "19\" Sport Wheels"),
        "W40B": (.wheels, "18\" Aero Wheels"),
        "W41B": (.wheels, "19\" Nova Wheels"),
        "W42B": (.wheels, "18\" Photon Wheels"),
        "W43D": (.wheels, "19\" Nova Wheels"),
        "W44D": (.wheels, "20\" Warp Wheels"),
        "WY18B": (.wheels, "18\" Aero Wheels"),
        "WY19B": (.wheels, "19\" Gemini Wheels"),
        "WY19P": (.wheels, "19\" Gemini Wheels"),
        "WY20P": (.wheels, "20\" Induction Wheels"),
        "WY21P": (.wheels, "21\" Überturbine Wheels"),
        "WY19C": (.wheels, "19\" Crossflow Wheels"),
        "WY20C": (.wheels, "20\" Helix Wheels"),
        "WY22P": (.wheels, "22\" Turbine Wheels"),
        "WT19": (.wheels, "19\" Tempest Wheels"),
        "WT20": (.wheels, "20\" Silver Wheels"),
        "WT21": (.wheels, "21\" Arachnid Wheels"),
        "WT22": (.wheels, "22\" Turbine Wheels"),
        "WS90": (.wheels, "19\" Silver Wheels"),
        "WX00": (.wheels, "20\" Silver Wheels"),
        "WX20": (.wheels, "22\" Onyx Black Turbine Wheels"),

        // ── Interior ─────────────────────────────────────────────────
        "IBB1": (.interior, "All Black Premium Interior"),
        "IBB0": (.interior, "All Black Interior"),
        "IWW1": (.interior, "Black and White Premium Interior"),
        "IPB0": (.interior, "All Black Interior"),
        "IPB1": (.interior, "All Black Premium Interior"),
        "IPW0": (.interior, "Black and White Interior"),
        "IPW1": (.interior, "Black and White Premium Interior"),
        "ICW1": (.interior, "Cream Premium Interior"),
        "IBE00": (.interior, "All Black Interior"),
        "IN3PB": (.interior, "All Black Premium Interior"),
        "IN3PW": (.interior, "Black and White Premium Interior"),
        "INPB0": (.interior, "All Black Interior"),
        "INPW0": (.interior, "Black and White Interior"),
        "IL31": (.interior, "Dark Ash Wood Trim"),
        "IDBA": (.interior, "Dark Ash Wood Decor"),
        "IDCF": (.interior, "Carbon Fiber Decor"),
        "IDOM": (.interior, "Oak Wood Decor"),
        "IDPB": (.interior, "Piano Black Decor"),

        // ── Seating ──────────────────────────────────────────────────
        "SC01": (.seating, "5 Seat Interior"),
        "SC04": (.seating, "5 Seat Interior"),
        "SC05": (.seating, "6 Seat Interior"),
        "SC06": (.seating, "7 Seat Interior"),
        "S31B": (.seating, "5 Seat Interior"),
        "S32B": (.seating, "7 Seat Interior"),
        "S3PB": (.seating, "5 Seat Interior"),
        "TR00": (.seating, "No Third-Row Seats"),
        "TR01": (.seating, "Third-Row Seating"),

        // ── Drive unit ───────────────────────────────────────────────
        "DV2W": (.driveUnit, "Rear-Wheel Drive"),
        "DV4W": (.driveUnit, "Dual Motor All-Wheel Drive"),
        "DRLH": (.driveUnit, "Left-Hand Drive"),
        "DRRH": (.driveUnit, "Right-Hand Drive"),
        "ACL1": (.driveUnit, "Acceleration Boost"),
        "PERFORMANCE": (.driveUnit, "Performance Package"),

        // ── Autopilot ────────────────────────────────────────────────
        "APBS": (.autopilot, "Basic Autopilot"),
        "APB1": (.autopilot, "Basic Autopilot"),
        "APPA": (.autopilot, "Enhanced Autopilot"),
        "APPB": (.autopilot, "Enhanced Autopilot"),
        "APF2": (.autopilot, "Full Self-Driving Capability"),
        "APFB": (.autopilot, "Full Self-Driving Capability"),
        "APF0": (.autopilot, "No Full Self-Driving"),
        "APH0": (.autopilot, "Autopilot Hardware 2.0"),
        "APH2": (.autopilot, "Autopilot Hardware 2.5"),
        "APH3": (.autopilot, "Autopilot Hardware 3.0"),
        "APH4": (.autopilot, "Autopilot Hardware 4.0 (AI4)"),

        // ── Roof / glass ─────────────────────────────────────────────
        "RF3G": (.roof, "Glass Roof"),
        "RFPX": (.roof, "Panoramic Windshield"),
        "RFP2": (.roof, "Glass Roof"),
        "RFBC": (.roof, "Body-Colored Roof"),

        // ── Towing ───────────────────────────────────────────────────
        "TW00": (.towing, "No Tow Package"),
        "TW01": (.towing, "Tow Hitch"),
        "TW02": (.towing, "Tow Package"),

        // ── Battery ──────────────────────────────────────────────────
        "BTX4": (.battery, "90 kWh Battery"),
        "BTX5": (.battery, "75 kWh Battery"),
        "BTX6": (.battery, "100 kWh Battery"),
        "BTX7": (.battery, "75 kWh Battery"),
        "BTX8": (.battery, "85 kWh Battery"),
        "BT37": (.battery, "75 kWh Battery"),
        "BT40": (.battery, "40 kWh Battery"),
        "BT60": (.battery, "60 kWh Battery"),
        "BT70": (.battery, "70 kWh Battery"),
        "BT85": (.battery, "85 kWh Battery"),
        "BR00": (.battery, "No Battery Firmware Limit"),
        "BC0R": (.battery, "Red Brake Calipers"),
        "BC3B": (.battery, "Black Brake Calipers"),

        // ── Market / region ──────────────────────────────────────────
        "CN00": (.market, "North America"),
        "CDM0": (.market, "North America Market"),
        "MI00": (.market, "2016 Production Refresh"),
        "MI01": (.market, "2017 Production Refresh"),
        "MI02": (.market, "2018 Production Refresh"),
        "MI03": (.market, "2019 Production Refresh"),
        "MI04": (.market, "2020 Production Refresh"),
        "MI05": (.market, "2021 Production Refresh"),

        // ── Other ────────────────────────────────────────────────────
        "CPF0": (.other, "Standard Connectivity"),
        "CPF1": (.other, "Premium Connectivity"),
        "PC30": (.other, "Paint Protection"),
        "SU3C": (.other, "Coil Spring Suspension"),
        "SU01": (.other, "Smart Air Suspension"),
        "HP00": (.other, "No HPWC Included"),
        "HP30": (.other, "HPWC Included"),
        "CH04": (.other, "48 A Onboard Charger"),
        "CH05": (.other, "32 A Onboard Charger"),
        "CH07": (.other, "48 A Onboard Charger"),
        "COUS": (.other, "United States"),
        "OSSB": (.other, "Standard Sound System"),
        "SP00": (.other, "No Parcel Shelf"),
        "SP01": (.other, "Parcel Shelf")
    ]
}
