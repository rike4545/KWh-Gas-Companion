import SwiftUI

@MainActor
struct SavingsScoreView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let score = SavingsScoreSummary.compute(from: entriesStore.energyEntries())

        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard(score)
                breakdownCard(score)
                habitsCard(score)
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Savings Score")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func headerCard(_ score: SavingsScoreSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Savings Score")
                    .font(.headline)
                Spacer()
                Text("\(score.totalScore)")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(theme.accent)
            }
            Text(score.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private func breakdownCard(_ score: SavingsScoreSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breakdown")
                .font(.headline)
            scoreRow("Rate efficiency", score.rateScore)
            scoreRow("Home vs fast charging", score.fastChargeScore)
            scoreRow("Consistent sessions", score.consistencyScore)
        }
        .themedCard()
    }

    private func habitsCard(_ score: SavingsScoreSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Habits to improve")
                .font(.headline)

            if score.habitNotes.isEmpty {
                Text("No major habits detected. Nice work keeping costs steady.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(score.habitNotes, id: \.self) { note in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .themedCard()
    }

    private func scoreRow(_ title: String, _ value: Int) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text("\(value)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(value >= 70 ? .green : value >= 50 ? .orange : .red)
        }
    }
}
