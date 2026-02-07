//
//  TeslaOwnersClubView.swift
//  KWh Gas Companion / My KWh Companion
//
//  Fixes:
//  - .sheet(item:) now uses an Identifiable wrapper instead of URL directly
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import SafariServices

@MainActor
struct TeslaOwnersClubView: View {

    // MARK: - Links (edit as you like)

    private let links: [ClubLink] = [
        .init(title: "Tesla Owners Online",
              subtitle: "Community forums & discussions",
              url: URL(string: "https://teslaownersonline.com")!,
              icon: "person.3.fill"),
        .init(title: "Tesla Motors Club",
              subtitle: "Largest Tesla forum community",
              url: URL(string: "https://teslamotorsclub.com")!,
              icon: "bolt.car.fill"),
        .init(title: "Tesla Owners Club (Directory)",
              subtitle: "Find local owner groups",
              url: URL(string: "https://www.tesla.com/community")!,
              icon: "map.fill")
    ]

    // MARK: - State

    @State private var query: String = ""
    @State private var selectedURL: IdentifiedURL? = nil   // ✅ Identifiable wrapper

    var body: some View {
        NavigationStack {
            ZStack {
                BG().ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        headerCard
                            .padding(.horizontal)

                        SettingsCard(title: "Links") {
                            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Filtering by “\(query)”")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(spacing: 0) {
                                ForEach(filteredLinks) { link in
                                    Button {
                                        selectedURL = IdentifiedURL(link.url)
                                    } label: {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(Color.accentColor.opacity(0.12))
                                                    .frame(width: 40, height: 40)
                                                Image(systemName: link.icon)
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundStyle(Color.accentColor)
                                            }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(link.title).font(.callout.weight(.semibold))
                                                Text(link.subtitle).font(.footnote).foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            Label("Open", systemImage: "safari")
                                                .labelStyle(.titleAndIcon)
                                                .foregroundStyle(.secondary)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 10)

                                    if link.id != filteredLinks.last?.id {
                                        Divider().opacity(0.12)
                                    }
                                }
                            }
                        }
                        .padding([.horizontal, .bottom])
                        .padding(.bottom, 24)
                    }
                    .searchable(text: $query,
                                placement: .navigationBarDrawer(displayMode: .always),
                                prompt: "Search links")
                }
            }
            .navigationTitle("Tesla Owners Club")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedURL) { item in
                SafariSheet(url: item.url)
            }
        }
    }

    private var filteredLinks: [ClubLink] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return links }
        return links.filter { l in
            l.title.lowercased().contains(q) ||
            l.subtitle.lowercased().contains(q) ||
            l.url.absoluteString.lowercased().contains(q)
        }
    }

    private var headerCard: some View {
        SettingsCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial).frame(width: 54, height: 54)
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tesla Owners Club")
                        .font(.title3.weight(.semibold))
                    Text("Tap a link to open it in an in-app Safari sheet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Models

private struct ClubLink: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let url: URL
    let icon: String
}

/// ✅ URL wrapper for `.sheet(item:)`
private struct IdentifiedURL: Identifiable, Hashable {
    let url: URL
    var id: String { url.absoluteString }
    init(_ url: URL) { self.url = url }
}

// MARK: - Safari Sheet

private struct SafariSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.dismissButtonStyle = .close
        return vc
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Simple styling shells (file-local)

private struct BG: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark ? [Color.black, Color(white: 0.12)] : [Color(white: 0.98), Color(white: 0.92)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct SettingsCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title).font(.headline)
            }
            content
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

#Preview {
    TeslaOwnersClubView()
}
