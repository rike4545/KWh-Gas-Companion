import SwiftUI

@MainActor
struct DuplicateResolverView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore
    @Environment(\.appThemeBox) private var themeBox

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let summary = DataQualityAnalyzer.summarize(entries: entriesStore.energyEntries(),
                                                    sessions: teslaFiStore.sessions)
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing) {
                header(summary)
                ForEach(summary.duplicates) { dup in
                    duplicateRow(dup)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("Duplicate Resolver")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ summary: DataQualitySummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Potential duplicates")
                .font(.headline)
            Text("We match sessions by time and kWh. Review and remove duplicates if needed.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("\(summary.duplicates.count) matches")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private func duplicateRow(_ dup: DataQualityDuplicate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dup.entry.location ?? "Entry vs TeslaFi")
                .font(.subheadline.weight(.semibold))
            Text("Δ \(String(format: "%.1f", dup.kwhDelta)) kWh • \(Int(dup.minutesApart)) min apart")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Button("Open Entry") { }
                    .buttonStyle(.bordered)
                Button("Remove Entry") {
                    entriesStore.remove(dup.entry)
                }
                .buttonStyle(.bordered)
            }
        }
        .themedCard()
    }
}
