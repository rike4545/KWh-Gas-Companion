//
//  RightToRepairView.swift
//  My KWh Companion (My EV Companion)
//
//  Educational explainer: Right to Repair (EVs + Tesla context)
//  Swift 6 • iOS 17+
//
//  Notes:
//  - This view is informational and not legal advice.
//  - Language is intentionally neutral: describes common arguments from multiple sides.
//  - Includes a “Rich Rebuilds” reference as a well-known public example in the Tesla repair space.
//

import SwiftUI
import SafariServices

@MainActor
public struct RightToRepairView: View {

    public init() {}

    // MARK: - UI State

    private enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case tesla = "Tesla Context"
        case actions = "What You Can Do"
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .overview: return "wrench.and.screwdriver.fill"
            case .tesla: return "car.fill"
            case .actions: return "hand.raised.fill"
            }
        }
    }

    private struct WebSheet: Identifiable {
        let id = UUID()
        let url: URL
        let title: String
    }

    @State private var tab: Tab = .overview
    @State private var webSheet: WebSheet? = nil

    @Environment(\.colorScheme) private var scheme

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { t in
                        Label(t.rawValue, systemImage: t.icon).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 2)

                switch tab {
                case .overview:
                    overviewSection
                case .tesla:
                    teslaSection
                case .actions:
                    actionsSection
                }

                footerDisclaimer
                    .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .navigationTitle("Right to Repair")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $webSheet) { item in
            SafariSheetView(url: item.url)
                .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(scheme == .dark ? 0.12 : 0.06))
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.9))
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Right to Repair")
                        .font(.title2.weight(.semibold))
                    Text("Why repair access matters — especially for software-defined vehicles.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Quick takeaway", systemImage: "sparkles")
                        .font(.headline)

                    Text("Right to Repair is about whether owners and independent shops can get the parts, tools, documentation, and diagnostics needed to fix what they own — without being forced into a single repair channel.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("What it usually includes", systemImage: "checklist")
                        .font(.headline)

                    BulletList(items: [
                        "Access to replacement parts (new or refurbished) at fair terms.",
                        "Repair manuals, wiring diagrams, and service procedures.",
                        "Diagnostic tools/software and fault-code meanings.",
                        "The ability to calibrate/initialize components after replacement.",
                        "Reasonable access for independent shops (not just authorized centers)."
                    ])
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Why EVs raise the stakes", systemImage: "bolt.car.fill")
                        .font(.headline)

                    Text("EVs are more software-defined and sensor-heavy. Repair can be blocked by software pairing, calibration requirements, or locked diagnostics — even when the physical replacement is straightforward.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    BulletList(items: [
                        "Battery/thermal systems and high-voltage safety procedures.",
                        "ADAS sensors (cameras/radar/ultrasonics) needing calibration after collision repair.",
                        "Secure modules that may require software authorization to “marry” parts to a car.",
                        "Over-the-air updates that can change behavior and repair steps over time."
                    ])
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Common pro–consumer arguments", systemImage: "person.2.fill")
                        .font(.headline)

                    BulletList(items: [
                        "Lower repair costs through competition and more options.",
                        "Faster turnaround (especially where service centers are far away).",
                        "Longer product lifespan and less waste.",
                        "More transparency around maintenance and diagnostics.",
                        "Supports local jobs and independent repair ecosystems."
                    ])
                }
            }
        }
    }

    // MARK: - Tesla Context

    private var teslaSection: some View {
        VStack(alignment: .leading, spacing: 14) {

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Why Tesla (or any OEM) might resist", systemImage: "shield.lefthalf.filled")
                        .font(.headline)

                    Text("Companies that are cautious about right-to-repair often point to safety, security, liability, and quality control — especially when software and high-voltage systems are involved.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    BulletList(items: [
                        "Safety & liability: high-voltage systems, airbags, structural repairs, and ADAS calibration.",
                        "Cybersecurity: diagnostic endpoints and secure modules can be abuse targets if widely exposed.",
                        "Quality control: inconsistent repairs can lead to brand damage and repeat failures.",
                        "Supply chain: prioritizing parts for warranty work or high-demand repairs.",
                        "Revenue model: service/parts can be a meaningful business line."
                    ])
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("EV-specific friction points people cite", systemImage: "lock.open.fill")
                        .font(.headline)

                    BulletList(items: [
                        "Parts pairing / component authentication (a replacement part may need software authorization).",
                        "Restricted diagnostics (fault trees, live sensor data, or guided tests not fully available).",
                        "Limited access to official calibration workflows for cameras/sensors after repair.",
                        "Salvage/rebuilt policies and uncertainty around what features remain available."
                    ])
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Rich Rebuilds (public example)", systemImage: "play.rectangle.fill")
                        .font(.headline)

                    Text("Rich Rebuilds is a well-known independent shop/creator that has documented Tesla rebuilds and the practical challenges independent repair can face (parts availability, pairing, policy changes, and post-repair enablement).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        LinkButton(
                            title: "Open Rich Rebuilds",
                            systemImage: "safari",
                            action: {
                                openWeb(
                                    URL(string: "https://www.youtube.com/@RichRebuilds")!,
                                    title: "Rich Rebuilds"
                                )
                            }
                        )

                        LinkButton(
                            title: "Why it matters",
                            systemImage: "info.circle",
                            action: {
                                openWeb(
                                    URL(string: "https://en.wikipedia.org/wiki/Right_to_repair")!,
                                    title: "Right to Repair (Overview)"
                                )
                            }
                        )
                    }
                    .padding(.top, 2)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("A balanced way to think about it", systemImage: "scale.3d")
                        .font(.headline)

                    Text("Right to repair doesn’t have to mean “no safety or security.” Many proposals aim for a middle ground: access to what’s necessary to repair, with guardrails for high-risk systems and secure authentication flows.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    BulletList(items: [
                        "Publish safe repair procedures and torque/spec requirements.",
                        "Offer paid access to diagnostics/calibration tools for independent shops.",
                        "Use secure authentication that enables legitimate repairs (not blanket lockouts).",
                        "Provide transparent policies for rebuilt/salvage vehicles and feature eligibility."
                    ])
                }
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Practical steps as an owner", systemImage: "checkmark.seal.fill")
                        .font(.headline)

                    BulletList(items: [
                        "Keep detailed service records (photos, invoices, parts used).",
                        "Ask for itemized estimates and diagnostic notes (fault codes + findings).",
                        "When possible, choose repairers who document calibration and safety checks.",
                        "Back up vehicle settings and keep app/vehicle software up to date.",
                        "If a repair involves ADAS, confirm post-repair calibration was performed."
                    ])
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Learn more / advocacy", systemImage: "book.fill")
                        .font(.headline)

                    Text("If you want to follow the broader movement (across electronics, farm equipment, and vehicles):")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        LinkRow(
                            title: "Repair.org (Right to Repair)",
                            subtitle: "Policy updates, guides, and campaigns",
                            url: URL(string: "https://www.repair.org")!
                        )
                        LinkRow(
                            title: "iFixit",
                            subtitle: "Repair guides and repairability reporting",
                            url: URL(string: "https://www.ifixit.com")!
                        )
                    }
                    .padding(.top, 4)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Share this page", systemImage: "square.and.arrow.up")
                        .font(.headline)

                    Text("Use this as a quick explainer when discussing repair access with friends, shops, or local groups.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // ShareLink is iOS 16+ and works fine in iOS 17+
                    if let shareURL = URL(string: "https://www.repair.org") {
                        ShareLink(item: shareURL) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Repair.org")
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(scheme == .dark ? 0.12 : 0.07), in: Capsule(style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footerDisclaimer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Disclaimer")
                .font(.footnote.weight(.semibold))
            Text("This content is educational and may not reflect current law or any specific manufacturer policy in your region. Always follow high-voltage and safety procedures, and consult qualified professionals for complex repairs.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.primary.opacity(scheme == .dark ? 0.10 : 0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Helpers

    private func openWeb(_ url: URL, title: String) {
        webSheet = WebSheet(url: url, title: title)
    }
}

// MARK: - UI Components

fileprivate struct Card<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary.opacity(scheme == .dark ? 0.10 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(scheme == .dark ? 0.14 : 0.10), lineWidth: 1)
            )
    }
}

fileprivate struct BulletList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items.indices, id: \.self) { i in
                HStack(alignment: .top, spacing: 10) {
                    Text("•")
                        .font(.body.weight(.semibold))
                        .padding(.top, 1)
                    Text(items[i])
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

fileprivate struct LinkButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.08), in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

fileprivate struct LinkRow: View {
    @Environment(\.colorScheme) private var scheme

    let title: String
    let subtitle: String
    let url: URL

    @State private var webSheet: _RightToRepairWebSheet? = nil

    private struct _RightToRepairWebSheet: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        Button {
            webSheet = _RightToRepairWebSheet(url: url)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(scheme == .dark ? 0.14 : 0.08))
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(scheme == .dark ? 0.08 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(scheme == .dark ? 0.12 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(item: $webSheet) { item in
            SafariSheetView(url: item.url)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Safari Wrapper

fileprivate struct SafariSheetView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // no-op
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        RightToRepairView()
    }
}
#endif
