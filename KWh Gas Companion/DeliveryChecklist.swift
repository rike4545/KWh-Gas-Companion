//
//  DeliveryChecklist.swift
//  KWh Gas Companion
//
//  The delivery-day inspection template — eight sections, each item written as
//  something you can actually stand next to the car and check.
//
//  Swift 6 • iOS 17+
//

import Foundation

// MARK: - Categories

public enum DeliveryChecklistCategory: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case exterior      = "Exterior"
    case interior      = "Interior"
    case functionality = "Functionality"
    case software      = "Software"
    case charging      = "Charging"
    case documentation = "Documentation"
    case testDrive     = "Test Drive"
    case extras        = "Extras"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .exterior:      return "car.side"
        case .interior:      return "carseat.left.fill"
        case .functionality: return "switch.2"
        case .software:      return "cpu"
        case .charging:      return "bolt.fill"
        case .documentation: return "doc.text.fill"
        case .testDrive:     return "road.lanes"
        case .extras:        return "shippingbox"
        }
    }

    public var blurb: String {
        switch self {
        case .exterior:      return "Paint, panel alignment, gaps, glass, lights, trim, wheels and tires"
        case .interior:      return "Seats, belts, trim, screens, vents, controls, carpets, trunk and frunk"
        case .functionality: return "Doors, windows, locks, mirrors, wipers, HVAC, cameras, sensors"
        case .software:      return "Version, connectivity, app pairing, driver profiles, key cards"
        case .charging:      return "Cables, adapters, port door, a real charging test"
        case .documentation: return "VIN match, agreement, plates, warranty, due bills"
        case .testDrive:     return "Noises, steering, brakes, regen, Autopilot basics"
        case .extras:        return "Mats, mud flaps, aero caps, accessories you paid for"
        }
    }

    /// Sections best done before signing anything.
    public var isPreSignature: Bool {
        switch self {
        case .exterior, .interior, .functionality, .documentation: return true
        default: return false
        }
    }
}

// MARK: - Item status

public enum DeliveryItemStatus: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case unchecked
    case pass
    case attention
    case recheck

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .unchecked: return "Not checked"
        case .pass:      return "Good"
        case .attention: return "Needs attention"
        case .recheck:   return "Recheck"
        }
    }

    public var systemImage: String {
        switch self {
        case .unchecked: return "circle"
        case .pass:      return "checkmark.circle.fill"
        case .attention: return "exclamationmark.triangle.fill"
        case .recheck:   return "arrow.clockwise.circle.fill"
        }
    }

    public var isResolved: Bool { self == .pass }
    public var isFlagged: Bool { self == .attention || self == .recheck }
}

// MARK: - Template

public struct DeliveryChecklistItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let category: DeliveryChecklistCategory
    public let title: String
    /// What to actually look for. Half the value of the list is in this line.
    public let detail: String

    public init(id: String, category: DeliveryChecklistCategory, title: String, detail: String) {
        self.id = id
        self.category = category
        self.title = title
        self.detail = detail
    }
}

public enum DeliveryChecklistTemplate {

    public static func items(in category: DeliveryChecklistCategory) -> [DeliveryChecklistItem] {
        all.filter { $0.category == category }
    }

    public static func item(id: String) -> DeliveryChecklistItem? {
        all.first { $0.id == id }
    }

    public static var count: Int { all.count }

    /// The whole list, in walk-around order.
    public static let all: [DeliveryChecklistItem] = {
        var items: [DeliveryChecklistItem] = []
        var counters: [DeliveryChecklistCategory: Int] = [:]

        func add(_ category: DeliveryChecklistCategory, _ title: String, _ detail: String) {
            let next = (counters[category] ?? 0) + 1
            counters[category] = next
            let slug = category.rawValue.lowercased().replacingOccurrences(of: " ", with: "")
            items.append(
                DeliveryChecklistItem(
                    id: "\(slug).\(next)",
                    category: category,
                    title: title,
                    detail: detail
                )
            )
        }

        // ── Exterior ─────────────────────────────────────────────────
        add(.exterior, "Panel gaps — front", "Hood/frunk to fenders, both sides. Gaps should be even top to bottom and match left to right.")
        add(.exterior, "Panel gaps — doors", "Open and close each door. Look down the body line for a step, and check the gap is parallel front to back.")
        add(.exterior, "Panel gaps — rear", "Trunk or liftgate to quarter panels, and the bumper-to-body seam on both sides.")
        add(.exterior, "Charge port door", "Sits flush, closes without a proud edge, and doesn't catch on the quarter panel.")
        add(.exterior, "Paint defects", "Walk it in direct light. Look for orange peel, runs, sanding marks, dry spray, and dust nibs.")
        add(.exterior, "Chips and scratches", "Especially leading edges — hood, mirror caps, front bumper. Transport damage is common and is on Tesla to fix.")
        add(.exterior, "Rail dust and fallout", "Feel the horizontal surfaces. Gritty paint means rail dust that needs decontaminating, not buffing.")
        add(.exterior, "Glass — windshield", "Chips, cracks, delamination at the edges, and distortion when you sight along it.")
        add(.exterior, "Glass — side and rear", "Scratches, chips, and that every window sits flush in its seal when closed.")
        add(.exterior, "Roof glass", "Alignment to the body, no chips at the corners, and clean seals with no adhesive squeeze-out.")
        add(.exterior, "Headlights and taillights", "All functions on. Check for moisture inside the housing and matched alignment side to side.")
        add(.exterior, "Trim and badges", "Straight, level, and fully seated. Confirm chrome-delete or badge choices match what you ordered.")
        add(.exterior, "Weatherstripping", "Fully seated all the way around every opening, with no lifted or twisted sections.")
        add(.exterior, "Wheels", "Curb rash, casting flaws, and finish defects on all four. Check center caps and aero covers are present.")
        add(.exterior, "Tires", "Same brand and model on all four, DOT date codes within a reasonable spread, no sidewall damage.")
        add(.exterior, "Tire pressures", "Compare the screen readout to the door-jamb placard. Delivery pressures are often high from transport.")
        add(.exterior, "Underbody shields", "Look underneath front and rear for hanging aero panels or missing fasteners.")
        add(.exterior, "Mirrors and handles", "No scuffs, both mirror caps seated, and door handles that sit flush and present properly.")

        // ── Interior ─────────────────────────────────────────────────
        add(.interior, "Seats — surfaces", "Every seat: stains, scuffs, loose or skipped stitching, and creases that shouldn't be there yet.")
        add(.interior, "Seats — adjustment", "Run every powered axis to both stops, front seats and any powered rears.")
        add(.interior, "Seat heaters", "Turn each on and confirm it actually warms — including rear seats if equipped.")
        add(.interior, "Seat belts", "Pull each fully out, let it retract, and latch it. Every position, including the middle and third row.")
        add(.interior, "Headliner", "Clean, no sag, no dirty handprints, and seams tight at the pillars.")
        add(.interior, "Door cards and trim", "Panel alignment, clip engagement, and no scratches on the sills from transport.")
        add(.interior, "Dash and console", "Alignment along the dash seam, console lid latch, and cubby doors that close cleanly.")
        add(.interior, "Center screen", "Dead pixels, uniform brightness, no lifted corners, and touch response across the whole surface.")
        add(.interior, "Instrument display", "If equipped, check for dead pixels and correct wake behavior.")
        add(.interior, "Air vents", "Every vent moves through its full range and actually blows air.")
        add(.interior, "Steering wheel", "Buttons and scroll wheels all respond, heat works, and tilt/telescope moves to both limits.")
        add(.interior, "Speakers", "Balance and fade to each corner in turn — that's the fastest way to catch a dead speaker.")
        add(.interior, "USB and 12 V", "Every port powers a device, including the glovebox port used for dashcam storage.")
        add(.interior, "Wireless chargers", "Both pads charge a phone, and the surface is unscratched.")
        add(.interior, "Sun visors", "Both fold down, swing to the side, and the vanity mirrors and lights work.")
        add(.interior, "Glovebox", "Opens from the screen, closes and latches, and isn't rubbing the dash.")
        add(.interior, "Carpets and mats", "Fitted, unstained, and the ones you paid for are in the car.")
        add(.interior, "Trunk area", "Liner fitted, no water intrusion, subfloor and tool kit present, and the load-floor latch works.")
        add(.interior, "Frunk", "Liner fitted and no damage to the seal or the latch mechanism.")
        add(.interior, "Third row", "If equipped: folds and unfolds, latches, and the seat belts reach.")
        add(.interior, "Rattles", "Push on the dash, doors, and console. Anything that creaks now will be worse in six months.")

        // ── Functionality ────────────────────────────────────────────
        add(.functionality, "Doors — outside", "Open and close every door from the outside handle, including the rears.")
        add(.functionality, "Doors — inside", "Both the powered release and the manual emergency release on every door that has one.")
        add(.functionality, "Windows", "All the way down and back up on every window, plus one-touch auto and the pinch sensor.")
        add(.functionality, "Powered trunk", "Open and close from the screen, the app, and the button. Set the height stop while you're there.")
        add(.functionality, "Powered frunk", "If equipped, cycle it fully and check for even closing.")
        add(.functionality, "Locks — key card", "Lock and unlock with each key card at the B-pillar, and start a drive with one.")
        add(.functionality, "Locks — phone key", "Pair your phone, then walk away and back to confirm walk-away lock and approach unlock.")
        add(.functionality, "Mirrors", "Adjust both, fold and unfold, and confirm heat and reverse auto-tilt.")
        add(.functionality, "Wipers", "Every speed, the auto mode, and the washers spraying from both nozzles.")
        add(.functionality, "Defrosters", "Front and rear, plus the mirror heaters on a cold enough day.")
        add(.functionality, "HVAC", "Full cold and full hot on both sides, fan through its range, and the recirculation flap.")
        add(.functionality, "Cameras", "Cycle every camera view on the screen. Look for haze, misalignment, and dead feeds.")
        add(.functionality, "Parking sensors", "Roll slowly toward a wall and confirm the visualization and chimes respond.")
        add(.functionality, "Horn", "One press. It's the item people most often forget.")
        add(.functionality, "Exterior lights", "Turn signals, hazards, brake lights, reverse lights, high beams — have someone walk around.")
        add(.functionality, "HomeLink", "If equipped and you have a door to test with, confirm it programs.")
        add(.functionality, "Tow hitch", "If equipped: the receiver is present, the cover fits, and the wiring is there.")

        // ── Software ─────────────────────────────────────────────────
        add(.software, "Software version", "Note the version on the screen. Write it down — it matters if a feature is missing.")
        add(.software, "Open alerts", "The screen should be clean. Any alert at handover is Tesla's to resolve before you sign.")
        add(.software, "Connectivity", "LTE bars and a Wi-Fi connection at the center. Confirm Premium Connectivity if you're entitled to it.")
        add(.software, "Account and VIN", "The car appears in your Tesla account under the correct VIN.")
        add(.software, "App pairing", "The mobile app controls the car — lock, climate, and honk all respond.")
        add(.software, "Phone key setup", "Set up each driver's phone key before leaving, while someone is there to help.")
        add(.software, "Driver profiles", "Create your profile and confirm it saves seat, mirror, and steering position.")
        add(.software, "Key cards and fob", "Two key cards is standard. Confirm any fob you ordered is in the car and paired.")
        add(.software, "Autopilot features", "The features you paid for are actually on the car — check Autopilot settings and the upgrades page.")
        add(.software, "Navigation", "Maps load, a route calculates, and Supercharger data appears along it.")
        add(.software, "Voice commands", "Press the right scroll wheel and give it a command.")
        add(.software, "Dashcam and Sentry", "Format a USB drive in the car and confirm dashcam recording starts.")
        add(.software, "Odometer", "Record the delivery mileage. Anything unusually high is worth asking about in writing.")
        add(.software, "Service mode", "The screen shouldn't be in service mode or showing a red diagnostic border.")
        add(.software, "Build match", "Compare the on-screen vehicle details against your order page, line by line.")

        // ── Charging ─────────────────────────────────────────────────
        add(.charging, "Mobile connector", "Present, in its bag, with the adapters that come with it.")
        add(.charging, "Adapters", "Every adapter you ordered or expect — J1772, NACS, CHAdeMO — is physically in the car.")
        add(.charging, "Charge port door", "Opens from the button, the screen, and the app. Closes flush.")
        add(.charging, "Port latch and light", "The latch engages and releases, and the port ring lights through its color sequence.")
        add(.charging, "AC charging test", "Plug in on site and confirm a real charge session starts and reports sane amperage.")
        add(.charging, "DC charging test", "If there's a Supercharger nearby, take a short session before you're relying on it.")
        add(.charging, "Cable release", "The cable unlocks from the screen, the app, and the button on the handle.")
        add(.charging, "Delivery state of charge", "Note it. Very low or very high is worth a question about how the car was stored.")
        add(.charging, "Charge limit and schedule", "Set your daily limit and, if you have off-peak rates, a scheduled start.")
        add(.charging, "Supercharging on account", "Confirm billing is attached and any included credits show up.")
        add(.charging, "Home charging plan", "Know what you're plugging into tonight. A dead 120 V outlet is a bad first evening.")
        add(.charging, "No charging faults", "No error on the screen or the app during or after the test session.")

        // ── Documentation ────────────────────────────────────────────
        add(.documentation, "VIN — dash", "Read the VIN through the windshield and compare it, character by character, to your paperwork.")
        add(.documentation, "VIN — door jamb", "The jamb sticker VIN matches the dash and the agreement. All three, not two of three.")
        add(.documentation, "Purchase agreement", "Model, trim, options, and color match what you configured and what's in front of you.")
        add(.documentation, "Price and fees", "Line by line against your order. Question anything that appeared since you configured.")
        add(.documentation, "Odometer disclosure", "The mileage on the form matches the mileage on the screen.")
        add(.documentation, "Registration and plates", "Plates or a temporary tag are in hand, with the paperwork to go with them.")
        add(.documentation, "Insurance active", "Confirm coverage is in force on this VIN before you drive off the lot.")
        add(.documentation, "Warranty terms", "Basic and battery/drive-unit coverage, with start date and mileage recorded.")
        add(.documentation, "Window sticker", "Keep it. It's the authoritative record of how the car was built.")
        add(.documentation, "Due bill in writing", "Anything they promise to fix goes on paper, with the VIN on it, before you sign.")
        add(.documentation, "Financing or lease docs", "Rate, term, and payment match what you were quoted.")
        add(.documentation, "Trade-in settled", "Payoff confirmed and the title handling for your old car is documented.")
        add(.documentation, "Service contact", "Know which service center owns this car and how to open a ticket in the app.")

        // ── Test Drive ───────────────────────────────────────────────
        add(.testDrive, "Quiet start", "No clunks from the suspension or drivetrain pulling out of the space.")
        add(.testDrive, "Steering centered", "On a straight, flat road the wheel sits level and the car tracks without pull.")
        add(.testDrive, "Vibration at speed", "Take it to highway speed. Wheel shimmy or seat buzz means balance or a bent wheel.")
        add(.testDrive, "Braking", "A firm stop from speed, somewhere safe. No pulsing, grinding, or pulling to one side.")
        add(.testDrive, "Regenerative braking", "Behaves as set, and one-pedal driving brings you smoothly to a stop.")
        add(.testDrive, "Suspension noise", "Over a rough patch and a speed bump. Listen for clunks, knocks, and rattles.")
        add(.testDrive, "Wind noise", "At highway speed, compare left and right. A whistle usually means a seal or a mirror.")
        add(.testDrive, "Tire and road noise", "Louder than expected on smooth pavement can point to a bad tire.")
        add(.testDrive, "HVAC under load", "Air stays cold or hot at speed, and the fan doesn't develop a whine.")
        add(.testDrive, "Autopilot engagement", "Engages on a marked road, centers in the lane, and disengages cleanly.")
        add(.testDrive, "Traffic-aware cruise", "Follows and slows for the car ahead without lurching.")
        add(.testDrive, "Steering wheel nag", "Confirm the torque detection responds to normal light pressure.")
        add(.testDrive, "Warning lights", "Nothing new appears on the screen during or after the drive.")
        add(.testDrive, "Hill hold", "On an incline, the car holds without rolling back.")

        // ── Extras ───────────────────────────────────────────────────
        add(.extras, "Floor mats", "The set you ordered — all-weather or carpet — is in the car, not on a shelf.")
        add(.extras, "Mud flaps", "Present and, if fitted, actually installed rather than boxed.")
        add(.extras, "Aero covers", "If your wheels came with them, all four are accounted for.")
        add(.extras, "Tire repair kit", "Present, sealed, and the compressor is in the trunk where you'd look for it.")
        add(.extras, "Jack pads", "If you ordered lift pucks, they're in the car.")
        add(.extras, "First aid kit", "Where local rules require one, or if you ordered it.")
        add(.extras, "Warning triangle", "Required in some regions. Check before you find out on the roadside.")
        add(.extras, "Extra key cards", "Count them. Two is standard; a third is easy to forget to hand over.")
        add(.extras, "Plate mount", "Front plate bracket and hardware, if your state requires a front plate.")
        add(.extras, "Accessory orders", "Anything shipped to the delivery center — roof rack, hitch cover, cables — is with the car.")
        add(.extras, "Referral credits", "Confirm a referral code was applied, before delivery closes it out.")
        add(.extras, "Charging adapters ordered", "Separate from the standard kit — check the box list against what's in your hands.")

        return items
    }()

    /// Shown once at the top of a run.
    public static let disclaimer = """
    Work through the pre-signature sections before you sign anything. Once the \
    paperwork is done, an unrecorded defect becomes a service appointment rather \
    than a delivery issue. Anything Tesla agrees to fix should be written on a \
    due bill with the VIN on it before you leave.
    """
}
