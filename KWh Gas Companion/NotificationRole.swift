//
//  NotificationRole.swift
//  My KWh Companion
//
//  Swift 6 / iOS 17+
//
//  - No DesignTokens dependency
//  - Public enum + views (use anywhere in the app)
//  - Safe ForEach over array (no Range<Int> confusion)
//  - Lightweight FlowLayout for chip-style wrapping
//

import SwiftUI

// MARK: - Role Model

public enum NotificationRole: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case guest
    case qvip
    case staff
    case ops

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .guest: return "Guest"
        case .qvip:  return "QVIP"
        case .staff: return "Staff"
        case .ops:   return "Ops"
        }
    }

    public var symbol: String {
        switch self {
        case .guest: return "person"
        case .qvip:  return "star"
        case .staff: return "wrench.and.screwdriver"
        case .ops:   return "lock.shield"
        }
    }

    public var tint: Color {
        switch self {
        case .guest: return .blue
        case .qvip:  return .purple
        case .staff: return .orange
        case .ops:   return .red
        }
    }
}

// MARK: - Badge

@MainActor
public struct NotificationRoleBadge: View {
    public let role: NotificationRole
    public init(role: NotificationRole) { self.role = role }

    public var body: some View {
        Label {
            Text(role.displayName)
                .font(.caption.weight(.semibold))
        } icon: {
            Image(systemName: role.symbol)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(role.tint.opacity(0.12), in: Capsule())
        .foregroundStyle(role.tint)
        .accessibilityLabel(Text("\(role.displayName) role"))
    }
}

// MARK: - Role Picker (multi-select, with optional admin gating)

@MainActor
public struct NotificationRolePicker: View {
    @Binding private var selection: Set<NotificationRole>
    private let isAdminUnlocked: Bool
    private let title: String

    public init(
        selection: Binding<Set<NotificationRole>>,
        isAdminUnlocked: Bool = false,
        title: String = "Roles"
    ) {
        self._selection = selection
        self.isAdminUnlocked = isAdminUnlocked
        self.title = title
    }

    private var visibleRoles: [NotificationRole] {
        NotificationRole.allCases.filter { role in
            switch role {
            case .staff, .ops: return isAdminUnlocked
            default: return true
            }
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            FlowLayout(spacing: 8) {
                ForEach(visibleRoles, id: \.self) { role in
                    Toggle(isOn: Binding(
                        get: { selection.contains(role) },
                        set: { isOn in
                            if isOn { selection.insert(role) }
                            else { selection.remove(role) }
                        })
                    ) {
                        HStack(spacing: 6) {
                            Image(systemName: role.symbol)
                            Text(role.displayName)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(
                                selection.contains(role)
                                ? role.tint.opacity(0.20)
                                : Color.secondary.opacity(0.12)
                            )
                        )
                        .foregroundStyle(selection.contains(role) ? role.tint : .primary)
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(role.displayName))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Lightweight Flow Layout (chips wrap)
// Use like: FlowLayout(spacing: 8) { ...your chip views... }

public struct FlowLayout: Layout {
    public let spacing: CGFloat

    public init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        var availableWidth = proposal.width ?? UIScreen.main.bounds.width - 32
        if availableWidth <= 0 {
            availableWidth = UIScreen.main.bounds.width - 32
        }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > availableWidth {
                // wrap to next line
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: availableWidth, height: y + rowHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                // wrap to next line
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Optional convenience for common defaults

public extension Set where Element == NotificationRole {
    static var defaultPublic: Set<NotificationRole> { [.guest, .qvip] }
    static var staffOnly: Set<NotificationRole> { [.staff] }
    static var opsOnly: Set<NotificationRole> { [.ops] }
    static var allUnlocked: Set<NotificationRole> { Set(NotificationRole.allCases) }
}
