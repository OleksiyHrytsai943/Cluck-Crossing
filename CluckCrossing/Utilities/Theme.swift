import SwiftUI

/// Night-city palette and type: neon signs, sodium lamps, graphite asphalt.
enum Theme {
    static let night = Color(red: 0.03, green: 0.05, blue: 0.11)
    static let nightBlue = Color(red: 0.06, green: 0.11, blue: 0.21)
    static let graphite = Color(red: 0.14, green: 0.15, blue: 0.18)
    static let panel = Color(red: 0.07, green: 0.06, blue: 0.14)
    static let sodium = Color(red: 1.0, green: 0.70, blue: 0.28)
    static let neonPink = Color(red: 1.0, green: 0.37, blue: 0.82)
    static let neonTeal = Color(red: 0.18, green: 0.90, blue: 0.84)
    static let neonRed = Color(red: 1.0, green: 0.23, blue: 0.36)
    static let eggGold = Color(red: 1.0, green: 0.84, blue: 0.29)
    static let cream = Color(red: 1.0, green: 0.96, blue: 0.86)
    static let ink = Color(red: 0.04, green: 0.05, blue: 0.09)
    static let signGreen = Color(red: 0.11, green: 0.42, blue: 0.29)
    static let led = Color(red: 1.0, green: 0.62, blue: 0.16)
    static let mutedText = Color(red: 0.75, green: 0.77, blue: 0.85)

    /// Condensed heavy display face (street signs, neon).
    static func display(_ size: CGFloat) -> Font {
        .custom("AvenirNextCondensed-Heavy", size: size, relativeTo: .title)
    }

    static func headline(_ size: CGFloat) -> Font {
        .custom("AvenirNextCondensed-Bold", size: size, relativeTo: .headline)
    }

    static func body(_ size: CGFloat) -> Font {
        .custom("AvenirNext-Medium", size: size, relativeTo: .body)
    }

    /// LED / split-flap digits.
    static func led(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }

    static let maxContentWidth: CGFloat = 520
    static let corner: CGFloat = 18
}
