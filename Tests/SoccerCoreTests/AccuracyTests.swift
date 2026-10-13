import Foundation
import Testing
@testable import SoccerCore

/// Guards matching quality, measured rather than assumed.
/// Tests/Fixtures/personas.json holds how 30 well-known players would answer the quiz.
@Suite struct AccuracyTests {
    static let players = BundledPlayers.load()
    static let filter = MatchFilter(minimumOverall: 75)

    static func personas() throws -> [String: [String: Int]] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/personas.json")
        return try JSONDecoder().decode([String: [String: Int]].self, from: Data(contentsOf: url))
    }

    /// Deterministic stand-in for random answers.
    static func answerSets(_ count: Int) -> [[String: Int]] {
        var state: UInt64 = 42
        func next(_ n: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 33) % UInt64(n))
        }
        return (0..<count).map { _ in Dictionary(uniqueKeysWithValues: Quiz.questions.map { ($0.id, next($0.options.count)) }) }
    }

    @Test func personasFindTheirPlayer() throws {
        var ranks: [Int] = []
        for (name, answers) in try Self.personas() {
            let ranked = Matcher.rank(Quiz.profile(from: answers), against: Self.players, filter: Self.filter, limit: 1000)
            let rank = try #require(ranked.firstIndex { $0.player.name == name }, "\(name) isn't in the bundled players") + 1
            ranks.append(rank)
        }
        ranks.sort()
        let topTen = ranks.filter { $0 <= 10 }.count
        // Measured 2026-10-13 on EA FC 27 data: 14 of 30 in the top 10, median rank 13.
        #expect(topTen >= 12, "only \(topTen) of 30 personas have their player in the top 10")
        #expect(ranks[ranks.count / 2] <= 16, "median rank \(ranks[ranks.count / 2])")
    }

    @Test func noPositionWinsByDefault() {
        var counts: [PositionGroup: Int] = [:]
        let sets = Self.answerSets(4000)
        for answers in sets { counts[Quiz.profile(from: answers).topPosition, default: 0] += 1 }
        for group in PositionGroup.allCases {
            let share = Double(counts[group] ?? 0) / Double(sets.count)
            #expect((0.18...0.32).contains(share), "\(group.name) wins \(Int(share * 100))% of random quizzes")
        }
    }

    @Test func traitsCanAllScoreSimilarly() {
        let maxima = Trait.allCases.map { trait in
            Quiz.questions.map { q in q.options.map { $0.traits[trait] ?? 0 }.max() ?? 0 }.reduce(0, +)
        }
        #expect((maxima.min() ?? 0) >= 0.8 * (maxima.max() ?? 1), "trait maxima \(maxima)")
    }

    @Test func keeperAnswersGetKeepers() {
        var keeperLed = 0, keeperMatched = 0
        for answers in Self.answerSets(4000) {
            let profile = Quiz.profile(from: answers)
            let best = profile.positions.values.max() ?? 0
            guard profile.positions[.goalkeeper] == best, profile.positions.values.filter({ $0 == best }).count == 1 else { continue }
            keeperLed += 1
            if Matcher.rank(profile, against: Self.players, filter: Self.filter, limit: 1).first?.player.isKeeper == true { keeperMatched += 1 }
        }
        // Measured 99.5% after comparing keepers with other keepers (it was 76%).
        #expect(Double(keeperMatched) >= 0.95 * Double(keeperLed), "\(keeperMatched) of \(keeperLed)")
    }
}
