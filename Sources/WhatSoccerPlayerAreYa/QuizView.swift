import SoccerCore
import SwiftUI

struct QuizView: View {
    enum Stage: Equatable { case start, question(Int), scouting, result }

    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.askForName) private var askForName = true
    @AppStorage(SettingsKey.gender) private var gender = "All"
    @State private var stage: Stage = .start
    @State private var name = ""
    @State private var answers: [String: Int] = [:]
    @State private var result: (profile: Profile, matches: [Match])?
    @State private var forward = true

    private let questions = Quiz.questions

    var body: some View {
        Group {
            switch stage {
            case .start: welcome
            case .question(let index): question(index)
            case .scouting: ScoutingView(playerCount: model.eligibleCount)
            case .result:
                if let result {
                    ResultView(name: name, profile: result.profile, matches: result.matches, retake: restart)
                }
            }
        }
        .animation(.smooth(duration: 0.35), value: stage)
        .onAppear(perform: showDemoResultIfAsked)
    }

    // MARK: Welcome

    private var welcome: some View {
        GeometryReader { geo in
            ZStack {
                PitchBackground()
                ScrollView {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .center, spacing: 48) {
                            welcomeText.frame(maxWidth: 520, alignment: .leading)
                            sampleCard
                        }
                        VStack(spacing: 32) {
                            welcomeText
                            sampleCard
                        }
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
            }
        }
        .foregroundStyle(.white)
    }

    private var welcomeText: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("⚽️  \(questions.count) questions · 2 minutes · \(model.eligibleCount.formatted()) players")
                .font(Theme.display(14, .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.white.opacity(0.15), in: Capsule())
            Text("Which soccer player are you?")
                .font(Theme.display(52))
                .fixedSize(horizontal: false, vertical: true)
            Text("Tell us how you play and who you are off the pitch. We'll scout every player and find the one who plays just like you.")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            if askForName {
                TextField("", text: $name, prompt: Text("Your name (optional)").foregroundStyle(.white.opacity(0.6)))
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(.white.opacity(0.14), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.3)))
                    .frame(maxWidth: 340)
                    .onSubmit(kickOff)
            }
            HStack(spacing: 8) {
                Text("Match me with").font(Theme.display(15, .semibold)).padding(.trailing, 4)
                ForEach([("All", "Everyone"), ("Men", "Men's"), ("Women", "Women's")], id: \.0) { value, label in
                    Button(label) { gender = value }
                        .buttonStyle(PillStyle(selected: gender == value))
                }
            }
            Button("Kick off  →", action: kickOff)
                .buttonStyle(GoldButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(model.eligibleCount == 0)
                .padding(.top, 6)
            if model.eligibleCount == 0 {
                Text("No players match your Settings. Loosen the filters or import players.")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Theme.gold)
            }
        }
    }

    private var sampleCard: some View {
        VStack(spacing: 14) {
            if let player = model.featuredPlayer {
                PlayerCard(player: player)
                    .rotationEffect(.degrees(-5))
                    .rotation3DEffect(.degrees(8), axis: (x: 0, y: 1, z: 0))
            }
            Text("Could this be you?")
                .font(Theme.display(15, .semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func kickOff() {
        guard model.eligibleCount > 0 else { return }
        answers = [:]
        forward = true
        stage = .question(0)
    }

    // MARK: Questions

    private func question(_ index: Int) -> some View {
        let q = questions[index]
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PitchProgress(step: index, total: questions.count)
                HStack {
                    Chip(text: q.kind.rawValue, color: q.kind == .style ? Theme.grass : Palette.color(group: .goalkeeper))
                    Spacer()
                    Text("Question \(index + 1) of \(questions.count)")
                        .font(Theme.display(14, .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(q.prompt)
                    .font(Theme.display(34))
                    .fixedSize(horizontal: false, vertical: true)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                    ForEach(Array(q.options.enumerated()), id: \.offset) { optionIndex, option in
                        AnswerCard(icon: AnswerIcons.icon(q.id, optionIndex), text: option.text, key: optionIndex + 1,
                                   chosen: answers[q.id] == optionIndex) {
                            answers[q.id] = optionIndex
                            advance(from: index)
                        }
                        .keyboardShortcut(KeyEquivalent(Character(String(optionIndex + 1))), modifiers: [])
                    }
                }
                HStack {
                    Button {
                        forward = false
                        stage = index == 0 ? .start : .question(index - 1)
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                    Text("Tip: press 1–\(q.options.count) to answer").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .padding(36)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
            .id(index)
            .transition(.asymmetric(
                insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                removal: .opacity))
        }
    }

    private func advance(from index: Int) {
        forward = true
        if index + 1 < questions.count {
            stage = .question(index + 1)
            return
        }
        let profile = Quiz.profile(from: answers)
        let matches = model.rank(profile)
        model.save(QuizResponse(name: name.trimmingCharacters(in: .whitespaces), answers: answers,
                                profile: profile, matches: matches))
        result = (profile, matches)
        stage = .scouting
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            if stage == .scouting { stage = .result }
        }
    }

    private func restart() {
        forward = false
        answers = [:]
        result = nil
        name = ""
        stage = .start
    }

    /// Screenshot helpers: `-demoResult YES` opens on a result for a fixed set of answers, without saving it;
    /// `-startQuestion 2` opens on that question.
    private func showDemoResultIfAsked() {
        if UserDefaults.standard.object(forKey: "startQuestion") != nil {
            stage = .question(min(questions.count - 1, max(0, UserDefaults.standard.integer(forKey: "startQuestion"))))
            return
        }
        guard UserDefaults.standard.bool(forKey: "demoResult"), result == nil else { return }
        let demo = ["pitch": 0, "ball": 0, "weapon": 3, "duel": 4, "goal": 1, "fitness": 3,
                    "captain": 1, "pressure": 1, "style": 0, "loss": 2, "weekend": 1, "role": 2]
        let profile = Quiz.profile(from: demo)
        name = "Sam"
        result = (profile, model.rank(profile))
        stage = .result
    }
}

/// The ball travels up the pitch towards the goal as you answer.
struct PitchProgress: View {
    var step: Int
    var total: Int

    var body: some View {
        GeometryReader { geo in
            let inset: CGFloat = 22
            let x = inset + (geo.size.width - 2 * inset - 28) * CGFloat(step) / CGFloat(max(1, total))
            ZStack(alignment: .leading) {
                Capsule().fill(LinearGradient(colors: [Theme.pitchTop, Theme.pitchBottom], startPoint: .leading, endPoint: .trailing))
                Path { p in
                    p.move(to: CGPoint(x: inset, y: geo.size.height / 2))
                    p.addLine(to: CGPoint(x: geo.size.width - inset, y: geo.size.height / 2))
                }
                .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                Capsule().fill(Theme.gold.opacity(0.55))
                    .frame(width: max(0, x - inset + 14), height: 4)
                    .offset(x: inset)
                Text("🥅").font(.system(size: 20)).offset(x: geo.size.width - inset - 14)
                Text("⚽️").font(.system(size: 22)).offset(x: x)
                    .animation(.spring(duration: 0.5, bounce: 0.35), value: step)
            }
        }
        .frame(height: 38)
    }
}

struct AnswerCard: View {
    var icon: String
    var text: String
    var key: Int
    var chosen: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(icon)
                    .font(.system(size: 26))
                    .frame(width: 52, height: 52)
                    .background(Theme.grass.opacity(0.14), in: Circle())
                Text(text)
                    .font(Theme.display(17, .semibold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Text("\(key)")
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.quaternary))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(chosen ? Theme.gold : (hovering ? Theme.grass.opacity(0.6) : Color.primary.opacity(0.1)),
                              lineWidth: chosen ? 3 : 1.5))
            .shadow(color: .black.opacity(hovering ? 0.12 : 0.05), radius: hovering ? 12 : 4, y: hovering ? 6 : 2)
            .scaleEffect(hovering ? 1.015 : 1)
            .animation(.spring(duration: 0.25), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// A short build-up before the reveal.
struct ScoutingView: View {
    var playerCount: Int
    @State private var spin = false
    @State private var line = 0

    private var lines: [String] {
        ["Checking your first touch…", "Timing your sprint…", "Studying your game…", "Comparing you with \(playerCount.formatted()) players…"]
    }

    var body: some View {
        ZStack {
            PitchBackground()
            VStack(spacing: 22) {
                Text("⚽️")
                    .font(.system(size: 72))
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spin)
                Text("Scouting your style")
                    .font(Theme.display(34))
                Text(lines[line % lines.count])
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))
                    .id(line)
                    .transition(.opacity)
            }
            .foregroundStyle(.white)
        }
        .onAppear { spin = true }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation { line += 1 }
            }
        }
    }
}

struct ResultView: View {
    @Environment(AppModel.self) private var model
    var name: String
    var profile: Profile
    var matches: [Match]
    var retake: () -> Void
    @State private var revealed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let top = matches.first {
                    hero(top)
                    VStack(alignment: .leading, spacing: 28) {
                        TraitComparison(profile: profile, player: top.player)
                        if matches.count > 1 { runnersUp }
                    }
                    .padding(36)
                    .frame(maxWidth: 900)
                } else {
                    ContentUnavailableView("No players to match", systemImage: "person.slash",
                                           description: Text("Loosen the filters in Settings or import players."))
                        .padding(60)
                    Button("Take It Again", action: retake)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.9, bounce: 0.3).delay(0.15)) { revealed = true }
        }
    }

    private func hero(_ top: Match) -> some View {
        ZStack {
            PitchBackground()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 44) {
                    card(top)
                    summary(top).frame(maxWidth: 440, alignment: .leading)
                }
                VStack(spacing: 28) {
                    card(top)
                    summary(top)
                }
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 36)
        }
        .foregroundStyle(.white)
    }

    private func card(_ top: Match) -> some View {
        PlayerCard(player: top.player)
            .rotation3DEffect(.degrees(revealed ? 0 : 90), axis: (x: 0, y: 1, z: 0))
            .scaleEffect(revealed ? 1 : 0.8)
            .opacity(revealed ? 1 : 0)
    }

    private func summary(_ top: Match) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(name.isEmpty ? "You play like" : "\(name), you play like")
                .font(Theme.display(20, .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(top.player.name)
                .font(Theme.display(46))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Text("\(top.score)% match")
                    .font(Theme.display(18, .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Theme.gold, in: Capsule())
                Text(top.player.era == .legend ? "Legend" : top.player.club)
                    .font(Theme.display(16, .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Text(why(top))
                .font(.title3)
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Take It Again", action: retake)
                    .buttonStyle(GoldButtonStyle())
                ShareLink(item: shareText(top)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(ChalkButtonStyle())
                Button("Everyone's Results") { model.section = .results }
                    .buttonStyle(ChalkButtonStyle())
            }
            .padding(.top, 6)
        }
    }

    /// The match explained in plain words.
    private func why(_ top: Match) -> String {
        let player = top.player
        let first = player.name.split(separator: " ").last.map(String.init) ?? player.name
        let place: String = switch profile.topPosition {
        case .forward: "up front"
        case .midfielder: "in midfield"
        case .defender: "at the back"
        case .goalkeeper: "in goal"
        }
        if player.isKeeper {
            return "Like \(first), you're happiest \(place) — calm, brave and ready to organise everyone in front of you."
        }
        let strengths = top.sharedStrengths.map { $0.name.lowercased() }
        guard !strengths.isEmpty else {
            return "You and \(first) share the same balance of skills and you both belong \(place)."
        }
        return "Like \(first), your game is built on \(ListFormatter.localizedString(byJoining: strengths)) — and you both belong \(place)."
    }

    private func shareText(_ top: Match) -> String {
        "I play like \(top.player.name) (\(top.score)% match) on What Soccer Player Are Ya! Which player are you? https://amalmehta.github.io/WhatSoccerPlayerAreYa/"
    }

    private var runnersUp: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Also a lot like").font(Theme.display(22))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(matches.dropFirst()) { m in
                        VStack(spacing: 8) {
                            PlayerCard(player: m.player, size: .small)
                            Text("\(m.score)% match").font(Theme.display(13, .bold)).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 4)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your style vs \(player.name)").font(Theme.display(22))
                Spacer()
                Text("Bars show each side's relative strengths").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Trait.allCases) { trait in
                let mine = player.isKeeper ? profile.value(Matcher.keeperSource[trait.rawValue]) : profile.value(trait)
                let theirs = high > low ? (Double(player.value(trait)) - low) / (high - low) : 0.5
                HStack(spacing: 12) {
                    Text(player.traitName(trait)).font(Theme.display(15, .semibold)).frame(width: 100, alignment: .leading)
                    VStack(spacing: 4) {
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
