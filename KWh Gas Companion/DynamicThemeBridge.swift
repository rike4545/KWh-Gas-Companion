import SwiftUI

/// Keeps a provided AppThemeBox in sync with the SwiftUI environment.
private struct _DynamicThemeEnv: ViewModifier {
    let box: AppThemeBox
    func body(content: Content) -> some View {
        content
            .environment(\.appThemeBox, box)
            .tint(box.base.accent)
    }
}

public extension View {
    /// Convenience wrapper used across the app and previews.
    func applyDynamicTheme(_ box: AppThemeBox) -> some View {
        modifier(_DynamicThemeEnv(box: box))
    }
}
