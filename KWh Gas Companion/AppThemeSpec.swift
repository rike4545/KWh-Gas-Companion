// Copyright Bryan Carroll. Made with Love in New York. All rights reserved. 2026.

//
//  AppThemeSpec.swift
//  My KWh Companion
//
//  Minimal theme core (iOS 17+ / Swift 6)
//  - Provides an AppThemeSpec protocol
//  - Stores the active theme in Environment via AppThemeBox
//  - Includes a DefaultAppTheme that follows system light/dark mode
//

import SwiftUI

// MARK: - Core Theme Protocol

public protocol AppThemeSpec: Sendable {
    // Layout
    var spacing: CGFloat { get }
    var corner: CGFloat { get }
    var smallCorner: CGFloat { get }
    var elevation: CGFloat { get }

    // Colors
    var accent: Color { get }
    var onAccent: Color { get }

    // Surfaces
    var cardBackground: Color { get }
    var separator: Color { get }
    var pillTint: Color { get }

    // Screen background (as a ShapeStyle)
    var screenBackground: AnyShapeStyle { get }
}

// MARK: - Environment Container

public struct AppThemeBox: Sendable {
    public let base: any AppThemeSpec
    public init(base: any AppThemeSpec) { self.base = base }
}

private struct AppThemeKey: EnvironmentKey {
    static var defaultValue: AppThemeBox = AppThemeBox(base: DefaultAppTheme())
}

public extension EnvironmentValues {
    var appThemeBox: AppThemeBox {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

// MARK: - View helpers

public extension View {
    /// Applies a theme by writing it to the environment and setting `.tint` to its accent color.
    func appTheme(_ theme: some AppThemeSpec) -> some View {
        appThemeBox(AppThemeBox(base: theme))
    }

    /// Convenience overload for cases where you already have an `AppThemeBox`.
    /// This prevents the common mistake of calling `.appTheme(box)` (which would otherwise fail to compile).
    func appTheme(_ box: AppThemeBox) -> some View {
        appThemeBox(box)
    }

    /// Applies a theme box (Environment) and updates `.tint` using the theme’s accent.
    func appThemeBox(_ box: AppThemeBox) -> some View {
        self.environment(\.appThemeBox, box)
            .tint(box.base.accent)
    }
}

// MARK: - Default Theme (classic, system-respecting)

public struct DefaultAppTheme: AppThemeSpec {

    public init() {}

    // Layout
    public var spacing: CGFloat { 14 }
    public var corner: CGFloat { 16 }
    public var smallCorner: CGFloat { 10 }
    public var elevation: CGFloat { 5 }

    // Colors
    /// Intentionally uses `.accentColor` so the app can control accent globally via `.tint(...)`.
    public var accent: Color { .accentColor }
    public var onAccent: Color { .white }

    // Surfaces
    public var cardBackground: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.08, green: 0.11, blue: 0.15, alpha: 1.0)
            }
            return UIColor(red: 0.985, green: 0.99, blue: 1.0, alpha: 1.0)
        })
    }

    public var separator: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(white: 1.0, alpha: 0.10)
            }
            return UIColor(red: 0.78, green: 0.82, blue: 0.88, alpha: 0.82)
        })
    }

    public var pillTint: Color { accent.opacity(0.14) }

    // Background
    public var screenBackground: AnyShapeStyle {
        AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color(uiColor: UIColor { traits in
                        traits.userInterfaceStyle == .dark
                            ? UIColor(red: 0.045, green: 0.065, blue: 0.095, alpha: 1.0)
                            : UIColor(red: 0.955, green: 0.97, blue: 0.995, alpha: 1.0)
                    }),
                    Color(uiColor: UIColor { traits in
                        traits.userInterfaceStyle == .dark
                            ? UIColor(red: 0.07, green: 0.10, blue: 0.14, alpha: 1.0)
                            : UIColor(red: 0.92, green: 0.95, blue: 0.985, alpha: 1.0)
                    }),
                    accent.opacity(0.055)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
