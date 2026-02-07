//
//  AppearanceMode.swift
//  KWh Gas Companion
//

import SwiftUI

public enum AppearanceMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case automatic
    case light
    case dark

    // Back-compat alias (so `.system` compiles if you used it earlier)
    public static var system: AppearanceMode { .automatic }

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .light:     return "Light"
        case .dark:      return "Dark"
        }
    }

    public var preferredColorScheme: ColorScheme? {
        switch self {
        case .automatic: return nil
        case .light:     return .light
        case .dark:      return .dark
        }
    }
}
