//
//  EVContentView.swift
//  KWh Gas Companion
//
//  YouTube creator hub + banner ad
//

import SwiftUI
import SafariServices
#if canImport(UIKit)
import UIKit
#endif

private struct EVContentLink: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let symbol: String
}

private enum EVContentUIStyle: String {
    case classic
    case teslaGlass
}

private func normalizedEVContentURL(_ raw: String) -> URL? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if let u = URL(string: trimmed), u.scheme != nil { return u }
    return URL(string: "https://\(trimmed)")
}

@MainActor
struct EVContentView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL
    @Environment(\.appThemeBox) private var themeBox
    @EnvironmentObject private var appearance: AppAppearance

    @AppStorage("uiStyle") private var uiStyleRaw: String = "teslaGlass"
    private var uiStyle: EVContentUIStyle { EVContentUIStyle(rawValue: uiStyleRaw) ?? .classic }

    @State private var searchText: String = ""
    @State private var safariItem: EVContentWebItem?
    @State private var shareItem: EVContentShareItem?
    @State private var toast: String?

    @StateObject private var adsStore = AdsEntitlementStore.shared

    private let links: [EVContentLink] = {
        var items: [EVContentLink] = []
        func add(_ name: String, _ raw: String, _ symbol: String) {
            if let u = normalizedEVContentURL(raw) {
                items.append(EVContentLink(name: name, url: u, symbol: symbol))
            }
        }

        add("Rich Rebuilds", "https://www.youtube.com/@RichRebuilds", "play.rectangle")
        add("Kim Java", "https://www.youtube.com/@ItsKimJava", "play.rectangle")
        add("Emelia Hartford", "https://www.youtube.com/@EmeliaHartford", "play.rectangle")
        add("The Greenes", "https://www.youtube.com/@thegreenesgowild", "play.rectangle")
        add("Out of Spec Bits", "https://www.youtube.com/@OutofSpecBITS", "play.rectangle")

        return items
    }()

    private var filteredLinks: [EVContentLink] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return links }
        return links.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        let theme = themeBox.base

        NavigationStack {
            ZStack {
                background(theme: theme)

                List {
                    Section {
                        headerCard(theme: theme)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }

                    Section {
                        ForEach(filteredLinks) { link in
                            EVContentRow(
                                link: link,
                                openInApp: { openInApp(link.url) },
                                openSystem: { openSystem(link.url) },
                                share: { shareItem = .init(items: [link.url]) }
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }

                    if !adsStore.hasRemovedAds {
                        Section {
                            AdBannerCard(adsStore: adsStore)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets())
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("EV Content")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer,
                prompt: Text("Search creators")
            )
            .tint(appearance.accentColor)

            .sheet(item: $safariItem) { item in
                EVContentSafariView(url: item.url)
                    .ignoresSafeArea()
            }

            .sheet(item: $shareItem) { item in
                EVContentShareSheet(items: item.items)
            }

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
        .task {
            await adsStore.load()
        }
    }

    @ViewBuilder
    private func headerCard(theme: any AppThemeSpec) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(appearance.accentColor.opacity(0.16))
                    Circle().stroke(appearance.accentColor.opacity(0.35), lineWidth: 1)
                    Image(systemName: "play.rectangle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(appearance.accentColor)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("EV Creator Hub")
                        .font(.headline)
                    Text("Curated YouTube channels for EV builds, news, and mods.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }
        }
        .padding(14)
        .evContentGlassCard(theme: theme, uiStyle: uiStyle)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private func background(theme: any AppThemeSpec) -> some View {
        Rectangle()
            .fill(theme.screenBackground)
            .overlay {
                if uiStyle == .teslaGlass {
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
}

private struct EVContentRow: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.appThemeBox) private var themeBox
    @EnvironmentObject private var appearance: AppAppearance
    @AppStorage("uiStyle") private var uiStyleRaw: String = "teslaGlass"
    private var uiStyle: EVContentUIStyle { EVContentUIStyle(rawValue: uiStyleRaw) ?? .classic }

    let link: EVContentLink
    let openInApp: () -> Void
    let openSystem: () -> Void
    let share: () -> Void

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

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .evContentGlassRow(theme: theme, uiStyle: uiStyle)
        .contextMenu {
            Button("Open in Safari", systemImage: "safari", action: openSystem)
            Button("Share", systemImage: "square.and.arrow.up", action: share)
            Button("Copy Link", systemImage: "doc.on.doc") {
                #if canImport(UIKit)
                UIPasteboard.general.string = link.url.absoluteString
                #endif
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens link in an in-app browser. Long-press for more options.")
    }
}

private struct EVContentWebItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct EVContentShareItem: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct EVContentSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct EVContentShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private extension View {
    func evContentGlassRow(theme: any AppThemeSpec, uiStyle: EVContentUIStyle) -> some View {
        self
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(uiStyle == .teslaGlass ? theme.cardBackground.opacity(0.92) : theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.separator.opacity(0.55), lineWidth: 1)
            )
    }

    func evContentGlassCard(theme: any AppThemeSpec, uiStyle: EVContentUIStyle) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(uiStyle == .teslaGlass ? theme.cardBackground.opacity(0.92) : theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(theme.separator.opacity(0.55), lineWidth: 1)
            )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        EVContentView()
    }
    .environmentObject(AppAppearance())
    .appTheme(DefaultAppTheme())
}
#endif
