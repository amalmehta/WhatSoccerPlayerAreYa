import Foundation

/// The six card attributes every player is described by, in EA card order.
public enum Trait: Int, CaseIterable, Codable, Sendable, Identifiable {
    case pace, shooting, passing, dribbling, defending, physical

    public var id: Int { rawValue }

    public var name: String {
        switch self {
        case .pace: "Pace"
        case .shooting: "Shooting"
        case .passing: "Passing"
        case .dribbling: "Dribbling"
        case .defending: "Defending"
        case .physical: "Physical"
        }
    }

    /// What the same slot means on a goalkeeper card.
    public var keeperName: String {
        switch self {
        case .pace: "Diving"
        case .shooting: "Handling"
        case .passing: "Kicking"
        case .dribbling: "Reflexes"
        case .defending: "Speed"
        case .physical: "Positioning"
        }
    }

    /// Short card label, e.g. "PAC".
    public var abbreviation: String {
        switch self {
        case .pace: "PAC"
        case .shooting: "SHO"
        case .passing: "PAS"
        case .dribbling: "DRI"
        case .defending: "DEF"
        case .physical: "PHY"
        }
    }
}

public enum PositionGroup: String, CaseIterable, Codable, CodingKeyRepresentable, Sendable, Identifiable {
    case goalkeeper, defender, midfielder, forward

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .goalkeeper: "Goalkeeper"
        case .defender: "Defender"
        case .midfielder: "Midfielder"
        case .forward: "Forward"
        }
    }

    /// Maps an EA-style position abbreviation (ST, CB, CAM…) to its group.
    public static func of(position: String) -> PositionGroup? {
        switch position.uppercased().trimmingCharacters(in: .whitespaces) {
        case "GK": .goalkeeper
        case "CB", "LB", "RB", "LWB", "RWB", "SW", "LCB", "RCB", "DF", "D": .defender
        case "CDM", "CM", "CAM", "LM", "RM", "LCM", "RCM", "LDM", "RDM", "MF", "M": .midfielder
        case "ST", "CF", "LW", "RW", "LF", "RF", "LS", "RS", "FW", "F": .forward
        default: nil
        }
    }
}

public enum Era: String, Codable, Sendable, CaseIterable {
    case current = "Current"
    case legend = "Legend"
    case imported = "Imported"
}

/// Whether a player plays in the men's or the women's game.
public enum Gender: String, Codable, Sendable, CaseIterable, Identifiable {
    case men = "Men"
    case women = "Women"

    public var id: String { rawValue }

    /// "Men's" / "Women's", as people say it.
    public var name: String {
        switch self {
        case .men: "Men's"
        case .women: "Women's"
        }
    }

    /// Reads the values CSVs tend to use: Men, Male, M, Women, Female, F, W…
    public init?(text: String) {
        switch text.trimmingCharacters(in: .whitespaces).lowercased() {
        case "men", "man", "male", "m", "men's", "mens": self = .men
        case "women", "woman", "female", "f", "w", "women's", "womens": self = .women
        default: return nil
        }
    }
}

public struct Player: Identifiable, Codable, Hashable, Sendable {
    public var id: String { "\(name)|\(club)|\(era.rawValue)" }
    public var name: String
    public var nationality: String
    public var club: String
    /// Best position first.
    public var positions: [String]
    public var era: Era
    public var overall: Int
    /// One value per `Trait`, in `Trait.allCases` order, each 1–99.
    public var traits: [Int]
    /// Nil when an imported file doesn't say.
    public var gender: Gender?

    public init(name: String, nationality: String = "", club: String = "", positions: [String],
                era: Era, overall: Int, traits: [Int], gender: Gender? = nil) {
        precondition(traits.count == Trait.allCases.count, "need one value per trait")
        self.name = name
        self.nationality = nationality
        self.club = club
        self.positions = positions
        self.era = era
        self.overall = overall
        self.traits = traits
        self.gender = gender
    }

    public var group: PositionGroup {
        positions.lazy.compactMap(PositionGroup.of(position:)).first ?? .midfielder
    }

    public var isKeeper: Bool { group == .goalkeeper }

    public func value(_ trait: Trait) -> Int { traits[trait.rawValue] }

    public func traitName(_ trait: Trait) -> String { isKeeper ? trait.keeperName : trait.name }
}
