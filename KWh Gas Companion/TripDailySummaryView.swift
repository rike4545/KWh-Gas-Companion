//
//  TripDailySummaryView.swift
//  My KWh Companion
//
//  Shows a single-line daily trip summary:
//  Date  •  <miles> mi  •  <kWh> kWh  •  <localized currency>
//
//  Swift 6 / iOS 17+
//

import SwiftUI

public struct TripDailySummaryView: View {
    public let summary: TripSummary

    public init(summary: TripSummary) {
        self.summary = summary
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(Self.dateFormatter.string(from: summary.date))
                .font(.headline)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(milesText)
                    .font(.subheadline)
                    .monospacedDigit()

                Text("\(energyText) • \(costText)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trip summary")
        .accessibilityValue("\(milesAX), \(energyAX), \(costAX)")
    }
}

// MARK: - Formatting helpers
private extension TripDailySummaryView {
    var milesText: String {
        guard let miles = summary.distanceMiles else { return "— mi" }
        if let s = Self.milesFormatter.string(from: miles as NSNumber) {
            return "\(s) mi"
        }
        return String(format: "%.1f mi", miles)
    }

    var energyText: String {
        String(format: "%.2f kWh", summary.energyKWh)
    }

    var costText: String {
        // Localize currency using the current locale’s currency code when available
        let code = Locale.current.currency?.identifier ?? "USD"
        return summary.estimatedCostUSD.formatted(.currency(code: code))
    }

    // AX-friendly, more conversational
    var milesAX: String {
        guard let miles = summary.distanceMiles else { return "miles unknown" }
        return "\(Int(round(miles))) miles"
    }
    var energyAX: String {
        "\(String(format: "%.2f", summary.energyKWh)) kilowatt hours"
    }
    var costAX: String {
        // Strip currency symbol spacing quirks for TTS; reuse same code decision
        let code = Locale.current.currency?.identifier ?? "USD"
        return summary.estimatedCostUSD.formatted(.currency(code: code))
    }

    // Cached formatters
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let milesFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 1
        nf.minimumFractionDigits = 0
        nf.usesGroupingSeparator = true
        return nf
    }()
}
