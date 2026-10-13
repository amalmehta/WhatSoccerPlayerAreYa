import SoccerCore
import SwiftUI

/// The Matchday look: pitch greens, floodlight glow, gold accents and heavy rounded type.
enum Theme {
    static let grass = Color(red: 0.08, green: 0.55, blue: 0.30)
    static let pitchTop = Color(red: 0.10, green: 0.52, blue: 0.29)
    static let pitchBottom = Color(red: 0.02, green: 0.22, blue: 0.13)
    static let gold = Color(red: 0.98, green: 0.78, blue: 0.24)
    static let goldDeep = Color(red: 0.85, green: 0.60, blue: 0.12)
    static let ink = Color(red: 0.10, green: 0.11, blue: 0.10)

    static func display(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// A floodlit pitch: gradient, mown stripes, halfway line and centre circle.
struct PitchBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.pitchTop, Theme.pitchBottom], startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                let stripe = size.width / 10
                for i in stride(from: 0, to: 10, by: 2) {
                    context.fill(Path(CGRect(x: CGFloat(i) * stripe, y: 0, width: stripe, height: size.height)),
                                 with: .color(.white.opacity(0.035)))
                }
                var lines = Path()
                lines.move(to: CGPoint(x: size.width / 2, y: 0))
                lines.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                let r = min(size.width, size.height) * 0.28
                lines.addEllipse(in: CGRect(x: size.width / 2 - r, y: size.height / 2 - r, width: 2 * r, height: 2 * r))
                lines.addEllipse(in: CGRect(x: size.width / 2 - 4, y: size.height / 2 - 4, width: 8, height: 8))
                context.stroke(lines, with: .color(.white.opacity(0.13)), lineWidth: 2)
            }
            RadialGradient(colors: [.white.opacity(0.22), .clear], center: .topLeading, startRadius: 0, endRadius: 520)
            RadialGradient(colors: [.white.opacity(0.14), .clear], center: .topTrailing, startRadius: 0, endRadius: 420)
        }
    }
}

/// A big gold call-to-action.
struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(20, .bold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 30)
            .padding(.vertical, 13)
            .background(
                LinearGradient(colors: [Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom),
                in: Capsule()
            )
            .shadow(color: Theme.gold.opacity(0.45), radius: configuration.isPressed ? 4 : 14, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// A translucent white button for use on the pitch.
struct ChalkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(15, .semibold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(.white.opacity(configuration.isPressed ? 0.28 : 0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.35)))
    }
}

/// A collectible player card. Generic design: no club badges, photos or EA marks.
struct PlayerCard: View {
    enum Size { case large, small }
    var player: Player
    var size: Size = .large

    private var scale: CGFloat { size == .large ? 1 : 0.62 }

    private var colors: [Color] {
        switch player.era {
        case .current: [Color(red: 0.99, green: 0.90, blue: 0.56), Color(red: 0.86, green: 0.66, blue: 0.24)]
        case .legend: [Color(red: 1.0, green: 0.98, blue: 0.92), Color(red: 0.90, green: 0.82, blue: 0.62)]
        case .imported: [Color(red: 0.92, green: 0.93, blue: 0.95), Color(red: 0.68, green: 0.71, blue: 0.76)]
        }
    }

    private var initials: String {
        let parts = player.name.split(separator: " ")
        return String((parts.first?.prefix(1) ?? "") + (parts.count > 1 ? parts.last!.prefix(1) : ""))
    }

    var body: some View {
        VStack(spacing: 6 * scale) {
            HStack(alignment: .top) {
                VStack(spacing: 0) {
                    Text("\(player.overall)").font(Theme.display(40 * scale))
                    Text(player.positions.first ?? "").font(Theme.display(16 * scale, .bold))
                }
                Spacer()
                if player.era == .legend {
                    Text("LEGEND").font(Theme.display(10 * scale, .black)).tracking(1.5)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Theme.ink.opacity(0.85), in: Capsule())
                        .foregroundStyle(Theme.gold)
                }
            }
            ZStack {
                Circle().fill(.white.opacity(0.55))
                Circle().strokeBorder(Theme.ink.opacity(0.15), lineWidth: 2)
                Text(initials).font(Theme.display(44 * scale)).foregroundStyle(Theme.ink.opacity(0.75))
            }
            .frame(width: 96 * scale, height: 96 * scale)
            Text(player.name)
                .font(Theme.display(size == .large ? 20 : 14, .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Rectangle().fill(Theme.ink.opacity(0.2)).frame(height: 1)
            Grid(horizontalSpacing: 14 * scale, verticalSpacing: 3 * scale) {
                ForEach(0..<3) { row in
                    GridRow {
                        stat(Trait.allCases[row])
                        stat(Trait.allCases[row + 3])
                    }
                }
            }
            if size == .large {
                Text([player.nationality, player.club].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .opacity(0.75)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(16 * scale)
        .frame(width: 230 * scale)
        .background(
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 22 * scale, style: .continuous).strokeBorder(.white.opacity(0.7), lineWidth: 2))
        .shadow(color: .black.opacity(0.35), radius: 18 * scale, y: 10 * scale)
        .accessibilityElement(children: .combine)
    }

    private func stat(_ trait: Trait) -> some View {
        HStack(spacing: 5) {
            Text("\(player.value(trait))").font(Theme.display(15 * scale, .heavy)).monospacedDigit()
            Text(player.isKeeper ? String(trait.keeperName.prefix(3)).uppercased() : trait.abbreviation)
                .font(Theme.display(12 * scale, .semibold))
                .opacity(0.7)
        }
        .frame(minWidth: 60 * scale, alignment: .leading)
    }
}

/// An emoji for every quiz answer, keyed by question id and option index.
enum AnswerIcons {
    static let icons: [String: [String]] = [
        "pitch": ["🎯", "🔄", "🧱", "🧤"],
        "ball": ["💨", "🪄", "🚀", "♻️"],
        "weapon": ["⚡️", "🎯", "👀", "🪄", "🧠", "💪"],
        "duel": ["🦵", "💪", "🧤", "🏃", "🙈"],
        "goal": ["🚀", "🌀", "👟", "⬆️", "🤝"],
        "fitness": ["⚡️", "🏃", "🏋️", "🪜"],
        "captain": ["📣", "🎶", "📊", "🎧"],
        "pressure": ["✋", "🥄", "🤝", "🧤"],
        "style": ["✨", "🧠", "🛡️", "🔥", "⏱️"],
        "loss": ["🏋️", "📺", "🙌", "🤫"],
        "weekend": ["♟️", "🤹", "🥾", "🏎️", "🛋️"],
        "role": ["📐", "🛡️", "🎸", "🛫", "🚗"],
    ]

    static func icon(_ questionID: String, _ index: Int) -> String {
        guard let list = icons[questionID], list.indices.contains(index) else { return "⚽️" }
        return list[index]
    }
}

/// A friendly empty state on a pitch.
struct EmptyPitch: View {
    var emoji: String
    var title: String
    var message: String
    var button: String
    var action: () -> Void

    var body: some View {
        ZStack {
            PitchBackground()
            VStack(spacing: 16) {
                Text(emoji).font(.system(size: 64))
                Text(title).font(Theme.display(32))
                Text(message)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: 480)
                Button(button, action: action).buttonStyle(GoldButtonStyle()).padding(.top, 6)
            }
            .foregroundStyle(.white)
            .padding(40)
        }
    }
}

/// A choice pill for use on the pitch: gold when selected.
struct PillStyle: ButtonStyle {
    var selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(14, .bold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(selected ? Theme.ink : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(selected ? AnyShapeStyle(Theme.gold) : AnyShapeStyle(.white.opacity(configuration.isPressed ? 0.25 : 0.14)), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(selected ? 0 : 0.3)))
            .animation(.spring(duration: 0.2), value: selected)
    }
}
