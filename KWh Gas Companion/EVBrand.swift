//
//  EVBrand.swift
//  KWh Gas Companion
//
//  Brand + model inference for common EVs.
//  Swift 6 • iOS 17+
//
//  Goal:
//  - Lightweight “good enough” inference from VIN WMI + name/model text
//  - Easy pathway to add more brands/models later (just append rules)
//

import Foundation

// MARK: - Brand

public enum EVBrand: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case tesla
    case rivian

    case ford
    case gmc
    case chevrolet
    case cadillac

    case hyundai
    case kia
    case genesis

    case volkswagen
    case audi
    case bmw
    case mercedes
    case porsche

    case nissan
    case toyota
    case subaru
    case honda
    case acura

    case polestar
    case volvo
    case lucid
    case jaguar
    case mini
    case fiat

    case other
    case unknown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .tesla: return "Tesla"
        case .rivian: return "Rivian"
        case .ford: return "Ford"
        case .gmc: return "GMC"
        case .chevrolet: return "Chevrolet"
        case .cadillac: return "Cadillac"
        case .hyundai: return "Hyundai"
        case .kia: return "Kia"
        case .genesis: return "Genesis"
        case .volkswagen: return "Volkswagen"
        case .audi: return "Audi"
        case .bmw: return "BMW"
        case .mercedes: return "Mercedes-Benz"
        case .porsche: return "Porsche"
        case .nissan: return "Nissan"
        case .toyota: return "Toyota"
        case .subaru: return "Subaru"
        case .honda: return "Honda"
        case .acura: return "Acura"
        case .polestar: return "Polestar"
        case .volvo: return "Volvo"
        case .lucid: return "Lucid"
        case .jaguar: return "Jaguar"
        case .mini: return "MINI"
        case .fiat: return "Fiat"
        case .other: return "Other"
        case .unknown: return "Unknown"
        }
    }

    /// SF Symbol used for UI badges (brand logo not available in SF Symbols).
    public var symbolName: String {
        switch self {
        case .tesla: return "bolt.car"
        case .rivian: return "mountain.2"
        case .ford: return "car"
        case .gmc: return "car.circle"
        case .chevrolet: return "car.fill"
        case .cadillac: return "crown"
        case .hyundai: return "leaf"
        case .kia: return "leaf"
        case .genesis: return "sparkles"
        case .volkswagen: return "circle"
        case .audi: return "circle.grid.2x2"
        case .bmw: return "gearshape.2"
        case .mercedes: return "shield"
        case .porsche: return "speedometer"
        case .nissan: return "bolt"
        case .toyota: return "car"
        case .subaru: return "snowflake"
        case .honda: return "car"
        case .acura: return "car"
        case .polestar: return "star"
        case .volvo: return "v.circle"
        case .lucid: return "cloud.sun"
        case .jaguar: return "hare"
        case .mini: return "circlebadge"
        case .fiat: return "f.cursive"
        case .other: return "questionmark.circle"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Model line (simple & future-proof)

public struct EVModelLine: Identifiable, Codable, Hashable, Sendable {
    public let name: String
    public var id: String { name }

    public init(_ name: String) { self.name = name }

    public static let unknown = EVModelLine("Unknown")
}

// MARK: - Inference result

public struct EVBrandInference: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let brand: EVBrand
    public let modelLine: EVModelLine
    /// 0.0–1.0, heuristic confidence
    public let confidence: Double
    public let reasons: [String]

    public init(
        brand: EVBrand,
        modelLine: EVModelLine,
        confidence: Double,
        reasons: [String]
    ) {
        self.brand = brand
        self.modelLine = modelLine
        self.confidence = max(0, min(confidence, 1))
        self.reasons = reasons
        self.id = "\(brand.rawValue)|\(modelLine.name)"
    }

    public static let unknown = EVBrandInference(
        brand: .unknown,
        modelLine: .unknown,
        confidence: 0,
        reasons: []
    )
}

// MARK: - Catalog

public enum EVBrandCatalog {

    // No closures here → Hashable/Equatable works.
    public struct ModelRule: Codable, Hashable, Sendable {
        public let modelLine: EVModelLine
        public let keywords: [String]   // lowercase tokens

        public init(_ modelLine: EVModelLine, keywords: [String]) {
            self.modelLine = modelLine
            self.keywords = keywords.map { $0.lowercased() }
        }
    }

    public struct BrandRule: Codable, Hashable, Sendable {
        public let brand: EVBrand
        public let wmiPrefixes: [String]    // VIN first 3 chars (or longer), uppercase
        public let brandKeywords: [String]  // lowercase tokens
        public let models: [ModelRule]
        public let priority: Int            // tie-breaker (higher wins)

        public init(
            brand: EVBrand,
            wmiPrefixes: [String] = [],
            brandKeywords: [String] = [],
            models: [ModelRule] = [],
            priority: Int = 0
        ) {
            self.brand = brand
            self.wmiPrefixes = wmiPrefixes.map { $0.uppercased() }
            self.brandKeywords = brandKeywords.map { $0.lowercased() }
            self.models = models
            self.priority = priority
        }
    }

    // MARK: - Public API

    /// Overload to match call sites that only have VIN.
    public static func infer(vin: String?) -> EVBrandInference {
        infer(vin: vin, name: nil, nickname: nil, model: nil)
    }

    /// Overload to match call sites using `name:` (your errors show this exists in VehicleProfileListView).
    public static func infer(vin: String?, name: String?) -> EVBrandInference {
        infer(vin: vin, name: name, nickname: nil, model: nil)
    }

    /// Most flexible overload — use this going forward.
    public static func infer(vin: String?, name: String?, nickname: String?, model: String?) -> EVBrandInference {
        let vinU = (vin ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let wmi = vinU.count >= 3 ? String(vinU.prefix(3)) : ""

        let blob = [
            name ?? "",
            nickname ?? "",
            model ?? "",
            vin ?? ""
        ]
        .joined(separator: " ")
        .lowercased()

        // Score each brand rule.
        var best: (rule: BrandRule, score: Int, model: EVModelLine, modelScore: Int, reasons: [String])? = nil

        for rule in rules {
            var score = 0
            var reasons: [String] = []

            // WMI match is strong
            if !wmi.isEmpty, rule.wmiPrefixes.contains(where: { wmi.hasPrefix($0) }) {
                score += 12
                reasons.append("VIN WMI matched \(wmi)")
            }

            // Brand keywords
            var kwHits = 0
            for kw in rule.brandKeywords where !kw.isEmpty {
                if blob.contains(kw) {
                    kwHits += 1
                }
            }
            if kwHits > 0 {
                score += kwHits * 3
                reasons.append("Brand keywords matched (\(kwHits))")
            }

            // Find best model under this brand
            var bestModel = EVModelLine.unknown
            var bestModelScore = 0

            for m in rule.models {
                var ms = 0
                for kw in m.keywords where !kw.isEmpty {
                    if blob.contains(kw) { ms += 2 }
                }
                // prefer a model if it hits at least once
                if ms > bestModelScore {
                    bestModelScore = ms
                    bestModel = m.modelLine
                }
            }

            if bestModelScore > 0 {
                score += bestModelScore
                reasons.append("Model matched: \(bestModel.name)")
            }

            // If nothing matched at all, skip (prevents false positives).
            if score == 0 { continue }

            if let cur = best {
                // Prefer higher score, then higher priority
                if score > cur.score || (score == cur.score && rule.priority > cur.rule.priority) {
                    best = (rule, score, bestModel, bestModelScore, reasons)
                }
            } else {
                best = (rule, score, bestModel, bestModelScore, reasons)
            }
        }

        guard let best else {
            // Special-case: Tesla/Rivian VIN WMIs that might appear without name text
            if teslaWMIs.contains(where: { wmi.hasPrefix($0) }) {
                return EVBrandInference(brand: .tesla, modelLine: .unknown, confidence: 0.55, reasons: ["VIN WMI matched Tesla"])
            }
            if rivianWMIs.contains(where: { wmi.hasPrefix($0) }) {
                return EVBrandInference(brand: .rivian, modelLine: .unknown, confidence: 0.55, reasons: ["VIN WMI matched Rivian"])
            }
            return .unknown
        }

        // Heuristic confidence mapping
        let raw = Double(best.score)
        let conf = min(1.0, max(0.25, raw / 28.0))

        return EVBrandInference(
            brand: best.rule.brand,
            modelLine: best.model,
            confidence: conf,
            reasons: best.reasons
        )
    }

    /// For building pickers/search (“pathway for future updates”).
    public static func supportedModels(for brand: EVBrand) -> [EVModelLine] {
        rules.first(where: { $0.brand == brand })?.models.map(\.modelLine) ?? []
    }

    /// “Most common EVs” quick list (for UI suggestions).
    public static var commonEVs: [(brand: EVBrand, model: EVModelLine)] {
        rules.flatMap { rule in
            rule.models.map { (rule.brand, $0.modelLine) }
        }
    }

    // MARK: - Rules data (extend here)

    // VIN WMIs (limited but helpful)
    private static let teslaWMIs: [String] = ["5YJ", "7SA", "LRW", "XP7"]
    private static let rivianWMIs: [String] = ["7FC"] // Rivian (commonly seen)

    // Big list of common EVs across the market
    public static let rules: [BrandRule] = [
        // TESLA
        BrandRule(
            brand: .tesla,
            wmiPrefixes: teslaWMIs,
            brandKeywords: ["tesla", "model s", "model 3", "model x", "model y", "cybertruck"],
            models: [
                ModelRule(EVModelLine("Model 3"), keywords: ["model 3", "m3"]),
                ModelRule(EVModelLine("Model Y"), keywords: ["model y", "my"]),
                ModelRule(EVModelLine("Model S"), keywords: ["model s", "ms"]),
                ModelRule(EVModelLine("Model X"), keywords: ["model x", "mx"]),
                ModelRule(EVModelLine("Cybertruck"), keywords: ["cybertruck"])
            ],
            priority: 100
        ),

        // RIVIAN
        BrandRule(
            brand: .rivian,
            wmiPrefixes: rivianWMIs,
            brandKeywords: ["rivian", "r1t", "r1s", "r2", "r3"],
            models: [
                ModelRule(EVModelLine("R1T"), keywords: ["r1t"]),
                ModelRule(EVModelLine("R1S"), keywords: ["r1s"]),
                ModelRule(EVModelLine("R2"), keywords: ["r2"]),
                ModelRule(EVModelLine("R3"), keywords: ["r3"])
            ],
            priority: 95
        ),

        // FORD
        BrandRule(
            brand: .ford,
            brandKeywords: ["ford", "mach-e", "mache", "mustang mach", "lightning", "e-transit", "etransit"],
            models: [
                ModelRule(EVModelLine("Mustang Mach-E"), keywords: ["mach-e", "mache", "mustang mach"]),
                ModelRule(EVModelLine("F-150 Lightning"), keywords: ["f-150 lightning", "f150 lightning", "lightning"]),
                ModelRule(EVModelLine("E-Transit"), keywords: ["e-transit", "etransit"])
            ],
            priority: 70
        ),

        // GMC (HUMMER EV + SIERRA EV)
        BrandRule(
            brand: .gmc,
            brandKeywords: ["gmc", "hummer ev", "sierra ev"],
            models: [
                ModelRule(EVModelLine("Hummer EV"), keywords: ["hummer ev", "hummer"]),
                ModelRule(EVModelLine("Sierra EV"), keywords: ["sierra ev"])
            ],
            priority: 85
        ),

        // CHEVROLET (BOLT, EQUINOX EV, BLAZER EV, SILVERADO EV)
        BrandRule(
            brand: .chevrolet,
            brandKeywords: ["chevy", "chevrolet", "bolt", "euv", "silverado ev", "blazer ev", "equinox ev"],
            models: [
                ModelRule(EVModelLine("Bolt EV"), keywords: ["bolt ev", "bolt"]),
                ModelRule(EVModelLine("Bolt EUV"), keywords: ["bolt euv", "euv"]),
                ModelRule(EVModelLine("Equinox EV"), keywords: ["equinox ev"]),
                ModelRule(EVModelLine("Blazer EV"), keywords: ["blazer ev"]),
                ModelRule(EVModelLine("Silverado EV"), keywords: ["silverado ev"])
            ],
            priority: 72
        ),

        // CADILLAC
        BrandRule(
            brand: .cadillac,
            brandKeywords: ["cadillac", "lyriq", "celestiq", "escalade iq", "opt iq"],
            models: [
                ModelRule(EVModelLine("Lyriq"), keywords: ["lyriq"]),
                ModelRule(EVModelLine("Escalade IQ"), keywords: ["escalade iq"]),
                ModelRule(EVModelLine("Celestiq"), keywords: ["celestiq"])
            ],
            priority: 68
        ),

        // HYUNDAI
        BrandRule(
            brand: .hyundai,
            brandKeywords: ["hyundai", "ioniq 5", "ioniq5", "ioniq 6", "ioniq6", "kona electric"],
            models: [
                ModelRule(EVModelLine("Ioniq 5"), keywords: ["ioniq 5", "ioniq5"]),
                ModelRule(EVModelLine("Ioniq 6"), keywords: ["ioniq 6", "ioniq6"]),
                ModelRule(EVModelLine("Kona Electric"), keywords: ["kona electric"])
            ],
            priority: 65
        ),

        // KIA
        BrandRule(
            brand: .kia,
            brandKeywords: ["kia", "ev6", "ev9", "niro ev", "soul ev"],
            models: [
                ModelRule(EVModelLine("EV6"), keywords: ["ev6"]),
                ModelRule(EVModelLine("EV9"), keywords: ["ev9"]),
                ModelRule(EVModelLine("Niro EV"), keywords: ["niro ev"]),
                ModelRule(EVModelLine("Soul EV"), keywords: ["soul ev"])
            ],
            priority: 64
        ),

        // VW
        BrandRule(
            brand: .volkswagen,
            brandKeywords: ["vw", "volkswagen", "id.4", "id4", "id buzz", "id.buzz"],
            models: [
                ModelRule(EVModelLine("ID.4"), keywords: ["id.4", "id4"]),
                ModelRule(EVModelLine("ID. Buzz"), keywords: ["id buzz", "id.buzz"])
            ],
            priority: 60
        ),

        // AUDI
        BrandRule(
            brand: .audi,
            brandKeywords: ["audi", "q4 e-tron", "q4 etron", "q8 e-tron", "e-tron", "etron"],
            models: [
                ModelRule(EVModelLine("Q4 e-tron"), keywords: ["q4 e-tron", "q4 etron"]),
                ModelRule(EVModelLine("Q8 e-tron"), keywords: ["q8 e-tron", "q8 etron"]),
                ModelRule(EVModelLine("e-tron GT"), keywords: ["e-tron gt", "etron gt"])
            ],
            priority: 58
        ),

        // BMW
        BrandRule(
            brand: .bmw,
            brandKeywords: ["bmw", "i4", "ix", "i7", "i5"],
            models: [
                ModelRule(EVModelLine("i4"), keywords: [" i4", "bmw i4"]),
                ModelRule(EVModelLine("iX"), keywords: [" ix", "bmw ix"]),
                ModelRule(EVModelLine("i7"), keywords: [" i7", "bmw i7"]),
                ModelRule(EVModelLine("i5"), keywords: [" i5", "bmw i5"])
            ],
            priority: 57
        ),

        // MERCEDES
        BrandRule(
            brand: .mercedes,
            brandKeywords: ["mercedes", "eqs", "eqe", "eqb", "eqa"],
            models: [
                ModelRule(EVModelLine("EQS"), keywords: [" eqs", "mercedes eqs"]),
                ModelRule(EVModelLine("EQE"), keywords: [" eqe", "mercedes eqe"]),
                ModelRule(EVModelLine("EQB"), keywords: [" eqb", "mercedes eqb"]),
                ModelRule(EVModelLine("EQA"), keywords: [" eqa", "mercedes eqa"])
            ],
            priority: 56
        ),

        // NISSAN
        BrandRule(
            brand: .nissan,
            brandKeywords: ["nissan", "leaf", "ariya"],
            models: [
                ModelRule(EVModelLine("Leaf"), keywords: ["leaf"]),
                ModelRule(EVModelLine("Ariya"), keywords: ["ariya"])
            ],
            priority: 55
        ),

        // POLESTAR
        BrandRule(
            brand: .polestar,
            brandKeywords: ["polestar", "polestar 2", "polestar 3", "polestar 4"],
            models: [
                ModelRule(EVModelLine("Polestar 2"), keywords: ["polestar 2"]),
                ModelRule(EVModelLine("Polestar 3"), keywords: ["polestar 3"]),
                ModelRule(EVModelLine("Polestar 4"), keywords: ["polestar 4"])
            ],
            priority: 54
        ),

        // VOLVO
        BrandRule(
            brand: .volvo,
            brandKeywords: ["volvo", "ex30", "ex90", "xc40 recharge", "c40 recharge"],
            models: [
                ModelRule(EVModelLine("EX30"), keywords: ["ex30"]),
                ModelRule(EVModelLine("EX90"), keywords: ["ex90"]),
                ModelRule(EVModelLine("XC40 Recharge"), keywords: ["xc40 recharge", "xc40"]),
                ModelRule(EVModelLine("C40 Recharge"), keywords: ["c40 recharge", "c40"])
            ],
            priority: 53
        ),

        // LUCID
        BrandRule(
            brand: .lucid,
            brandKeywords: ["lucid", "lucid air", "lucid gravity"],
            models: [
                ModelRule(EVModelLine("Air"), keywords: ["lucid air", " air "]),
                ModelRule(EVModelLine("Gravity"), keywords: ["lucid gravity", " gravity "])
            ],
            priority: 52
        ),

        // PORSCHE
        BrandRule(
            brand: .porsche,
            brandKeywords: ["porsche", "taycan", "macan ev"],
            models: [
                ModelRule(EVModelLine("Taycan"), keywords: ["taycan"]),
                ModelRule(EVModelLine("Macan EV"), keywords: ["macan ev"])
            ],
            priority: 51
        ),

        // TOYOTA / SUBARU (shared platform models)
        BrandRule(
            brand: .toyota,
            brandKeywords: ["toyota", "bz4x", "bZ4X"],
            models: [
                ModelRule(EVModelLine("bZ4X"), keywords: ["bz4x"])
            ],
            priority: 45
        ),
        BrandRule(
            brand: .subaru,
            brandKeywords: ["subaru", "solterra"],
            models: [
                ModelRule(EVModelLine("Solterra"), keywords: ["solterra"])
            ],
            priority: 44
        ),

        // HONDA / ACURA
        BrandRule(
            brand: .honda,
            brandKeywords: ["honda", "prologue"],
            models: [
                ModelRule(EVModelLine("Prologue"), keywords: ["prologue"])
            ],
            priority: 43
        ),
        BrandRule(
            brand: .acura,
            brandKeywords: ["acura", "zdx"],
            models: [
                ModelRule(EVModelLine("ZDX"), keywords: ["zdx"])
            ],
            priority: 42
        )
    ]
}
