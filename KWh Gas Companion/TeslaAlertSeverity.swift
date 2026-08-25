//
//  TeslaAlertSeverity.swift
//  My EV Companion (or KWh Gas Companion)
//
//  Swift 6 • iOS 17+
//
//  IMPORTANT:
//  - This file MUST exist only once in your target.
//  - Ensure there are NO other files in the build target defining:
//      TeslaAlertSeverity, TeslaServiceAlert, TeslaServiceAlertAnalyzer,
//      VisionOCR, TeslaServiceAlertScannerView, etc.
//
//  This revision (per your request):
//  ✅ NO live camera scanning
//  ✅ Photo-only workflow (PhotosPicker + Vision OCR)
//  ✅ Better code extraction for BOTH:
//        - "GTW_w027_epbMia" (3-part codes)
//        - "VCFRONT_a180"   (2-part codes)
//  ✅ Better decoding when the code has no token by using the source line text.
//
//  Styling:
//  - Uses AppThemeSpec via Environment (AppThemeBox).
//

import SwiftUI
@preconcurrency import Vision
import PhotosUI
import UIKit

// MARK: - Severity

public enum TeslaAlertSeverity: String, CaseIterable, Codable, Hashable {
    case critical
    case high
    case medium
    case low
    case info
    case unknown

    public var label: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .info: return "Info"
        case .unknown: return "Unknown"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .critical: return "exclamationmark.octagon.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "info.circle.fill"
        case .info: return "info.circle"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Alert Model

public struct TeslaServiceAlert: Identifiable, Hashable {
    public let id: UUID
    public let code: String
    public let sourceLine: String?
    public let subsystem: String?
    public let title: String
    public let summary: String
    public let details: String
    public let severity: TeslaAlertSeverity
    public let confidence: String
    public let suggestedAction: String

    public init(
        id: UUID = UUID(),
        code: String,
        sourceLine: String?,
        subsystem: String?,
        title: String,
        summary: String,
        details: String,
        severity: TeslaAlertSeverity,
        confidence: String,
        suggestedAction: String
    ) {
        self.id = id
        self.code = code
        self.sourceLine = sourceLine
        self.subsystem = subsystem
        self.title = title
        self.summary = summary
        self.details = details
        self.severity = severity
        self.confidence = confidence
        self.suggestedAction = suggestedAction
    }
}

// MARK: - Analyzer / Decoder

@MainActor
public final class TeslaServiceAlertAnalyzer: ObservableObject {
    @Published public private(set) var alerts: [TeslaServiceAlert] = []
    @Published public private(set) var recognizedText: String = ""
    @Published public var isWorking: Bool = false
    @Published public var lastError: String? = nil

    public init() {}

    public func clear() {
        alerts = []
        recognizedText = ""
        lastError = nil
        isWorking = false
    }

    public func ingestRecognizedText(_ text: String) {
        recognizedText = text

        let normalized = Self.normalize(text)
        let lines: [String] = normalized
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let codes = Self.extractAlertCodes(from: normalized)

        func looseKey(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }
        let lineKeys = lines.map { (line: $0, key: looseKey($0)) }

        var built: [TeslaServiceAlert] = []
        built.reserveCapacity(codes.count)

        for code in codes {
            let canonical = TeslaAlertInference.canonicalizeCode(code)
            let codeKey = looseKey(canonical)
            let src = lineKeys.first(where: { $0.key.contains(codeKey) })?.line
            built.append(Self.decode(code: canonical, sourceLine: src))
        }

        // de-dup by code, keep order
        var seen = Set<String>()
        alerts = built.filter { seen.insert($0.code).inserted }
    }

    public func ingestImage(_ image: UIImage) async {
        isWorking = true
        lastError = nil
        defer { isWorking = false }

        do {
            let text = try await VisionOCR.recognizeText(in: image)
            ingestRecognizedText(text)
        } catch {
            lastError = "OCR failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Parsing

    public static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
    }

    /// Extracts alert codes from raw text (OCR).
    /// Supports:
    /// - 3-part codes: "GTW_w027_epbMia"
    /// - 2-part codes: "VCFRONT_a180"
    public static func extractAlertCodes(from text: String) -> [String] {
        let normalized = normalize(text)

        // 3-part: PREFIX_a123_token
        let pattern3 = #"\b[A-Za-z0-9]{2,12}_[A-Za-z]\d{2,4}_[A-Za-z0-9_]+\b"#
        // 2-part: PREFIX_a123
        let pattern2 = #"\b[A-Za-z0-9]{2,12}_[A-Za-z]\d{2,4}\b"#

        let regex3 = try? NSRegularExpression(pattern: pattern3)
        let regex2 = try? NSRegularExpression(pattern: pattern2)

        let ns = normalized as NSString
        var out: [String] = []

        if let r3 = regex3 {
            let matches = r3.matches(in: normalized, range: NSRange(location: 0, length: ns.length))
            out.append(contentsOf: matches.map { ns.substring(with: $0.range) })
        }
        if let r2 = regex2 {
            let matches = r2.matches(in: normalized, range: NSRange(location: 0, length: ns.length))
            out.append(contentsOf: matches.map { ns.substring(with: $0.range) })
        }

        // Repair common OCR underscore/space issues per line (and rerun)
        let lines = normalized
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            let repaired = line
                .replacingOccurrences(of: " _", with: "_")
                .replacingOccurrences(of: "_ ", with: "_")
                .replacingOccurrences(of: " ", with: "_")

            let repairedNS = repaired as NSString
            if let r3 = regex3, let m = r3.firstMatch(in: repaired, range: NSRange(location: 0, length: repairedNS.length)) {
                out.append(repairedNS.substring(with: m.range))
            } else if let r2 = regex2, let m = r2.firstMatch(in: repaired, range: NSRange(location: 0, length: repairedNS.length)) {
                out.append(repairedNS.substring(with: m.range))
            }
        }

        // Canonicalize + de-dup
        var seen = Set<String>()
        return out
            .map { TeslaAlertInference.canonicalizeCode($0) }
            .filter { seen.insert($0).inserted }
    }

    // MARK: - Decoder (best-effort, OCR-tolerant)

    public static func decode(code: String, sourceLine: String?) -> TeslaServiceAlert {
        let normalizedCode = TeslaAlertInference.canonicalizeCode(code)
        let parts = normalizedCode.split(separator: "_").map(String.init)

        let subsystem = parts.first
        let prefix = (subsystem ?? "").uppercased()

        // Token:
        // - For 3-part codes, use the suffix token.
        // - For 2-part codes (e.g., VCFRONT_a180), infer token from the source line text (OCR often captures the human message).
        let tokenRaw: String = {
            if parts.count >= 3 { return parts[2...].joined(separator: "_") }
            return TeslaAlertInference.tokenFromSourceLine(sourceLine, code: normalizedCode) ?? ""
        }()

        let tokenCanon = TeslaAlertInference.canonicalizeToken(tokenRaw)
        let tokenLower = tokenCanon.lowercased()
        let key = TeslaAlertInference.matchKey(tokenCanon) // ignores underscores/casing

        func make(
            _ severity: TeslaAlertSeverity,
            _ title: String,
            _ summary: String,
            _ details: String,
            _ confidence: String,
            _ action: String
        ) -> TeslaServiceAlert {
            TeslaServiceAlert(
                code: normalizedCode,
                sourceLine: sourceLine,
                subsystem: subsystem,
                title: title,
                summary: summary,
                details: details,
                severity: severity,
                confidence: confidence,
                suggestedAction: action
            )
        }

        // Known patterns (matchKey form). Extend as you see more codes.
        let rules: [(String, () -> TeslaServiceAlert)] = [

            // Battery / LV
            ("lowvoltagebattery", {
                make(.high,
                     "Low voltage battery needs service",
                     "The 12V/low-voltage battery is weak and should be replaced.",
                     "A weak low-voltage battery can cause widespread warnings and can prevent updates. The car may fail to wake/start as expected.",
                     "Source text match",
                     "Schedule service soon. Avoid leaving the car parked for long periods without driving/charging.")
            }),

            // Electrical power reduced / shutdown risk
            ("electricalsystempowerreduced", {
                make(.critical,
                     "Electrical system power reduced",
                     "Vehicle may shut down unexpectedly.",
                     "The vehicle is reporting reduced electrical system power. This can be caused by low-voltage battery issues, DC-DC conversion problems, or related controllers.",
                     "Source text match",
                     "If warnings persist or the vehicle behavior changes, park safely and contact service/roadside.")
            }),

            ("backuppowerisunavailable", {
                make(.high,
                     "Electrical system backup power unavailable",
                     "The vehicle may consume more energy while idle.",
                     "Backup power for the low-voltage system appears unavailable, which can increase idle consumption and contribute to other alerts.",
                     "Source text match",
                     "Schedule service. Minimize idle time until resolved.")
            }),

            ("vehiclecontroller", {
                make(.high,
                     "Vehicle controller condition detected",
                     "A vehicle controller reported an abnormal condition.",
                     "A controller-related alert was detected. Multiple controller errors can point to low-voltage instability or a module issue.",
                     "Source text match",
                     "Schedule service. If you see braking/steering/airbag alerts, treat as urgent.")
            }),

            // Parking brake degraded
            ("parkingbrakefunctionsdegraded", {
                make(.high,
                     "Parking brake functions degraded",
                     "Parking brake may not apply or release.",
                     "Parking brake operation may be unreliable until resolved.",
                     "Source text match",
                     "Avoid steep grades. Verify the vehicle is secured when parking. Schedule service.")
            }),

            // Steering / EPAS
            ("assisttorquedisabled", {
                make(.critical,
                     "Steering assist disabled",
                     "Power steering assist may be reduced or unavailable.",
                     "If steering assist is disabled, steering effort can increase significantly—treat as safety-critical.",
                     "Token match",
                     "Drive only if safe. If steering feels heavy, stop when safe and contact service/roadside.")
            }),
            ("vregerror", {
                make(.high,
                     "Steering/EPAS regulator error",
                     "A steering assist regulator error was reported.",
                     "This is commonly associated with EPAS (electric power assist steering). It may appear repeatedly if the condition persists.",
                     "Token match",
                     "Drive cautiously. If steering feel changes, stop when safe and contact service. Schedule service soon.")
            }),

            // Trunk / frunk
            ("frunksensorservice", {
                make(.low,
                     "Frunk sensor service",
                     "A frunk latch/sensor needs attention.",
                     "A frunk sensor or latch signal may be unreliable.",
                     "Token match",
                     "Inspect frunk closure. Schedule service if it persists.")
            }),

            // Generic tokens from older screen
            ("regenlimited", {
                make(.medium,
                     "Regenerative braking limited",
                     "Regen is reduced; friction brakes will be used more.",
                     "Regen can be limited due to battery temperature/state of charge or a related system condition. One-pedal behavior may feel different.",
                     "Token match",
                     "Increase following distance and anticipate reduced one-pedal braking.")
            }),
            ("tpmssystemfault", {
                make(.low,
                     "TPMS system fault",
                     "Tire pressure monitoring may be unavailable or inaccurate.",
                     "You may not get reliable tire pressure readings or warnings until the system recovers.",
                     "Token match",
                     "Manually check tire pressures. Service if it persists.")
            }),

            ("tpmsfaultsensor", {
                make(.low,
                     "TPMS sensor fault",
                     "One tire pressure sensor may not be sending reliable data.",
                     "This mirrors common VCSEC TPMS fault patterns from Tesla alert catalogs. It can happen after tire work, sensor aging, or a configuration mismatch.",
                     "Catalog pattern",
                     "Manually verify tire pressures. If it follows tire service, verify the sensor ID and TPMS type.")
            }),

            ("tpmsdeterminedtypemismatch", {
                make(.low,
                     "TPMS type mismatch",
                     "The stored TPMS type does not match the vehicle configuration.",
                     "The vehicle security/body controller is seeing a TPMS configuration mismatch. It can create unnecessary owner-facing tire alerts.",
                     "Catalog pattern",
                     "Verify the tires and TPMS sensors match the vehicle configuration, especially after wheel swaps.")
            }),

            ("candatabus", {
                make(.medium,
                     "CAN communication integrity warning",
                     "A controller is intermittent or failing a bus integrity check.",
                     "Tessie and MyTeslaMate catalogs include many PM and gateway-style CAN data bus alerts. One isolated event can be transient; repeated events can point to module, wiring, or low-voltage instability.",
                     "Catalog pattern",
                     "Document the exact code. Schedule service if it repeats or if braking, steering, propulsion, or drive readiness changes.")
            }),

            ("asilstatuserror", {
                make(.medium,
                     "Infotainment display safety-status error",
                     "The center display or infotainment path reported a status error.",
                     "This pattern can be associated with blank or unavailable display behavior, which may affect access to some vehicle controls.",
                     "Catalog pattern",
                     "Reboot if the display is affected. Service it if the display blanks repeatedly or returns after software updates.")
            }),

            ("audiosystemunavailable", {
                make(.low,
                     "Audio system unavailable",
                     "The audio processor or speaker path reported an unavailable state.",
                     "Usually infotainment-focused rather than propulsion-critical, but it can affect alerts, media, or pedestrian-warning audio depending on the exact code.",
                     "Catalog pattern",
                     "Reboot and monitor. Service it if warnings persist or safety-related sounds are affected.")
            })
        ]

        if let hit = rules.first(where: { key.contains($0.0) }) {
            return hit.1()
        }

        if let prefixHit = Self.decodeByCatalogPrefix(prefix: prefix, key: key, make: make) {
            return prefixHit
        }

        // Heuristics
        if key.contains("mia") {
            let inferred = TeslaAlertInference.infer(prefix: prefix, tokenLower: tokenLower, force: .mia)
            return make(inferred.severity, inferred.title, inferred.summary, inferred.details, inferred.confidence, inferred.action)
        }

        if key.contains("fault") {
            let inferred = TeslaAlertInference.infer(prefix: prefix, tokenLower: tokenLower, force: .fault)
            return make(inferred.severity, inferred.title, inferred.summary, inferred.details, inferred.confidence, inferred.action)
        }

        let inferred = TeslaAlertInference.infer(prefix: prefix, tokenLower: tokenLower, force: nil)
        return make(inferred.severity, inferred.title, inferred.summary, inferred.details, inferred.confidence, inferred.action)
    }

    private static func decodeByCatalogPrefix(
        prefix: String,
        key: String,
        make: (
            TeslaAlertSeverity,
            String,
            String,
            String,
            String,
            String
        ) -> TeslaServiceAlert
    ) -> TeslaServiceAlert? {
        if prefix.hasPrefix("BMS") || prefix.hasPrefix("BATT") {
            return make(
                .critical,
                "High-voltage battery alert",
                "Battery management reported a pack, isolation, contactor, thermal, or charge-limit condition.",
                "Treat BMS and BATT alerts with extra caution because they can affect range, charging, power delivery, or pack protection.",
                "Catalog prefix",
                "Avoid deep discharge and repeated fast charging until understood. Book service if range, charging, or power is limited."
            )
        }

        if prefix.hasPrefix("PCS") || prefix == "CP" || prefix.hasPrefix("CHG") {
            return make(
                .high,
                "Charging hardware alert",
                "Charging, charge-port, onboard charger, or connected-supply behavior needs attention.",
                "These alerts commonly point to AC/DC charging negotiation, charge-port latch state, onboard charger faults, or a charger-side problem.",
                "Catalog prefix",
                "Try a known-good charger and inspect the port/cable. Service it if the same code repeats across chargers."
            )
        }

        if prefix.hasPrefix("DI") || prefix.hasPrefix("DIR") || prefix.hasPrefix("INV") {
            return make(
                .critical,
                "Propulsion or inverter alert",
                "Drive-unit, inverter, traction, or power-delivery behavior may be degraded.",
                "Propulsion alerts can affect acceleration, regen, drive readiness, or reduced-power behavior.",
                "Catalog prefix",
                "Do not ignore if driving behavior changes. Pull over safely for active warnings and open a service request."
            )
        }

        if prefix.hasPrefix("ESP") || prefix.hasPrefix("ABS") || prefix.hasPrefix("EPB") || prefix.hasPrefix("IBST") {
            return make(
                .critical,
                "Brake or stability alert",
                "Brake, stability control, parking brake, or booster assistance may be degraded.",
                "These alerts are safety-relevant even when the car remains drivable.",
                "Catalog prefix",
                "Reduce driving and request service if any brake, ABS, stability, or parking-brake warning is shown."
            )
        }

        if prefix.hasPrefix("SRS") || prefix.hasPrefix("RCM") {
            return make(
                .critical,
                "Restraint-system alert",
                "Airbag, seatbelt pretensioner, occupant classification, or crash-safety readiness may be affected.",
                "Restraint alerts deserve prompt attention because they can affect passenger protection.",
                "Catalog prefix",
                "Book service quickly and avoid carrying passengers in affected seats if the car displays a restraint or airbag warning."
            )
        }

        if prefix.hasPrefix("DAS") || prefix.hasPrefix("APP") || prefix.hasPrefix("AP") {
            return make(
                .medium,
                "Driver-assistance alert",
                "Autopilot, camera, radar, compute, or calibration features may be blocked or unavailable.",
                "The car should be driven manually when driver-assistance features are unavailable or degraded.",
                "Catalog prefix",
                "Clean cameras and monitor after sleep/reboot. Service it if warnings persist in clear weather."
            )
        }

        if prefix.hasPrefix("UI") || prefix.hasPrefix("MCU") || prefix.hasPrefix("IC") || prefix.hasPrefix("ADSP") {
            return make(
                .medium,
                "Infotainment or display alert",
                "Display, instrument cluster, audio, or infotainment software reported an error.",
                "Most of these are not propulsion-critical, but blank displays can affect access to vehicle controls.",
                "Catalog prefix",
                "Reboot if the screen or audio is affected. Escalate if the display blanks repeatedly."
            )
        }

        if prefix.hasPrefix("HVAC") || prefix.hasPrefix("THERM") || prefix.hasPrefix("VCSEAT") || key.contains("seatcurrstall") {
            return make(
                .medium,
                "Comfort or thermal alert",
                "Seat, cabin climate, battery conditioning, or thermal hardware reported a limit or fault.",
                "Seat motor stalls may be minor, but thermal and defrost issues can affect comfort, range, or safety.",
                "Catalog prefix",
                "Monitor seat-only stalls. Service it if heat, battery conditioning, or defrost is impaired."
            )
        }

        return nil
    }
}

// MARK: - OCR-tolerant decoding helpers (private)

private enum TeslaAlertInference {

    enum Condition { case mia, fault, limited, error, warning, other }

    struct Inferred {
        let severity: TeslaAlertSeverity
        let title: String
        let summary: String
        let details: String
        let action: String
        let confidence: String
    }

    static func canonicalizeCode(_ code: String) -> String {
        var s = code.trimmingCharacters(in: .whitespacesAndNewlines)

        // Normalize separators
        s = s.replacingOccurrences(of: " ", with: "_")
        s = s.replacingOccurrences(of: "-", with: "_")
        while s.contains("__") { s = s.replacingOccurrences(of: "__", with: "_") }

        // Fix common OCR confusion: O/o mistaken for 0 in the middle segment (w027)
        var parts = s.split(separator: "_").map(String.init)
        if parts.count >= 2 {
            var mid = parts[1]
            mid = mid.replacingOccurrences(of: "O", with: "0")
            mid = mid.replacingOccurrences(of: "o", with: "0")
            parts[1] = mid
            s = parts.joined(separator: "_")
        }

        // Trim edge junk (keep underscores/alphanumerics)
        while let first = s.first, isEdgeJunk(first) { s.removeFirst() }
        while let last = s.last, isEdgeJunk(last) { s.removeLast() }

        return s
    }

    static func canonicalizeToken(_ token: String) -> String {
        var t = token.trimmingCharacters(in: .whitespacesAndNewlines)

        // Normalize separators first
        t = t.replacingOccurrences(of: "-", with: "_")
        t = t.replacingOccurrences(of: " ", with: "_")
        while t.contains("__") { t = t.replacingOccurrences(of: "__", with: "_") }

        // Fix common OCR confusions for "MIA"
        t = t.replacingOccurrences(of: "M1A", with: "MIA")
        t = t.replacingOccurrences(of: "MlA", with: "MIA")
        t = t.replacingOccurrences(of: "MIa", with: "MIA")
        t = t.replacingOccurrences(of: "m1a", with: "mia")
        t = t.replacingOccurrences(of: "mla", with: "mia")
        t = t.replacingOccurrences(of: "mIa", with: "mia")

        // Rare OCR: "M|A"
        t = t.replacingOccurrences(of: "M|A", with: "MIA")
        t = t.replacingOccurrences(of: "m|a", with: "mia")

        return t
    }

    /// Matching key that ignores underscores and casing.
    static func matchKey(_ token: String) -> String {
        token.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// If OCR captured "VCFRONT_a180 Electrical system power reduced",
    /// return the human phrase portion as the token basis.
    static func tokenFromSourceLine(_ sourceLine: String?, code: String) -> String? {
        guard var line = sourceLine?.trimmingCharacters(in: .whitespacesAndNewlines),
              !line.isEmpty else { return nil }

        // Normalize whitespace a bit
        while line.contains("  ") { line = line.replacingOccurrences(of: "  ", with: " ") }

        // Remove the code if present (best effort)
        let codeKey = matchKey(code)
        let parts = line.split(separator: " ").map(String.init)
        let kept = parts.filter { matchKey($0) != codeKey }
        let remainder = kept.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        return remainder.isEmpty ? nil : remainder
    }

    private static func isEdgeJunk(_ c: Character) -> Bool {
        if c == "_" { return false }
        if c.isLetter || c.isNumber { return false }
        return true
    }

    static func infer(prefix: String, tokenLower: String, force: Condition?) -> Inferred {
        let key = matchKey(tokenLower)

        let domain: String = {
            if key.contains("lowvoltage") || key.contains("12v") { return "Low Voltage System" }
            if key.contains("electrical") { return "Electrical System" }
            if key.contains("steer") || key.contains("epas") || key.contains("eps") { return "Steering Assist" }
            if key.contains("brake") || key.contains("epb") { return "Braking / Parking Brake" }
            if key.contains("airbag") || prefix == "RCM" { return "Airbags / Restraints" }
            if key.contains("tpms") { return "TPMS" }
            if key.contains("regen") { return "Regenerative Braking" }
            if key.contains("frunk") || key.contains("trunk") { return "Body / Latches" }
            if prefix == "VCFRONT" { return "Vehicle Controller" }
            return "Vehicle System"
        }()

        let condition: Condition = force ?? {
            if key.contains("mia") { return .mia }
            if key.contains("fault") { return .fault }
            if key.contains("limited") || key.contains("reduced") || key.contains("degraded") { return .limited }
            if key.contains("error") { return .error }
            if key.contains("warning") { return .warning }
            return .other
        }()

        let severity: TeslaAlertSeverity = {
            switch condition {
            case .mia:
                if domain == "Braking / Parking Brake" || domain == "Steering Assist" || domain == "Airbags / Restraints" { return .critical }
                return .high
            case .fault:
                if domain == "Steering Assist" || domain == "Airbags / Restraints" { return .high }
                return .medium
            case .limited:
                if key.contains("shutdown") || key.contains("powerreduced") { return .critical }
                if domain == "Steering Assist" || domain == "Braking / Parking Brake" { return .high }
                return .medium
            case .error:
                if domain == "Steering Assist" { return .high }
                return .medium
            case .warning:
                return .low
            case .other:
                return .medium
            }
        }()

        let title = "\(domain): \(conditionLabel(condition, key: key))"
        let summary = "\(domain) \(conditionSummary(condition, key: key))"

        let details = """
This description is inferred from the code token and/or the message text captured from the screen. Tesla internal codes can vary by model and firmware.

Token/message: \(tokenLower.isEmpty ? "Unavailable" : tokenLower)
Subsystem prefix: \(prefix.isEmpty ? "Unknown" : prefix)

If the alert relates to braking, steering, or airbags, treat it as safety-critical.
"""

        let action: String = {
            switch severity {
            case .critical:
                return "Drive cautiously. If vehicle behavior changes, stop when safe and contact service/roadside."
            case .high:
                return "Drive cautiously and schedule service soon."
            case .medium:
                return "Feature may be limited. Monitor; service if it persists."
            case .low:
                return "Likely non-critical. Verify basics and monitor."
            case .info:
                return "Informational. Monitor."
            case .unknown:
                return "Copy the code and consult service."
            }
        }()

        return Inferred(
            severity: severity,
            title: title,
            summary: summary,
            details: details,
            action: action,
            confidence: "Inferred"
        )
    }

    private static func conditionLabel(_ c: Condition, key: String) -> String {
        switch c {
        case .mia: return "not communicating"
        case .fault: return "fault detected"
        case .limited:
            if key.contains("degraded") { return "degraded" }
            if key.contains("reduced") { return "reduced" }
            return "limited"
        case .error: return "error"
        case .warning: return "warning"
        case .other: return "alert"
        }
    }

    private static func conditionSummary(_ c: Condition, key: String) -> String {
        switch c {
        case .mia: return "is not communicating."
        case .fault: return "reported a fault."
        case .limited:
            if key.contains("shutdown") { return "may cause a shutdown." }
            return "may be limited."
        case .error: return "reported an error."
        case .warning: return "reported a warning."
        case .other: return "reported a condition."
        }
    }
}

// MARK: - Vision OCR (Photo mode)

public enum VisionOCR {
    public enum OCRFailure: Error {
        case cgImageMissing
        case requestFailed
    }

    public static func recognizeText(in image: UIImage) async throws -> String {
        guard let cg = image.cgImage else { throw OCRFailure.cgImageMissing }

        return try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { req, err in
                if let err {
                    cont.resume(throwing: err)
                    return
                }
                guard let results = req.results as? [VNRecognizedTextObservation] else {
                    cont.resume(throwing: OCRFailure.requestFailed)
                    return
                }

                let lines: [String] = results.compactMap { $0.topCandidates(1).first?.string }
                cont.resume(returning: lines.joined(separator: "\n"))
            }

            request.recognitionLevel = .accurate

            // For codes: language correction can "helpfully" change the text and break codes.
            request.usesLanguageCorrection = false

            // Help OCR keep the tokens we care about.
            request.customWords = [
                "VCFRONT","EPBR","EPAS3S","GTW","MCU","RCM","DAS","LFA",
                "low voltage battery","electrical system power reduced","backup power is unavailable",
                "parking brake functions degraded","assist torque disabled","vRegError",
                "lowPowerIndexFlagged","frunkSensorService"
            ]

            request.minimumTextHeight = 0.018
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do {
                try handler.perform([request])
            } catch {
                cont.resume(throwing: error)
            }
        }
    }
}

// MARK: - Photo-only Scanner View

public struct TeslaServiceAlertScannerView: View {

    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var analyzer = TeslaServiceAlertAnalyzer()

    // Photo
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?

    // Results UX
    @State private var selectedItem: TeslaServiceAlert?
    @State private var showRecognizedText: Bool = false

    @State private var searchText: String = ""
    @State private var severityFilter: TeslaAlertSeverity? = nil

    public init() {}

    public var body: some View {
        let t = themeBox.base

        NavigationStack {
            ZStack {
                Rectangle()
                    .fill(t.screenBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: t.spacing) {
                        photoCard(t)

                        if analyzer.alerts.isEmpty {
                            emptyStateCard(t)
                        } else {
                            summaryCard(t)
                            filterCard(t)
                            resultsCard(t)
                        }

                        if let err = analyzer.lastError {
                            errorCard(t, err)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                }
            }
            .navigationTitle("Tesla Alerts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            analyzer.clear()
                            pickedImage = nil
                            selectedPhotoItem = nil
                            searchText = ""
                            severityFilter = nil
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }

                        Button {
                            showRecognizedText = true
                        } label: {
                            Label("Recognized Text", systemImage: "doc.text.magnifyingglass")
                        }
                        .disabled(analyzer.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search codes or titles")
            .sheet(item: $selectedItem) { item in
                TADetailSheet(item: item, fullRecognizedText: analyzer.recognizedText)
            }
            .sheet(isPresented: $showRecognizedText) {
                TARecognizedTextSheet(text: analyzer.recognizedText)
            }
        }
        .tint(themeBox.base.accent)
    }

    // MARK: - Photo UI

    @ViewBuilder
    private func photoCard(_ t: any AppThemeSpec) -> some View {
        TACard(title: "Photo scan", icon: "photo.on.rectangle", t: t) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Choose Photo", systemImage: "photo.on.rectangle")
                    }

                    Spacer()

                    if analyzer.isWorking {
                        ProgressView()
                    } else {
                        Button {
                            guard let img = pickedImage else { return }
                            Task { await analyzer.ingestImage(img) }
                        } label: {
                            Label("Run OCR", systemImage: "text.viewfinder")
                        }
                        .disabled(pickedImage == nil)
                    }
                }

                if let img = pickedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: t.corner, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: t.corner, style: .continuous)
                                .strokeBorder(t.separator.opacity(0.9), lineWidth: 1)
                        )
                } else {
                    Text("Pick a screenshot of the Tesla Alerts / Service Alerts screen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text("Tip: crop tightly around the alert list for best results.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: selectedPhotoItem) {
            guard let item = selectedPhotoItem else { return }
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    pickedImage = img
                    await analyzer.ingestImage(img)
                }
            } catch {
                analyzer.lastError = "Couldn’t load photo: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Results UI

    @ViewBuilder
    private func emptyStateCard(_ t: any AppThemeSpec) -> some View {
        TACard(title: "Decoded alerts", icon: "list.bullet.rectangle", t: t) {
            VStack(alignment: .leading, spacing: 8) {
                Text("No alert codes found yet.")
                    .font(.headline)
                Text("Choose a screenshot and run OCR.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func summaryCard(_ t: any AppThemeSpec) -> some View {
        let total = analyzer.alerts.count
        let counts = severityCounts(analyzer.alerts)

        TACard(title: "Summary", icon: "chart.bar.doc.horizontal", t: t) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(total) alert\(total == 1 ? "" : "s") found")
                        .font(.headline)
                    Spacer()
                    Button {
                        showRecognizedText = true
                    } label: {
                        Label("Text", systemImage: "doc.text")
                    }
                    .font(.subheadline)
                }

                TAWrapChips(spacing: 8) {
                    TASummaryChip(label: "Critical", value: counts[.critical, default: 0], severity: .critical, t: t)
                    TASummaryChip(label: "High", value: counts[.high, default: 0], severity: .high, t: t)
                    TASummaryChip(label: "Med", value: counts[.medium, default: 0], severity: .medium, t: t)
                    TASummaryChip(label: "Low", value: counts[.low, default: 0], severity: .low, t: t)
                    TASummaryChip(label: "Unk", value: counts[.unknown, default: 0], severity: .unknown, t: t)
                }

                Text("Tap any alert below to read more.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func filterCard(_ t: any AppThemeSpec) -> some View {
        TACard(title: "Filter", icon: "line.3.horizontal.decrease.circle", t: t) {
            VStack(alignment: .leading, spacing: 10) {
                TAWrapChips(spacing: 8) {
                    TAFilterChip(title: "All", isSelected: severityFilter == nil, t: t) { severityFilter = nil }

                    ForEach([TeslaAlertSeverity.critical, .high, .medium, .low, .unknown], id: \.self) { sev in
                        TAFilterChip(title: sev.label, isSelected: severityFilter == sev, t: t) { severityFilter = sev }
                    }
                }

                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Searching: “\(searchText)”")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func resultsCard(_ t: any AppThemeSpec) -> some View {
        let filtered = filteredAlerts(analyzer.alerts)

        TACard(title: "Alerts", icon: "exclamationmark.bubble", t: t) {
            LazyVStack(spacing: 10) {
                ForEach(filtered) { item in
                    Button { selectedItem = item } label: {
                        TACompactRow(item: item, t: t)
                    }
                    .buttonStyle(.plain)

                    if item.id != filtered.last?.id {
                        TADivider(t: t).padding(.leading, 46)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func errorCard(_ t: any AppThemeSpec, _ err: String) -> some View {
        TACard(title: "Issue", icon: "xmark.octagon", t: t) {
            Text(err)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Helpers

    private func filteredAlerts(_ input: [TeslaServiceAlert]) -> [TeslaServiceAlert] {
        let s = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return input.filter { item in
            let matchesSeverity = (severityFilter == nil) || (item.severity == severityFilter)
            if s.isEmpty { return matchesSeverity }
            let hay = (item.code + " " + item.title + " " + item.summary).lowercased()
            return matchesSeverity && hay.contains(s)
        }
    }

    private func severityCounts(_ items: [TeslaServiceAlert]) -> [TeslaAlertSeverity: Int] {
        var dict: [TeslaAlertSeverity: Int] = [:]
        for i in items { dict[i.severity, default: 0] += 1 }
        return dict
    }
}

// MARK: - UI Building Blocks (prefixed to avoid collisions)

private struct TACompactRow: View {
    let item: TeslaServiceAlert
    let t: any AppThemeSpec

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.severity.sfSymbol)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(item.code)
                        .font(.system(.subheadline, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 10)

                    TASeverityPill(severity: item.severity, t: t)
                }

                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(item.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                HStack(spacing: 8) {
                    if let sub = item.subsystem, !sub.isEmpty {
                        Text("Subsystem: \(sub)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Read more")
                        .font(.caption)
                        .foregroundStyle(t.accent)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct TADetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appThemeBox) private var themeBox

    let item: TeslaServiceAlert
    let fullRecognizedText: String

    var body: some View {
        let t = themeBox.base

        NavigationStack {
            ZStack {
                Rectangle().fill(t.screenBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: t.spacing) {

                        TACard(title: item.title, icon: item.severity.sfSymbol, t: t) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(item.code)
                                        .font(.system(.subheadline, design: .monospaced))
                                        .textSelection(.enabled)
                                    Spacer()
                                    TASeverityPill(severity: item.severity, t: t)
                                }

                                if let line = item.sourceLine, !line.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Source line")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(line)
                                            .font(.footnote)
                                            .textSelection(.enabled)
                                            .padding(10)
                                            .background(t.cardBackground.opacity(0.6))
                                            .clipShape(RoundedRectangle(cornerRadius: t.smallCorner, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: t.smallCorner, style: .continuous)
                                                    .strokeBorder(t.separator.opacity(0.75), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }

                        TACard(title: "Meaning", icon: "text.alignleft", t: t) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(item.summary).font(.headline)
                                Text(item.details)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        TACard(title: "Suggested action", icon: "bolt.fill", t: t) {
                            Text(item.suggestedAction)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        TACard(title: "Confidence", icon: "checkmark.seal", t: t) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.confidence)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text("Tesla codes and meanings can vary by model and firmware. Treat this as best-effort guidance.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        TACard(title: "Tools", icon: "wrench.and.screwdriver", t: t) {
                            VStack(alignment: .leading, spacing: 10) {
                                Button { UIPasteboard.general.string = item.code } label: {
                                    Label("Copy Code", systemImage: "doc.on.doc")
                                }

                                if !fullRecognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Button { UIPasteboard.general.string = fullRecognizedText } label: {
                                        Label("Copy Recognized Text", systemImage: "doc.text")
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(t.accent)
                        }

                        Text("If you have braking/steering/airbag alerts, prioritize safety and consider contacting service/roadside.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                }
            }
            .navigationTitle("Alert Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(t.accent)
    }
}

private struct TARecognizedTextSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appThemeBox) private var themeBox

    let text: String

    var body: some View {
        let t = themeBox.base

        NavigationStack {
            ZStack {
                Rectangle().fill(t.screenBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: t.spacing) {
                        TACard(title: "Recognized text", icon: "doc.text.magnifyingglass", t: t) {
                            Text(text.isEmpty ? "No text available." : text)
                                .font(.footnote)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if !text.isEmpty {
                            Button { UIPasteboard.general.string = text } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(t.accent)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                }
            }
            .navigationTitle("Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(t.accent)
    }
}

private struct TACard<Content: View>: View {
    let title: String
    let icon: String
    let t: any AppThemeSpec
    @ViewBuilder var content: Content

    init(title: String, icon: String, t: any AppThemeSpec, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.t = t
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: t.spacing) {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(t.accent)
                Text(title).font(.headline)
                Spacer()
            }
            content
        }
        .padding(t.spacing)
        .background(t.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: t.corner, style: .continuous))
        .shadow(radius: t.elevation * 0.15, y: t.elevation * 0.08)
    }
}

private struct TADivider: View {
    let t: any AppThemeSpec
    var body: some View {
        Rectangle()
            .fill(t.separator.opacity(0.8))
            .frame(height: 1)
    }
}

private struct TASeverityPill: View {
    let severity: TeslaAlertSeverity
    let t: any AppThemeSpec

    var body: some View {
        Text(severity.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(t.pillTint)
            .clipShape(Capsule())
    }
}

private struct TAFilterChip: View {
    let title: String
    let isSelected: Bool
    let t: any AppThemeSpec
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? t.accent.opacity(0.18) : t.cardBackground.opacity(0.6))
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(t.separator.opacity(isSelected ? 0.25 : 0.8), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct TASummaryChip: View {
    let label: String
    let value: Int
    let severity: TeslaAlertSeverity
    let t: any AppThemeSpec

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: severity.sfSymbol)
                .font(.caption.weight(.semibold))
            Text("\(label): \(value)")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(t.cardBackground.opacity(0.6))
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(t.separator.opacity(0.75), lineWidth: 1)
        )
    }
}

private struct TAWrapChips<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: Content

    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        TAFlowLayout(spacing: spacing) { content }
    }

    // Nested Layout so we don't collide with any other FlowLayout in the project
    private struct TAFlowLayout: Layout {
        let spacing: CGFloat
        init(spacing: CGFloat) { self.spacing = spacing }

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let maxWidth: CGFloat = {
                if let w = proposal.width, w > 0 { return w }
                return 360
            }()

            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for v in subviews {
                let s = v.sizeThatFits(.unspecified)
                if x > 0, x + s.width > maxWidth {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                x += s.width + spacing
                lineHeight = max(lineHeight, s.height)
            }
            return CGSize(width: maxWidth, height: y + lineHeight)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            var x = bounds.minX
            var y = bounds.minY
            var lineHeight: CGFloat = 0

            for v in subviews {
                let s = v.sizeThatFits(.unspecified)
                if x > bounds.minX, x + s.width > bounds.maxX {
                    x = bounds.minX
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                v.place(at: CGPoint(x: x, y: y),
                        proposal: ProposedViewSize(width: s.width, height: s.height))
                x += s.width + spacing
                lineHeight = max(lineHeight, s.height)
            }
        }
    }
}
