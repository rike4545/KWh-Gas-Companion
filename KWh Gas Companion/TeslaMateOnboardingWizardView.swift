//
//  TeslaMateOnboardingWizardView.swift
//  KWh Gas Companion
//
//  TeslaMate setup wizard copy + paths for new vs existing users.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct TeslaMateOnboardingWizardView: View {
    @State private var step: WizardStep = .welcome

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    wizardHeader
                    step.header
                    step.content(onJump: { next in
                        step = next
                    })
                }
                .padding(16)
            }

            Divider()

            HStack(spacing: 12) {
                Button("Back") { step = step.previous ?? step }
                    .buttonStyle(.bordered)
                    .disabled(step.previous == nil)

                Spacer()

                if let next = step.next {
                    Button(step.nextTitle) { step = next }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Done") { step = .welcome }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
        }
        .navigationTitle("TeslaMate Setup")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var wizardHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)
                Text("Setup Wizard")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let progress = step.progress {
                WizardProgressView(current: progress.current, total: progress.total)
            }
        }
    }
}

private enum WizardStep {
    case welcome
    case haveTeslamate
    case deploymentType
    case authChoice
    case existingSelfHosted
    case existingMyTeslaMate
    case newStart
    case newSelfHosted
    case newMyTeslaMate

    struct Progress {
        let current: Int
        let total: Int
    }

    var previous: WizardStep? {
        switch self {
        case .welcome: return nil
        case .haveTeslamate: return .welcome
        case .deploymentType: return .haveTeslamate
        case .authChoice: return .deploymentType
        case .existingSelfHosted, .existingMyTeslaMate: return .deploymentType
        case .newStart: return .welcome
        case .newSelfHosted, .newMyTeslaMate: return .newStart
        }
    }

    var next: WizardStep? {
        switch self {
        case .welcome: return .haveTeslamate
        case .haveTeslamate: return .deploymentType
        case .deploymentType: return .authChoice
        case .authChoice: return nil
        case .existingSelfHosted, .existingMyTeslaMate: return nil
        case .newStart: return nil
        case .newSelfHosted, .newMyTeslaMate: return nil
        }
    }

    var nextTitle: String {
        switch self {
        case .welcome: return "Yes, I do"
        case .haveTeslamate: return "Choose Type"
        default: return "Next"
        }
    }

    var progress: Progress? {
        switch self {
        case .welcome: return .init(current: 1, total: 3)
        case .haveTeslamate: return .init(current: 2, total: 3)
        case .deploymentType: return .init(current: 3, total: 4)
        case .authChoice: return .init(current: 4, total: 4)
        case .newStart: return .init(current: 2, total: 3)
        case .newSelfHosted, .newMyTeslaMate, .existingSelfHosted, .existingMyTeslaMate:
            return .init(current: 3, total: 3)
        }
    }

    var header: some View {
        switch self {
        case .welcome:
            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    Text("TeslaMate Setup Wizard")
                        .font(.title2.bold())
                    Text("Not sure? No worries, we’ll help you find the right path.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            )
        case .haveTeslamate:
            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    Text("Do you already have TeslaMate?")
                        .font(.title2.bold())
                    Text("Choose the path that matches your setup.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            )
        case .deploymentType:
            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    Text("What type of TeslaMate do you have?")
                        .font(.title2.bold())
                    Text("Different types require different setup methods.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            )
        case .authChoice:
            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose Your Tesla API Path")
                        .font(.title2.bold())
                    Text("You decide what’s best: maximum control with your own app, or fastest setup with the MyTeslaMate proxy.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            )
        case .existingSelfHosted:
            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    Text("Existing TeslaMate (Self‑hosted)")
                        .font(.title2.bold())
                    Text("If you already have TeslaMate deployed, add the API service and connect the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            )
        case .existingMyTeslaMate:
            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    Text("Existing TeslaMate (myTeslaMate)")
                        .font(.title2.bold())
                    Text("Use your myteslamate.com add‑on to enable the API and connect the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            )
        case .newStart:
            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    Text("I’m new to TeslaMate")
                        .font(.title2.bold())
                    Text("We’ll get you set up from scratch.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            )
        case .newSelfHosted:
            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start with Self‑hosted TeslaMate")
                        .font(.title2.bold())
                    Text("Best for technical users who want full control.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            )
        case .newMyTeslaMate:
            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start with myTeslaMate Hosted")
                        .font(.title2.bold())
                    Text("Fastest path with minimal technical setup.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            )
        }
    }

    func content(onJump: @escaping (WizardStep) -> Void) -> some View {
        switch self {
        case .welcome:
            return AnyView(
                VStack(alignment: .leading, spacing: 12) {
                    WizardOptionCard(
                        title: "Yes, I do",
                        subtitle: "I already have TeslaMate and need to connect to the app.",
                        systemImage: "checkmark.seal.fill",
                        primary: true,
                        action: { onJump(.deploymentType) }
                    )

                    Divider().opacity(0.6)

                    WizardOptionCard(
                        title: "No, I want to start",
                        subtitle: "I’m new and need to set up from scratch.",
                        systemImage: "wand.and.stars",
                        primary: false,
                        action: { onJump(.newStart) }
                    )
                }
            )
        case .haveTeslamate:
            return AnyView(
                VStack(alignment: .leading, spacing: 12) {
                    WizardOptionCard(
                        title: "Yes, I do",
                        subtitle: "I already have TeslaMate and need to connect to the app.",
                        systemImage: "checkmark.seal.fill",
                        primary: true,
                        action: { onJump(.deploymentType) }
                    )

                    WizardOptionCard(
                        title: "No, I want to start",
                        subtitle: "I’m new and need to set up from scratch.",
                        systemImage: "wand.and.stars",
                        primary: false,
                        action: { onJump(.newStart) }
                    )
                }
            )
        case .deploymentType:
            return AnyView(
                VStack(alignment: .leading, spacing: 12) {
                    WizardOptionCard(
                        title: "Self‑hosted TeslaMate",
                        subtitle: "Built with Docker on your own server (home NAS, cloud server, etc.).",
                        systemImage: "server.rack",
                        primary: true,
                        action: { onJump(.existingSelfHosted) }
                    )

                    Text("Requires running Docker commands.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    WizardOptionCard(
                        title: "myTeslaMate Hosted",
                        subtitle: "Subscribed to myteslamate.com cloud hosting service.",
                        systemImage: "cloud.fill",
                        primary: false,
                        action: { onJump(.existingMyTeslaMate) }
                    )

                    Text("Web‑based, no technical knowledge needed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            )
        case .authChoice:
            return AnyView(
                VStack(alignment: .leading, spacing: 12) {
                    WizardOptionCard(
                        title: "Use MyTeslaMate Proxy",
                        subtitle: "Fastest setup, minimal infrastructure. You rely on a hosted proxy.",
                        systemImage: "bolt.horizontal.circle.fill",
                        primary: true,
                        action: { onJump(.existingMyTeslaMate) }
                    )

                    WizardOptionCard(
                        title: "Register Your Own Tesla API App",
                        subtitle: "Maximum control and portability. You own credentials and setup.",
                        systemImage: "key.horizontal.fill",
                        primary: false,
                        action: { onJump(.existingSelfHosted) }
                    )

                    Text("Both options work. Choose what fits your needs best.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            )
        case .existingSelfHosted:
            return AnyView(existingSelfHostedContent)
        case .existingMyTeslaMate:
            return AnyView(existingMyTeslaMateContent)
        case .newStart:
            return AnyView(
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose your deployment method")
                        .font(.headline)
                    Text("Whether you’re a TeslaMate veteran or newcomer, we have a solution for you.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    WizardOptionCard(
                        title: "Self‑hosted TeslaMate",
                        subtitle: "Best for technical users who want full control.",
                        systemImage: "server.rack",
                        primary: true,
                        action: { onJump(.newSelfHosted) }
                    )

                    WizardOptionCard(
                        title: "myTeslaMate Hosted",
                        subtitle: "Fastest path with minimal technical setup.",
                        systemImage: "cloud.fill",
                        primary: false,
                        action: { onJump(.newMyTeslaMate) }
                    )
                }
            )
        case .newSelfHosted:
            return AnyView(
                VStack(alignment: .leading, spacing: 12) {
                    Text("Self‑hosted path")
                        .font(.headline)
                    Text("You’ll need Docker and a server to run TeslaMate. We can guide you to the exact steps next.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    WizardBulletList(items: [
                        "Install Docker on your server or NAS",
                        "Deploy TeslaMate with PostgreSQL + MQTT",
                        "Enable the TeslaMate API service",
                        "Connect the app with your endpoint + token"
                    ])
                }
            )
        case .newMyTeslaMate:
            return AnyView(
                VStack(alignment: .leading, spacing: 12) {
                    Text("myTeslaMate hosted path")
                        .font(.headline)
                    Text("Sign up at myteslamate.com and enable the TeslaMate API add‑on. Then connect here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    WizardBulletList(items: [
                        "Create a myteslamate.com account",
                        "Enable the TeslaMate API add‑on",
                        "Copy your endpoint URL + token",
                        "Connect in the app"
                    ])
                }
            )
        }
    }
}

private var existingSelfHostedContent: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Existing TeslaMate")
            .font(.headline)
        Text("If you already have TeslaMate deployed, add the mytesla API service to get started.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        WizardBulletList(items: [
            "Add mytesla API service to docker‑compose.yml",
            "Configure environment variables for database connection",
            "Run docker‑compose up -d",
            "Configure API URL in the app"
        ])

        Text("Terminal Commands")
            .font(.headline)

        WizardCodeBlock(
            code: """
# docker-compose.yml - Add this service
  teslamateapi:
    image: mytesla/teslamateapi:latest
    restart: unless-stopped
    depends_on:
      - database
      - teslamate
      - mosquitto
    environment:
      - DATABASE_USER=${TM_DB_USER}
      - DATABASE_PASS=${TM_DB_PASS}
      - DATABASE_NAME=${TM_DB_NAME}
      - DATABASE_HOST=database
      - ENCRYPTION_KEY=${TM_ENCRYPTION_KEY}
      - MQTT_HOST=mosquitto
      - API_TOKEN=${API_TOKEN}
    ports:
      - 3030:8080

# Then run:
docker compose up -d teslamateapi
"""
        )

        Text("Environment Variables")
            .font(.headline)
        WizardBulletList(items: [
            "DATABASE_* required (must match TeslaMate database configuration)",
            "MQTT_HOST required (usually mosquitto container name)",
            "ENCRYPTION_KEY required (must match TeslaMate ENCRYPTION_KEY)",
            "API_TOKEN recommended (used for app authentication)"
        ])

        Text("App Configuration")
            .font(.headline)
        WizardBulletList(items: [
            "Open the app → Settings → Pro Features → Server Config",
            "API Address: http://192.168.1.x:3030 or https://your-domain.com",
            "Token Auth: use API_TOKEN from docker-compose",
            "Tap Test Connection, then select your vehicle"
        ])

        Text("Fleet Tokens (Tesla API Application)")
            .font(.headline)
        Text("Generate Tesla Fleet API tokens for TeslaMate or other self‑hosted apps.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        WizardCodeBlock(
            code: """
[Windows] Open PowerShell and run:
iex "& { $(iwr -UseBasicParsing \"https://raw.githubusercontent.com/MyTeslaMate/tesla-fleet-api-tokens/refs/tags/v0.0.12/tokens.ps1\") } 7547
"""
        )

        WizardCodeBlock(
            code: """
[Mac / Linux] Open Terminal and run:
curl -fsSL https://raw.githubusercontent.com/MyTeslaMate/tesla-fleet-api-tokens/refs/tags/v0.0.12/tokens.sh | bash -s -- 7547
"""
        )
    }
}

private var existingMyTeslaMateContent: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("myTeslaMate Users")
            .font(.headline)
        Text("myteslamate offers hosted TeslaMate connectivity services without local installation.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        WizardBulletList(items: [
            "Go to Add‑on section in myteslamate dashboard",
            "Enable “TeslaMate API & MQTT” and select mytesla/teslamateapi:latest",
            "Copy the generated Endpoint URL and Token",
            "Open the app → Settings → Pro Features → Server Config",
            "Enter Endpoint as API URL and Token for authentication"
        ])

        Text("Proxy Environment (example)")
            .font(.headline)
        Text("Use values provided by your MyTeslaMate dashboard. Keep tokens private.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        WizardCodeBlock(
            code: """
TESLA_API_HOST=https://api.myteslamate.com
TESLA_AUTH_HOST=https://api.myteslamate.com
TESLA_AUTH_PATH=/api/oauth2/v3
TOKEN=?token=YOUR_PROXY_TOKEN
TESLA_WSS_HOST=wss://streaming.myteslamate.com
TESLA_WSS_TLS_ACCEPT_INVALID_CERTS=true
TESLA_WSS_USE_VIN=true
"""
        )

        Text("evcc Setup (Tesla Wall Connector)")
            .font(.headline)
        Text("Create your own Tesla App for clientId, then use your proxy token.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        WizardCodeBlock(
            code: """
vehicles:
  - type: template
    template: tesla
    title: Tesla Model 3
    clientId: YOUR_TESLA_CLIENT_ID
    accessToken: YOUR_ACCESS_TOKEN
    refreshToken: YOUR_REFRESH_TOKEN
    proxyToken: YOUR_PROXY_TOKEN
"""
        )

        Text("MCP Server Setup (optional)")
            .font(.headline)
        Text("Use your proxy token for authorization.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        WizardCodeBlock(
            code: """
claude mcp add --transport http secure-api "https://mcp.myteslamate.com/mcp?tags=tesla_fleet_api" --header "Authorization: Bearer YOUR_PROXY_TOKEN"
"""
        )

        WizardCodeBlock(
            code: """
{"servers":{"tesla_fleet_api":{"type":"http","url":"https://mcp.myteslamate.com/mcp?tags=tesla_fleet_api","headers":{"Authorization":"Bearer YOUR_PROXY_TOKEN"}}}}
"""
        )

        Text("Fleet Tokens (Tesla API Application)")
            .font(.headline)
        Text("If prompted by your hosting provider, generate tokens with the official Tesla Fleet API flow.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        WizardCodeBlock(
            code: """
[Windows] Open PowerShell and run:
iex "& { $(iwr -UseBasicParsing \"https://raw.githubusercontent.com/MyTeslaMate/tesla-fleet-api-tokens/refs/tags/v0.0.12/tokens.ps1\") } 7547
"""
        )

        WizardCodeBlock(
            code: """
[Mac / Linux] Open Terminal and run:
curl -fsSL https://raw.githubusercontent.com/MyTeslaMate/tesla-fleet-api-tokens/refs/tags/v0.0.12/tokens.sh | bash -s -- 7547
"""
        )
    }
}

private struct WizardProgressView: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...total, id: \.self) { idx in
                Circle()
                    .fill(idx <= current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
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
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(primary ? Color.accentColor : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.thinMaterial)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct WizardBulletList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.caption)
                        .padding(.top, 2)
                    Text(item)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct WizardCodeBlock: View {
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Copy")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(copied ? "Copied" : "Copy") {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = code
                    #endif
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        copied = false
                    }
                }
                .buttonStyle(.bordered)
            }

            Text(code)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.thinMaterial)
                )
        }
    }
}
