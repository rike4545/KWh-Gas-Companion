//
//  RouteDiscoveryView.swift
//  KWh Gas Companion
//
//  Route Discovery — browse shared driving routes, favorite them, publish your
//  own, and open any of them in the embedded LibreNav screen.
//
//  Swift 6 • iOS 17+
//

import SwiftUI

// MARK: - Browse

@MainActor
struct RouteDiscoveryView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @Environment(\.appThemeBox) private var themeBox

    @StateObject private var store = RouteDiscoveryStore()

    @State private var search = ""
    @State private var region: String?
    @State private var sort: RouteSort = .newest
    @State private var favoritesOnly = false
    @State private var showingPublish = false

    private var theme: any AppThemeSpec { themeBox.base }

    private var rows: [SharedRoute] {
        let base = store.filtered(search: search, region: region, sort: sort)
        return favoritesOnly ? base.filter { store.isFavorite($0) } : base
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                filterBar

                if store.isLoading && store.visibleRoutes.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if rows.isEmpty {
                    emptyState
                } else {
                    ForEach(rows) { route in
                        NavigationLink {
                            RouteDetailView(route: route, store: store)
                        } label: {
                            RouteCard(route: route, isFavorite: store.isFavorite(route), isMine: store.isMine(route))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.screenBackground)
        .searchable(text: $search, prompt: "Search routes, regions, tags")
        .navigationTitle("Route Discovery")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingPublish = true } label: {
                    Label("Share a route", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingPublish) {
            PublishRouteView(store: store)
        }
        .task { await store.refresh() }
        .refreshable { await store.refresh() }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("Favorites", systemImage: "star.fill", isOn: favoritesOnly) {
                        favoritesOnly.toggle()
                    }
                    chip("All regions", isOn: region == nil) { region = nil }
                    ForEach(store.regions, id: \.self) { name in
                        chip(name, isOn: region == name) {
                            region = (region == name) ? nil : name
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            Picker("Sort", selection: $sort) {
                ForEach(RouteSort.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private func chip(_ title: String, systemImage: String? = nil, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage).font(.caption2) }
                Text(title).font(.footnote.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(isOn ? theme.accent.opacity(0.22) : theme.pillTint.opacity(0.18))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isOn ? theme.accent.opacity(0.55) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: favoritesOnly ? "star" : "map")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text(favoritesOnly ? "No favorites yet" : "No routes match")
                .font(.headline)
            Text(favoritesOnly
                 ? "Tap the star on any route to keep it here."
                 : "Try a different region or clear the search.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Card

private struct RouteCard: View {
    let route: SharedRoute
    let isFavorite: Bool
    let isMine: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(route.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }

            Text(route.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 10) {
                stat("figure.walk.departure", route.distanceLabel)
                stat("mappin.and.ellipse", "\(route.stopCount) stops")
                if route.hasChargingNoted {
                    stat("bolt.fill", "Charging")
                }
            }

            HStack(spacing: 6) {
                Text(route.region)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.quaternary))
                if isMine {
                    Text("Yours")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(.tint.opacity(0.2)))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .themedCard()
    }

    private func stat(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.caption2)
            Text(text).font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Detail

@MainActor
struct RouteDetailView: View {
    let route: SharedRoute
    @ObservedObject var store: RouteDiscoveryStore

    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.dismiss) private var dismiss

    @State private var showingReport = false
    @State private var reportReason = ""
    @State private var showingBlockConfirm = false

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                stopsCard
                if !route.tags.isEmpty { tagsCard }
                driveButton
                if !store.isMine(route) { moderationCard } else { ownerCard }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.screenBackground)
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.toggleFavorite(route)
                } label: {
                    Label("Favorite",
                          systemImage: store.isFavorite(route) ? "star.fill" : "star")
                }
                .tint(store.isFavorite(route) ? .yellow : nil)
            }
        }
        .alert("Report this route", isPresented: $showingReport) {
            TextField("What's wrong with it?", text: $reportReason)
            Button("Cancel", role: .cancel) { reportReason = "" }
            Button("Report", role: .destructive) {
                let reason = reportReason
                reportReason = ""
                Task {
                    await store.report(route, reason: reason)
                    dismiss()
                }
            }
        } message: {
            Text("It will be hidden from your feed right away and sent for review.")
        }
        .confirmationDialog("Block \(route.authorName)?",
                            isPresented: $showingBlockConfirm,
                            titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                store.blockAuthor(of: route)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't see any routes from this author.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(route.summary).font(.subheadline)

            HStack(spacing: 14) {
                labelled("Distance", route.distanceLabel)
                labelled("Stops", "\(route.stopCount)")
                labelled("Region", route.region)
            }
            .padding(.top, 2)

            Text("Shared by \(route.authorName) • \(route.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if route.statedMiles == nil {
                Text("Distance shown is a straight-line estimate between stops. LibreNav calculates the real driving distance when you open the route.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(prominent: true)
    }

    private func labelled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold))
        }
    }

    private var stopsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Stops").font(.headline)
            ForEach(Array(route.stops.enumerated()), id: \.element.id) { index, stop in
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(theme.accent.opacity(0.18)).frame(width: 24, height: 24)
                        Text("\(index + 1)").font(.caption2.weight(.bold))
                    }
                    Text(stop.name).font(.subheadline)
                    Spacer()
                    Text(String(format: "%.4f, %.4f", stop.coordinate.latitude, stop.coordinate.longitude))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private var tagsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags").font(.headline)
            FlowTags(tags: route.tags)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private var driveButton: some View {
        NavigationLink {
            LibreNavView(tripQuery: route.tripQuery, title: route.title)
        } label: {
            Label("Open in LibreNav", systemImage: "location.north.line.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(theme.accent.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private var moderationCard: some View {
        VStack(spacing: 8) {
            Button(role: .destructive) { showingReport = true } label: {
                Label("Report this route", systemImage: "flag")
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
            }
            Button(role: .destructive) { showingBlockConfirm = true } label: {
                Label("Block \(route.authorName)", systemImage: "person.slash")
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 4)
    }

    private var ownerCard: some View {
        Button(role: .destructive) {
            store.deleteMyRoute(route)
            dismiss()
        } label: {
            Label("Delete my route", systemImage: "trash")
                .font(.footnote)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
    }
}

// MARK: - Tag flow

private struct FlowTags: View {
    let tags: [String]

    var body: some View {
        // Simple wrapping row; tag counts here are small (typically 2–4).
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(.quaternary))
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Publish

@MainActor
struct PublishRouteView: View {
    @ObservedObject var store: RouteDiscoveryStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var summary = ""
    @State private var region = ""
    @State private var tagText = ""
    @State private var milesText = ""
    @State private var shareLink = ""
    @State private var hasCharging = false
    @State private var acceptedTerms = false

    /// Accepts either a full LibreNav share URL or just its query string.
    private var normalizedQuery: String {
        let raw = shareLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "" }
        // Keep the percent-encoded form: `SharedRoute.parseStops` reads it via
        // `percentEncodedQuery`, and the `|` separators must stay escaped on the
        // way through or the round-trip collapses to a single stop.
        if let components = URLComponents(string: raw),
           let query = components.percentEncodedQuery, !query.isEmpty {
            return query
        }
        return raw.hasPrefix("?") ? String(raw.dropFirst()) : raw
    }

    private var parsedStops: [SharedRouteStop] { SharedRoute.parseStops(from: normalizedQuery) }

    private var canPublish: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !region.trimmingCharacters(in: .whitespaces).isEmpty
            && parsedStops.count >= 2
            && acceptedTerms
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Route name", text: $title)
                    TextField("What makes it worth driving?", text: $summary, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Region (e.g. Hudson Valley, NY)", text: $region)
                } header: {
                    Text("About")
                }

                Section {
                    TextField("Paste a LibreNav share link", text: $shareLink, axis: .vertical)
                        .lineLimit(2...4)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if !shareLink.isEmpty {
                        if parsedStops.count >= 2 {
                            Label("\(parsedStops.count) stops recognised", systemImage: "checkmark.circle.fill")
                                .font(.footnote)
                                .foregroundStyle(.green)
                        } else {
                            Label("Couldn't read a route from that link", systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                } header: {
                    Text("The route")
                } footer: {
                    Text("Plan the trip in LibreNav, tap its share button, and paste the link here. It carries every stop and your routing preferences.")
                }

                Section {
                    TextField("Distance in miles (optional)", text: $milesText)
                        .keyboardType(.numberPad)
                    TextField("Tags, comma separated", text: $tagText)
                        .autocorrectionDisabled()
                    Toggle("Charging available along the way", isOn: $hasCharging)
                } header: {
                    Text("Details")
                } footer: {
                    Text("Leave distance blank and we'll show a straight-line estimate until someone drives it.")
                }

                Section {
                    Toggle(isOn: $acceptedTerms) {
                        Text("This route is mine to share and contains nothing offensive or unsafe.")
                            .font(.footnote)
                    }
                } footer: {
                    Text("Shared routes are visible to other drivers. Anything reported is hidden immediately and reviewed.")
                }
            }
            .navigationTitle("Share a route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") { publish() }
                        .disabled(!canPublish)
                }
            }
        }
    }

    private func publish() {
        let tags = tagText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let route = SharedRoute(
            title: title.trimmingCharacters(in: .whitespaces),
            summary: summary.trimmingCharacters(in: .whitespaces),
            tripQuery: normalizedQuery,
            region: region.trimmingCharacters(in: .whitespaces),
            tags: tags,
            statedMiles: Double(milesText.trimmingCharacters(in: .whitespaces)),
            authorName: "You",
            authorID: "local-user",
            createdAt: Date(),
            hasChargingNoted: hasCharging
        )

        Task {
            await store.publish(route)
            dismiss()
        }
    }
}
