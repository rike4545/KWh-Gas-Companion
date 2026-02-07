//
//  NoticeRole.swift
//  My KWh Companion
//
//  Swift 6 / iOS 17+
//
//  Notices filtered by role, with a simple adaptive chip layout and safe material usage.
//  - No external themes/tokens
//  - No custom result-builder layouts (avoids control-flow-in-ViewBuilder errors)
//  - Empty state is uniquely named to avoid collisions
//

import SwiftUI

// MARK: - Roles

enum NoticeRole: String, CaseIterable, Identifiable {
    case guest, qvip, staff, ops

    var id: String { rawValue }

    var title: String {
        switch self {
        case .guest: return "Guest"
        case .qvip:  return "QVIP"
        case .staff: return "Staff"
        case .ops:   return "Ops"
        }
    }

    var color: Color {
        switch self {
        case .guest: return .blue
        case .qvip:  return .purple
        case .staff: return .orange
        case .ops:   return .red
        }
    }
}

// MARK: - Model

struct NoticeItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let message: String
    let role: NoticeRole
    let date: Date
}

// MARK: - View

@MainActor
struct NoticeRoleView: View {

    // Replace this with your real store/source
    @State private var allNotices: [NoticeItem] = sampleNotices()

    // Default visibility: show guest + qvip
    @State private var selectedRoles: Set<NoticeRole> = [.guest, .qvip]

    @State private var query: String = ""

    // Adaptive chips (simple, compile-safe)
    private var chipColumns: [GridItem] = Array(
        repeating: GridItem(.adaptive(minimum: 100), spacing: 8, alignment: .leading),
        count: 1
    )

    var body: some View {
        VStack(spacing: 16) {

            // Role chips (adaptive grid)
            VStack(alignment: .leading, spacing: 8) {
                Text("Visible Roles")
                    .font(.headline)

                LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 8) {
                    ForEach(NoticeRole.allCases) { role in
                        let isOn = selectedRoles.contains(role)
                        Button {
                            if isOn { selectedRoles.remove(role) } else { selectedRoles.insert(role) }
                        } label: {
                            HStack(spacing: 8) {
                                Circle().fill(role.color).frame(width: 8, height: 8)
                                Text(role.title)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(isOn ? role.color.opacity(0.15) : Color.secondary.opacity(0.10))
                            )
                            .overlay(
                                Capsule().strokeBorder(isOn ? role.color.opacity(0.6) : Color.secondary.opacity(0.25))
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(role.title) role filter")
                        .accessibilityAddTraits(isOn ? [.isSelected] : [])
                    }
                }
            }

            // Search
            TextField("Search notices", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )

            // List or Empty
            let filtered = filteredNotices()
            if filtered.isEmpty {
                NoticeEmptyStateView(
                    systemImage: "bell.slash",
                    title: "No Notices",
                    message: "Try changing selected roles or clearing the search."
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filtered) { item in
                            NoticeRow(item: item)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .navigationTitle("Notices")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        )
    }

    // MARK: - Helpers

    private func filteredNotices() -> [NoticeItem] {
        var base = allNotices.filter { selectedRoles.contains($0.role) }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            base = base.filter {
                $0.title.lowercased().contains(q) || $0.message.lowercased().contains(q)
            }
        }
        return base.sorted { $0.date > $1.date }
    }
}

// MARK: - Subviews

fileprivate struct NoticeRow: View {
    let item: NoticeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(item.role.color).frame(width: 8, height: 8)
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(shortDate(item.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(item.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            // ✅ Correct material usage (works on iOS 15+)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.05))
        )
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: d)
    }
}

/// Unique name to avoid collisions with any other EmptyStateView in the project.
fileprivate struct NoticeEmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}

// MARK: - Sample data

fileprivate func sampleNotices() -> [NoticeItem] {
    [
        NoticeItem(title: "Welcome", message: "Thanks for trying My KWh Companion!", role: .guest, date: Date().addingTimeInterval(-3600)),
        NoticeItem(title: "QVIP Lounge", message: "Exclusive pre-release features available.", role: .qvip, date: Date().addingTimeInterval(-7200)),
        NoticeItem(title: "Shift Queue", message: "3 entries awaiting review.", role: .staff, date: Date().addingTimeInterval(-10800)),
        NoticeItem(title: "Ops Alert", message: "Background task schedule updated.", role: .ops, date: Date().addingTimeInterval(-14400))
    ]
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        NoticeRoleView()
    }
}
#endif
