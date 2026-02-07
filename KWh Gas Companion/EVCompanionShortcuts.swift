//
//  EVCompanionShortcuts.swift
//  My KWh Companion
//
//  iOS 17-safe App Shortcuts.
//  FIXES:
//  - Uses AppShortcutsProvider result-builder style (no array literal)
//  - No OpenURLIntent (iOS 18+)
//  - Every utterance contains EXACTLY ONE \(.applicationName)
//
//  Swift 6 • iOS 17+
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
struct EVCompanionShortcuts: AppShortcutsProvider {

    static var shortcutTileColor: ShortcutTileColor { .teal }

    static var appShortcuts: [AppShortcut] {

        AppShortcut(
            intent: OpenDashboardIntent(),
            phrases: [
                "Open dashboard in \(.applicationName)",
                "Show my dashboard in \(.applicationName)",
                "Go to dashboard in \(.applicationName)"
            ],
            shortTitle: "Dashboard",
            systemImageName: "speedometer"
        )

        AppShortcut(
            intent: OpenChargingDataIntent(),
            phrases: [
                "Open charging data in \(.applicationName)",
                "Show charging data in \(.applicationName)",
                "Go to charging data in \(.applicationName)"
            ],
            shortTitle: "Charging Data",
            systemImageName: "bolt.car"
        )

        AppShortcut(
            intent: OpenToolsIntent(),
            phrases: [
                "Open tools in \(.applicationName)",
                "Show tools in \(.applicationName)",
                "Go to tools in \(.applicationName)"
            ],
            shortTitle: "Tools",
            systemImageName: "square.grid.2x2"
        )

        AppShortcut(
            intent: StartTeslaFiImportIntent(),
            phrases: [
                "Import TeslaFi in \(.applicationName)",
                "Start TeslaFi import in \(.applicationName)",
                "Open TeslaFi import in \(.applicationName)"
            ],
            shortTitle: "Import TeslaFi",
            systemImageName: "tray.and.arrow.down"
        )
    }
}

// MARK: - Intents (iOS 17-safe)

@available(iOS 16.0, *)
struct OpenDashboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Dashboard"
    static var description = IntentDescription("Opens My KWh Companion to the dashboard.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Opening your dashboard.")
    }
}

@available(iOS 16.0, *)
struct OpenChargingDataIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Charging Data"
    static var description = IntentDescription("Opens My KWh Companion to charging data tools.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Opening charging data.")
    }
}

@available(iOS 16.0, *)
struct OpenToolsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Tools"
    static var description = IntentDescription("Opens My KWh Companion to the tools screen.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Opening tools.")
    }
}

@available(iOS 16.0, *)
struct StartTeslaFiImportIntent: AppIntent {
    static var title: LocalizedStringResource = "Start TeslaFi Import"
    static var description = IntentDescription("Opens My KWh Companion so you can import a TeslaFi CSV.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Opening TeslaFi import.")
    }
}
