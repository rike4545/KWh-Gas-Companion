// TeslaVINDecoderLogic.swift
import Foundation

/// Decoded Tesla VIN information
public struct TeslaVINInfo {
    public let vin: String
    public let wmi: String                  // World Manufacturer Identifier
    public let wmiDescription: String       // Decoded WMI description
    public let series: String               // Make/Line/Series
    public let bodyType: String             // Body Type and GVWR
    public let restraintSystem: String      // Restraint system
    public let fuelType: String             // Charger/Battery/Fuel type
    public let motorType: String            // Motor/drive unit
    public let checkDigit: String           // Check digit
    public let modelYear: Int?              // Model year
    public let plant: String                // Plant of manufacture
    public let serial: String               // Production sequence (digits 12-17)
}

/// Logic to decode various fields of a Tesla VIN (Vehicle Identification Number)
public struct TeslaVINDecoderLogic {
    // 1-3: WMI
    private static let wmiMap: [String: String] = [
        "5YJ": "Fremont, California (Model S & 3 post-2022)",
        "7SA": "Fremont, California (Model X & Y post-2022)",
        "LRW": "China (Giga Shanghai)",
        "XP7": "Germany (Giga Berlin)",
        "SFZ": "United Kingdom (Roadster 1)"
    ]

    // 4: Make/Line/Series
    private static let seriesMap: [Character: String] = [
        "S": "Tesla Model S",
        "X": "Tesla Model X",
        "3": "Tesla Model 3",
        "Y": "Tesla Model Y",
        "R": "Tesla Roadster"
    ]

    // 5: Body Type & GVWR
    private static let bodyMap: [Character: String] = [
        "A": "5 Door LHD car (Model S)",
        "B": "5 Door RHD car (Model S)",
        "C": "5 Door LHD Large MPV (Model X)",
        "D": "5 Door RHD Large MPV (Model X)",
        "E": "4 Door LHD Sedan (Model 3/Roadster)",
        "F": "4 Door RHD Sedan (Model 3)",
        "G": "5 Door LHD Small MPV (Model Y)",
        "H": "5 Door RHD Small MPV (Model Y)"
    ]

    // 6: Restraint System
    private static let restraintMap: [Character: String] = [
        "1": "2 Front, 3 Rear belts, Airbags, PODS, Side inflatable, Knee airbags (Front)",
        "2": "Pre-2014 restraint config (TBA)",
        "3": "2 Front, 2 Rear belts, Airbags, Side inflatable, Knee airbags (Front)",
        "4": "2 Front, 3 Rear belts, Airbags, Side inflatable, Knee airbags (Front)",
        "5": "2 Front, 2 Rear belts, Airbags, Side inflatable",
        "6": "2 Front, 3 Rear belts, Airbags, Side inflatable",
        "7": "2 Front, 3 Rear belts, Airbags, Side inflatable & Active Hood",
        "8": "2 Front, 2 Rear belts, Airbags, Side inflatable & Active Hood",
        "A": "2 Front, 3 Rear+3rd row belts, Airbags, PODS, Side inflatable, Knee airbags",
        "B": "2 Front, 2 Rear+3rd row belts, Airbags, PODS, Side inflatable",
        "C": "2 Front, 2 Rear+3rd row belts, Airbags, PODS, Side inflatable",
        "D": "2 Front, 3 Rear belts, Airbags, PODS, Side inflatable, Knee airbags"
    ]

    // 7: Charger/Battery/Fuel Type
    private static let fuelMap: [Character: String] = [
        "A": "10 kW Charger",
        "B": "20 kW Charger",
        "C": "10 kW Charger with DC Fast Charge",
        "D": "20 kW Charger with DC Fast Charge",
        "E": "Extended Capacity Lithium-ion Battery (NMC/NCA)",
        "F": "Lithium Iron Phosphate Battery (LFP)",
        "H": "High Capacity Lithium-ion Battery (LFP)",
        "S": "Standard Capacity Lithium-ion Battery (NMC/NCA)",
        "V": "Very High Capacity Lithium-ion Battery (NMC/NCA)"
    ]

    // 8: Motor/Drive Unit
    private static let motorMap: [Character: String] = [
        "C": "Base A/C Motor, Tier 2 Battery (31-40 kWh)",
        "G": "Base A/C Motor, Tier 4 Battery (51-60 kWh)",
        "N": "Base A/C Motor, Tier 7 Battery (81-90 kWh)",
        "P": "Performance A/C Motor, Tier 7 Battery (81-90 kWh)",
        "1": "Single Motor – Standard",
        "2": "Dual Motor – Standard",
        "3": "Single Performance Motor",
        "4": "Dual Motor – Performance",
        "5": "P2 Dual Motor – Long Range (2021+)",
        "6": "P2 Tri Motor – Plaid",
        "A": "Single Motor for Model 3",
        "B": "Dual Motor for Model 3",
        "D": "Single Motor – Standard/Performance for Model Y",
        "E": "Dual Motor – Standard for Model Y",
        "F": "Dual Motor – Performance for Model Y",
        "J": "Single Motor hairpin winding",
        "K": "Dual Motor hairpin winding",
        "L": "Performance Motor hairpin winding",
        "R": "RWD V1 Motor"
    ]

    // 10: Model Year
    private static let yearMap: [Character: Int] = [
        "C": 2012, "D": 2013, "E": 2014, "F": 2015,
        "G": 2016, "H": 2017, "J": 2018, "K": 2019,
        "L": 2020, "M": 2021, "N": 2022, "P": 2023,
        "R": 2024, "S": 2025, "T": 2026
    ]

    // 11: Plant of Manufacture
    private static let plantMap: [Character: String] = [
        "1": "Menlo Park, CA",
        "3": "Hethel, UK",
        "A": "Austin, TX",
        "B": "Berlin, Germany",
        "C": "Shanghai, China",
        "F": "Fremont, CA",
        "P": "Palo Alto, CA"
    ]

    /// Decode a 17-character Tesla VIN. Returns nil if invalid length.
    public static func decode(_ vin: String) -> TeslaVINInfo? {
        let vin = vin.uppercased()
        guard vin.count == 17 else { return nil }
        let chars = Array(vin)

        let wmiCode = String(chars[0...2])
        let wmiDesc = wmiMap[wmiCode] ?? "Unknown"
        let series = seriesMap[chars[3]] ?? "Unknown"
        let body = bodyMap[chars[4]] ?? "Unknown"
        let restraint = restraintMap[chars[5]] ?? "Unknown"
        let fuel = fuelMap[chars[6]] ?? "Unknown"
        let motor = motorMap[chars[7]] ?? "Unknown"
        let check = String(chars[8])
        let year = yearMap[chars[9]]
        let plant = plantMap[chars[10]] ?? "Unknown"
        let serial = String(chars[11...16])

        return TeslaVINInfo(
            vin: vin,
            wmi: wmiCode,
            wmiDescription: wmiDesc,
            series: series,
            bodyType: body,
            restraintSystem: restraint,
            fuelType: fuel,
            motorType: motor,
            checkDigit: check,
            modelYear: year,
            plant: plant,
            serial: serial
        )
    }
}
