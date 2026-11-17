import SwiftUI

/// Bright-day farm palette and type: walnut sign boards, barn red, wheat, meadow green, chalk.
enum Theme {
    static let soil = Color(red: 0.23, green: 0.14, blue: 0.08)
    static let sky = Color(red: 0.49, green: 0.78, blue: 0.95)
    static let gravel = Color(red: 0.55, green: 0.49, blue: 0.42)
    /// Walnut sign board behind light text.
    static let panel = Color(red: 0.29, green: 0.18, blue: 0.11)
    static let pumpkin = Color(red: 0.95, green: 0.55, blue: 0.16)
    static let barnRed = Color(red: 0.84, green: 0.27, blue: 0.20)
    static let meadow = Color(red: 0.55, green: 0.82, blue: 0.35)
    static let tomato = Color(red: 0.91, green: 0.26, blue: 0.18)
    static let wheat = Color(red: 0.96, green: 0.78, blue: 0.27)
    static let cream = Color(red: 1.0, green: 0.96, blue: 0.88)
    static let ink = Color(red: 0.17, green: 0.10, blue: 0.06)
    static let signGreen = Color(red: 0.18, green: 0.48, blue: 0.24)
    /// Chalk on the green chalkboards.
    static let chalk = Color(red: 0.95, green: 0.93, blue: 0.86)
    static let chalkboard = Color(red: 0.18, green: 0.29, blue: 0.22)
    static let mutedText = Color(red: 0.91, green: 0.85, blue: 0.74)

    /// Condensed typewriter face, like stencils on feed sacks and barn signs.
    static func display(_ size: CGFloat) -> Font {
        .custom("AmericanTypewriter-CondensedBold", size: size, relativeTo: .title)
    }

    static func headline(_ size: CGFloat) -> Font {
        .custom("AmericanTypewriter-Semibold", size: size, relativeTo: .headline)
    }

    static func body(_ size: CGFloat) -> Font {
        .custom("AvenirNext-Medium", size: size, relativeTo: .body)
    }

    /// Hand-written chalk for boards and counters.
    static func chalkFont(_ size: CGFloat) -> Font {
        .custom("ChalkboardSE-Bold", size: size, relativeTo: .body)
    }

    static let maxContentWidth: CGFloat = 520
    static let corner: CGFloat = 18
}
