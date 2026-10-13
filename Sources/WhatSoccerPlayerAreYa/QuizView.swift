import SoccerCore
import SwiftUI

struct QuizView: View {
    enum Stage: Equatable { case start, question(Int), result(QuizResponse.ID) }

    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.askForName) private var askForName = true
    @AppStorage(SettingsKey.gender) private var gender = "All"
    @State private var stage: Stage = .start
    @State private var name = ""
    @State private var answers: [String: Int] = [:]
    @State private var result: (profile: Profile, matches: [Match])?

    private let questions = Quiz.questions

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                switch stage {
                case .start: start
                case .question(let index): question(index)
                case .result:
                    if let result {
                        ResultView(name: name, profile: result.profile, matches: result.matches, retake: restart)
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: showDemoResultIfAsked)
    }

    /// Screenshot helper: `-demoResult YES` opens on a result for a fixed set of answers, without saving it.
    private func showDemoResultIfAsked() {
        guard UserDefaults.standard.bool(forKey: "demoResult"), result == nil else { return }
        let demo = ["pitch": 0, "ball": 0, "weapon": 3, "duel": 3, "goal": 1, "fitness": 3,
                    "captain": 1, "pressure": 1, "style": 0, "loss": 2, "weekend": 1, "role": 2]
        let profile = Quiz.profile(from: demo)
        name = "Sam"
        result = (profile, model.rank(profile))
        stage = .result(UUID())
    }

    private var start: some View {
        VStack(spacing: 20) {
            Image(systemName: "soccerball")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .padding(.top, 40)
            Text("Which soccer player are you?")
                .font(.largeTitle.bold())
            Text("\(questions.count) quick questions about how you play and who you are. We'll match you against \(model.eligibleCount.formatted()) players.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if askForName {
                TextField("Your name (optional)", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
            }
            GenderPicker(selection: $gender, label: "Match me with")
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)
            Button {
                answers = [:]
                stage = .question(0)
            } label: {
                Text("Start the Quiz").font(.title3.weight(.semibold)).padding(.horizontal, 20).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(model.eligibleCount == 0)
            if model.eligibleCount == 0 {
                Text("No players match your Settings. Loosen the filters or import players.")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func question(_ index: Int) -> some View {
        let q = questions[index]
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Chip(text: q.kind.rawValue, color: q.kind == .style ? Palette.color(group: .forward) : Palette.color(group: .goalkeeper))
                Spacer()
                Text("Question \(index + 1) of \(questions.count)").foregroundStyle(.secondary)
            }
            ProgressView(value: Double(index), total: Double(questions.count))
            Text(q.prompt).font(.title.bold())
            VStack(spacing: 10) {
                ForEach(Array(q.options.enumerated()), id: \.offset) { optionIndex, option in
                    Button {
                        answers[q.id] = optionIndex
                        advance(from: index)
                    } label: {
                        HStack {
                            Text(option.text).font(.title3)
                            Spacer()
                            if answers[q.id] == optionIndex { Image(systemName: "checkmark.circle.fill") }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .background(.quaternary.opacity(answers[q.id] == optionIndex ? 1 : 0.5),
                                    in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(KeyEquivalent(Character(String(optionIndex + 1))), modifiers: [])
                }
            }
            HStack {
                Button("Back") { stage = index == 0 ? .start : .question(index - 1) }
                Spacer()
                Text("Tip: press 1–\(q.options.count) to answer").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    private func advance(from index: Int) {
        if index + 1 < questions.count {
            stage = .question(index + 1)
            return
        }
        let profile = Quiz.profile(from: answers)
        let matches = model.rank(profile)
        let response = QuizResponse(name: name.trimmingCharacters(in: .whitespaces), answers: answers,
                                    profile: profile, matches: matches)
        model.save(response)
        result = (profile, matches)
        stage = .result(response.id)
    }

    private func restart() {
        answers = [:]
        result = nil
        name = ""
        stage = .start
    }
}

struct ResultView: View {
    @Environment(AppModel.self) private var model
    var name: String
    var profile: Profile
    var matches: [Match]
    var retake: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let top = matches.first {
                VStack(alignment: .leading, spacing: 10) {
                    Text(name.isEmpty ? "You're most like" : "\(name), you're most like")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline) {
                        Text(top.player.name).font(.system(size: 44, weight: .bold))
                        Spacer()
                        Text("\(top.score)% match").font(.title2.weight(.semibold)).foregroundStyle(.tint)
                    }
                    HStack(spacing: 8) {
                        PositionChips(positions: top.player.positions)
                        Chip(text: top.player.era.rawValue, color: Palette.color(era: top.player.era))
                        Text([top.player.club, top.player.nationality].filter { !$0.isEmpty }.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    }
                    if !top.sharedStrengths.isEmpty {
                        Text("You both stand out for \(ListFormatter.localizedString(byJoining: top.sharedStrengths.map { $0.name.lowercased() })).")
                            .font(.title3)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))

                TraitComparison(profile: profile, player: top.player)

                if matches.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Also a lot like").font(.headline)
                        ForEach(matches.dropFirst()) { m in
                            HStack {
                                Text(m.player.name).fontWeight(.medium)
                                PositionChips(positions: Array(m.player.positions.prefix(2)))
                                Text(m.player.club).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(m.score)%").monospacedDigit().foregroundStyle(.secondary)
                            }
                            Divider()
                        }
                    }
                }
            } else {
                ContentUnavailableView("No players to match", systemImage: "person.slash",
                                       description: Text("Loosen the filters in Settings or import players."))
            }

            HStack {
                Button("Take It Again", action: retake).keyboardShortcut(.defaultAction)
                Button("See Everyone's Results") { model.section = .results }
            }
        }
    }
}

/// Side-by-side bars: the quiz-taker's trait shape against the matched player's.
struct TraitComparison: View {
    var profile: Profile
    var player: Player

    var body: some View {
        let values = player.traits.map(Double.init)
        let low = values.min() ?? 0, high = values.max() ?? 1
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your style vs \(player.name)").font(.headline)
                Spacer()
                Text("Bars show each side's relative strengths").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Trait.allCases) { trait in
                let mine = player.isKeeper ? profile.value(Matcher.keeperSource[trait.rawValue]) : profile.value(trait)
                let theirs = high > low ? (Double(player.value(trait)) - low) / (high - low) : 0.5
                HStack(spacing: 12) {
                    Text(player.traitName(trait)).frame(width: 90, alignment: .leading)
                    VStack(spacing: 3) {
                        bar(mine, color: Palette.color(trait: trait), label: "You")
                        bar(theirs, color: Palette.color(trait: trait).opacity(0.45), label: "\(player.value(trait))")
                    }
                }
            }
        }
    }

    private func bar(_ value: Double, color: Color, label: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary.opacity(0.4))
                    Capsule().fill(color).frame(width: max(8, geo.size.width * value))
                }
            }
            .frame(height: 12)
        }
    }
}
