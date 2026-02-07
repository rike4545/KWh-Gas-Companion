//
//  SuperchargerHelperView.swift
//  My KWh Companion
//
//  Single-screen helper: “What’s the cheapest time to charge?”
//  Uses on-device Core ML (SuperchargerPriceNN) via SuperchargerPredictionEngine.
//

import SwiftUI

@MainActor
struct SuperchargerHelperView: View {
    @Environment(\.colorScheme) private var scheme

    // Optional external station id (e.g., from a station DB or "nearest" provider)
    private let stationId: UUID?

    @StateObject private var viewModel: SuperchargerPredictionViewModel

    // MARK: - Init

    init(stationId: UUID? = nil) {
        self.stationId = stationId
        _viewModel = StateObject(
            wrappedValue: SuperchargerPredictionViewModel(horizonHours: 24)
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                statusSection
                mainCardSection
                detailsSection
                footerSection
            }
            .padding()
        }
        .background(backgroundView)
        .onAppear {
            guard !viewModel.hasPrediction else { return }

            // If the view model has a “default station” concept, use it.
            // Otherwise you can change this to refresh(using: stationId) when
            // you wire a real station id through.
            viewModel.refreshDefaultStation()
        }
        .navigationTitle("Cheapest Time to Charge")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cheapest Time to Charge")
                .font(.title2.weight(.semibold))

            // Prefer real station name / city when available,
            // otherwise fall back to an honest generic label.
            let trimmedName = viewModel.stationName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedCity = viewModel.stationCity?.trimmingCharacters(in: .whitespacesAndNewlines)

            if !trimmedName.isEmpty, let city = trimmedCity, !city.isEmpty {
                Text("\(trimmedName) · \(city)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if !trimmedName.isEmpty {
                Text(trimmedName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let city = trimmedCity, !city.isEmpty {
                Text(city)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Nearest fast charger")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("On-device neural network")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var statusSection: some View {
        Group {
            if viewModel.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Analyzing the next 24 hours of prices…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if let error = viewModel.errorMessage {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Prediction unavailable")
                            .font(.subheadline.weight(.semibold))
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.headline)
                    Text("""
                    Predictions are calculated on your device using the time of day \
                    and a small neural network. Values are estimates based on patterns \
                    in fast-charging prices, not guaranteed live rates.
                    """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private var mainCardSection: some View {
        Group {
            if viewModel.hasPrediction {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Best 1-hour Window")
                            .font(.headline)
                        Spacer()
                        Button {
                            viewModel.refreshDefaultStation()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.footnote)
                        }
                        .buttonStyle(.borderless)
                    }

                    Text(viewModel.bestWindowText)
                        .font(.title3.weight(.semibold))

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Best price")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(viewModel.bestPriceText)
                                .font(.body.weight(.semibold))
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Typical price")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(viewModel.medianPriceText)
                                .font(.body.weight(.semibold))
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Confidence")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(viewModel.confidenceText)
                                .font(.body.weight(.semibold))
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Day’s range")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(viewModel.spreadText)
                                .font(.body.weight(.semibold))
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Waiting for prediction…")
                        .font(.headline)
                    Text("If this takes more than a few seconds, try refreshing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        viewModel.refreshDefaultStation()
                    } label: {
                        Label("Refresh now", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }

    private var detailsSection: some View {
        Group {
            if let prediction = viewModel.prediction {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Next 24 Hours")
                        .font(.headline)

                    VStack(spacing: 8) {
                        ForEach(prediction.priceBuckets.prefix(6)) { bucket in
                            HStack {
                                Text(hourLabel(for: bucket.hourStart))
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text(String(format: "$%.3f", bucket.predictedPrice))
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(bucket.isBestWindow ? .green : .primary)

                                if bucket.isBestWindow {
                                    Text("Best")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(Color.green.opacity(0.18))
                                        )
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                }
            }
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How this works")
                .font(.subheadline.weight(.semibold))

            Text("""
            This tool runs an on-device neural network (SuperchargerPriceNN) to \
            estimate which hours are likely cheaper or more expensive to fast charge \
            over the next 24 hours.
            """)
            .font(.footnote)
            .foregroundStyle(.secondary)

            Text("""
            The model looks at factors like hour of day, weekday vs weekend, and \
            season, then ranks each hour and maps those scores into a realistic \
            Supercharger price range.
            """)
            .font(.footnote)
            .foregroundStyle(.secondary)

            Text("""
            These prices are estimates only. Always check the live price at the \
            charger before you start a session.
            """)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var backgroundView: some View {
        Group {
            if scheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.05, blue: 0.10),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.secondarySystemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }

    private func hourLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
