// DS.swift (only the accent changed to a dynamic provider)
import SwiftUI

enum DS {
    enum Color {
        static let bg       = SwiftUI.Color(white: 0.06)
        static let surface  = SwiftUI.Color(white: 0.10)
        static let surface2 = SwiftUI.Color(white: 0.14)
        static let text     = SwiftUI.Color(white: 0.96)
        static let subtext  = SwiftUI.Color(white: 0.70)

        // Dynamic Tesla-ish accent: slightly brighter in Light Mode, a touch softer in Dark Mode.
        static var accent: SwiftUI.Color {
            SwiftUI.Color(UIColor { trait in
                if trait.userInterfaceStyle == .dark {
                    // Dark Mode: softer to reduce glare
                    return UIColor(red: 0.90, green: 0.18, blue: 0.20, alpha: 1.0)
                } else {
                    // Light Mode: vivid/contrasty
                    return UIColor(red: 0.89, green: 0.09, blue: 0.16, alpha: 1.0)
                }
            })
        }

        static let good     = SwiftUI.Color.green
        static let warn     = SwiftUI.Color.orange
        static let bad      = SwiftUI.Color.red
    }

    enum Radius {
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 22
    }

    enum Spacing {
        static let xs: CGFloat = 6
        static let s: CGFloat  = 10
        static let m: CGFloat  = 14
        static let l: CGFloat  = 20
        static let xl: CGFloat = 28
    }

    enum Shadow {
        static let card = SwiftUI.Color.black.opacity(0.35)
    }

    enum Font {
        static func number(_ size: CGFloat, weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            SwiftUI.Font.system(size: size, weight: weight, design: .rounded)
        }
        static func label(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            SwiftUI.Font.system(size: size, weight: weight, design: .rounded)
        }
        static func title(_ size: CGFloat, weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            SwiftUI.Font.system(size: size, weight: weight, design: .rounded)
        }
    }
}
