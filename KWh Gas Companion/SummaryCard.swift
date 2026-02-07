import SwiftUI

/// A simple, reusable card container with a title, optional footer, and custom content body.
///
/// Usage:
/// ```swift
/// SummaryCard(title: "Section Title", footer: "Optional footer") {
///     YourContentView()
/// }
/// ```
public struct SummaryCard<Content: View>: View {
    public enum Style {
        case material
        case plain(Color)
    }

    private let title: String
    private let footer: String?
    private let style: Style
    @ViewBuilder private let content: Content

    // MARK: - Init
    public init(title: String,
                footer: String? = nil,
                style: Style = .material,
                @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.style = style
        self.content = content()
    }

    // MARK: - Body
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
            if let footer = footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(padding: 16, corner: 20, surface: surfaceStyle)
    }

    // MARK: - Private helpers
    private var surfaceStyle: AnyShapeStyle {
        switch style {
        case .material:
            return AnyShapeStyle(.thinMaterial)
        case .plain(let color):
            return AnyShapeStyle(color)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct SummaryCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            SummaryCard(title: "Material Card", footer: "Tap to see more") {
                Text("Body content goes here")
            }
            .padding(.horizontal)

            SummaryCard(title: "Plain Card", footer: nil, style: .plain(Color.gray.opacity(0.15))) {
                VStack(alignment: .leading) {
                    Text("Custom body")
                    Text("Another line").font(.caption)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
        .environmentObject(AppUISettings())
    }
}
#endif
