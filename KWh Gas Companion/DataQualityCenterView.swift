import SwiftUI

@MainActor
struct DataQualityCenterView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore
    @Environment(\.appThemeBox) private var themeBox

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let summary = DataQualityAnalyzer.summarize(
            entries: entriesStore.energyEntries(),
            sessions: teslaFiStore.sessions
        )

        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard(summary)
                consistencyCard(summary)
                costSpikeCard(summary)
                idleFeeCard(summary)
                duplicateCard(summary)
                outlierCard(summary)
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Data Quality Center")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func headerCard(_ summary: DataQualitySummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Clean, reliable data")
                .font(.headline)
            Text("We flag unusual sessions, potential duplicates, and idle‑fee risks.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private func consistencyCard(_ summary: DataQualitySummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Consistency Tracker", systemImage: "chart.bar.doc.horizontal")
                    .font(.headline)
                Spacer()
                Text("\(summary.consistencyScore)")
                    .font(.title3.weight(.semibold))
            }
            Text(summary.consistencyNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private func costSpikeCard(_ summary: DataQualitySummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Cost Spike Detector", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                Spacer()
                Text("\(summary.costSpikes.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if summary.costSpikes.isEmpty {
                Text("No significant spikes detected.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(summary.costSpikes.prefix(4)) { entry in
                    NavigationLink {
                        EditChargeEntryView(expense: entry) { updated in
                            entriesStore.update(updated)
                        }
                    } label: {
                        issueRow(title: entry.location ?? "Charging session",
                                 subtitle: entry.date.formatted(date: .abbreviated, time: .omitted),
                                 trailing: entry.costPerKWh?.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")) ?? "—")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .themedCard()
    }

    private func idleFeeCard(_ summary: DataQualitySummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Idle‑Fee Risk", systemImage: "timer")
                    .font(.headline)
                Spacer()
                Text("\(summary.idleFeeRisk.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if summary.idleFeeRisk.isEmpty {
                Text("No long Supercharger sessions detected.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(summary.idleFeeRisk.prefix(4)) { entry in
                    let minutes = entry.charging?.durationMinutes ?? entry.chargeDurationMinutes ?? 0
                    issueRow(
                        title: entry.location ?? entry.charging?.siteName ?? "Supercharger session",
                        subtitle: entry.date.formatted(date: .abbreviated, time: .omitted),
                        trailing: "\(minutes) min"
                    )
                }
            }
        }
        .themedCard()
    }

    private func duplicateCard(_ summary: DataQualitySummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Duplicate Finder", systemImage: "square.stack.3d.up")
                    .font(.headline)
                Spacer()
                Text("\(summary.duplicates.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if summary.duplicates.isEmpty {
                Text("No likely duplicates found.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(summary.duplicates.prefix(4)) { dup in
                    issueRow(
                        title: dup.entry.location ?? "Entry vs imported session",
                        subtitle: "Δ \(String(format: "%.1f", dup.kwhDelta)) kWh • \(Int(dup.minutesApart)) min apart",
                        trailing: dup.entry.amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
                    )
                }
            }
        }
        .themedCard()
    }

    private func outlierCard(_ summary: DataQualitySummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Outlier Cleanup", systemImage: "wand.and.stars")
                    .font(.headline)
                Spacer()
                Text("\(summary.outliers.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if summary.outliers.isEmpty {
                Text("No extreme outliers detected.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(summary.outliers.prefix(4)) { entry in
                    NavigationLink {
                        EditChargeEntryView(expense: entry) { updated in
                            entriesStore.update(updated)
                        }
                    } label: {
                        issueRow(
                            title: entry.location ?? "Charging session",
                            subtitle: entry.date.formatted(date: .abbreviated, time: .omitted),
                            trailing: entry.amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .themedCard()
    }

    private func issueRow(title: String, subtitle: String, trailing: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(trailing)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
        }
    }
}
