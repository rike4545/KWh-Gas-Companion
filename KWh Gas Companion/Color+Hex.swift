import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

extension Color {
    public init(hex: String) {
        self = Self.fromHex(hex) ?? .clear
    }

    public static func fromHex(_ hex: String) -> Color? {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var hexValue: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&hexValue) else { return nil }

        let r, g, b, a: Double
        switch cleaned.count {
        case 6:
            r = Double((hexValue & 0xFF0000) >> 16) / 255.0
            g = Double((hexValue & 0x00FF00) >> 8) / 255.0
            b = Double(hexValue & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = Double((hexValue & 0xFF000000) >> 24) / 255.0
            g = Double((hexValue & 0x00FF0000) >> 16) / 255.0
            b = Double((hexValue & 0x0000FF00) >> 8) / 255.0
            a = Double(hexValue & 0x000000FF) / 255.0
        default:
            return nil
        }

        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    func toHex() -> String? {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "#%02X%02X%02X", Int(r * 255.0), Int(g * 255.0), Int(b * 255.0))
        #else
        return nil
        #endif
    }
}
