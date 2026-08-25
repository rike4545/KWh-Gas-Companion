// Copyright Bryan Carroll. Made with Love in New York. All rights reserved. 2026.

import SwiftUI

public enum TypographyMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case classic
    case bold
    case compact

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .classic: return "Classic"
        case .bold: return "Bold"
        case .compact: return "Compact"
        }
    }
}

public enum CardStyleMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case flat
    case elevated
    case glass

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .flat: return "Flat"
        case .elevated: return "Elevated"
        case .glass: return "Glass"
        }
    }
}

public enum DensityMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case comfortable
    case compact

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .comfortable: return "Comfortable"
        case .compact: return "Compact"
        }
    }
}

public enum CardCornerMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case crisp
    case rounded
    case soft

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .crisp: return "Crisp"
        case .rounded: return "Rounded"
        case .soft: return "Soft"
        }
    }

    public var multiplier: CGFloat {
        switch self {
        case .crisp: return 0.85
        case .rounded: return 1.0
        case .soft: return 1.2
        }
    }
}

public enum CardPaddingMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case tight
    case standard
    case roomy

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .tight: return "Tight"
        case .standard: return "Standard"
        case .roomy: return "Roomy"
        }
    }

    public var multiplier: CGFloat {
        switch self {
        case .tight: return 0.85
        case .standard: return 1.0
        case .roomy: return 1.15
        }
    }
}

public enum MotionMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case full
    case reduced
    case none

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .full: return "Full"
        case .reduced: return "Reduced"
        case .none: return "None"
        }
    }
}

public enum BackgroundStyle: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case defaultGlow
    case aurora
    case dusk
    case carbon
    case blackHistoryMonth
    case christmas
    case lunarNewYear
    case halloween
    case thanksgiving
    case newYear

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .defaultGlow: return "Default"
        case .aurora: return "Aurora"
        case .dusk: return "Dusk"
        case .carbon: return "Carbon"
        case .blackHistoryMonth: return "Black History Month"
        case .christmas: return "Christmas"
        case .lunarNewYear: return "Chinese New Year"
        case .halloween: return "Halloween"
        case .thanksgiving: return "Thanksgiving"
        case .newYear: return "New Year"
        }
    }
}

public enum HapticsLevel: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case off
    case low
    case standard

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .off: return "Off"
        case .low: return "Low"
        case .standard: return "Standard"
        }
    }
}

@MainActor
public final class AppUISettings: ObservableObject {
    private enum Keys {
        static let typography = "ui.typography"
        static let cardStyle = "ui.cardStyle"
        static let density = "ui.density"
        static let cardCorner = "ui.cardCorner"
        static let cardPadding = "ui.cardPadding"
        static let motion = "ui.motion"
        static let background = "ui.backgroundStyle"
        static let haptics = "ui.hapticsLevel"
    }

    private let defaults: UserDefaults

    @Published public var typography: TypographyMode {
        didSet { defaults.set(typography.rawValue, forKey: Keys.typography) }
    }
    @Published public var cardStyle: CardStyleMode {
        didSet { defaults.set(cardStyle.rawValue, forKey: Keys.cardStyle) }
    }
    @Published public var density: DensityMode {
        didSet { defaults.set(density.rawValue, forKey: Keys.density) }
    }
    @Published public var cardCorner: CardCornerMode {
        didSet { defaults.set(cardCorner.rawValue, forKey: Keys.cardCorner) }
    }
    @Published public var cardPadding: CardPaddingMode {
        didSet { defaults.set(cardPadding.rawValue, forKey: Keys.cardPadding) }
    }
    @Published public var motion: MotionMode {
        didSet { defaults.set(motion.rawValue, forKey: Keys.motion) }
    }
    @Published public var background: BackgroundStyle {
        didSet { defaults.set(background.rawValue, forKey: Keys.background) }
    }
    @Published public var haptics: HapticsLevel {
        didSet { defaults.set(haptics.rawValue, forKey: Keys.haptics) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedTypography = defaults.string(forKey: Keys.typography).flatMap(TypographyMode.init(rawValue:))
        let storedCard = defaults.string(forKey: Keys.cardStyle).flatMap(CardStyleMode.init(rawValue:))
        let storedDensity = defaults.string(forKey: Keys.density).flatMap(DensityMode.init(rawValue:))
        let storedCorner = defaults.string(forKey: Keys.cardCorner).flatMap(CardCornerMode.init(rawValue:))
        let storedPadding = defaults.string(forKey: Keys.cardPadding).flatMap(CardPaddingMode.init(rawValue:))
        let storedMotion = defaults.string(forKey: Keys.motion).flatMap(MotionMode.init(rawValue:))
        let storedBackground = defaults.string(forKey: Keys.background).flatMap(BackgroundStyle.init(rawValue:))
        let storedHaptics = defaults.string(forKey: Keys.haptics).flatMap(HapticsLevel.init(rawValue:))

        self.typography = storedTypography ?? .classic
        self.cardStyle = storedCard ?? .flat
        self.density = storedDensity ?? .comfortable
        self.cardCorner = storedCorner ?? .rounded
        self.cardPadding = storedPadding ?? .standard
        self.motion = storedMotion ?? .reduced
        self.background = storedBackground ?? .defaultGlow
        self.haptics = storedHaptics ?? .standard
    }

    public var spacingMultiplier: CGFloat {
        density == .compact ? 0.85 : 1.0
    }

    public var cardCornerMultiplier: CGFloat {
        cardCorner.multiplier
    }

    public var cardPaddingMultiplier: CGFloat {
        cardPadding.multiplier
    }

    public var shadowMultiplier: Double {
        switch cardStyle {
        case .flat: return 0.0
        case .elevated: return 1.15
        case .glass: return 0.85
        }
    }

    public var borderOpacity: Double {
        switch cardStyle {
        case .flat: return 0.40
        case .elevated: return 0.70
        case .glass: return 0.55
        }
    }

    public func resetToDefaults() {
        defaults.removeObject(forKey: Keys.typography)
        defaults.removeObject(forKey: Keys.cardStyle)
        defaults.removeObject(forKey: Keys.density)
        defaults.removeObject(forKey: Keys.cardCorner)
        defaults.removeObject(forKey: Keys.cardPadding)
        defaults.removeObject(forKey: Keys.motion)
        defaults.removeObject(forKey: Keys.background)
        defaults.removeObject(forKey: Keys.haptics)

        typography = .classic
        cardStyle = .flat
        density = .comfortable
        cardCorner = .rounded
        cardPadding = .standard
        motion = .reduced
        background = .defaultGlow
        haptics = .standard
    }
}
