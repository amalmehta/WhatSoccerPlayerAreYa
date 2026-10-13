import Foundation
import Testing
@testable import SoccerCore

/// Writes the quiz and a set of worked matches to Tests/Fixtures/parity.json.
/// The website's tests (web/tests) check their JavaScript port against this file,
/// so the Mac app and the website always give the same answers.
/// Regenerate after changing the quiz or matcher: WSPAY_WRITE_FIXTURE=1 swift test --filter Parity
@Suite struct ParityTests {
    static let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/parity.json")

    static func traitKey(_ t: SoccerCore.Trait) -> String { t.name.lowercased() }

    static func fixture() -> [String: Any] {
        let questions: [[String: Any]] = Quiz.questions.map { q in
            [
                "id": q.id, "kind": q.kind.rawValue, "prompt": q.prompt,
                "options": q.options.map { o in
                    [
                        "text": o.text,
                        "traits": Dictionary(uniqueKeysWithValues: o.traits.map { (traitKey($0.key), $0.value) }),
                        "positions": Dictionary(uniqueKeysWithValues: o.positions.map { ($0.key.rawValue, $0.value) }),
                    ] as [String: Any]
                },
            ]
        }

        let players = BundledPlayers.load()
        let filters: [(MatchFilter, String)] = [
            (MatchFilter(minimumOverall: 75), "default"),
            (MatchFilter(minimumOverall: 75, gender: .women), "women"),
            (MatchFilter(minimumOverall: 75, gender: .men), "men"),
            (MatchFilter(minimumOverall: 0, eras: [.legend]), "legends"),
        ]
        var cases: [[String: Any]] = []
        for seed in 0..<40 {
            var answers: [String: Int] = [:]
            for (i, q) in Quiz.questions.enumerated() where (seed + i) % 9 != 0 {
                answers[q.id] = (seed * 7 + i * 3 + seed / 5) % q.options.count
            }
            let (filter, label) = filters[seed % filters.count]
            let profile = Quiz.profile(from: answers)
            let matches = Matcher.rank(profile, against: players, filter: filter, limit: 5)
            cases.append([
                "answers": answers,
                "filter": [
                    "label": label,
                    "minimumOverall": filter.minimumOverall,
                    "eras": filter.eras.map(\.rawValue).sorted(),
                    "gender": filter.gender?.rawValue ?? "All",
                ] as [String: Any],
                "profile": [
                    "traits": profile.traits,
                    "positions": Dictionary(uniqueKeysWithValues: profile.positions.map { ($0.key.rawValue, $0.value) }),
                ] as [String: Any],
                "matches": matches.map { ["name": $0.player.name, "score": $0.score,
                                          "shared": $0.sharedStrengths.map { Self.traitKey($0) }] as [String: Any] },
            ])
        }
        return ["questions": questions, "cases": cases]
    }

    @Test func fixtureIsCurrent() throws {
        let data = try JSONSerialization.data(withJSONObject: Self.fixture(), options: [.prettyPrinted, .sortedKeys])
        if ProcessInfo.processInfo.environment["WSPAY_WRITE_FIXTURE"] == "1" {
            try data.write(to: Self.fixtureURL)
        }
        let saved = try Data(contentsOf: Self.fixtureURL)
        let a = try JSONSerialization.jsonObject(with: saved) as! NSDictionary
        let b = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        #expect(a == b, "Tests/Fixtures/parity.json is stale. Regenerate it with WSPAY_WRITE_FIXTURE=1 swift test --filter Parity")
    }
}
