import Foundation

public struct Match: Identifiable, Hashable, Sendable {
    public var id: String { player.id }
    public var player: Player
    /// 0–100: how closely the player fits the profile.
    public var score: Int
    /// Traits that stand out for both the person and the player.
    public var sharedStrengths: [Trait]
}

public struct MatchFilter: Sendable, Equatable {
    public var minimumOverall: Int
    public var eras: Set<Era>

    public init(minimumOverall: Int = 0, eras: Set<Era> = Set(Era.allCases)) {
        self.minimumOverall = minimumOverall
        self.eras = eras
    }
}

public enum Matcher {
    static let shapeWeight = 0.60
    static let positionWeight = 0.35
    static let fameWeight = 0.05

    /// Keeper cards hold Diving, Handling, Kicking, Reflexes, Speed, Positioning in the six slots.
    /// This says which of a person's traits stands in for each keeper slot.
    public static let keeperSource: [Trait] = [.pace, .defending, .passing, .dribbling, .pace, .physical]

    public static func rank(_ profile: Profile, against players: [Player],
                            filter: MatchFilter = MatchFilter(), limit: Int = 5) -> [Match] {
        let candidates = players.filter { $0.overall >= filter.minimumOverall && filter.eras.contains($0.era) }
        let bestShare = profile.positions.values.max() ?? 1
        var scored: [(player: Player, score: Double)] = []
        for player in candidates {
            scored.append((player, score(profile, player, bestShare: bestShare)))
        }
        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.player.name < $1.player.name }
        return scored.prefix(limit).map { item in
            Match(player: item.player, score: Int((item.score * 100).rounded()),
                  sharedStrengths: sharedStrengths(profile, item.player))
        }
    }

    /// 0–1 fit: mostly trait shape, then position, with a small nudge towards better-known players.
    static func score(_ profile: Profile, _ player: Player, bestShare: Double) -> Double {
        let personShape: [Double] = player.isKeeper ? keeperSource.map { profile.value($0) } : profile.traits
        let playerShape: [Double] = player.traits.map { Double($0) }
        let shape: Double = (cosine(centered(personShape), centered(playerShape)) + 1) / 2
        let share: Double = profile.positions[player.group] ?? 0
        let relative: Double = bestShare > 0 ? share / bestShare : 0
        // Squared so the position people lean towards clearly beats a close second.
        let position: Double = relative * relative
        let fame: Double = Double(max(0, player.overall - 40)) / 59
        return shapeWeight * shape + positionWeight * position + fameWeight * fame
    }

    static func sharedStrengths(_ profile: Profile, _ player: Player) -> [Trait] {
        guard !player.isKeeper else { return [] }
        let mine = Trait.allCases.sorted { profile.value($0) > profile.value($1) }.prefix(3)
        let theirs = Set(Trait.allCases.sorted { player.value($0) > player.value($1) }.prefix(3))
        return mine.filter(theirs.contains)
    }

    static func centered(_ v: [Double]) -> [Double] {
        let mean = v.reduce(0, +) / Double(v.count)
        return v.map { $0 - mean }
    }

    static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        var dot = 0.0, na = 0.0, nb = 0.0
        for (x, y) in zip(a, b) { dot += x * y; na += x * x; nb += y * y }
        let norms = sqrt(na) * sqrt(nb)
        return norms > 0 ? dot / norms : 0
    }
}
