import SwiftUI

/// Global polish that applies motion + scroll behavior consistently.
struct AppPolishModifier: ViewModifier {
    @EnvironmentObject private var uiSettings: AppUISettings

    func body(content: Content) -> some View {
        content
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .transaction { tx in
                switch uiSettings.motion {
                case .none:
                    tx.animation = nil
                    tx.disablesAnimations = true
                case .reduced:
                    tx.animation = nil
                    tx.disablesAnimations = true
                case .full:
                    tx.animation = .snappy(duration: 0.25)
                    tx.disablesAnimations = false
                }
            }
    }
}

extension View {
    func appPolish() -> some View {
        modifier(AppPolishModifier())
    }
}
