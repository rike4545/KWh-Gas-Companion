import SwiftUI

private struct AdsInlineEnabledKey: EnvironmentKey {
    static var defaultValue: Bool = true
}

extension EnvironmentValues {
    var adsInlineEnabled: Bool {
        get { self[AdsInlineEnabledKey.self] }
        set { self[AdsInlineEnabledKey.self] = newValue }
    }
}
