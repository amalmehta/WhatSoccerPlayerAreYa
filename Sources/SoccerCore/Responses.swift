import Foundation

/// One completed quiz.
public struct QuizResponse: Identifiable, Codable, Hashable, Sendable {
    public struct MatchSummary: Codable, Hashable, Sendable {
        public var name: String
        public var club: String
        public var positions: [String]
        public var score: Int
    }

    public var id: UUID
    public var date: Date
    public var name: String
    public var answers: [String: Int]
    public var profile: Profile
    public var matches: [MatchSummary]

    public init(id: UUID = UUID(), date: Date = Date(), name: String, answers: [String: Int],
                profile: Profile, matches: [Match]) {
        self.id = id
        self.date = date
        self.name = name
        self.answers = answers
        self.profile = profile
        self.matches = matches.map {
            MatchSummary(name: $0.player.name, club: $0.player.club, positions: $0.player.positions, score: $0.score)
        }
    }

    public var displayName: String { name.isEmpty ? "Anonymous" : name }
    public var topMatch: MatchSummary? { matches.first }
}

/// Saved responses, kept as one JSON file.
public final class ResponseStore {
    public let url: URL
    public private(set) var responses: [QuizResponse] = []

    public init(url: URL) {
        self.url = url
        if let data = try? Data(contentsOf: url),
           let decoded = try? Self.decoder.decode([QuizResponse].self, from: data) {
            responses = decoded
        }
    }

    public func add(_ response: QuizResponse) throws {
        responses.append(response)
        try save()
    }

    public func delete(ids: Set<UUID>) throws {
        responses.removeAll { ids.contains($0.id) }
        try save()
    }

    public func removeAll() throws {
        responses = []
        try save()
    }

    func save() throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder.encode(responses).write(to: url, options: .atomic)
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

/// Totals across many responses, for the Results screen.
public struct ResponseSummary: Sendable {
    public struct Count: Identifiable, Sendable, Hashable {
        public var id: String { name }
        public var name: String
        public var count: Int
    }

    public var total: Int
    /// Top-match players, most frequent first.
    public var topPlayers: [Count]
    /// Average profile value per trait (0–1), in `Trait` order.
    public var averageTraits: [Double]
    /// How many people's strongest position was each group.
    public var positions: [PositionGroup: Int]

    public init(_ responses: [QuizResponse]) {
        total = responses.count
        var counts: [String: Int] = [:]
        for r in responses { if let top = r.topMatch { counts[top.name, default: 0] += 1 } }
        topPlayers = counts.map { Count(name: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
        averageTraits = Trait.allCases.map { trait in
            responses.isEmpty ? 0 : responses.map { $0.profile.value(trait) }.reduce(0, +) / Double(responses.count)
        }
        var groups: [PositionGroup: Int] = [:]
        for r in responses { groups[r.profile.topPosition, default: 0] += 1 }
        positions = groups
    }
}

public enum ResponseExporter {
    public static func csv(_ responses: [QuizResponse], questions: [QuizQuestion] = Quiz.questions) -> String {
        var header = ["Date", "Name", "Top Match", "Club", "Score", "Runners-Up", "Top Position"]
        header += Trait.allCases.map(\.name)
        header += questions.map(\.prompt)
        let formatter = ISO8601DateFormatter()
        var lines = [header.map(escape).joined(separator: ",")]
        for r in responses.sorted(by: { $0.date < $1.date }) {
            var fields = [
                formatter.string(from: r.date), r.displayName,
                r.topMatch?.name ?? "", r.topMatch?.club ?? "", r.topMatch.map { String($0.score) } ?? "",
                r.matches.dropFirst().map(\.name).joined(separator: "; "),
                r.profile.topPosition.name,
            ]
            fields += Trait.allCases.map { String(format: "%.2f", r.profile.value($0)) }
            fields += questions.map { q in
                r.answers[q.id].flatMap { q.options.indices.contains($0) ? q.options[$0].text : nil } ?? ""
            }
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func escape(_ s: String) -> String {
        s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" })
            ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            : s
    }
}
