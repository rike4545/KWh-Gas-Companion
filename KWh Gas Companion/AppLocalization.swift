// Copyright Bryan Carroll. Made with Love in New York. All rights reserved. 2026.

import Foundation

enum AppMarket: String, CaseIterable, Identifiable, Sendable {
    case unitedStates = "us"
    case chinaMainland = "cn"
    case canada = "ca"
    case japan = "jp"
    case singapore = "sg"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unitedStates: return "United States"
        case .chinaMainland: return "China Mainland"
        case .canada: return "Canada"
        case .japan: return "Japan"
        case .singapore: return "Singapore"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .unitedStates: return "en_US"
        case .chinaMainland: return "zh_Hans_CN"
        case .canada: return "en_CA"
        case .japan: return "ja_JP"
        case .singapore: return "en_SG"
        }
    }

    var locale: Locale {
        Locale(identifier: localeIdentifier)
    }

    var currencyCode: String {
        switch self {
        case .unitedStates: return "USD"
        case .chinaMainland: return "CNY"
        case .canada: return "CAD"
        case .japan: return "JPY"
        case .singapore: return "SGD"
        }
    }

    var usesMetricUnits: Bool {
        switch self {
        case .unitedStates: return false
        case .chinaMainland, .canada, .japan, .singapore: return true
        }
    }

    var defaultDistanceUnit: DistanceUnit {
        usesMetricUnits ? .kilometers : .miles
    }
}

enum AppLocalization {
    enum Keys {
        static let marketRaw = "app.localization.market"
        static let autoApplyMarketDefaults = "app.localization.autoApplyDefaults"
        static let lastAppliedMarketRaw = "app.localization.lastAppliedMarket"
    }

    static func inferredMarket(from locale: Locale = .autoupdatingCurrent) -> AppMarket {
        let region = locale.region?.identifier.uppercased() ?? ""

        switch region {
        case "CN": return .chinaMainland
        case "CA": return .canada
        case "JP": return .japan
        case "SG": return .singapore
        default: return .unitedStates
        }
    }

    static func market(fromRaw raw: String?) -> AppMarket {
        if let raw = raw?.trimmedNonEmpty, let parsed = AppMarket(rawValue: raw) {
            return parsed
        }
        return inferredMarket()
    }

    static var selectedMarket: AppMarket {
        market(fromRaw: UserDefaults.standard.string(forKey: Keys.marketRaw))
    }

    static var locale: Locale {
        selectedMarket.locale
    }

    static var currencyCode: String {
        if let stored = UserDefaults.standard.string(forKey: "currencyCode")?.trimmedNonEmpty {
            return stored.uppercased()
        }
        return selectedMarket.currencyCode
    }

    static var usesMetricUnits: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "settings.useMetric") != nil {
            return defaults.bool(forKey: "settings.useMetric")
        }
        return selectedMarket.usesMetricUnits
    }

    @MainActor
    static func applyMarketDefaults(_ market: AppMarket, profileStore: ProfileStore? = nil) {
        let defaults = UserDefaults.standard
        defaults.set(market.rawValue, forKey: Keys.marketRaw)
        defaults.set(market.currencyCode, forKey: "currencyCode")
        defaults.set(market.usesMetricUnits, forKey: "settings.useMetric")
        defaults.set(market.defaultDistanceUnit.rawValue, forKey: "settings.distanceUnit")
        defaults.set(market.rawValue, forKey: Keys.lastAppliedMarketRaw)

        profileStore?.currencyCode = market.currencyCode
    }
}
