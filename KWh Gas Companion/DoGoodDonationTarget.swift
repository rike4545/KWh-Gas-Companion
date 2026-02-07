//
//  DoGoodDonationShiftView.swift
//  My KWh Companion
//  Link-only version (no amounts)
//
//  Swift 6 / iOS 17+
//
//  Notes:
//  - Uses explicit Color.* in foregroundStyle to avoid the “HierarchicalShapeStyle vs Color” inference issue.
//  - Link-only: opens websites via openURL (no in-app payments).
//

import SwiftUI

@MainActor
struct DoGoodDonationShiftView: View {
    @Environment(\.openURL) private var openURL

    // Simple editable catalog of links
    private let sites: [DonationLink] = [
        .init(
            title: "Plug In America",
            subtitle: "EV advocacy & education",
            url: URL(string: "https://pluginamerica.org")!,
            icon: "bolt.car"
        ),
        .init(
            title: "Rewiring America",
            subtitle: "Electrification non-profit",
            url: URL(string: "https://www.rewiringamerica.org")!,
            icon: "house"
        ),
        .init(
            title: "Carbonfund.org",
            subtitle: "Carbon offsets & projects",
            url: URL(string: "https://carbonfund.org")!,
            icon: "leaf"
        ),
        .init(
            title: "The Nature Conservancy",
            subtitle: "Climate & conservation",
            url: URL(string: "https://www.nature.org")!,
            icon: "globe.americas"
        ),
        .init(
            title: "Drive Electric Campaign",
            subtitle: "Global EV adoption coalition",
            url: URL(string: "https://www.driveelectriccampaign.org")!,
            icon: "car.2"
        )
    ]

    @State private var query: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                BG().ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        headerCard
                            .padding(.horizontal)

                        SettingsCard {
                            Text("Pick a cause and tap **Visit** to open their website. These are just links—no donation amounts or in-app payments.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        SettingsCard(title: "Organizations") {
                            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Filtering by “\(query)”")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(spacing: 0) {
                                ForEach(filteredSites) { site in
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color.accentColor.opacity(0.12))
                                                .frame(width: 40, height: 40)

                                            Image(systemName: site.icon)
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        .accessibilityHidden(true)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(site.title)
                                                .font(.callout.weight(.semibold))
                                            Text(site.subtitle)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button {
                                            openURL(site.url)
                                        } label: {
                                            Label("Visit", systemImage: "safari")
                                                .labelStyle(.titleAndIcon)
                                        }
                                        .buttonStyle(.bordered)
                                        .accessibilityLabel("Visit \(site.title) in Safari")
                                    }
                                    .padding(.vertical, 10)

                                    if site.id != filteredSites.last?.id {
                                        Divider().opacity(0.12)
                                    }
                                }
                            }
                        }
                        .padding([.horizontal, .bottom])
                        .padding(.bottom, 24)
                    }
                    .searchable(
                        text: $query,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search organizations"
                    )
                }
            }
            .navigationTitle("Do Good")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var filteredSites: [DonationLink] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sites }
        let q = trimmed.lowercased()
        return sites.filter { s in
            s.title.lowercased().contains(q) ||
            s.subtitle.lowercased().contains(q) ||
            s.url.absoluteString.lowercased().contains(q)
        }
    }

    private var headerCard: some View {
        SettingsCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 54, height: 54)

                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.pink) // explicit Color to avoid style inference issues
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Do Good")
                        .font(.title3.weight(.semibold))
                    Text("Quick links to reputable orgs—no amounts here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }
}

// MARK: - Models & local shells

private struct DonationLink: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let url: URL
    let icon: String
}

private struct BG: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.black, Color(white: 0.12)]
                : [Color(white: 0.98), Color(white: 0.92)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct SettingsCard<Content: View>: View {
    var title: String?
    var subtitle: String?
    @ViewBuilder var content: Content

    init(title: String? = nil, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)
            }

            content
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1) // explicit Color.white
        )
    }
}

#Preview {
    DoGoodDonationShiftView()
}
