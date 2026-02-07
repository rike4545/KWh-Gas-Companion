import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Small pill-style toast bubble.
struct PanelToastBubble: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.callout) // respects Dynamic Type
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(radius: 4)
            .accessibilityLabel("Notification: \(message)")
            .allowsHitTesting(false)
    }
}

/// Reusable toast modifier.
/// Usage:
///   .modifier(PanelToastModifier(isPresented: $isToastPresented, text: toastMessage))
/// or:
///   .panelToast(isPresented: $isToastPresented, text: toastMessage)
struct PanelToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let text: String
    /// Optional auto-dismiss duration; set to nil to keep until caller hides.
    var autoDismissAfter: TimeInterval? = 1.8

    @State private var keepMounted = false
    @State private var textIdentity = UUID() // triggers transition when text changes

    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if keepMounted {
                    PanelToastBubble(message: text)
                        .id(textIdentity) // animate on content change
                        .padding(.horizontal, 16)
                        .padding(.bottom, safeBottomPadding)
                        .transition(transition)
                        .onAppear {
                            announceAccessibility(text)
                            scheduleAutoDismissIfNeeded()
                        }
                        .onChange(of: text) { _, newValue in
                            // retrigger transition for new text while shown
                            textIdentity = UUID()
                            announceAccessibility(newValue)
                            scheduleAutoDismissIfNeeded() // restart timer on new text
                        }
                }
            }
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    keepMounted = true
                    scheduleAutoDismissIfNeeded()
                } else {
                    unmountAfterAnimation()
                }
            }
            .onAppear { keepMounted = isPresented }
            .animation(animation, value: isPresented)
    }

    // MARK: - Helpers

    private var animation: Animation {
        reduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: 0.25)
    }

    private var transition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    private var safeBottomPadding: CGFloat {
        // A bit more breathing room above the home indicator
        24
    }

    private func unmountAfterAnimation() {
        let delay = reduceMotion ? 0.01 : 0.25
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            keepMounted = false
        }
    }

    private func scheduleAutoDismissIfNeeded() {
        guard isPresented, let seconds = autoDismissAfter, seconds > 0 else { return }
        let token = textIdentity
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            // Only dismiss if the same toast instance is still visible
            if token == textIdentity { isPresented = false }
        }
    }

    private func announceAccessibility(_ message: String) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }
}

extension View {
    /// Convenience wrapper for the toast modifier.
    func panelToast(
        isPresented: Binding<Bool>,
        text: String,
        autoDismissAfter: TimeInterval? = 1.8
    ) -> some View {
        self.modifier(PanelToastModifier(isPresented: isPresented, text: text, autoDismissAfter: autoDismissAfter))
    }
}
