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
    public var corner: CGFloat { 18 }
    public var smallCorner: CGFloat { 12 }
    public var elevation: CGFloat { 8 }

    // Colors
    /// Intentionally uses `.accentColor` so the app can control accent globally via `.tint(...)`.
    public var accent: Color { .accentColor }
    public var onAccent: Color { .white }

    // Surfaces
    public var cardBackground: Color { Color(uiColor: .secondarySystemBackground) }
    public var separator: Color { Color(uiColor: .separator).opacity(0.55) }
    public var pillTint: Color { accent.opacity(0.14) }

    // Background
    public var screenBackground: AnyShapeStyle {
        AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground),
                    Color(uiColor: .secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
