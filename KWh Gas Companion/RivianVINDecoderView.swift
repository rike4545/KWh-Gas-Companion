import SwiftUI

struct RivianVINDecoderView: View {
    @State private var vin: String = ""
    
    // Decoded fields
    @State private var decodedInfo: RivianVINDecodedInfo? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Enter VIN")) {
                    TextField("17-character VIN", text: $vin)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                }
                
                Section {
                    Button("Decode VIN") {
                        decodeFields()
                    }
                }
                
                if let info = decodedInfo {
                    Section(header: Text("Decoded Details")) {
                        HStack { Text("WMI"); Spacer(); Text(info.wmi) }
                        HStack { Text("Model Line"); Spacer(); Text(info.modelLine) }
                        HStack { Text("GVWR"); Spacer(); Text(info.gvwr) }
                        HStack { Text("Drivetrain"); Spacer(); Text(info.drivetrain) }
                        HStack { Text("Restraints"); Spacer(); Text(info.restraints) }
                        HStack { Text("Trim"); Spacer(); Text(info.trim) }
                        HStack { Text("Check Digit"); Spacer(); Text(info.checkDigit) }
                        HStack { Text("Model Year"); Spacer(); Text(info.modelYear) }
                        HStack { Text("Plant"); Spacer(); Text(info.plant) }
                        HStack { Text("Serial"); Spacer(); Text(info.serial) }
                    }
                }
            }
            .navigationTitle("Rivian VIN Decoder")
        }
    }
    
    private func decodeFields() {
        let cleaned = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleaned.count == 17 else { return }
        
        let decoder = RivianVINDecoder(vin: cleaned)
        decodedInfo = decoder.decode()
    }
}

// MARK: - Decoded Info Model

struct RivianVINDecodedInfo {
    let wmi: String
    let modelLine: String
    let gvwr: String
    let drivetrain: String
    let restraints: String
    let trim: String
    let checkDigit: String
    let modelYear: String
    let plant: String
    let serial: String
}

// MARK: - Decoder

class RivianVINDecoder {
    private let vin: String
    init(vin: String) { self.vin = vin }
    
    func decode() -> RivianVINDecodedInfo {
        func char(_ idx: Int) -> Character {
            vin[vin.index(vin.startIndex, offsetBy: idx)]
        }
        
        let wmiCode  = String(vin.prefix(3))
        let wmi      = decodeWMI(wmiCode)
        let modelLine = decodeModelLine(char(3))
        let gvwr     = decodeGVWR(char(4))
        let drivetrain = decodeDrivetrain(char(5), yearChar: char(9))
        let restraints = decodeRestraints(char(6))
        let trim     = decodeTrim(char(7))
        let checkDigit = String(char(8))
        let year     = decodeYear(char(9)).map(String.init) ?? "Unknown"
        let plant    = decodePlant(char(10))
        let serial   = String(vin.suffix(from: vin.index(vin.startIndex, offsetBy: 11)))
        
        return .init(
            wmi: wmi,
            modelLine: modelLine,
            gvwr: gvwr,
            drivetrain: drivetrain,
            restraints: restraints,
            trim: trim,
            checkDigit: checkDigit,
            modelYear: year,
            plant: plant,
            serial: serial
        )
    }
    
    // — Helper mappings
    
    private func decodeWMI(_ code: String) -> String {
        switch code {
        case "7FC": return "Rivian R1T (Truck)"
        case "7PD": return "Rivian R1S (MPV)"
        default:    return "Unknown WMI"
        }
    }
    
    private func decodeModelLine(_ c: Character) -> String {
        switch c {
        case "T": return "R1T 4‑door Pickup Truck"
        case "S": return "R1S 4‑door MPV"
        default:  return "Unknown Model Line"
        }
    }
    
    private func decodeGVWR(_ c: Character) -> String {
        switch c {
        case "G": return "8,001–9,000 lbs.; Hydraulic Brakes"
        default:  return "Unknown GVWR"
        }
    }
    
    private func decodeDrivetrain(_ c: Character, yearChar: Character) -> String {
        let year = decodeYear(yearChar) ?? 0
        if year < 2025 {
            switch c {
            case "A": return "Large Pack, Quad‑Motor, AWD"
            case "B": return "Large Pack, Dual‑Motor, AWD"
            case "C": return "Max Pack, Dual‑Motor, AWD"
            default:  return "Unknown Drivetrain"
            }
        } else {
            switch c {
            case "A": return "Quad‑Motor, AWD"
            case "B": return "Dual‑Motor, AWD"
            case "C": return "Tri‑Motor, AWD"
            default:  return "Unknown Drivetrain"
            }
        }
    }
    
    private func decodeRestraints(_ c: Character) -> String {
        "2x front airbags; 2x knee airbags; 2x side airbags; 2x curtains; 5‑seatbelt setup"
    }
    
    private func decodeTrim(_ c: Character) -> String {
        switch c {
        case "A": return "Adventure"
        case "E": return "Entry"
        case "L": return "Launch Edition"
        case "P": return "Premium"
        default:  return "Unknown Trim"
        }
    }
    
    private func decodeYear(_ c: Character) -> Int? {
        ["N":2022, "P":2023, "R":2024, "S":2025][c]
    }
    
    private func decodePlant(_ c: Character) -> String {
        switch c {
        case "N": return "Normal, IL"
        default:  return "Unknown Plant"
        }
    }
}
