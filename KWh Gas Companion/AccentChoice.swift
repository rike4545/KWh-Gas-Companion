//  AppAppearance.swift
//  KWh Gas Companion
//
//  App-wide appearance model (accent + light/dark/auto).
//

import SwiftUI

public enum AccentChoice: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case blue, indigo, purple, pink, red, orange, yellow, green, mint, teal, cyan, gray

    public var id: String { rawValue }

    public var title: String { rawValue.capitalized }

    public var color: Color {
        switch self {
        case .blue:   return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink:   return .pink
        case .red:    return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green:  return .green
        case .mint:   return .mint
        case .teal:   return .teal
        case .cyan:   return .cyan
        case .gray:   return .gray
        }
    }
}

@MainActor
public final class AppAppearance: ObservableObject {

    private enum Keys {
        static let scheme = "appearance.scheme"
        static let accent = "appearance.accent"
    }

    /// Stored raw values
    private let defaults: UserDefaults

    @Published public var scheme: AppearanceMode {
        didSet { defaults.set(scheme.rawValue, forKey: Keys.scheme) }
    }

    @Published public var accentChoice: AccentChoice {
        didSet {
            defaults.set(accentChoice.rawValue, forKey: Keys.accent)
            accentColor = accentChoice.color
        }
    }

    /// What views should use for tinting
    @Published public var accentColor: Color

    /// Convenience for root view
    public var preferredColorScheme: ColorScheme? { scheme.preferredColorScheme }

    /// IMPORTANT: keep this no-arg init so `AppAppearance()` in previews compiles.
    public init(
        accentColor: Color = .accentColor,
        scheme: AppearanceMode = .automatic,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults

        // Load persisted values (if any)
        let storedScheme = defaults.string(forKey: Keys.scheme).flatMap(AppearanceMode.init(rawValue:))
        let storedAccent = defaults.string(forKey: Keys.accent).flatMap(AccentChoice.init(rawValue:))

        let resolvedScheme = storedScheme ?? scheme
        // Default to blue to match the Tesla default look; explicit user choices persist and win.
        let resolvedAccent = storedAccent ?? .blue

        self.scheme = resolvedScheme
        self.accentChoice = resolvedAccent
        self.accentColor = resolvedAccent.color

        // If caller explicitly passed a non-default accent, honor it (won’t persist unless user picks it).
        if accentColor != Color.accentColor && storedAccent == nil {
            self.accentColor = accentColor
        }
    }

    public func resetToDefaults() {
        defaults.removeObject(forKey: Keys.scheme)
        defaults.removeObject(forKey: Keys.accent)
        scheme = .automatic
        accentChoice = .blue
        accentColor = accentChoice.color
    }
}
