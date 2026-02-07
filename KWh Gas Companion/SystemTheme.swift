//
//  SystemTheme.swift
//  My KWh Companion
//
//  Concrete themes used by ThemeBinder / SettingsView.
//  Swift 6 • iOS 17+
//
//  Notes:
//  - `SystemTheme` (classic) mirrors system surfaces in both light/dark.
//  - `TeslaGlassTheme` is a "glass" aesthetic that remains readable in light mode.
//  - Both offer an init(accentColor:scheme:) with DEFAULT values to avoid call-site churn.
//

import SwiftUI

// MARK: - Classic theme (system-respecting)

public struct SystemTheme: AppThemeSpec {
    public let accentColor: Color
    public let scheme: ColorScheme

    public init(accentColor: Color = .accentColor, scheme: ColorScheme = .light) {
        self.accentColor = accentColor
        self.scheme = scheme
    }

    // Layout
    public var spacing: CGFloat { 14 }
    public var corner: CGFloat { 18 }
    public var smallCorner: CGFloat { 12 }
    public var elevation: CGFloat { 8 }

    // Colors
    public var accent: Color { accentColor }
    public var onAccent: Color { .white }

    // Surfaces
    public var cardBackground: Color {
        let accentUIColor = UIColor(accentColor)
        return Color(uiColor: UIColor { traits in
            let base = UIColor.secondarySystemBackground.resolvedColor(with: traits)
            let overlayAlpha: CGFloat = traits.userInterfaceStyle == .dark ? 0.06 : 0.03
            return base.blended(with: accentUIColor.resolvedColor(with: traits), alpha: overlayAlpha)
        })
    }

    public var separator: Color {
        Color(uiColor: UIColor { traits in
            let base = UIColor.separator.resolvedColor(with: traits)
            let alpha: CGFloat = traits.userInterfaceStyle == .dark ? 0.40 : 0.28
            return base.withAlphaComponent(alpha)
        })
    }

    public var pillTint: Color {
        accent.opacity(scheme == .dark ? 0.16 : 0.12)
    }

    // Background
    public var screenBackground: AnyShapeStyle {
        if scheme == .dark {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemBackground),
                        accent.opacity(0.08),
                        Color(uiColor: .secondarySystemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        accent.opacity(0.06),
                        Color(uiColor: .systemBackground),
                        Color(uiColor: .secondarySystemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

// MARK: - Tesla glass theme

public struct TeslaGlassTheme: AppThemeSpec {
    public let accentColor: Color
    public let scheme: ColorScheme

    public init(accentColor: Color = Color(red: 0.89, green: 0.12, blue: 0.18), scheme: ColorScheme = .dark) {
        self.accentColor = accentColor
        self.scheme = scheme
    }

    // Layout
    public var spacing: CGFloat { 14 }
    public var corner: CGFloat { 22 }
    public var smallCorner: CGFloat { 14 }
    public var elevation: CGFloat { 12 }

    // Colors
    public var accent: Color { accentColor }
    public var onAccent: Color { .white }

    // Surfaces
    public var cardBackground: Color {
        // Glassy, high-contrast surface with a subtle red cast in dark mode.
        let accentUIColor = UIColor(accentColor)
        return Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                let base = UIColor(white: 1.0, alpha: 0.08)
                return base.blended(with: accentUIColor.resolvedColor(with: traits), alpha: 0.08)
            } else {
                return UIColor(white: 1.0, alpha: 0.90)
            }
        })
    }

    public var separator: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(white: 1.0, alpha: 0.18)
            } else {
                return UIColor(white: 0.0, alpha: 0.10)
            }
        })
    }

    public var pillTint: Color {
        accent.opacity(scheme == .dark ? 0.20 : 0.16)
    }

    // Background
    public var screenBackground: AnyShapeStyle {
        if scheme == .dark {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.04, blue: 0.06),
                        Color(red: 0.02, green: 0.02, blue: 0.03),
                        Color(red: 0.01, green: 0.01, blue: 0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        accent.opacity(0.16),
                        Color(uiColor: .systemBackground),
                        Color(uiColor: .secondarySystemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

// MARK: - Compatibility aliases (avoid breaking older call-sites)

public typealias KWhClassicTheme = SystemTheme
public typealias KWhTeslaGlassTheme = TeslaGlassTheme

// Keep older name used in some files; this points to the glass aesthetic.
public typealias TeslaTheme = TeslaGlassTheme

// Optional: a second accent flavor if you still reference it elsewhere.
public struct RivianTheme: AppThemeSpec {
    public let accentColor: Color
    public let scheme: ColorScheme

    public init(accentColor: Color = Color(red: 0.00, green: 0.65, blue: 0.55), scheme: ColorScheme = .dark) {
        self.accentColor = accentColor
        self.scheme = scheme
    }

    public var spacing: CGFloat { 14 }
    public var corner: CGFloat { 20 }
    public var smallCorner: CGFloat { 12 }
    public var elevation: CGFloat { 9 }

    public var accent: Color { accentColor }
    public var onAccent: Color { .white }

    public var cardBackground: Color {
        let accentUIColor = UIColor(accentColor)
        return Color(uiColor: UIColor { traits in
            let base = UIColor.secondarySystemBackground.resolvedColor(with: traits)
            let overlayAlpha: CGFloat = traits.userInterfaceStyle == .dark ? 0.07 : 0.04
            return base.blended(with: accentUIColor.resolvedColor(with: traits), alpha: overlayAlpha)
        })
    }
    public var separator: Color {
        Color(uiColor: UIColor { traits in
            let base = UIColor.separator.resolvedColor(with: traits)
            let alpha: CGFloat = traits.userInterfaceStyle == .dark ? 0.42 : 0.30
            return base.withAlphaComponent(alpha)
        })
    }
    public var pillTint: Color { accent.opacity(scheme == .dark ? 0.18 : 0.12) }

    public var screenBackground: AnyShapeStyle {
        AnyShapeStyle(
            LinearGradient(
                colors: [
                    accent.opacity(scheme == .dark ? 0.10 : 0.16),
                    Color(uiColor: .systemBackground),
                    Color(uiColor: .secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - UIColor blending helper

private extension UIColor {
    func blended(with overlay: UIColor, alpha: CGFloat) -> UIColor {
        let alphaClamped = max(0, min(1, alpha))
        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0

        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        overlay.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let r = r1 + (r2 - r1) * alphaClamped
        let g = g1 + (g2 - g1) * alphaClamped
        let b = b1 + (b2 - b1) * alphaClamped
        let a = a1 + (a2 - a1) * alphaClamped

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
