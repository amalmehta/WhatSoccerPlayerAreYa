import Foundation
import Testing
@testable import SoccerCore

@Suite struct CSVParserTests {
    @Test func quotedFieldsAndNewlines() {
        let rows = CSVParser.parse("\u{FEFF}a,b,c\r\n\"x, y\",\"say \"\"hi\"\"\",\"line\nbreak\"\n\n1,2,3")
        #expect(rows == [["a", "b", "c"], ["x, y", "say \"hi\"", "line\nbreak"], ["1", "2", "3"]])
    }
}

@Suite struct ImporterTests {
    @Test func appFormat() throws {
        let csv = """
        name,nationality,club,positions,era,overall,pace,shooting,passing,dribbling,defending,physical
        Lionel Messi,Argentina,Inter Miami,"RW, CF",Current,88,76,86,90,92,34,64
        """
        let r = try PlayerImporter.load(csv: csv)
        #expect(r.players.count == 1)
        let p = try #require(r.players.first)
        #expect(p.positions == ["RW", "CF"])
        #expect(p.group == .forward)
        #expect(p.era == .current)
        #expect(p.value(.dribbling) == 92)
    }

    @Test func sofifaFormatWithKeeperFallbackAndSkips() throws {
        let csv = """
        sofifa_id,short_name,long_name,player_positions,overall,pace,shooting,passing,dribbling,defending,physic,goalkeeping_diving,goalkeeping_handling,goalkeeping_kicking,goalkeeping_reflexes,goalkeeping_speed,goalkeeping_positioning,club_name,nationality_name
        1,K. De Bruyne,Kevin De Bruyne,"CM, CAM",91,76,86,93,88,64,78,15,13,5,10,,13,Manchester City,Belgium
        2,Alisson,Alisson Ramses Becker,GK,89,,,,,,,86,85,85,89,54,90,Liverpool,Brazil
        3,,Nameless,ST,70,70,70,70,70,70,70,,,,,,,X,Y
        4,Half Data,Half Data,ST,70,70,,70,70,70,70,,,,,,,X,Y
        """
        let r = try PlayerImporter.load(csv: csv)
        #expect(r.players.map(\.name) == ["K. De Bruyne", "Alisson"])
        #expect(r.skippedRows == 2)
        #expect(r.players[0].era == .imported)
        #expect(r.players[1].isKeeper)
        #expect(r.players[1].traits == [86, 85, 85, 89, 54, 90])
        #expect(r.players[1].club == "Liverpool")
    }

    @Test func missingColumnsAreReported() {
        #expect(throws: ImportError.missingColumn("name")) { try PlayerImporter.load(csv: "foo,bar\n1,2") }
        #expect(throws: ImportError.missingColumn("shooting")) {
            try PlayerImporter.load(csv: "name,position,pace\nA,ST,80")
        }
        #expect(throws: ImportError.empty) { try PlayerImporter.load(csv: "") }
    }

    @Test func genderColumnAndAliases() throws {
        let csv = """
        name,position,pace,shooting,passing,dribbling,defending,physical,sex
        A,ST,80,80,80,80,40,70,Female
        B,ST,80,80,80,80,40,70,M
        C,ST,80,80,80,80,40,70,
        """
        let r = try PlayerImporter.load(csv: csv)
        #expect(r.players.map(\.gender) == [.women, .men, nil])
    }

    @Test func bundledDatasetLoads() {
        let players = BundledPlayers.load()
        #expect(players.count >= 150)
        #expect(Set(players.map(\.group)) == Set(PositionGroup.allCases))
        #expect(players.contains { $0.era == .legend })
        #expect(players.allSatisfy { $0.gender != nil })
        #expect(players.filter { $0.gender == .women }.count >= 40)
    }
}

@Suite struct QuizTests {
    @Test func questionIDsAreUnique() {
        #expect(Set(Quiz.questions.map(\.id)).count == Quiz.questions.count)
        #expect(Quiz.questions.allSatisfy { $0.options.count >= 2 })
    }

    @Test func profileIsScaledAndPositionsSumToOne() {
        let answers = Dictionary(uniqueKeysWithValues: Quiz.questions.map { ($0.id, 0) })
        let p = Quiz.profile(from: answers)
        #expect(p.traits.max() == 1)
        #expect(p.traits.min() == 0)
        #expect(abs(p.positions.values.reduce(0, +) - 1) < 1e-9)
    }

    @Test func emptyAnswersGiveNeutralProfile() {
        let p = Quiz.profile(from: [:])
        #expect(p.traits.allSatisfy { $0 == 0.5 })
        #expect(p.positions.count == 4)
    }

    @Test func profileRoundTripsThroughJSON() throws {
        let p = Profile(traits: [1, 0, 0.5, 0.2, 0.3, 0.4], positions: [.forward: 0.75, .midfielder: 0.25])
        let data = try JSONEncoder().encode(p)
        #expect(String(decoding: data, as: UTF8.self).contains("\"forward\""))
        #expect(try JSONDecoder().decode(Profile.self, from: data) == p)
    }
}

@Suite struct MatcherTests {
    let poacher = Player(name: "Poacher", positions: ["ST"], era: .current, overall: 85, traits: [88, 92, 70, 80, 35, 78])
    let regista = Player(name: "Regista", positions: ["CDM"], era: .legend, overall: 85, traits: [55, 70, 93, 82, 75, 68])
    let stopper = Player(name: "Stopper", positions: ["CB"], era: .current, overall: 85, traits: [70, 40, 65, 62, 90, 86])
    let keeper = Player(name: "Keeper", positions: ["GK"], era: .current, overall: 85, traits: [88, 85, 80, 90, 50, 88])
    var all: [Player] { [poacher, regista, stopper, keeper] }

    func answers(_ picks: [String: Int]) -> Profile { Quiz.profile(from: picks) }

    @Test func strikerAnswersFindTheStriker() {
        let p = answers(["pitch": 0, "ball": 2, "weapon": 1, "goal": 2, "pressure": 0, "role": 2])
        #expect(Matcher.rank(p, against: all).first?.player.name == "Poacher")
    }

    @Test func playmakerAnswersFindTheRegista() {
        let p = answers(["pitch": 1, "ball": 1, "weapon": 2, "goal": 4, "style": 1, "role": 0])
        let top = Matcher.rank(p, against: all).first
        #expect(top?.player.name == "Regista")
        #expect(top?.sharedStrengths.contains(.passing) == true)
    }

    @Test func defenderAnswersFindTheStopper() {
        let p = answers(["pitch": 2, "weapon": 4, "duel": 0, "style": 2, "role": 1])
        #expect(Matcher.rank(p, against: all).first?.player.name == "Stopper")
    }

    @Test func keeperAnswersFindTheKeeper() {
        let p = answers(["pitch": 3, "duel": 2, "pressure": 3, "role": 3])
        #expect(Matcher.rank(p, against: all).first?.player.name == "Keeper")
    }

    @Test func filterAndLimit() {
        let p = answers(["pitch": 1])
        let currentOnly = Matcher.rank(p, against: all, filter: MatchFilter(eras: [.current]), limit: 10)
        #expect(!currentOnly.contains { $0.player.era == .legend })
        #expect(Matcher.rank(p, against: all, filter: MatchFilter(minimumOverall: 90)).isEmpty)
        #expect(Matcher.rank(p, against: all, limit: 2).count == 2)
        let mixed = [poacher, Player(name: "Her", positions: ["ST"], era: .current, overall: 85,
                                     traits: [88, 92, 70, 80, 35, 78], gender: .women)]
        let women = Matcher.rank(p, against: mixed, filter: MatchFilter(gender: .women), limit: 10)
        #expect(women.map(\.player.name) == ["Her"])  // poacher has no gender, so it's left out
        #expect(Matcher.rank(p, against: mixed, limit: 10).count == 2)
        #expect(Matcher.rank(p, against: all, limit: 10).allSatisfy { (0...100).contains($0.score) })
    }
}

@Suite struct ResponseTests {
    func sample(_ name: String, top: String, pitch: Int) -> QuizResponse {
        let profile = Quiz.profile(from: ["pitch": pitch])
        let player = Player(name: top, club: "FC", positions: ["ST"], era: .current, overall: 80, traits: [1, 2, 3, 4, 5, 6])
        return QuizResponse(name: name, answers: ["pitch": pitch], profile: profile,
                            matches: [Match(player: player, score: 90, sharedStrengths: [])])
    }

    @Test func storePersistsAndDeletes() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("r.json")
        let store = ResponseStore(url: url)
        let a = sample("Ana", top: "X", pitch: 0)
        try store.add(a)
        try store.add(sample("", top: "Y", pitch: 1))
        #expect(ResponseStore(url: url).responses.count == 2)
        try store.delete(ids: [a.id])
        let reloaded = ResponseStore(url: url)
        #expect(reloaded.responses.map(\.displayName) == ["Anonymous"])
    }

    @Test func summaryCountsTopMatches() {
        let s = ResponseSummary([sample("a", top: "X", pitch: 0), sample("b", top: "X", pitch: 0), sample("c", top: "Y", pitch: 2)])
        #expect(s.total == 3)
        #expect(s.topPlayers.first == .init(name: "X", count: 2))
        #expect(s.positions[.forward] == 2)
        #expect(s.positions[.defender] == 1)
    }

    @Test func csvExportEscapes() {
        let csv = ResponseExporter.csv([sample("Smith, \"Jo\"", top: "X", pitch: 0)])
        let rows = CSVParser.parse(csv)
        #expect(rows.count == 2)
        #expect(rows[1][1] == "Smith, \"Jo\"")
        #expect(rows[1][2] == "X")
        #expect(rows[0].count == rows[1].count)
    }
}
