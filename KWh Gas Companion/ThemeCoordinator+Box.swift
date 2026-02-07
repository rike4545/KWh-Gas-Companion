//  ThemeCoordinator+Box.swift
//  My KWh Companion
//
//  Lightweight adapter so .box is available on ThemeCoordinator without
//  redefining any environment keys or types.

import SwiftUI

public extension ThemeCoordinator {
    /// Convenience wrapper to build an AppThemeBox from inputs.
    static func makeBox(uiStyleRaw: String, accentColor: Color, scheme: ColorScheme) -> AppThemeBox {
        ThemeCoordinator.makeThemeBox(uiStyleRaw: uiStyleRaw, accentColor: accentColor, scheme: scheme)
    }
}
