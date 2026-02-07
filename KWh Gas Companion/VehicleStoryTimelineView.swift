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

    private enum StoryKind { case diy, expense }

    private struct StoryItem: Identifiable {
        let id: String
        let date: Date
        let kind: StoryKind
        let title: String
        let subtitle: String
        let amount: Double?
        let currencyCode: String?
        let photoFilename: String?
        let partNumbers: [String]
        let tags: [String]
    }

    private var items: [StoryItem] {
        var result: [StoryItem] = []

        for e in entriesStore.entries {
            let title = e.location ?? e.charging?.siteName ?? e.category
            let subtitle = e.category.isEmpty ? "Expense" : e.category
            result.append(
                StoryItem(
                    id: "expense-\(e.id.uuidString)",
                    date: e.date,
                    kind: .expense,
                    title: title,
                    subtitle: subtitle,
                    amount: e.amount,
                    currencyCode: e.currencyCode,
                    photoFilename: nil,
                    partNumbers: [],
                    tags: []
                )
            )
        }

        for e in diyStore.items {
            let partSummary = e.partNumbers.isEmpty ? nil : "\(e.partNumbers.count) part(s)"
            let tagSummary = e.tags.isEmpty ? nil : "\(e.tags.count) tag(s)"
            let summary = [partSummary, tagSummary].compactMap { $0 }.joined(separator: " • ")
            result.append(
                StoryItem(
                    id: "diy-\(e.id.uuidString)",
                    date: e.date,
                    kind: .diy,
                    title: e.title,
                    subtitle: summary.isEmpty ? "DIY service" : "DIY service • \(summary)",
                    amount: e.cost,
                    currencyCode: Locale.current.currency?.identifier,
                    photoFilename: e.photoFilename,
                    partNumbers: e.partNumbers,
                    tags: e.tags
                )
            )
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                storyIcon(item)

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
                    Text(amount, format: .currency(code: item.currencyCode ?? (Locale.current.currency?.identifier ?? "USD")))
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .themedCard()
    }

    @ViewBuilder
    private func storyIcon(_ item: StoryItem) -> some View {
        #if canImport(UIKit)
        if let filename = item.photoFilename,
           let ui = UIImage(contentsOfFile: diyStore.imageURL(for: filename).path) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
        } else {
            defaultIcon(for: item.kind)
        }
        #else
        defaultIcon(for: item.kind)
        #endif
    }

    private func defaultIcon(for kind: StoryKind) -> some View {
        let symbol = (kind == .diy) ? "wrench.and.screwdriver" : "bolt.car"
        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)
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
