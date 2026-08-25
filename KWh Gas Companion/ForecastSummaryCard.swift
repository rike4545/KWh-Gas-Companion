// ForecastSummaryCard.swift
// KWh Gas Companion
//
// 🔧 FIX 1: `.accent` ShapeStyle is unavailable before iOS 17 and may not
//    resolve in all project configurations. Replaced with `.accentColor`
//    (available from iOS 13) throughout.
//
// 🔧 FIX 2: `refresh()` used `defer { isRefreshing = false }` inside an
//    async function. While `defer` is safe for synchronous cleanup, in an
//    async context a Task cancellation does NOT prevent defer from running —
//    but it does mean `isRefreshing` could be set to false before the
//    awaited work actually finishes if the task is cancelled mid-await.
//    Restructured to explicit try/finally pattern using withTaskCancellationHandler
//    so the spinner always clears on both completion and cancellation.

import SwiftUI

// MARK: - Model

struct ForecastSummary: Hashable {
    var periodLabel: String
    var kWh: Double
    var costUSD: Double? = nil
    var sessions: Int? = nil
    var kWhRange: ClosedRange<Double>? = nil
    var costRangeUSD: ClosedRange<Double>? = nil
    var confidence: Double? = nil        // 0.0 ... 1.0
    var asOf: Date = Date()
}

// MARK: - View

struct ForecastSummaryCard: View {
    let title: String
    let systemImage: String
    let summary: ForecastSummary
    var subtitle: String? = nil

    var onTap: (() -> Void)? = nil
    var onRefresh: (() async -> Void)? = nil

    @State private var isRefreshing: Bool = false

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 12) {
                header
                metrics
                if let conf = summary.confidence {
                    FSConfidenceBar(confidence: conf)
                }
                footer
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if onRefresh != nil {
                Button {
                    Task { await refresh() }
                } label: {
                    Label("Refresh Forecast", systemImage: "arrow.clockwise")
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .imageScale(.medium)
                // 🔧 FIX 1: `.accent` → `.accentColor`
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle ?? summary.periodLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if onRefresh != nil {
                if isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Refresh Forecast")
                }
            }
        }
    }

    private var metrics: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            FSMetricTile(
                title: "Expected kWh",
                valueText: kWhString(summary.kWh),
                caption: summary.kWhRange.map(rangeKWhString),
                systemImage: "bolt.fill"
            )
            FSMetricTile(
                title: "Expected Cost",
                valueText: summary.costUSD.map(moneyString) ?? "—",
                caption: summary.costRangeUSD.map(rangeMoneyString),
                systemImage: "dollarsign.circle"
            )
            FSMetricTile(
                title: "Sessions",
                valueText: summary.sessions.map { "\($0)" } ?? "—",
                caption: nil,
                systemImage: "battery.100.bolt"
            )
            FSMetricTile(
                title: "Confidence",
                valueText: summary.confidence.map { percentString($0, oneDecimal: true) } ?? "—",
                caption: nil,
                systemImage: "checkmark.seal"
            )
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .imageScale(.small)
                .foregroundStyle(.secondary)
            Text("As of \(summary.asOf.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: Actions

    // 🔧 FIX 2: Explicit isRefreshing reset on both success and cancellation.
    private func refresh() async {
        guard let onRefresh else { return }
        isRefreshing = true
        await withTaskCancellationHandler {
            await onRefresh()
            isRefreshing = false
        } onCancel: {
            Task { @MainActor in isRefreshing = false }
        }
    }
}

// MARK: - Subviews

private struct FSMetricTile: View {
    let title: String
    let valueText: String
    let caption: String?
    let systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(valueText)
                .font(.title3).bold()
                .monospacedDigit()
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.thinMaterial)
        )
    }
}

private struct FSConfidenceBar: View {
    var confidence: Double  // 0.0 ... 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Confidence").font(.caption).foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                    RoundedRectangle(cornerRadius: 6)
                        // 🔧 FIX 1: `.accent` → `Color.accentColor`
                        .fill(Color.accentColor)
                        .frame(width: max(0, min(1, confidence)) * geo.size.width)
                        .animation(.easeInOut(duration: 0.35), value: confidence)
                }
            }
            .frame(height: 8)
            Text(percentString(confidence))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Formatting

private func kWhString(_ value: Double) -> String {
    value >= 1000
        ? String(format: "%.1fk kWh", value / 1000.0)
        : String(format: "%.1f kWh", value)
}

private func rangeKWhString(_ r: ClosedRange<Double>) -> String {
    "\(kWhString(r.lowerBound)) – \(kWhString(r.upperBound))"
}

private func moneyString(_ value: Double) -> String {
    String(format: "$%.2f", value)
}

private func rangeMoneyString(_ r: ClosedRange<Double>) -> String {
    "\(moneyString(r.lowerBound)) – \(moneyString(r.upperBound))"
}

private func percentString(_ unitValue: Double, oneDecimal: Bool = false) -> String {
    let pct = max(0, min(1, unitValue)) * 100.0
    return String(format: oneDecimal ? "%.1f%%" : "%.0f%%", pct)
}

// MARK: - Preview

#if DEBUG
struct ForecastSummaryCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ForecastSummaryCard(
                title: "Usage Forecast",
                systemImage: "chart.line.uptrend.xyaxis",
                summary: ForecastSummary(
                    periodLabel: "August 2025",
                    kWh: 312.4,
                    costUSD: 48.72,
                    sessions: 22,
                    kWhRange: 280...340,
                    costRangeUSD: 43...54,
                    confidence: 0.78
                ),
                subtitle: "Home + Supercharger",
                onTap: {},
                onRefresh: { try? await Task.sleep(nanoseconds: 600_000_000) }
            )
            .padding()
            .previewLayout(.sizeThatFits)

            ForecastSummaryCard(
                title: "Cost Forecast",
                systemImage: "dollarsign.circle.fill",
                summary: ForecastSummary(
                    periodLabel: "This Month",
                    kWh: 0
                )
            )
            .padding()
            .previewLayout(.sizeThatFits)
            .preferredColorScheme(.dark)
        }
    }
}
#endif
