import SwiftUI

private struct AdsInlineEnabledKey: EnvironmentKey {
    static var defaultValue: Bool = false
}

extension EnvironmentValues {
    var adsInlineEnabled: Bool {
        get { self[AdsInlineEnabledKey.self] }
        set { self[AdsInlineEnabledKey.self] = newValue }
    }
}
