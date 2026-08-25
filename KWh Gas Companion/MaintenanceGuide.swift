//
//  MaintenanceGuide.swift
//  KWh Gas Companion
//
//  Static DIY / maintenance guide content + library.
//  Swift 6 • iOS 17+
//

import Foundation

// MARK: - Model

public enum MaintenanceGuideCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case wheelsAndTires = "Wheels & Tires"
    case filtersAndAir  = "Filters & Air"
    case cooling        = "Cooling"
    case diagnostics    = "Diagnostics"
    case charging       = "Charging"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .wheelsAndTires: return "circle.dashed"
        case .filtersAndAir:  return "wind"
        case .cooling:        return "thermometer.snowflake"
        case .diagnostics:    return "stethoscope"
        case .charging:       return "bolt.fill"
        }
    }
}

public enum MaintenanceDifficulty: String, CaseIterable, Identifiable, Hashable, Sendable {
    case easy      = "Easy"
    case moderate  = "Moderate"
    case advanced  = "Advanced"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .easy:     return "gauge.low"
        case .moderate: return "gauge.medium"
        case .advanced: return "gauge.high"
        }
    }
}

public struct MaintenanceGuideStep: Identifiable, Hashable, Sendable {
    public let id: String
    public let number: Int
    public let title: String
    public let detail: String
    /// Optional inline caution shown under the step body.
    public let caution: String?

    public init(id: String, number: Int, title: String, detail: String, caution: String? = nil) {
        self.id = id
        self.number = number
        self.title = title
        self.detail = detail
        self.caution = caution
    }
}

public struct MaintenanceSpec: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let value: String

    public init(id: String, label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

public struct MaintenanceGuide: Identifiable, Hashable, Sendable {
    public let id: String
    public let number: Int
    public let title: String
    public let summary: String
    public let category: MaintenanceGuideCategory
    public let difficulty: MaintenanceDifficulty
    public let timeEstimate: String
    public let systemImage: String
    /// What the procedure was written against.
    public let appliesTo: String
    public let tools: [String]
    public let parts: [String]
    public let steps: [MaintenanceGuideStep]
    public let specs: [MaintenanceSpec]
    public let warnings: [String]
    public let tips: [String]
    /// Touchscreen reset / follow-up note, when the job has one.
    public let resetNote: String?

    public var searchBlob: String {
        var parts: [String] = [title, summary, category.rawValue, difficulty.rawValue, appliesTo]
        parts.append(contentsOf: tools)
        parts.append(contentsOf: self.parts)
        parts.append(contentsOf: steps.map { "\($0.title) \($0.detail)" })
        parts.append(contentsOf: specs.map { "\($0.label) \($0.value)" })
        parts.append(contentsOf: tips)
        return parts.joined(separator: " ").lowercased()
    }
}

// MARK: - Library

public enum MaintenanceGuideLibrary {

    /// Shown once on the hub and again at the bottom of every guide.
    public static let disclaimer = """
    These guides are provided for reference only. Vehicle service carries real risk of \
    damage and injury. You are responsible for working safely, verifying every \
    specification against current Tesla owner and service documentation for your exact \
    vehicle, and knowing when a job belongs with a qualified technician.
    """

    public static let all: [MaintenanceGuide] = [
        tireRotation,
        cabinAirFilter,
        serviceMode,
        wheelTorque,
        frunkFilter,
        radiatorCleaning,
        homeCharging
    ]

    public static func guide(id: String) -> MaintenanceGuide? {
        all.first { $0.id == id }
    }

    public static var categoriesInUse: [MaintenanceGuideCategory] {
        let used = Set(all.map(\.category))
        return MaintenanceGuideCategory.allCases.filter(used.contains)
    }

    // MARK: 01 — Tire Rotation

    private static let tireRotation = MaintenanceGuide(
        id: "tire-rotation",
        number: 1,
        title: "Tire Rotation",
        summary: "Jack points, rotation patterns by tire type, and the torque spec that finishes the job.",
        category: .wheelsAndTires,
        difficulty: .moderate,
        timeEstimate: "45–60 min",
        systemImage: "arrow.triangle.2.circlepath",
        appliesTo: "Model Y, 2020–2026, all trims",
        tools: [
            "Floor jack (and jack stands if the car will stay up)",
            "Tesla jack pads / lift pucks",
            "Torque wrench",
            "21 mm socket"
        ],
        parts: [],
        steps: [
            MaintenanceGuideStep(
                id: "tire-rotation-1",
                number: 1,
                title: "Lift the car and pull all four wheels",
                detail: "Set jack pads at the factory lift points before raising anything — the battery enclosure sits close by and will not tolerate a misplaced jack. Raise the vehicle, support it safely, and remove all four wheels.",
                caution: "Never work under a car held up by a jack alone. Use stands."
            ),
            MaintenanceGuideStep(
                id: "tire-rotation-2",
                number: 2,
                title: "Identify your tire setup",
                detail: "The rotation pattern depends on what you're running, so confirm before anything goes back on:\n\n• Square, non-directional (typical RWD / Long Range) — each front wheel crosses to the opposite rear corner; each rear wheel moves straight forward.\n\n• Staggered, non-directional (typical Performance) — front and rear sizes differ, so you can only swap side-to-side on the same axle.\n\n• Directional — the tread has a required rotation direction. Swap front-to-back only and keep every tire on the side of the car it started on."
            ),
            MaintenanceGuideStep(
                id: "tire-rotation-3",
                number: 3,
                title: "Remount and torque",
                detail: "Hang each wheel, start every lug by hand to avoid cross-threading, then bring them down in a star pattern with a 21 mm socket. Final torque is 129 lb·ft (175 Nm). Do the final pass with the wheels back on the ground.",
                caution: "Torque wrench only. Guessing with an impact gun stretches studs."
            ),
            MaintenanceGuideStep(
                id: "tire-rotation-4",
                number: 4,
                title: "Reset the reminder on the touchscreen",
                detail: "On the car's display go to Controls → Service → Wheel & Tire → Tires, confirm the tire season selection, and tap Reset so the service mileage counter starts over."
            )
        ],
        specs: [
            MaintenanceSpec(id: "tire-rotation-spec-torque", label: "Lug nut torque", value: "129 lb·ft (175 Nm)"),
            MaintenanceSpec(id: "tire-rotation-spec-socket", label: "Socket size", value: "21 mm"),
            MaintenanceSpec(id: "tire-rotation-spec-pattern", label: "Tightening pattern", value: "Star / criss-cross")
        ],
        warnings: [
            "Jacking anywhere other than the designated lift points can damage the battery enclosure or rocker.",
            "Directional tires run backwards if you cross them side-to-side — check the sidewall arrow."
        ],
        tips: [
            "Mark each wheel with chalk or tape as it comes off so the pattern stays straight.",
            "Re-check torque after the first 50–100 miles.",
            "Rotation is a good moment to record tread depth and set pressures cold."
        ],
        resetNote: "Controls → Service → Wheel & Tire → Tires → Reset"
    )

    // MARK: 02 — Cabin Air Filter Swap

    private static let cabinAirFilter = MaintenanceGuide(
        id: "cabin-air-filter",
        number: 2,
        title: "Cabin Air Filter Swap",
        summary: "The behind-the-console pair, reached from the passenger footwell — trim clips, one Torx screw, two filters.",
        category: .filtersAndAir,
        difficulty: .moderate,
        timeEstimate: "20–30 min",
        systemImage: "wind",
        appliesTo: "Model Y — passenger footwell filter housing",
        tools: [
            "Plastic trim tool",
            "T20 Torx screwdriver (a 6 mm socket also fits)",
            "Small flathead screwdriver"
        ],
        parts: [
            "Cabin air filters — set of 2"
        ],
        steps: [
            MaintenanceGuideStep(
                id: "cabin-air-filter-1",
                number: 1,
                title: "Make room",
                detail: "Switch the HVAC system off from the center touchscreen. Slide the front passenger seat all the way back and pull the floor mat out so you have clear space to work in."
            ),
            MaintenanceGuideStep(
                id: "cabin-air-filter-2",
                number: 2,
                title: "Drop the footwell panel",
                detail: "Find the clips underneath the glovebox. Work a flathead under each one and ease it down until the clip body sits proud, then let the panel hang free."
            ),
            MaintenanceGuideStep(
                id: "cabin-air-filter-3",
                number: 3,
                title: "Unplug the harnesses",
                detail: "Disconnect the footwell light and the speaker. Grip the connector body itself, never the wires behind it.",
                caution: "Pulling on wiring instead of the connector is how you turn a filter swap into a wiring repair."
            ),
            MaintenanceGuideStep(
                id: "cabin-air-filter-4",
                number: 4,
                title: "Peel back the console side panel",
                detail: "Start at the top right corner with a trim tool and pop the carpeted panel along the right side of the center console, peeling it back as each clip releases."
            ),
            MaintenanceGuideStep(
                id: "cabin-air-filter-5",
                number: 5,
                title: "Open the filter cover",
                detail: "A single T20 screw holds the cover. Remove it and set it somewhere it cannot roll away, then release the cover tabs.",
                caution: "Orange high-voltage wiring is routed nearby. Do not stretch, pinch, or lever against it."
            ),
            MaintenanceGuideStep(
                id: "cabin-air-filter-6",
                number: 6,
                title: "Pull the old filters",
                detail: "The upper filter has a fabric tab — pull it outward and draw the filter toward the seat. Then lift the lower filter up into the empty top slot and remove it the same way."
            ),
            MaintenanceGuideStep(
                id: "cabin-air-filter-7",
                number: 7,
                title: "Fit the new pair",
                detail: "Check the airflow arrows on the filters you just removed: they point toward the rear of the car, away from the firewall and into the cabin. Match that direction on the new filters and leave the pull tabs facing out so the next swap is easy.",
                caution: "A filter installed backwards still fits. Confirm the arrow before the cover goes back on."
            ),
            MaintenanceGuideStep(
                id: "cabin-air-filter-8",
                number: 8,
                title: "Reassemble",
                detail: "Re-engage the cover tabs and run the Torx screw back in, reseat the console side panel, reconnect the light and speaker, and press the footwell panel clips home."
            ),
            MaintenanceGuideStep(
                id: "cabin-air-filter-9",
                number: 9,
                title: "Clear the reminder",
                detail: "Turn the HVAC back on and confirm normal airflow with no new alerts, then reset the cabin air filter interval from the Service menu on the touchscreen."
            )
        ],
        specs: [
            MaintenanceSpec(id: "cabin-air-filter-spec-count", label: "Filters", value: "2 (upper + lower)"),
            MaintenanceSpec(id: "cabin-air-filter-spec-driver", label: "Fastener", value: "1 × T20 Torx"),
            MaintenanceSpec(id: "cabin-air-filter-spec-flow", label: "Airflow direction", value: "Arrows point rearward, into the cabin")
        ],
        warnings: [
            "Orange cabling is high voltage. Keep tools clear of it and never use it as leverage.",
            "Cold trim clips break. If the car has been sitting outside in the cold, let the interior warm first."
        ],
        tips: [
            "Photograph the old filter's arrow before it leaves the housing.",
            "Keep a magnetic tray or cup for the screw — the housing below it is unforgiving.",
            "Log the swap so the next interval is easy to find."
        ],
        resetNote: "Touchscreen → Service → reset the cabin air filter interval"
    )

    // MARK: 03 — Service Mode

    private static let serviceMode = MaintenanceGuide(
        id: "service-mode",
        number: 3,
        title: "Service Mode",
        summary: "How to enter it, how to leave it, and what the diagnostic screens actually show you.",
        category: .diagnostics,
        difficulty: .easy,
        timeEstimate: "2 min",
        systemImage: "wrench.and.screwdriver",
        appliesTo: "Model Y, 2020–2026, all trims",
        tools: [],
        parts: [],
        steps: [
            MaintenanceGuideStep(
                id: "service-mode-1",
                number: 1,
                title: "Open Controls",
                detail: "Tap the car icon in the bottom-left corner of the touchscreen."
            ),
            MaintenanceGuideStep(
                id: "service-mode-2",
                number: 2,
                title: "Go to Software",
                detail: "From the Controls panel, select Software."
            ),
            MaintenanceGuideStep(
                id: "service-mode-3",
                number: 3,
                title: "Trigger the prompt",
                detail: "Press and hold your vehicle's model name for 3–5 seconds until it flashes, then type \"service\" into the prompt that appears."
            ),
            MaintenanceGuideStep(
                id: "service-mode-4",
                number: 4,
                title: "Enable",
                detail: "Tap Enable. A red border around the screen confirms Service Mode is active."
            ),
            MaintenanceGuideStep(
                id: "service-mode-5",
                number: 5,
                title: "Exit when you're done",
                detail: "Open the Service Mode menu, then press and hold the Exit Service Mode control (the red door/wrench icon) until the red frame disappears. Don't leave the car in Service Mode for normal driving.",
                caution: "Service Mode changes how some systems behave. Exit before you drive."
            )
        ],
        specs: [
            MaintenanceSpec(id: "service-mode-spec-lv", label: "Low-voltage battery", value: "Voltage, status, system draw"),
            MaintenanceSpec(id: "service-mode-spec-hv", label: "High-voltage battery", value: "Thermal and cell status, energy retention"),
            MaintenanceSpec(id: "service-mode-spec-hvac", label: "Thermal / HVAC", value: "Heat pump, valves, coolant flow, temp sensors"),
            MaintenanceSpec(id: "service-mode-spec-tires", label: "Tires & brakes", value: "TPMS sensor values, brake service functions"),
            MaintenanceSpec(id: "service-mode-spec-alerts", label: "Alerts & maintenance", value: "Active and historical alerts, notification flags")
        ],
        warnings: [
            "Service Mode exposes actuation functions, not just readouts. Some controls physically move components or change system settings.",
            "Stick to reading status unless you know exactly what a control does. Anything beyond that belongs with a qualified technician."
        ],
        tips: [
            "It's the fastest way to read raw TPMS pressures when you suspect a slow leak.",
            "The alert history is useful context before booking service — note the codes.",
            "Check the 12 V / low-voltage battery here if the car has been throwing odd electrical behavior."
        ],
        resetNote: nil
    )

    // MARK: 04 — Wheel Torque Reference

    private static let wheelTorque = MaintenanceGuide(
        id: "wheel-torque",
        number: 4,
        title: "Wheel Torque Reference",
        summary: "Factory lug torque by wheel size and trim — plus the pattern and the re-check interval.",
        category: .wheelsAndTires,
        difficulty: .easy,
        timeEstimate: "Reference",
        systemImage: "gauge.with.dots.needle.67percent",
        appliesTo: "Model Y, 2020–2026 including Juniper",
        tools: [
            "Calibrated torque wrench",
            "21 mm socket"
        ],
        parts: [],
        steps: [
            MaintenanceGuideStep(
                id: "wheel-torque-1",
                number: 1,
                title: "Start every lug by hand",
                detail: "Thread each lug nut in by hand until it seats. This is the single best defense against cross-threading a hub."
            ),
            MaintenanceGuideStep(
                id: "wheel-torque-2",
                number: 2,
                title: "Tighten in a star pattern",
                detail: "Work across the wheel rather than around it, snugging in stages so the wheel pulls down evenly against the hub face."
            ),
            MaintenanceGuideStep(
                id: "wheel-torque-3",
                number: 3,
                title: "Final torque at 129 lb·ft",
                detail: "Bring every lug to 129 lb·ft (175 Nm) with a calibrated torque wrench, with the wheels on the ground. This figure is the same across every Model Y wheel size and trim listed below."
            ),
            MaintenanceGuideStep(
                id: "wheel-torque-4",
                number: 4,
                title: "Re-check after 50–100 miles",
                detail: "Any time a wheel has been off — or on new wheels — re-check torque after the first 50–100 miles of driving."
            )
        ],
        specs: [
            MaintenanceSpec(id: "wheel-torque-spec-1", label: "2020–2024 Long Range AWD — 19\" / 20\"", value: "129 lb·ft (175 Nm)"),
            MaintenanceSpec(id: "wheel-torque-spec-2", label: "2020–2024 Performance AWD — 21\"", value: "129 lb·ft (175 Nm)"),
            MaintenanceSpec(id: "wheel-torque-spec-3", label: "2024+ RWD — 19\"", value: "129 lb·ft (175 Nm)"),
            MaintenanceSpec(id: "wheel-torque-spec-4", label: "2025+ Juniper RWD — 18\"", value: "129 lb·ft (175 Nm)"),
            MaintenanceSpec(id: "wheel-torque-spec-5", label: "2025+ Juniper AWD — 19\" / 20\"", value: "129 lb·ft (175 Nm)"),
            MaintenanceSpec(id: "wheel-torque-spec-6", label: "2025+ Juniper Performance AWD — 21\"", value: "129 lb·ft (175 Nm)"),
            MaintenanceSpec(id: "wheel-torque-spec-7", label: "Socket size", value: "21 mm")
        ],
        warnings: [
            "Under-torqued wheels work loose over time.",
            "Over-torquing stretches studs and can snap them — often later, under load, rather than in the driveway.",
            "Verify against the current Owner's Manual and Service Manual for your exact vehicle before you rely on any published figure."
        ],
        tips: [
            "Get the wrench calibrated if it has been dropped or stored under load.",
            "Wind a click-type wrench back to its lowest setting for storage.",
            "Torque sticks on an impact gun are a rough approximation — finish by hand."
        ],
        resetNote: nil
    )

    // MARK: 05 — Frunk Filter Swap

    private static let frunkFilter = MaintenanceGuide(
        id: "frunk-filter",
        number: 5,
        title: "Frunk Filter Swap",
        summary: "The up-front filter housing: one panel, ten screws, four filter pieces.",
        category: .filtersAndAir,
        difficulty: .easy,
        timeEstimate: "5–10 min",
        systemImage: "air.purifier",
        appliesTo: "Model Y — frunk filter housing",
        tools: [
            "T20 Torx screwdriver, or a power driver with a T20 bit"
        ],
        parts: [
            "Replacement frunk filters — set of 4 pieces"
        ],
        steps: [
            MaintenanceGuideStep(
                id: "frunk-filter-1",
                number: 1,
                title: "Lift off the top panel",
                detail: "The cover is held by plastic clips that stay attached to the panel rather than the car. Start at one side, lift gradually until the clips let go, then work across. Set it somewhere it won't get stepped on."
            ),
            MaintenanceGuideStep(
                id: "frunk-filter-2",
                number: 2,
                title: "Remove ten T20 screws",
                detail: "There are 10 Torx 20 screws — one on the passenger side, and the rest split above and below the rubber seal. Take them out slowly and keep them together.",
                caution: "Drop a screw down into the housing and retrieving it becomes the longest part of the job."
            ),
            MaintenanceGuideStep(
                id: "frunk-filter-3",
                number: 3,
                title: "Swap the four filter pieces",
                detail: "Lift the cover away and pull the four existing pieces. They aren't side-specific, so orientation left-to-right doesn't matter — but the filter element must sit on top of its backing piece, not underneath it.",
                caution: "Element under the backing piece is the classic mistake here."
            ),
            MaintenanceGuideStep(
                id: "frunk-filter-4",
                number: 4,
                title: "Close it back up",
                detail: "Refit the filter cover, run all 10 screws back in, then press the top panel down along both sides until every clip seats firmly."
            )
        ],
        specs: [
            MaintenanceSpec(id: "frunk-filter-spec-screws", label: "Screws", value: "10 × T20 Torx"),
            MaintenanceSpec(id: "frunk-filter-spec-pieces", label: "Filter pieces", value: "4"),
            MaintenanceSpec(id: "frunk-filter-spec-orientation", label: "Orientation", value: "Not side-specific; element on top of backing")
        ],
        warnings: [
            "Don't force the top panel — the clips are part of the panel and will snap before the panel gives."
        ],
        tips: [
            "A magnetic tray keeps all ten screws in one place.",
            "Good moment to look at how much debris made it past the filter — that's your cue for the radiator guide.",
            "A power driver on low torque makes this a genuinely quick job."
        ],
        resetNote: nil
    )

    // MARK: 06 — Radiator Cleaning

    private static let radiatorCleaning = MaintenanceGuide(
        id: "radiator-cleaning",
        number: 6,
        title: "Radiator Cleaning",
        summary: "Clearing leaves and road debris off the front radiator so the cooling system stops working overtime.",
        category: .cooling,
        difficulty: .moderate,
        timeEstimate: "30–45 min",
        systemImage: "leaf",
        appliesTo: "Model Y — front radiator behind the frunk tub",
        tools: [
            "10 mm socket",
            "Plastic trim tool",
            "Needle-nose pliers",
            "Shop vac with a hose extension"
        ],
        parts: [],
        steps: [
            MaintenanceGuideStep(
                id: "radiator-cleaning-1",
                number: 1,
                title: "Turn the AC off",
                detail: "Disable air conditioning from the touchscreen before you start pulling things apart."
            ),
            MaintenanceGuideStep(
                id: "radiator-cleaning-2",
                number: 2,
                title: "Remove the top panel",
                detail: "Take off the panel covering the frunk filter housing. Its plastic clips stay attached to the cover rather than the car — work gradually from one side across until it separates."
            ),
            MaintenanceGuideStep(
                id: "radiator-cleaning-3",
                number: 3,
                title: "Free the frunk tub",
                detail: "Remove the four 10 mm fasteners holding the frunk, then release the driver-side clip with a trim tool or flathead."
            ),
            MaintenanceGuideStep(
                id: "radiator-cleaning-4",
                number: 4,
                title: "Disconnect the frunk light",
                detail: "Wedge a trim tool near the top of the light housing to release it, then use needle-nose pliers to press the tab and separate the plug.",
                caution: "Work the connector, not the wires."
            ),
            MaintenanceGuideStep(
                id: "radiator-cleaning-5",
                number: 5,
                title: "Lift the frunk out",
                detail: "Raise the tub away, watching that the light wiring doesn't snag on the way past."
            ),
            MaintenanceGuideStep(
                id: "radiator-cleaning-6",
                number: 6,
                title: "Open up the radiator cover",
                detail: "There are six clips. Release three on one side and leave the trim tool wedged in place so they can't re-seat, then move to the remaining three. Pinch the side clips inward with pliers until they release, then ease the cover open."
            ),
            MaintenanceGuideStep(
                id: "radiator-cleaning-7",
                number: 7,
                title: "Vacuum it out",
                detail: "Work the shop vac systematically across and downward to lift out leaves, seed pods, and grit. Radiator fins are extremely fragile — light contact only, no scraping or prying.",
                caution: "Bent fins block airflow permanently. Gentle wins here."
            ),
            MaintenanceGuideStep(
                id: "radiator-cleaning-8",
                number: 8,
                title: "Reassemble in reverse",
                detail: "Radiator cover clips, frunk tub, light connector, 10 mm fasteners, then the top panel. Take the same care on the way back in."
            ),
            MaintenanceGuideStep(
                id: "radiator-cleaning-9",
                number: 9,
                title: "Verify and reset",
                detail: "Turn the AC back on and confirm it cools normally with no new alerts on the screen, then reset the maintenance reminder from the Service settings."
            )
        ],
        specs: [
            MaintenanceSpec(id: "radiator-cleaning-spec-bolts", label: "Frunk fasteners", value: "4 × 10 mm"),
            MaintenanceSpec(id: "radiator-cleaning-spec-clips", label: "Radiator cover clips", value: "6 (3 per side)"),
            MaintenanceSpec(id: "radiator-cleaning-spec-tool", label: "Cleaning method", value: "Shop vac only — no pressure washer")
        ],
        warnings: [
            "Radiator fins bend under almost no force. Never poke, scrape, or pressure-wash them.",
            "Release electrical connectors by their tab. Pulling wires damages the harness.",
            "A restricted radiator makes the cooling system work harder — worth checking seasonally if you park under trees."
        ],
        tips: [
            "Pair this with the frunk filter swap — you're already most of the way in.",
            "Autumn and after long highway trips are when the debris builds up.",
            "Photograph clip positions before releasing them if this is your first time in there."
        ],
        resetNote: "Touchscreen → Service → reset the maintenance reminder"
    )

    // MARK: 07 — At-Home Charging Setup

    private static let homeCharging = MaintenanceGuide(
        id: "home-charging-setup",
        number: 7,
        title: "At-Home Charging Setup",
        summary: "Weekday and weekend charge schedules, plus getting your real electricity rate into the picture.",
        category: .charging,
        difficulty: .easy,
        timeEstimate: "15 min",
        systemImage: "house.and.flag",
        appliesTo: "Tesla app + vehicle touchscreen",
        tools: [
            "Tesla app, signed in",
            "Home location set on the vehicle",
            "Your utility's residential rate plan"
        ],
        parts: [],
        steps: [
            MaintenanceGuideStep(
                id: "home-charging-setup-1",
                number: 1,
                title: "Set Home on the car",
                detail: "On the touchscreen, go to Navigation → Set Home. Scheduling is tied to this location, so the app needs it before the rest works."
            ),
            MaintenanceGuideStep(
                id: "home-charging-setup-2",
                number: 2,
                title: "Open the schedule screen",
                detail: "In the Tesla app choose Set Schedules, go to Charging, and tap +."
            ),
            MaintenanceGuideStep(
                id: "home-charging-setup-3",
                number: 3,
                title: "Add a weekday schedule",
                detail: "Create a Monday–Friday window that sits inside your off-peak hours — for example 10:15 PM to 6:00 AM. Starting a few minutes after the hour keeps you clear of the moment every other EV on your street plugs in."
            ),
            MaintenanceGuideStep(
                id: "home-charging-setup-4",
                number: 4,
                title: "Add a separate weekend schedule",
                detail: "Weekend rates are often flat or off-peak all day. A second Saturday–Sunday schedule can run far wider — 12:00 AM to 11:45 PM, for instance — so the car takes whatever it needs."
            ),
            MaintenanceGuideStep(
                id: "home-charging-setup-5",
                number: 5,
                title: "Look up your actual rates",
                detail: "Pull your utility's time-of-use rates — off-peak, mid-peak, and on-peak. If they change seasonally and the windows overlap, an average is close enough for tracking."
            ),
            MaintenanceGuideStep(
                id: "home-charging-setup-6",
                number: 6,
                title: "Enter the rates and check Charge Stats",
                detail: "Put those rates into Charging Settings in the app, then open Charging → Charge Stats to see home versus elsewhere as a share of your charging and your spend over the past month."
            ),
            MaintenanceGuideStep(
                id: "home-charging-setup-7",
                number: 7,
                title: "Mirror the rate in this app",
                detail: "Enter the same rate in Energy Rates here so your logged sessions, cost-per-mile, and gas comparisons are all built on the number you actually pay rather than a default estimate."
            )
        ],
        specs: [
            MaintenanceSpec(id: "home-charging-setup-spec-weekday", label: "Weekday example", value: "Mon–Fri, 10:15 PM – 6:00 AM"),
            MaintenanceSpec(id: "home-charging-setup-spec-weekend", label: "Weekend example", value: "Sat–Sun, 12:00 AM – 11:45 PM"),
            MaintenanceSpec(id: "home-charging-setup-spec-override", label: "Override", value: "Start Charging button charges now, any time")
        ],
        warnings: [
            "App layouts move between software releases — menu names may not match exactly.",
            "Rates you enter produce estimates for tracking, not a bill. Your utility's statement is the authority."
        ],
        tips: [
            "A schedule doesn't lock you in — Start Charging overrides it when you need range now.",
            "Re-check your rate plan once a year; utilities shift time-of-use windows more often than people expect.",
            "If you have solar or a battery, aim the weekend window at your export surplus instead of the off-peak clock."
        ],
        resetNote: nil
    )
}
