//
//  HistoryOfTeslaAndRivianView.swift
//  MyKWhCompanion
//
//  Swift 6 / iOS 17+
//
//  EV-centric, scannable overview of:
//  - Nikola Tesla’s foundational inventions
//  - Tesla, Inc. milestones
//  - Rivian milestones
//  - Comparison of focus + EV impact
//
//  Includes:
//  - “Highlight EV-impact items” toggle
//  - Optional deep link into a Tesla-Inventions destination
//  - Static “last reviewed” stamp so copy stays honest
//

import SwiftUI

@MainActor
public struct HistoryOfTeslaAndRivianView: View {

    // MARK: - Public API

    /// Optional destination for a detailed "Tesla Inventions" view.
    /// Example:
    ///     HistoryOfTeslaAndRivianView {
    ///         AnyView(TeslaInventionsShiftView())
    ///     }
    private let inventionsDestination: (() -> AnyView)?

    public init(inventionsDestination: (() -> AnyView)? = nil) {
        self.inventionsDestination = inventionsDestination
    }

    // MARK: - State

    @State private var highlightEVImpact: Bool = true

    // MARK: - Constants

    /// Manually updated “last reviewed” stamp (keep in sync when you edit copy).
    private let lastReviewed: String = "October 2025"

    // MARK: - Body

    public var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    summaryCard
                    nikolaTeslaCard
                    teslaIncCard
                    rivianCard
                    comparisonCard
                    learnMoreCard
                    footerStamp
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Tesla & Rivian History")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Background

    private var background: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground),
                    Color.accentColor.opacity(0.12),
                    Color(uiColor: .secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                RadialGradient(
                    colors: [
                        Color.accentColor.opacity(0.25),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: max(height * 0.5, 260)
                )
                .blur(radius: 32)
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Header & Summary

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("⚡️ History of Tesla & Rivian")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)

            Text("How Nikola Tesla’s ideas, Tesla, Inc., and Rivian helped shape modern EVs.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Toggle(isOn: $highlightEVImpact) {
                Text("Highlight EV-impact items")
                    .font(.subheadline)
            }
            .toggleStyle(.switch)
            .accessibilityHint("Toggles extra emphasis on historically important EV milestones.")
        }
    }

    private var summaryCard: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(title: "Big picture", symbol: "sparkles")

                Text("""
Nikola Tesla’s AC inventions made long-distance electric power practical. A century later, Tesla, Inc. proved EVs could be desirable and scalable, while Rivian focused on electric adventure vehicles and commercial fleets. Together, they pushed EVs from niche to mainstream.
""")
                .font(.subheadline)
            }
        }
    }

    // MARK: - Nikola Tesla

    private var nikolaTeslaCard: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(title: "Nikola Tesla – Inventions", symbol: "brain.head.profile")

                Text("""
Inventor and electrical engineer whose work on AC power, motors, and grid distribution is foundational for today’s EVs and charging networks.
""")
                .font(.subheadline)

                if let dest = inventionsDestination {
                    NavigationLink {
                        dest()
                    } label: {
                        Label("Open detailed Tesla inventions", systemImage: "book.pages")
                            .font(.callout.weight(.semibold))
                    }
                    .padding(.top, 4)
                    .accessibilityHint("Opens a detailed in-app screen about Tesla’s inventions.")
                }

                Divider().opacity(0.2)

                Text("Selected milestones")
                    .font(.headline)

                EVBulletRow(
                    "1888 – AC induction motor and rotating magnetic field concepts published.",
                    isCritical: true,
                    highlight: highlightEVImpact
                )
                EVBulletRow(
                    "1888 – Polyphase (three-phase) AC systems proposed, enabling efficient long-distance power.",
                    isCritical: true,
                    highlight: highlightEVImpact
                )
                EVBulletRow(
                    "1891 – Tesla coil developed for high-voltage, high-frequency experiments.",
                    isCritical: false,
                    highlight: highlightEVImpact
                )
                EVBulletRow(
                    "1893 – AC power showcased at the Chicago World’s Fair, demonstrating a practical grid.",
                    isCritical: true,
                    highlight: highlightEVImpact
                )
                EVBulletRow(
                    "1898 – Radio-controlled ‘teleautomaton’ boat demonstrated.",
                    isCritical: false,
                    highlight: highlightEVImpact
                )
                EVBulletRow(
                    "1901–1906 – Wardenclyffe Tower and wireless power research.",
                    isCritical: false,
                    highlight: highlightEVImpact
                )
            }
        }
    }

    // MARK: - Tesla, Inc.

    private var teslaIncCard: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(title: "Tesla, Inc.", symbol: "car.fill")

                Text("""
Founded in 2003 by engineers Martin Eberhard and Marc Tarpenning. Elon Musk led the 2004 Series A investment and became CEO in 2008. Strategy: prove EVs can be better than gas cars, then scale via mass-market models and a proprietary charging network.
""")
                .font(.subheadline)

                Divider().opacity(0.2)

                Text("Key milestones")
                    .font(.headline)

                EVBulletRow(
                    "2008 – Tesla Roadster launch, delivering sports-car performance with long-range lithium-ion batteries.",
                    isCritical: true,
                    highlight: highlightEVImpact
                )
                EVBulletRow(
                    "2012 – Model S sedan; 2015 – Model X SUV; 2017 – Model 3; 2020 – Model Y crossover.",
                    isCritical: true,
                    highlight: highlightEVImpact
                )
                EVBulletRow(
                    "Ongoing – Global rollout of Gigafactories and the Supercharger network.",
                    isCritical: true,
                    highlight: highlightEVImpact
                )
                EVBulletRow(
                    "Nov 30, 2023 – First Cybertruck deliveries at Gigafactory Texas.",
                    isCritical: true,
                    highlight: highlightEVImpact
                )

                BulletRow("Expanded into energy storage (Powerwall, Megapack) and solar, tying EVs into home and grid-scale storage.")
            }
        }
    }

    // MARK: - Rivian

    private var rivianCard: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(title: "Rivian Automotive, Inc.", symbol: "truck.pickup.side.fill")

                Text("""
Founded in 2009 by RJ Scaringe (originally as Mainstream/Avera Motors; renamed Rivian in 2011). Focus: electric adventure vehicles and commercial delivery vans.
""")
                .font(.subheadline)

                Divider().opacity(0.2)

                Text("Key milestones")
                    .font(.headline)

                EVBulletRow(
                    "2018 – R1T pickup and R1S SUV revealed with off-road and adventure-focused positioning.",
                    isCritical: true,
                    highlight: highlightEVImpact
                )
                EVBulletRow(
                    "2021 – First R1T customer deliveries from the Normal, Illinois plant.",
                    isCritical: true,
                    highlight: highlightEVImpact
                )
                EVBulletRow(
                    "2021+ – Commercial van partnership with Amazon for electric delivery vehicles (EDVs).",
                    isCritical: true,
                    highlight: highlightEVImpact
                )
                EVBulletRow(
                    "Mar 7, 2024 – R2 mid-size SUV and R3/R3X revealed, targeting more affordable segments.",
                    isCritical: true,
                    highlight: highlightEVImpact
                )

                BulletRow("Rivian builds an ecosystem around off-road capability, over-the-air updates, and software-driven features similar to Tesla’s approach.")
            }
        }
    }

    // MARK: - Comparison

    private var comparisonCard: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(title: "Tesla vs. Rivian – Focus & Impact", symbol: "chart.bar.xaxis")

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("Tesla").font(.subheadline.bold())
                        Text("Rivian").font(.subheadline.bold())
                    }

                    Divider().gridCellUnsizedAxes(.horizontal)

                    GridRow {
                        BulletRow("High-volume consumer EVs across sedan, SUV, crossover, and now pickup.")
                        BulletRow("Adventure-focused pickups/SUVs plus commercial delivery vans.")
                    }
                    GridRow {
                        BulletRow("Supercharger network and global DC fast-charging expansion.")
                        BulletRow("Adventure-biased charging and partnerships; leverages broader DC networks.")
                    }
                    GridRow {
                        BulletRow("Strong emphasis on software, OTA updates, and driver-assist (Autopilot/FSD).")
                        BulletRow("Software-centric approach with OTA updates and off-road / trail-focused modes.")
                    }
                    GridRow {
                        BulletRow("Scale: major influence on EV adoption curves and charging standards.")
                        BulletRow("Influence: pushes EVs into outdoor, fleet, and logistics use-cases.")
                    }
                }
                .font(.footnote)
            }
        }
    }

    // MARK: - Learn more

    private var learnMoreCard: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(title: "Learn more", symbol: "arrow.up.right.square")

                if let dest = inventionsDestination {
                    NavigationLink {
                        dest()
                    } label: {
                        Label("In-app: Tesla Inventions", systemImage: "book")
                            .font(.callout.weight(.semibold))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Link(
                        "Tesla – Cybertruck Delivery Event (Nov 30, 2023)",
                        destination: URL(string: "https://www.tesla.com/cybertruck-delivery-event")!
                    )
                    Link(
                        "Rivian – R2 / R3 reveal announcement (Mar 7, 2024)",
                        destination: URL(string: "https://rivian.com/newsroom/article/rivian-announces-mid-sized-platform")!
                    )
                }
                .font(.callout)
            }
        }
    }

    // MARK: - Footer

    private var footerStamp: some View {
        Text("Facts last reviewed \(lastReviewed).")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .textSelection(.enabled)
    }
}

// MARK: - Shared Card Surface

fileprivate struct CardSurface<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        scheme == .dark
                        ? Color.white.opacity(0.06)
                        : Color(uiColor: .systemBackground).opacity(0.96)
                    )
                    .background(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        scheme == .dark
                        ? Color.white.opacity(0.18)
                        : Color.black.opacity(0.06),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(scheme == .dark ? 0.55 : 0.12),
                radius: scheme == .dark ? 14 : 8,
                x: 0,
                y: scheme == .dark ? 10 : 4
            )
    }
}

// MARK: - Small Reusable Bits

fileprivate struct CardHeader: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .imageScale(.medium)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.title3.bold())
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

fileprivate struct BulletRow: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
                .accessibilityHidden(true)
            Text(text)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

fileprivate struct EVBulletRow: View {
    let text: String
    let isCritical: Bool
    let highlight: Bool

    init(_ text: String, isCritical: Bool, highlight: Bool) {
        self.text = text
        self.isCritical = isCritical
        self.highlight = highlight
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
                .accessibilityHidden(true)

            if isCritical && highlight {
                Image(systemName: "bolt.fill")
                    .imageScale(.small)
                    // Explicit Color prevents the HierarchicalShapeStyle inference issue.
                    .foregroundStyle(Color.yellow)
                    .accessibilityLabel("EV-impact item")
            }

            Text(text)
                .font(.subheadline)
                .padding(isCritical && highlight ? EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6) : .init())
                .background {
                    if isCritical && highlight {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                            )
                    }
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isCritical ? "EV-impact: \(text)" : text)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HistoryOfTeslaAndRivianView()
            .preferredColorScheme(.dark)
    }
}
