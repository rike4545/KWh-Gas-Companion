//
//  WinterDrivingTechniquesView.swift
//  KWh Gas Companion
//
//  Created by Bryan on 1/26/26.
//


//
//  WinterDrivingTechniquesView.swift
//  My KWh Companion
//
//  Winter driving techniques (EV + ICE friendly)
//  Swift 6 • iOS 17+
//

import SwiftUI

@MainActor
struct WinterDrivingTechniquesView: View {

    @Environment(\.appThemeBox) private var themeBox
    @EnvironmentObject private var appearance: AppAppearance

    private var theme: any AppThemeSpec { themeBox.base }
    private var accent: Color { appearance.accentColor }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing + 8) {

                introCard

                card(title: "Before you drive", systemImage: "checklist") {
                    BulletList(items: [
                        "Clear ALL snow/ice: roof, hood, lights, cameras/sensors, and plates.",
                        "Check tire pressure — cold air drops PSI (underinflation reduces traction and efficiency).",
                        "Use proper tires: winter tires beat “all-season” in real snow/ice.",
                        "Preheat/precondition while plugged in (warms cabin + battery, saves range).",
                        "Set gentle regen/one-pedal if conditions are slick — avoid abrupt decel."
                    ], theme: theme)
                }

                card(title: "Traction & control on snow/ice", systemImage: "snowflake") {
                    BulletList(items: [
                        "Smooth inputs: gentle throttle, gentle steering, gentle braking.",
                        "Increase following distance (think 6–10 seconds, more in heavy snow).",
                        "Avoid sudden lane changes; keep tires rolling, not sliding.",
                        "If you start to skid: look where you want to go, ease off, steer smoothly into control.",
                        "Use traction/stability controls — don’t disable unless you’re truly stuck and need wheel spin."
                    ], theme: theme)
                }

                card(title: "Braking & regen (EVs)", systemImage: "bolt.circle") {
                    BulletList(items: [
                        "Regen can be strong and surprise you on slick surfaces — use a low regen mode if available.",
                        "Prefer smooth, early deceleration; avoid last-second braking.",
                        "Know the feel of ABS: steady pressure, let the system work.",
                        "If your EV offers “slip start”/snow mode, use it only when needed (it reduces intervention)."
                    ], theme: theme)
                }

                card(title: "Visibility & awareness", systemImage: "eye") {
                    BulletList(items: [
                        "Keep windshield washer fluid rated for sub-freezing temps.",
                        "Use headlights in snow (even daytime) so others can see you.",
                        "Defog smart: A/C helps dehumidify even in winter.",
                        "Watch for black ice: bridges, shaded areas, and temps near freezing."
                    ], theme: theme)
                }

                card(title: "Energy & range tips (EVs)", systemImage: "battery.100") {
                    BulletList(items: [
                        "Cold reduces range: plan a buffer (especially for highway driving).",
                        "Cabin heat is expensive — use seat/steering wheel heaters first when possible.",
                        "Drive a bit slower on highways: aerodynamic drag is a big winter range killer.",
                        "Use route planning that accounts for temperature, elevation, and wind."
                    ], theme: theme)
                }

                card(title: "Charging in the cold", systemImage: "bolt.fill") {
                    BulletList(items: [
                        "Fast charging is best after the battery is warm — precondition en-route to DC fast chargers.",
                        "Expect slower charging when the pack is cold (and more time to reach the same %).",
                        "If you can, arrive with a lower state of charge for faster charging curves.",
                        "Keep a backup plan: alternate chargers and a conservative arrival buffer."
                    ], theme: theme)
                }

                card(title: "If you get stuck", systemImage: "car.rear.and.tire.marks") {
                    BulletList(items: [
                        "Clear snow from around tires and under the car (especially EV battery shield area).",
                        "Use sand/cat litter/traction mats for grip.",
                        "Rock gently: forward a bit, reverse a bit — avoid high wheel spin (overheats, polishes ice).",
                        "If safe, lower tire pressure slightly for traction only as a last resort — reinflate ASAP."
                    ], theme: theme)
                }

                card(title: "Emergency kit basics", systemImage: "cross.case") {
                    BulletList(items: [
                        "Warm layers, gloves, hat, blanket.",
                        "Phone charger, flashlight, reflective triangle/flares.",
                        "Snow brush/ice scraper, small shovel, traction aid.",
                        "Water + snacks.",
                        "First-aid kit."
                    ], theme: theme)
                }

                quickChecklistCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .navigationTitle("Winter Driving")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accent)
        .background(
            Rectangle()
                .fill(theme.screenBackground)
                .ignoresSafeArea()
        )
    }

    private var introCard: some View {
        card(title: "Winter driving techniques", systemImage: "thermometer.snowflake") {
            Text("A practical guide for safer winter driving—focused on traction, visibility, and cold-weather EV specifics like regen and charging.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var quickChecklistCard: some View {
        card(title: "Quick checklist before you leave", systemImage: "checkmark.seal") {
            VStack(alignment: .leading, spacing: 10) {
                ChecklistRow(text: "Snow cleared from roof/lights/cameras", theme: theme)
                ChecklistRow(text: "Tire pressure + tread OK", theme: theme)
                ChecklistRow(text: "Washer fluid good for freezing temps", theme: theme)
                ChecklistRow(text: "Charging plan + backup charger (EV)", theme: theme)
                ChecklistRow(text: "Extra time + extra distance", theme: theme)
            }
        }
    }

    // MARK: - Card UI

    private func card<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            content()
        }
        .padding(theme.spacing)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                .strokeBorder(theme.separator.opacity(0.85), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: theme.elevation, x: 0, y: 2)
    }
}

// MARK: - Helpers

private struct BulletList: View {
    let items: [String]
    let theme: any AppThemeSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items.indices, id: \.self) { idx in
                HStack(alignment: .top, spacing: 10) {
                    Text("•")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)

                    Text(items[idx])
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct ChecklistRow: View {
    let text: String
    let theme: any AppThemeSpec

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
