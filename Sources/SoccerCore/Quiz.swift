import Foundation

public struct QuizOption: Sendable, Hashable {
    public var text: String
    /// How much this answer nudges each trait (any scale; only the shape matters).
    public var traits: [Trait: Double]
    /// How much this answer points to each part of the pitch.
    public var positions: [PositionGroup: Double]

    public init(_ text: String, traits: [Trait: Double] = [:], positions: [PositionGroup: Double] = [:]) {
        self.text = text
        self.traits = traits
        self.positions = positions
    }
}

public struct QuizQuestion: Identifiable, Sendable, Hashable {
    public enum Kind: String, Sendable { case style = "Playing style", personality = "Personality" }
    public var id: String
    public var kind: Kind
    public var prompt: String
    public var options: [QuizOption]
}

/// What the quiz learned about someone: a trait shape and where on the pitch they belong.
public struct Profile: Codable, Hashable, Sendable {
    /// One value per `Trait`, scaled so the strongest trait is 1 and the weakest 0.
    public var traits: [Double]
    /// Share of answers pointing at each position group; sums to 1.
    public var positions: [PositionGroup: Double]

    public init(traits: [Double], positions: [PositionGroup: Double]) {
        self.traits = traits
        self.positions = positions
    }

    public var topPosition: PositionGroup {
        PositionGroup.allCases.max { (positions[$0] ?? 0) < (positions[$1] ?? 0) } ?? .midfielder
    }

    public func value(_ trait: Trait) -> Double { traits[trait.rawValue] }
}

public enum Quiz {
    public static let questions: [QuizQuestion] = [
        QuizQuestion(id: "pitch", kind: .style, prompt: "Five-a-side with friends. Where do you end up?", options: [
            QuizOption("Up front, waiting for the ball", traits: [.shooting: 2], positions: [.forward: 3]),
            QuizOption("In the middle, touching it every play", traits: [.passing: 2], positions: [.midfielder: 3]),
            QuizOption("At the back, keeping it tight", traits: [.defending: 2], positions: [.defender: 3]),
            QuizOption("In goal — someone has to", traits: [.physical: 1], positions: [.goalkeeper: 4]),
        ]),
        QuizQuestion(id: "ball", kind: .style, prompt: "The ball comes to you in space. First thought?", options: [
            QuizOption("Run at them", traits: [.dribbling: 2, .pace: 1], positions: [.forward: 1]),
            QuizOption("Pick out the perfect pass", traits: [.passing: 3], positions: [.midfielder: 1]),
            QuizOption("Shoot from anywhere", traits: [.shooting: 3], positions: [.forward: 1]),
            QuizOption("Keep it simple, recycle possession", traits: [.passing: 1, .defending: 1], positions: [.defender: 1, .midfielder: 1]),
        ]),
        QuizQuestion(id: "weapon", kind: .style, prompt: "Pick your superpower.", options: [
            QuizOption("Blistering speed", traits: [.pace: 3]),
            QuizOption("Ice-cold finishing", traits: [.shooting: 3]),
            QuizOption("Seeing passes no one else sees", traits: [.passing: 3]),
            QuizOption("Ball glued to your feet", traits: [.dribbling: 3]),
            QuizOption("Reading the game, winning it back", traits: [.defending: 3]),
            QuizOption("Strength nobody can move", traits: [.physical: 3]),
        ]),
        QuizQuestion(id: "duel", kind: .style, prompt: "A big striker is bearing down on you. You…", options: [
            QuizOption("Time the slide tackle perfectly", traits: [.defending: 3], positions: [.defender: 2]),
            QuizOption("Body them off the ball", traits: [.physical: 3], positions: [.defender: 1]),
            QuizOption("Narrow the angle and spread yourself big", traits: [.physical: 1, .defending: 1], positions: [.goalkeeper: 2]),
            QuizOption("Honestly? Hope someone else deals with it", traits: [.shooting: 1, .dribbling: 1], positions: [.forward: 2]),
        ]),
        QuizQuestion(id: "goal", kind: .style, prompt: "Your dream goal looks like…", options: [
            QuizOption("A 40-yard screamer into the top corner", traits: [.shooting: 3, .physical: 1]),
            QuizOption("Beating four players and slotting it home", traits: [.dribbling: 3, .pace: 1]),
            QuizOption("A tap-in after a perfect run", traits: [.shooting: 2, .pace: 1], positions: [.forward: 1]),
            QuizOption("A towering header from a corner", traits: [.physical: 3], positions: [.defender: 1]),
            QuizOption("I'd rather make the assist", traits: [.passing: 3], positions: [.midfielder: 1]),
        ]),
        QuizQuestion(id: "fitness", kind: .style, prompt: "Pre-season fitness tests. You're best at…", options: [
            QuizOption("The sprints", traits: [.pace: 3]),
            QuizOption("The long runs — I never stop", traits: [.physical: 2, .defending: 1], positions: [.midfielder: 1]),
            QuizOption("The gym — lifting heavy", traits: [.physical: 3]),
            QuizOption("The agility ladders", traits: [.dribbling: 2, .pace: 1]),
        ]),
        QuizQuestion(id: "captain", kind: .personality, prompt: "In the dressing room, you're the one who…", options: [
            QuizOption("Gives the team talk", traits: [.defending: 2, .physical: 1], positions: [.defender: 1]),
            QuizOption("Controls the music and the mood", traits: [.dribbling: 2], positions: [.forward: 1]),
            QuizOption("Studies the opponent on a tablet", traits: [.passing: 2, .defending: 1], positions: [.midfielder: 1]),
            QuizOption("Sits quietly, headphones on, focused", traits: [.shooting: 2], positions: [.goalkeeper: 1, .forward: 1]),
        ]),
        QuizQuestion(id: "pressure", kind: .personality, prompt: "Last minute, penalty to win the final. You…", options: [
            QuizOption("Grab the ball — it's mine", traits: [.shooting: 3]),
            QuizOption("Chip it down the middle, cheeky", traits: [.dribbling: 2, .shooting: 1]),
            QuizOption("Let the designated taker do it and organise the rebound", traits: [.defending: 1, .passing: 1], positions: [.defender: 1, .midfielder: 1]),
            QuizOption("Wish I was the keeper facing it", traits: [.physical: 1], positions: [.goalkeeper: 3]),
        ]),
        QuizQuestion(id: "style", kind: .personality, prompt: "How would your friends describe you?", options: [
            QuizOption("A showman — style matters", traits: [.dribbling: 3]),
            QuizOption("The brains of the group", traits: [.passing: 3]),
            QuizOption("Reliable, steady, always there", traits: [.defending: 3]),
            QuizOption("Competitive to a fault", traits: [.physical: 2, .shooting: 1]),
            QuizOption("Always in a hurry", traits: [.pace: 3]),
        ]),
        QuizQuestion(id: "loss", kind: .personality, prompt: "After a loss, you…", options: [
            QuizOption("Hit the gym that night", traits: [.physical: 3]),
            QuizOption("Rewatch the match and analyse it", traits: [.passing: 2, .defending: 1]),
            QuizOption("Shake it off — next game I'll score two", traits: [.shooting: 2, .pace: 1]),
            QuizOption("Blame the defence (quietly)", traits: [.dribbling: 1, .shooting: 1], positions: [.forward: 1]),
        ]),
        QuizQuestion(id: "weekend", kind: .personality, prompt: "Perfect day off?", options: [
            QuizOption("Chess, puzzles or a strategy game", traits: [.passing: 3], positions: [.midfielder: 1]),
            QuizOption("Freestyle tricks in the park", traits: [.dribbling: 3]),
            QuizOption("A long run or a hike", traits: [.physical: 2, .pace: 1]),
            QuizOption("Racing anything — karts, bikes, friends", traits: [.pace: 3]),
            QuizOption("Rest. Recovery is training too", traits: [.defending: 2], positions: [.goalkeeper: 1, .defender: 1]),
        ]),
        QuizQuestion(id: "role", kind: .personality, prompt: "Which job sounds most like you?", options: [
            QuizOption("Architect — designing how it all fits", traits: [.passing: 3], positions: [.midfielder: 2]),
            QuizOption("Bodyguard — nobody gets past", traits: [.defending: 3, .physical: 1], positions: [.defender: 2]),
            QuizOption("Rock star — centre of the show", traits: [.dribbling: 2, .shooting: 2], positions: [.forward: 2]),
            QuizOption("Air-traffic controller — calm while chaos happens", traits: [.physical: 1, .passing: 1], positions: [.goalkeeper: 2]),
        ]),
    ]

    /// Builds a profile from answers keyed by question id (value = chosen option index).
    /// Unanswered or out-of-range answers are ignored.
    public static func profile(from answers: [String: Int], questions: [QuizQuestion] = questions) -> Profile {
        var traits = Array(repeating: 0.0, count: Trait.allCases.count)
        var positions: [PositionGroup: Double] = [:]
        for question in questions {
            guard let index = answers[question.id], question.options.indices.contains(index) else { continue }
            let option = question.options[index]
            for (trait, amount) in option.traits { traits[trait.rawValue] += amount }
            for (group, amount) in option.positions { positions[group, default: 0] += amount }
        }
        let low = traits.min() ?? 0, high = traits.max() ?? 0
        let scaled = high > low ? traits.map { ($0 - low) / (high - low) } : traits.map { _ in 0.5 }
        let total = positions.values.reduce(0, +)
        let shares = total > 0
            ? positions.mapValues { $0 / total }
            : Dictionary(uniqueKeysWithValues: PositionGroup.allCases.map { ($0, 0.25) })
        return Profile(traits: scaled, positions: shares)
    }
}
