import Foundation

public enum ImportError: LocalizedError, Equatable {
    case empty
    case missingColumn(String)
    case noPlayers

    public var errorDescription: String? {
        switch self {
        case .empty: "The file has no rows."
        case .missingColumn(let c): "The file has no \(c) column."
        case .noPlayers: "No rows had a name, a position and all six attributes."
        }
    }
}

public struct ImportResult: Sendable {
    public var players: [Player]
    public var skippedRows: Int
}

/// Reads player CSVs: the app's own format and FIFA / EA FC exports (sofifa / Kaggle column names).
public enum PlayerImporter {
    static let aliases: [String: [String]] = [
        "name": ["name", "short_name", "known_as", "common_name", "player", "player_name", "full name", "long_name"],
        "nationality": ["nationality", "nationality_name", "nation", "country"],
        "club": ["club", "club_name", "team", "team_name"],
        "positions": ["positions", "player_positions", "position", "best_position", "best position", "pos"],
        "era": ["era"],
        "gender": ["gender", "sex"],
        "overall": ["overall", "ovr", "overall_rating", "overall rating", "rating"],
        "pace": ["pace", "pac"],
        "shooting": ["shooting", "sho"],
        "passing": ["passing", "pas"],
        "dribbling": ["dribbling", "dri"],
        "defending": ["defending", "def"],
        "physical": ["physical", "physic", "phy"],
        "gk_diving": ["goalkeeping_diving", "gk_diving", "gk diving", "diving", "div"],
        "gk_handling": ["goalkeeping_handling", "gk_handling", "gk handling", "handling", "han"],
        "gk_kicking": ["goalkeeping_kicking", "gk_kicking", "gk kicking", "kicking", "kic"],
        "gk_reflexes": ["goalkeeping_reflexes", "gk_reflexes", "gk reflexes", "reflexes", "ref"],
        "gk_speed": ["goalkeeping_speed", "gk_speed", "gk speed", "spd"],
        "gk_positioning": ["goalkeeping_positioning", "gk_positioning", "gk positioning", "positioning_gk"],
    ]

    static let outfieldKeys = ["pace", "shooting", "passing", "dribbling", "defending", "physical"]
    static let keeperKeys = ["gk_diving", "gk_handling", "gk_kicking", "gk_reflexes", "gk_speed", "gk_positioning"]

    public static func load(csv text: String, defaultEra: Era = .imported) throws -> ImportResult {
        let rows = CSVParser.parse(text)
        guard let header = rows.first else { throw ImportError.empty }
        let normalized = header.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        var column: [String: Int] = [:]
        for (key, names) in aliases {
            // Earlier aliases win, so "name" beats "long_name".
            if let index = names.lazy.compactMap({ normalized.firstIndex(of: $0) }).first {
                column[key] = index
            }
        }
        guard column["name"] != nil else { throw ImportError.missingColumn("name") }
        guard column["positions"] != nil else { throw ImportError.missingColumn("position") }
        if let missing = outfieldKeys.first(where: { column[$0] == nil }) {
            throw ImportError.missingColumn(missing)
        }

        var players: [Player] = []
        var skipped = 0
        var seen = Set<String>()
        for row in rows.dropFirst() {
            func text(_ key: String) -> String {
                guard let i = column[key], i < row.count else { return "" }
                return row[i].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            func number(_ key: String) -> Int? {
                let raw = text(key)
                // FIFA exports sometimes write "88+2"; take the base value.
                let base = raw.split(whereSeparator: { $0 == "+" || $0 == "-" }).first.map(String.init) ?? raw
                guard let v = Int(base.trimmingCharacters(in: .whitespaces)), (1...99).contains(v) else { return nil }
                return v
            }

            let name = text("name")
            let positions = text("positions")
                .split(whereSeparator: { $0 == "," || $0 == "/" || $0 == ";" || $0 == " " })
                .map { $0.uppercased() }
                .filter { PositionGroup.of(position: $0) != nil }
            guard !name.isEmpty, !positions.isEmpty else { skipped += 1; continue }

            var traits = outfieldKeys.compactMap(number)
            if PositionGroup.of(position: positions[0]) == .goalkeeper {
                let keeper = keeperKeys.compactMap(number)
                if keeper.count == 6 { traits = keeper }
            }
            guard traits.count == 6 else { skipped += 1; continue }

            let era = Era(rawValue: text("era").capitalized) ?? defaultEra
            let overall = number("overall") ?? Int((Double(traits.reduce(0, +)) / 6).rounded())
            let player = Player(name: name, nationality: text("nationality"), club: text("club"),
                                positions: positions, era: era, overall: overall, traits: traits,
                                gender: Gender(text: text("gender")))
            guard seen.insert(player.id).inserted else { skipped += 1; continue }
            players.append(player)
        }
        guard !players.isEmpty else { throw ImportError.noPlayers }
        return ImportResult(players: players, skippedRows: skipped)
    }

    public static func load(url: URL, defaultEra: Era = .imported) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        let text = String(decoding: data, as: UTF8.self)
        return try load(csv: text, defaultEra: defaultEra)
    }
}

public enum BundledPlayers {
    /// The players shipped with the app. Looks in the app bundle first, then the SwiftPM resource bundle.
    public static func load() -> [Player] {
        let url = Bundle.main.url(forResource: "players", withExtension: "csv")
            ?? Bundle.module.url(forResource: "players", withExtension: "csv")
        guard let url, let result = try? PlayerImporter.load(url: url, defaultEra: .current) else { return [] }
        return result.players
    }
}
