//
//  EVNewsView.swift
//  MyKWh Companion
//
//  Theme-aware (AppThemeSpec + AppAppearance), safe URL handling,
//  favorites + search preserved, and optional Easter-egg coin in the toolbar.
//

import SwiftUI
import SafariServices
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Model

private enum EVCategory: String, CaseIterable, Identifiable {
    case news = "News"
    case trackers = "Forums"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .news:
            return "newspaper"
        case .trackers:
            return "point.bottomleft.forward.to.point.topright.scurvepath"
        }
    }
}

private struct EVLink: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let category: EVCategory
    let symbol: String
}

// MARK: - Settings keys (mirrors SettingsView)

private enum EVUIStyle: String {
    case classic
    case teslaGlass
}

// MARK: - URL Utilities

private func normalizedURL(_ raw: String) -> URL? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if let u = URL(string: trimmed), u.scheme != nil { return u }
    return URL(string: "https://\(trimmed)")
}

// MARK: - View

@MainActor
struct EVNewsView: View {
    // Settings-driven
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL
    @Environment(\.appThemeBox) private var themeBox
    @EnvironmentObject private var appearance: AppAppearance

    @AppStorage("uiStyle") private var uiStyleRaw: String = "teslaGlass"
    private var uiStyle: EVUIStyle { EVUIStyle(rawValue: uiStyleRaw) ?? .classic }

    // Persisted favorites (by name) as a simple "|" delimited string
    @AppStorage("EVNewsFavorites") private var favoritesRaw: String = ""

    @State private var searchText: String = ""
    @State private var safariItem: EVWebItem?
    @State private var shareItem: EVShareItem?
    @State private var toast: String?

    // Base data (all URLs normalized safely)
    private let allLinks: [EVLink] = {
        var items: [EVLink] = []

        func add(_ name: String, _ raw: String, _ cat: EVCategory, _ symbol: String) {
            if let u = normalizedURL(raw) {
                items.append(EVLink(name: name, url: u, category: cat, symbol: symbol))
            }
        }

        // News
        add("InsideEVs", "https://insideevs.com/", .news, "bolt.car")
        add("Electrek", "https://electrek.co/", .news, "bolt")
        add("TorqueNews", "https://www.torquenews.com/", .news, "globe")
        add("Not a Tesla App", "https://www.notateslaapp.com/", .news, "app.badge.checkmark")
        add("Teslarati", "https://www.teslarati.com/", .news, "app.badge.checkmark")
        add("Tesla Media Relations", "https://ir.tesla.com/press", .news, "app.badge.checkmark")
        
        // Forums / Community
        add("Rivian Trackr Forum", "https://riviantrackr.com/", .trackers, "text.bubble")
        add("TMC Forum", "https://teslamotorsclub.com/tmc/", .trackers, "text.bubble.fill")

        return items
    }()

    // Read-only favorites set
    private var favorites: Set<String> {
        Set(favoritesRaw.split(separator: "|").map(String.init))
    }

    // Writer for favorites
    private func setFavorites(_ new: Set<String>) {
        favoritesRaw = new.sorted().joined(separator: "|")
    }

    private var filteredLinks: [EVLink] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allLinks }
        return allLinks.filter {
            $0.name.lowercased().contains(q) ||
            $0.category.rawValue.lowercased().contains(q)
        }
    }

    // Group by category; show "Favorites" pseudo-section if any are set
    private var grouped: [(title: String, symbol: String, links: [EVLink])] {
        var buckets: [(String, String, [EVLink])] = []
        let favNames = favorites

        let favs = filteredLinks.filter { favNames.contains($0.name) }
        if !favs.isEmpty {
            buckets.append(("Favorites", "star.fill", favs.sorted { $0.name < $1.name }))
        }

        for cat in EVCategory.allCases {
            let items = filteredLinks.filter { $0.category == cat && !favNames.contains($0.name) }
            if !items.isEmpty {
                buckets.append((cat.rawValue, cat.symbol, items.sorted { $0.name < $1.name }))
            }
        }
        return buckets
    }

    var body: some View {
        let theme = themeBox.base

        NavigationStack {
            ZStack {
                evBackground(theme: theme)

                List {
                    // Optional “hero” intro card (keeps the screen from looking empty)
                    Section {
                        headerCard(theme: theme)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }

                    ForEach(grouped, id: \.title) { group in
                        Section {
                            ForEach(group.links) { link in
                                EVNewsRow(
                                    link: link,
                                    isFavorite: favorites.contains(link.name),
                                    openInApp: { openInApp(link.url) },
                                    openSystem: { openSystem(link.url) },
                                    share: { shareItem = .init(items: [link.url]) },
                                    toggleFavorite: { toggleFavorite(named: link.name) }
                                )
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        } header: {
                            HStack(spacing: 8) {
                                Image(systemName: group.symbol)
                                    .foregroundStyle(appearance.accentColor)
                                Text(group.title)
                                    .font(.headline)
                            }
                            .textCase(nil)
                        }
                    }

                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("EV News & Forums")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer,
                prompt: Text("Search links")
            )
            .tint(appearance.accentColor)

            // Optional easter egg coin (requires EasterEggCoinButton.swift in target)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EasterEggCoinButton(
                        hingedAssetName: "hingedpic",
                        unhingedAssetName: "unhingedpic",
                        size: 34
                    )
                    .accessibilityLabel("Easter egg coin")
                }
            }

            // In-app Safari sheet
            .sheet(item: $safariItem) { item in
                EVSafariView(url: item.url)
                    .ignoresSafeArea()
            }

            // Share sheet
            .sheet(item: $shareItem) { item in
                EVLinkShareSheet(items: item.items)
            }

            // Toast
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.easeInOut(duration: 0.25)) { self.toast = nil }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Themed pieces

    @ViewBuilder
    private func headerCard(theme: any AppThemeSpec) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(appearance.accentColor.opacity(0.16))
                    Circle().stroke(appearance.accentColor.opacity(0.35), lineWidth: 1)
                    Image(systemName: "bolt.car.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(appearance.accentColor)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick Links")
                        .font(.headline)
                    Text("Browse news and forums. Favorite your go-to sites.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }
        }
        .padding(14)
        .evGlassCard(theme: theme, uiStyle: uiStyle)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private func evBackground(theme: any AppThemeSpec) -> some View {
        Rectangle()
            .fill(theme.screenBackground)
            .overlay {
                if uiStyle == .teslaGlass {
                    // Accent haze (Tesla Glass)
                    RadialGradient(
                        colors: [
                            appearance.accentColor.opacity(scheme == .dark ? 0.55 : 0.25),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: scheme == .dark ? 560 : 520
                    )
                    .blur(radius: scheme == .dark ? 44 : 34)

                    // Secondary glow (adds depth, still subtle)
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(scheme == .dark ? 0.28 : 0.14),
                            Color.clear
                        ],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: scheme == .dark ? 520 : 480
                    )
                    .blur(radius: scheme == .dark ? 46 : 36)
                } else {
                    // Light haze even in Classic (keeps it premium)
                    RadialGradient(
                        colors: [
                            appearance.accentColor.opacity(scheme == .dark ? 0.22 : 0.14),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 520
                    )
                    .blur(radius: scheme == .dark ? 30 : 26)
                }
            }
            .ignoresSafeArea()
    }

    // MARK: - Actions

    private func openInApp(_ url: URL) {
        let scheme = url.scheme?.lowercased()
        guard scheme == "https" || scheme == "http" else {
            openSystem(url)
            return
        }
        safariItem = .init(url: url)
    }

    private func openSystem(_ url: URL) {
        openURL(url) { accepted in
            if !accepted { self.toast = "Couldn’t open link." }
        }
    }

    private func toggleFavorite(named name: String) {
        var set = favorites
        if set.contains(name) { set.remove(name) } else { set.insert(name) }
        setFavorites(set)
    }
}

// MARK: - Row

private struct EVNewsRow: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.appThemeBox) private var themeBox
    @EnvironmentObject private var appearance: AppAppearance
    @AppStorage("uiStyle") private var uiStyleRaw: String = "teslaGlass"
    private var uiStyle: EVUIStyle { EVUIStyle(rawValue: uiStyleRaw) ?? .classic }

    let link: EVLink
    let isFavorite: Bool
    let openInApp: () -> Void
    let openSystem: () -> Void
    let share: () -> Void
    let toggleFavorite: () -> Void

    var body: some View {
        let theme = themeBox.base

        Button(action: openInApp) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(appearance.accentColor.opacity(scheme == .dark ? 0.18 : 0.10))
                    Image(systemName: link.symbol)
                        .imageScale(.large)
                        .foregroundStyle(appearance.accentColor)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(link.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let host = link.url.host, !host.isEmpty {
                        Text(host)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Favorited")
                }

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .evGlassRow(theme: theme, uiStyle: uiStyle)
        .contextMenu {
            Button("Open in Safari", systemImage: "safari", action: openSystem)
            Button("Share", systemImage: "square.and.arrow.up", action: share)
            Button("Copy Link", systemImage: "doc.on.doc") {
                #if canImport(UIKit)
                UIPasteboard.general.string = link.url.absoluteString
                #endif
            }
            Divider()
            Button(
                isFavorite ? "Remove Favorite" : "Add to Favorites",
                systemImage: isFavorite ? "star.slash" : "star",
                action: toggleFavorite
            )
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { toggleFavorite() } label: {
                Label(isFavorite ? "Unfavorite" : "Favorite",
                      systemImage: isFavorite ? "star.slash" : "star")
            }
            .tint(.yellow)
        }
        .swipeActions(edge: .trailing) {
            Button { share() } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens link in an in-app browser. Long-press for more options.")
    }
}

// MARK: - Helpers

private struct EVWebItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct EVShareItem: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct EVSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct EVLinkShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Local styling (collision-safe)

private extension View {
    func evGlassRow(theme: any AppThemeSpec, uiStyle: EVUIStyle) -> some View {
        self
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(uiStyle == .teslaGlass ? theme.cardBackground.opacity(0.92) : theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.separator.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 4)
    }

    func evGlassCard(theme: any AppThemeSpec, uiStyle: EVUIStyle) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(uiStyle == .teslaGlass ? theme.cardBackground.opacity(0.92) : theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(theme.separator.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EVNewsView()
    }
    .preferredColorScheme(.dark)
    .environmentObject(AppAppearance()) // required for accent + settings-driven tint
    .appTheme(DefaultAppTheme())
}
