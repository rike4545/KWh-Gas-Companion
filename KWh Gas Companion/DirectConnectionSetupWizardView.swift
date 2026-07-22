//
//  DirectConnectionSetupWizardView.swift
//  KWh Gas Companion
//
//  TeslaMate setup guide for direct and proxy-backed connections.
//

import SwiftUI

@MainActor
struct DirectConnectionSetupWizardView: View {
    @State private var step: DirectConnectionWizardStep = .welcome

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    wizardHeader
                    step.header
                    step.content { next in
                        step = next
                    }
                }
                .padding(16)
            }

            Divider()

            HStack(spacing: 12) {
                Button("Back") {
                    step = step.previous ?? step
                }
                .buttonStyle(.bordered)
                .disabled(step.previous == nil)

                Spacer()

                if let next = step.next {
                    Button(step.nextTitle) {
                        step = next
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Done") {
                        step = .welcome
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
        }
        .navigationTitle("Connection Setup")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var wizardHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)
                Text("Setup Guide")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let progress = step.progress {
                WizardProgressView(current: progress.current, total: progress.total)
            }
        }
    }
}

private enum DirectConnectionWizardStep {
    case welcome
    case choosePath
    case selfHosted
    case hostedProxy
    case ownerAPITokens

    struct Progress {
        let current: Int
        let total: Int
    }

    var previous: DirectConnectionWizardStep? {
        switch self {
        case .welcome: return nil
        case .choosePath: return .welcome
        case .selfHosted, .hostedProxy, .ownerAPITokens: return .choosePath
        }
    }

    var next: DirectConnectionWizardStep? {
        switch self {
        case .welcome: return .choosePath
        case .choosePath, .selfHosted, .hostedProxy, .ownerAPITokens: return nil
        }
    }

    var nextTitle: String {
        switch self {
        case .welcome: return "Continue"
        default: return "Next"
        }
    }

    var progress: Progress? {
        switch self {
        case .welcome: return .init(current: 1, total: 2)
        case .choosePath: return .init(current: 2, total: 2)
        case .selfHosted, .hostedProxy, .ownerAPITokens: return .init(current: 2, total: 2)
        }
    }

    @ViewBuilder
    var header: some View {
        switch self {
        case .welcome:
            VStack(alignment: .leading, spacing: 8) {
                Text("TeslaMate setup")
                    .font(.title2.bold())
                Text("Choose the connection path that matches how you access TeslaMate from this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .choosePath:
            VStack(alignment: .leading, spacing: 8) {
                Text("How do you connect?")
                    .font(.title2.bold())
                Text("You can point the app at TeslaMateApi, a compatible read-only proxy, or a hosted endpoint that gives you a URL and token.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .selfHosted:
            VStack(alignment: .leading, spacing: 8) {
                Text("Self-hosted TeslaMate")
                    .font(.title2.bold())
                Text("Use this if you manage TeslaMate, TeslaMateApi, Grafana, PostgreSQL, or MQTT yourself.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .hostedProxy:
            VStack(alignment: .leading, spacing: 8) {
                Text("Hosted proxy")
                    .font(.title2.bold())
                Text("Use this if a service provides a ready-made TeslaMate-compatible endpoint URL and token for you.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .ownerAPITokens:
            VStack(alignment: .leading, spacing: 8) {
                Text("Tesla Owner API tokens")
                    .font(.title2.bold())
                Text("Use this only if your TeslaMate-compatible backend already handles Tesla OAuth safely.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    func content(onJump: @escaping (DirectConnectionWizardStep) -> Void) -> some View {
        switch self {
        case .welcome:
            VStack(alignment: .leading, spacing: 12) {
                WizardOptionCard(
                    title: "Set up TeslaMate",
                    subtitle: "Review supported TeslaMate connection styles.",
                    systemImage: "server.rack",
                    primary: true,
                    action: { onJump(.choosePath) }
                )

                Text("You’ll only need a base URL and an access token once your TeslaMate API endpoint is ready.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .choosePath:
            VStack(alignment: .leading, spacing: 12) {
                WizardOptionCard(
                    title: "Self-hosted TeslaMate",
                    subtitle: "You run TeslaMate and expose TeslaMateApi or a compatible API.",
                    systemImage: "server.rack",
                    primary: true,
                    action: { onJump(.selfHosted) }
                )

                WizardOptionCard(
                    title: "Hosted proxy",
                    subtitle: "A provider gives you a TeslaMate-compatible endpoint URL and token.",
                    systemImage: "cloud.fill",
                    primary: false,
                    action: { onJump(.hostedProxy) }
                )

                WizardOptionCard(
                    title: "Owner API token backend",
                    subtitle: "Advanced setups where your backend handles Tesla OAuth separately.",
                    systemImage: "key.horizontal",
                    primary: false,
                    action: { onJump(.ownerAPITokens) }
                )
            }
        case .selfHosted:
            VStack(alignment: .leading, spacing: 12) {
                Text("Recommended checklist")
                    .font(.headline)
                WizardBulletList(items: [
                    "Deploy TeslaMate, then enable TeslaMateApi or another read-only API exposing cars, drives, charges, and status endpoints.",
                    "Keep PostgreSQL and MQTT private unless you are deliberately using your own backend in front of them.",
                    "Confirm the API is reachable from your device over HTTPS, HTTP on your LAN, or a trusted VPN.",
                    "Create or copy an API token that the app can use for read access.",
                    "Paste the base URL and token into TeslaMate Connection in the app.",
                    "Run Test connection, select the vehicle, then import fetched charges if you want them in app analytics."
                ])
                Text("TeslaMate support reads status, drives, charges, geofences, and vehicle-detail fields when the endpoint provides them. If an endpoint omits tire pressure, software version, or battery-health values, those cards stay marked as unknown.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .hostedProxy:
            VStack(alignment: .leading, spacing: 12) {
                Text("Recommended checklist")
                    .font(.headline)
                WizardBulletList(items: [
                    "Copy the endpoint URL provided by your hosting service.",
                    "Copy the token exactly as provided, including any query-string token if required.",
                    "Turn on Pass token in query string if your provider expects that format.",
                    "Run Test connection, then select the vehicle you want to inspect or import."
                ])
            }
        case .ownerAPITokens:
            VStack(alignment: .leading, spacing: 12) {
                Text("Implementation notes")
                    .font(.headline)
                WizardBulletList(items: [
                    "Tesla Owner API access tokens are OAuth bearer tokens and should be refreshed with the paired refresh token by your backend.",
                    "Avoid repeated automated login attempts against Tesla SSO; token refresh should be the normal path after setup.",
                    "This app expects a TeslaMate-compatible read endpoint URL and token, not a Tesla account email or password.",
                    "Keep TeslaMate, TeslaFi, and Tesla Owner API tokens separate; they are different credentials for different services."
                ])
            }
        }
    }
}

private struct WizardProgressView: View {
    let current: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: Double(current), total: Double(total))
            Text("Step \(current) of \(total)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct WizardOptionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let primary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .frame(width: 28)
                    .foregroundStyle(primary ? .white : .primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(primary ? .white : .primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(primary ? Color.white.opacity(0.82) : .secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(primary ? Color.white.opacity(0.82) : .secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(primary ? AnyShapeStyle(.tint) : AnyShapeStyle(.thinMaterial))
    }
}

private struct WizardBulletList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                    Text(item)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
    }
}
