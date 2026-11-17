import Foundation

/// Identifiers shared with the UI tests (duplicated there as plain strings).
enum AccessibilityID {
    static let cornerScreen = "corner.screen"
    static let walkButton = "corner.walk"
    static let longRoadButton = "corner.longRoad"
    static let dailyButton = "corner.daily"
    static let settingsButton = "corner.settings"
    static let coinsBadge = "coins.badge"
    static let backButton = "back.button"
    static let toast = "toast"

    static func sign(_ screen: String) -> String { "sign.\(screen)" }

    static let timetableScreen = "timetable.screen"
    static func crossing(_ index: Int) -> String { "crossing.\(index)" }
    static let districtCard = "district.card"
    static let districtStart = "district.start"

    static let vendingScreen = "vending.screen"
    static func vendingBuy(_ kind: UpgradeKind) -> String { "vending.buy.\(kind.rawValue)" }
    static func vendingLevel(_ kind: UpgradeKind) -> String { "vending.level.\(kind.rawValue)" }

    static let henhouseScreen = "henhouse.screen"
    static func henWindow(_ id: String) -> String { "hen.window.\(id)" }
    static let henAction = "hen.action"

    static let billboardScreen = "billboard.screen"
    static func achievement(_ a: Achievement) -> String { "achievement.\(a.rawValue)" }

    static let rosterScreen = "roster.screen"
    static let rosterWeb = "roster.web"
    static let rosterSunflowers = "roster.sunflowers"
    static func sunflowerClaim(_ sunflowers: Int) -> String { "roster.claim.\(sunflowers)" }
    static let shiftStrip = "corner.shift"

    static let rulebookScreen = "rulebook.screen"
    static let tutorialScreen = "tutorial.screen"
    static let tutorialNext = "tutorial.next"

    static let settingsScreen = "settings.screen"
    static let settingsReset = "settings.reset"
    static let settingsDone = "settings.done"
    static let settingsTutorial = "settings.tutorial"

    static let gameScreen = "game.screen"
    static let pauseButton = "game.pause"
    static let bellButton = "game.bell"
    static let roostButton = "game.roost"
    static let scoreLabel = "game.score"
    static let clutchLabel = "game.clutch"
    static let feathers = "game.feathers"
    static let resumeButton = "pause.resume"
    static let quitButton = "pause.quit"

    static let resultScreen = "result.screen"
    static let resultAgain = "result.again"
    static let resultNext = "result.next"
    static let resultHome = "result.home"
    static let resultCoins = "result.coins"
}
