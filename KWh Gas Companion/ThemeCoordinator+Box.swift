// Copyright Bryan Carroll. Made with Love in New York. All rights reserved. 2026.

//  ThemeCoordinator+Box.swift
//  My KWh Companion

import SwiftUI

public extension ThemeCoordinator {
    static func makeBox(
        style: ThemeStyle,
        accentColor: Color,
        scheme: ColorScheme
    ) -> AppThemeBox {
        ThemeCoordinator.makeThemeBox(style: style, accentColor: accentColor, scheme: scheme)
    }
}
