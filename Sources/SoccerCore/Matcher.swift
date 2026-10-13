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
    /// Nil matches everyone. Set to one game, it leaves out players whose gender isn't known.
    public var gender: Gender?

    public init(minimumOverall: Int = 0, eras: Set<Era> = Set(Era.allCases), gender: Gender? = nil) {
        self.minimumOverall = minimumOverall
        self.eras = eras
        self.gender = gender
    }

    public func allows(_ player: Player) -> Bool {
        player.overall >= minimumOverall && eras.contains(player.era) && (gender == nil || player.gender == gender)
    }
}

public enum Matcher {
    static let shapeWeight = 0.60
    static let positionWeight = 0.35
    static let fameWeight = 0.05
    /// How much a player's alternative positions count next to their best one.
    static let alternativePositionWeight = 0.7

    /// Keeper cards hold Diving, Handling, Kicking, Reflexes, Speed, Positioning in the six slots.
    /// This says which of a person's traits stands in for each keeper slot.
    public static let keeperSource: [Trait] = [.pace, .defending, .passing, .dribbling, .pace, .physical]

    public static func rank(_ profile: Profile, against players: [Player],
                            filter: MatchFilter = MatchFilter(), limit: Int = 5) -> [Match] {
        let candidates = players.filter(filter.allows)
        let bestShare = profile.positions.values.max() ?? 1
        let keepers = KeeperScale(players.filter(\.isKeeper))
        var scored: [(player: Player, score: Double)] = []
        for player in candidates {
            scored.append((player, score(profile, player, bestShare: bestShare, keepers: keepers)))
        }
        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.player.name < $1.player.name }
        return scored.prefix(limit).map { item in
            Match(player: item.player, score: Int((item.score * 100).rounded()),
                  sharedStrengths: sharedStrengths(profile, item.player))
        }
    }

    /// 0–1 fit: mostly trait shape, then position, with a small nudge towards better-known players.
    static func score(_ profile: Profile, _ player: Player, bestShare: Double, keepers: KeeperScale) -> Double {
        let personShape: [Double] = player.isKeeper ? keeperSource.map { profile.value($0) } : profile.traits
        let playerShape: [Double] = player.isKeeper ? keepers.scaled(player) : player.traits.map { Double($0) }
        let shape: Double = (cosine(centered(personShape), centered(playerShape)) + 1) / 2
        let position = positionFit(profile, player, bestShare: bestShare)
        let fame: Double = Double(max(0, player.overall - 40)) / 59
        return shapeWeight * shape + positionWeight * position + fameWeight * fame
    }

    /// How well the player's positions suit where the person plays: the best position counts in full,
    /// alternatives at `alternativePositionWeight`. Squared so the position people lean towards clearly beats a close second.
    static func positionFit(_ profile: Profile, _ player: Player, bestShare: Double) -> Double {
        guard bestShare > 0 else { return 0 }
        var fit = 0.0
        for (i, code) in player.positions.enumerated() {
            guard let group = PositionGroup.of(position: code) else { continue }
            let relative = (profile.positions[group] ?? 0) / bestShare
            fit = max(fit, (i == 0 ? 1 : alternativePositionWeight) * relative * relative)
        }
        return fit
    }

    /// Every keeper card has a low Speed and high everything else, so raw keeper shapes are nearly identical.
    /// Comparing each keeper stat with the other keepers' (a z-score) brings out what makes each keeper different.
    struct KeeperScale {
        var means: [Double] = []
        var deviations: [Double] = []

        init(_ keepers: [Player]) {
            guard keepers.count >= 2 else { return }
            for i in Trait.allCases.indices {
                let values = keepers.map { Double($0.traits[i]) }
                let mean = values.reduce(0, +) / Double(values.count)
                var squares = 0.0
                for v in values { squares += (v - mean) * (v - mean) }
                let sd = (squares / Double(values.count)).squareRoot()
                means.append(mean)
                deviations.append(sd > 0 ? sd : 1)
            }
        }

        func scaled(_ player: Player) -> [Double] {
            guard !means.isEmpty else { return player.traits.map { Double($0) } }
            return player.traits.indices.map { (Double(player.traits[$0]) - means[$0]) / deviations[$0] }
        }
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
