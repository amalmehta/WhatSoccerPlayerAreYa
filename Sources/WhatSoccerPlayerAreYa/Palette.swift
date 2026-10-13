import AppKit
import SoccerCore
import SwiftUI

/// Category colours. Related categories share a hue family (attack = reds, midfield = greens,
/// defence = blues, keepers = purple) with shades spaced far enough apart to tell at a glance.
/// Every colour has a darker light-mode and a brighter dark-mode variant.
enum Palette {
    static func dynamic(hue: Double, saturation: Double, lightBrightness: Double, darkBrightness: Double) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hue: hue.truncatingRemainder(dividingBy: 1), saturation: dark ? saturation * 0.75 : saturation,
                           brightness: dark ? darkBrightness : lightBrightness, alpha: 1)
        })
    }

    static func hue(_ group: PositionGroup) -> Double {
        switch group {
        case .forward: 0.0
        case .midfielder: 0.36
        case .defender: 0.60
        case .goalkeeper: 0.78
        }
    }

    // Shade variants within a family: (hue shift, saturation, light-mode brightness, dark-mode brightness).
    static let shades: [(Double, Double, Double, Double)] = [
        (0.00, 0.85, 0.72, 0.95),
        (0.05, 0.70, 0.55, 0.80),
        (-0.04, 0.95, 0.45, 1.00),
        (0.09, 0.60, 0.65, 0.88),
    ]

    static func shade(for position: String) -> Int {
        switch position.uppercased() {
        case "CF", "CM", "LB", "RB": 1
        case "LW", "RW", "LF", "RF", "CAM", "LWB", "RWB": 2
        case "LS", "RS", "LM", "RM": 3
        default: 0
        }
    }

    static func color(position: String) -> Color {
        let group = PositionGroup.of(position: position) ?? .midfielder
        let (shift, s, lb, db) = shades[shade(for: position)]
        return dynamic(hue: hue(group) + shift + 1, saturation: s, lightBrightness: lb, darkBrightness: db)
    }

    static func color(group: PositionGroup) -> Color {
        let (_, s, lb, db) = shades[0]
        return dynamic(hue: hue(group), saturation: s, lightBrightness: lb, darkBrightness: db)
    }

    /// Attacking traits are warm (reds/oranges), build-up is green, defensive traits are blues.
    static func color(trait: Trait) -> Color {
        switch trait {
        case .shooting: dynamic(hue: 0.0, saturation: 0.80, lightBrightness: 0.78, darkBrightness: 0.95)
        case .dribbling: dynamic(hue: 0.07, saturation: 0.85, lightBrightness: 0.85, darkBrightness: 1.0)
        case .pace: dynamic(hue: 0.12, saturation: 0.90, lightBrightness: 0.80, darkBrightness: 1.0)
        case .passing: dynamic(hue: 0.36, saturation: 0.75, lightBrightness: 0.62, darkBrightness: 0.85)
        case .defending: dynamic(hue: 0.58, saturation: 0.85, lightBrightness: 0.75, darkBrightness: 1.0)
        case .physical: dynamic(hue: 0.66, saturation: 0.65, lightBrightness: 0.60, darkBrightness: 0.90)
        }
    }

    static func color(era: Era) -> Color {
        switch era {
        case .current: dynamic(hue: 0.50, saturation: 0.80, lightBrightness: 0.60, darkBrightness: 0.85)
        case .legend: dynamic(hue: 0.13, saturation: 0.85, lightBrightness: 0.65, darkBrightness: 0.95)
        case .imported: dynamic(hue: 0.60, saturation: 0.15, lightBrightness: 0.50, darkBrightness: 0.75)
        }
    }
}

struct Chip: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.16), in: Capsule())
    }
}

struct PositionChips: View {
    var positions: [String]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(positions, id: \.self) { Chip(text: $0, color: Palette.color(position: $0)) }
        }
    }
}
