import SwiftUI

/// A robust row for a single charging entry.
/// Uses reflection to read common fields from any ExpenseEntry-like type.
///
/// 🔧 FIX: primaryTitle previously returned the literal string "Charge" whenever
/// a location was available — hiding the useful location name in the title and
/// then redundantly showing it again in the subtitle, producing:
///   Title: "Charge"  Subtitle: "· Supercharger Exit 12"
/// Fixed: when a location is available, use it directly as the title. The
/// subtitle then shows secondary details (charge type) instead of repeating it.
///
struct ChargeLogRowView: View {

    // PERF: `date`, `kWh`, `cost`, `location` and `isFast` used to be computed
    // properties, each running `extractChild(named:)` — a *nested* Mirror walk
    // over the backing value and then over every one of its children. `body`
    // touches those properties around a dozen times per pass (several of them
    // twice, plus again inside `accessibilitySummary`), so scrolling a charge
    // log re-ran the whole reflection cascade for every visible row on every
    // frame. Reflection now happens exactly once, in `init`.
    private let date: Date
    private let kWh: Double?
    private let cost: Double?
    private let location: String?
    private let isFast: Bool

    // MARK: - Designated init for app use
    init(entry: ExpenseEntry) {
        self.init(backing: entry)
    }

    // MARK: - Convenience init for previews/tests
    init(date: Date, kWh: Double, cost: Double, location: String? = nil, isFast: Bool = false) {
        self.init(backing: PreviewBacking(date: date, kWh: kWh, cost: cost, location: location, isFast: isFast))
    }

    /// Resolves every displayed field from `backing` in one reflection pass.
    private init(backing: Any) {
        let date = Self.extractDate(backing, ["date", "timestamp", "time", "createdAt", "loggedAt"]) ?? Date()
        let kWh = Self.extractDouble(backing, ["kWh", "energyKWh", "energy", "quantity", "amountKWh", "consumedKWh",
                                               "energyAddedKWh", "kwh"])
        let cost = Self.extractDouble(backing, ["cost", "totalCost", "amount", "price", "spend"])
        let location = Self.extractString(backing, ["location", "site", "title", "name"])

        self.date = date
        self.kWh = kWh
        self.cost = cost
        self.location = location
        self.isFast = Self.resolveIsFast(backing, cost: cost, kWh: kWh)
    }

    /// Mirrors the original `isFast` heuristic, evaluated once at init.
    private static func resolveIsFast(_ backing: Any, cost: Double?, kWh: Double?) -> Bool {
        if let b = extractBool(backing, ["isFastCharge", "fast", "isDCFC"]) { return b }
        let inferKeys = ["chargerType", "locationType", "kind", "type"]
        if let s = extractString(backing, inferKeys)?.lowercased() {
            if s.contains("fast") || s.contains("dcfc") || s.contains("super") { return true }
            if s.contains("home") || s.contains("level 1") || s.contains("level 2") { return false }
        }
        if let c = cost, let k = kWh, k > 0, c / k >= 0.45 { return true }
        return false
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 12) {
            icon
                .font(.title3)
                .foregroundStyle(isFast ? .yellow : .blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                // 🔧 FIX: primaryTitle now returns the location if available, so the
                // title row carries meaningful content. The subtitle shows charge type.
                Text(primaryTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(dateFormatter.string(from: date))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                if let k = kWh {
                    Text(kWhString(k))
                        .font(.headline.monospacedDigit())
                }
                if let c = cost, c > 0 {
                    Text(currencyString(c))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else if let k = kWh, k > 0, let p = pricePerKWh {
                    Text("\(currencyString(p)) / kWh")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - UI bits

    private var icon: Image {
        isFast ? Image(systemName: "bolt.fill") : Image(systemName: "house.fill")
    }

    /// 🔧 FIX: Was `if let loc = location, !loc.isEmpty { return "Charge" }`.
    /// That discards the location string and produces a generic title.
    /// Now: use the location if present, otherwise fall back to charge type label.
    private var primaryTitle: String {
        if let loc = location, !loc.isEmpty { return loc }
        return isFast ? "Fast charge" : "Home charge"
    }

    private var accessibilitySummary: String {
        var parts: [String] = []
        parts.append(primaryTitle)
        parts.append(dateFormatter.string(from: date))
        if let k = kWh { parts.append(kWhString(k)) }
        if let c = cost, c > 0 { parts.append(currencyString(c)) }
        return parts.joined(separator: ", ")
    }

    // MARK: - Derived values (cheap — no reflection)

    private var pricePerKWh: Double? {
        guard let c = cost, let k = kWh, k > 0 else { return nil }
        return c / k
    }

    // MARK: - Formatting

    private func kWhString(_ kwh: Double) -> String {
        let rounded = (kwh * 10).rounded() / 10
        return "\(rounded.cleanOneDecimal) kWh"
    }

    // PERF: these were built fresh on every call — `currencyString` allocated a
    // NumberFormatter up to 3× per row and `dateFormatter` a DateFormatter 2×.
    // Foundation formatter construction is one of the most expensive things you
    // can do per frame, and this runs for every visible row while scrolling.
    // Both are immutable once configured, so they are shared.
    private static let sharedCurrencyFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        return nf
    }()

    private static let sharedDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    private func currencyString(_ value: Double) -> String {
        Self.sharedCurrencyFormatter.string(from: NSNumber(value: value))
            ?? String(format: "$%.2f", value)
    }

    private var dateFormatter: DateFormatter { Self.sharedDateFormatter }

    // MARK: - Reflection helpers

    private static func extractChild(_ backing: Any, named candidates: [String]) -> Any? {
        let m = Mirror(reflecting: backing)
        for child in m.children {
            guard let label = child.label else { continue }
            if candidates.contains(label) {
                return unwrapOptional(child.value)
            }
        }
        for child in m.children {
            let cm = Mirror(reflecting: child.value)
            for grand in cm.children {
                if let label = grand.label, candidates.contains(label) {
                    return unwrapOptional(grand.value)
                }
            }
        }
        return nil
    }

    private static func extractDouble(_ backing: Any, _ names: [String]) -> Double? {
        guard let raw = extractChild(backing, named: names) else { return nil }
        if let v = raw as? Double { return v }
        if let v = raw as? Float { return Double(v) }
        if let v = raw as? Int { return Double(v) }
        if let v = raw as? NSNumber { return v.doubleValue }
        if let s = raw as? String { return Double(s) }
        return nil
    }

    private static func extractString(_ backing: Any, _ names: [String]) -> String? {
        guard let raw = extractChild(backing, named: names) else { return nil }
        if let s = raw as? String { return s }
        if let v = raw as? NSNumber { return v.stringValue }
        return nil
    }

    private static func extractBool(_ backing: Any, _ names: [String]) -> Bool? {
        guard let raw = extractChild(backing, named: names) else { return nil }
        if let b = raw as? Bool { return b }
        if let n = raw as? NSNumber { return n.boolValue }
        if let s = raw as? String {
            let ls = s.lowercased()
            if ["true", "yes", "1", "fast", "dcfc", "supercharger"].contains(ls) { return true }
            if ["false", "no", "0", "home", "ac"].contains(ls) { return false }
        }
        return nil
    }

    private static func extractDate(_ backing: Any, _ names: [String]) -> Date? {
        guard let raw = extractChild(backing, named: names) else { return nil }
        if let d = raw as? Date { return d }
        if let s = raw as? String {
            let f1 = ISO8601DateFormatter()
            if let d = f1.date(from: s) { return d }
            let f2 = DateFormatter()
            f2.dateFormat = "yyyy-MM-dd HH:mm:ss"
            if let d = f2.date(from: s) { return d }
        }
        if let t = raw as? TimeInterval { return Date(timeIntervalSince1970: t) }
        if let n = raw as? NSNumber { return Date(timeIntervalSince1970: n.doubleValue) }
        return nil
    }

    private static func unwrapOptional(_ any: Any) -> Any {
        let mirror = Mirror(reflecting: any)
        guard mirror.displayStyle == .optional else { return any }
        if let child = mirror.children.first { return child.value }
        return NSNull()
    }

    // MARK: - Preview backing
    private struct PreviewBacking {
        var date: Date
        var kWh: Double
        var cost: Double
        var location: String?
        var isFastCharge: Bool
        init(date: Date, kWh: Double, cost: Double, location: String?, isFast: Bool) {
            self.date = date
            self.kWh = kWh
            self.cost = cost
            self.location = location
            self.isFastCharge = isFast
        }
    }
}

// MARK: - Preview

struct ChargeLogRowView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ChargeLogRowView(
                date: .now,
                kWh: 42.7,
                cost: 11.84,
                location: "Home",
                isFast: false
            )
            .previewLayout(.sizeThatFits)
            .padding()

            ChargeLogRowView(
                date: .now.addingTimeInterval(-3600),
                kWh: 31.2,
                cost: 17.45,
                location: "Supercharger • Exit 12",
                isFast: true
            )
            .previewLayout(.sizeThatFits)
            .padding()
        }
    }
}

// MARK: - Numeric convenience

private extension Double {
    var cleanOneDecimal: String {
        let v = (self * 10).rounded() / 10
        if v == floor(v) { return String(Int(v)) }
        return String(format: "%.1f", v)
    }
}
