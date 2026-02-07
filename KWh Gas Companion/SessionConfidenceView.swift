import SwiftUI

@MainActor
struct SessionConfidenceView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @Environment(\.appThemeBox) private var themeBox

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let items = entriesStore.energyEntries()
            .sorted { $0.date > $1.date }
            .prefix(20)
            .map { SessionConfidence.score(for: $0) }

        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing) {
                header
                ForEach(items) { item in
                    row(item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("Session Confidence")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Confidence score")
                .font(.headline)
            Text("Higher scores mean the session has complete, reliable data (kWh, cost, location).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private func row(_ item: SessionConfidence.Item) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(item.score)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(item.score >= 80 ? Color.green : (item.score >= 60 ? Color.orange : Color.red))
            }
            Text(item.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }
}

enum SessionConfidence {
    struct Item: Identifiable {
        let id: UUID
        let title: String
        let subtitle: String
        let score: Int
    }

    static func score(for entry: ExpenseEntry) -> Item {
        var score = 100
        if entry.energyAddedKWh == nil { score -= 25 }
        if entry.amount <= 0 { score -= 20 }
        if (entry.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score -= 15 }
        if entry.costPerKWh == nil { score -= 10 }
        if entry.amount > 250 { score -= 10 }

        let title = entry.location?.trimmedNonEmpty ?? entry.category
        let subtitle = entry.date.formatted(date: .abbreviated, time: .shortened)
        return Item(id: entry.id, title: title, subtitle: subtitle, score: max(10, score))
    }
}
