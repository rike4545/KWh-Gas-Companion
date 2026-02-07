import SwiftUI

enum VINBrand: String, CaseIterable, Identifiable {
    case tesla = "Tesla"
    case rivian = "Rivian"

    var id: String { rawValue }

    /// Returns the brand matching the VIN's WMI prefix
    static func from(vin: String) -> VINBrand? {
        let prefix = vin.trimmingCharacters(in: .whitespacesAndNewlines)
                        .uppercased()
                        .prefix(3)
        switch prefix {
        case "5YJ", "7SA", "LRW", "XP7": return .tesla
        case "7FC", "7PD":               return .rivian
        default:                            return nil
        }
    }

    /// Returns the appropriate decoder view for this brand
    @MainActor @ViewBuilder
    func decoderView() -> some View {
        switch self {
        case .tesla:
            TeslaVINDecoderView()
        case .rivian:
            RivianVINDecoderView()
        }
    }
}
