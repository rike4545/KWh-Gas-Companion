//
//  VehicleStoryTimelineView.swift
//  KWh Gas Companion
//
//  🔧 CRASH FIX: UIImage(contentsOfFile:) was called synchronously inside
//     `storyIcon(_:)`, which is evaluated directly in the SwiftUI body on the
//     @MainActor. File I/O on the main thread blocks rendering and will trigger
//     the iOS watchdog if a large photo takes >300ms to load — killing the app.
//
//     Fix: async image loading via a dedicated StoryIconView that uses
//     .task(id:) to load off-thread and shows a placeholder until ready.
//     The synchronous UIImage call is gone from the render path entirely.
//
//  Swift 6 • iOS 17+

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct VehicleStoryTimelineView: View {
    @Environment(\.appThemeBox) private var themeBox
    @EnvironmentObject private var entriesStore: EntriesStore
    @StateObject private var diyStore = DIYServiceVaultStore()
    @StateObject private var adsStore = AdsEntitlementStore.shared

    private var theme: any AppThemeSpec { themeBox.base }

    private struct StoryItem: Identifiable {
        let id: String
        let date: Date
        let kind: StoryKind
        let title: String
        let subtitle: String
        let amount: Double?
        let currencyCode: String?
        // 🔧 FIX: Store the full URL path instead of just filename so async
        //   loader has what it needs without calling back into diyStore.
        let photoFilePath: String?
        let partNumbers: [String]
        let tags: [String]
    }

    private var items: [StoryItem] {
        var result: [StoryItem] = []

        for e in entriesStore.entries {
            let title = e.location ?? e.charging?.siteName ?? e.category
            let subtitle = e.category.isEmpty ? "Expense" : e.category
            result.append(StoryItem(
                id: "expense-\(e.id.uuidString)",
                date: e.date,
                kind: .expense,
                title: title,
                subtitle: subtitle,
                amount: e.amount,
                currencyCode: e.currencyCode,
                photoFilePath: nil,
                partNumbers: [],
                tags: []
            ))
        }

        for e in diyStore.items {
            let partSummary = e.partNumbers.isEmpty ? nil : "\(e.partNumbers.count) part(s)"
            let tagSummary  = e.tags.isEmpty        ? nil : "\(e.tags.count) tag(s)"
            let summary = [partSummary, tagSummary].compactMap { $0 }.joined(separator: " • ")
            // Resolve the full path once here, not inside the body.
            let photoPath: String? = e.photoFilename.map { diyStore.imageURL(for: $0).path }
            result.append(StoryItem(
                id: "diy-\(e.id.uuidString)",
                date: e.date,
                kind: .diy,
                title: e.title,
                subtitle: summary.isEmpty ? "DIY service" : "DIY service • \(summary)",
                amount: e.cost,
                currencyCode: Locale.current.currency?.identifier,
                photoFilePath: photoPath,
                partNumbers: e.partNumbers,
                tags: e.tags
            ))
        }

        return result.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard

                if items.isEmpty {
                    ContentUnavailableView(
                        "No timeline entries yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Add expenses or DIY service entries to build your vehicle story.")
                    )
                } else {
                    ForEach(items) { item in
                        storyRow(item)
                    }
                }

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Vehicle Story")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your vehicle story")
                .font(.headline)
            Text("Timeline of expenses, charging, and DIY work.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private func storyRow(_ item: StoryItem) -> some View {
        HStack(spacing: 12) {
            // 🔧 CRASH FIX: StoryIconView loads asynchronously — no blocking I/O in body.
            StoryIconView(filePath: item.photoFilePath, kind: item.kind)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                Text("\(item.subtitle) • \(item.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let amount = item.amount {
                Text(
                    amount,
                    format: .currency(code: item.currencyCode
                        ?? (Locale.current.currency?.identifier ?? "USD"))
                )
                .font(.subheadline.weight(.semibold))
            }
        }
        .themedCard()
    }
}

// MARK: - Story Kind (file-scoped so StoryIconView can reference it)

fileprivate enum StoryKind { case diy, expense }

// MARK: - Async Icon View

// 🔧 CRASH FIX: Replaces the synchronous UIImage(contentsOfFile:) call that
// was blocking the main thread inside VehicleStoryTimelineView.storyIcon(_:).
// This view shows a placeholder immediately and loads the image asynchronously.
private struct StoryIconView: View {
    let filePath: String?
    let kind: StoryKind

    #if canImport(UIKit)
    @State private var loadedImage: UIImage? = nil
    #endif

    private var symbolName: String {
        kind == .diy ? "wrench.and.screwdriver" : "bolt.car"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.12))

            #if canImport(UIKit)
            if let img = loadedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            #else
            Image(systemName: symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
            #endif
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityHidden(true)
        #if canImport(UIKit)
        .task(id: filePath) {
            guard let path = filePath else { loadedImage = nil; return }
            // Dispatch to a background thread so disk I/O doesn't block main.
            loadedImage = await Task.detached(priority: .utility) {
                UIImage(contentsOfFile: path)
            }.value
        }
        #endif
    }
}


#if DEBUG
#Preview {
    NavigationStack {
        VehicleStoryTimelineView()
            .environmentObject(EntriesStore())
            .environmentObject(AppAppearance())
            .environment(\.appThemeBox, AppThemeBox(base: SystemTheme(accentColor: .blue, scheme: .light)))
    }
}
#endif
