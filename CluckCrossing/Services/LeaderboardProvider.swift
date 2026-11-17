import Foundation

struct LeaderboardEntry: Equatable, Codable {
    var rank: Int
    var name: String
    var hen: String
    var score: Int
    var isPlayer: Bool
}

/// Everything the Top Players page renders (encoded to JSON for the HTML template).
struct LeaderboardPage: Equatable, Codable {
    var weekKey: String
    var themeTitle: String
    var themeDetail: String
    var daysLeft: Int
    var entries: [LeaderboardEntry]
    var rewards: [RosterRewardSlot]
    var sunflowersLit: Int
    var sunflowersPerWeek: Int
    /// True while the board shows sample rivals instead of a live roster.
    var isPreview: Bool
    var notice: String
}

/// The local player's standing sent to a provider.
struct PlayerStanding: Equatable {
    var name: String
    var hen: String
    var weeklyBest: Int
}

/// Extension point for the weekly roster. A future online provider implements this
/// (fetch top 5 for `shift.weekKey`, submit `player.weeklyBest`); the app only depends on the protocol.
protocol LeaderboardProviding {
    func weeklyTop(for shift: FarmWeek, player: PlayerStanding, sunflowersLit: Int, now: Date) async throws -> LeaderboardPage
}

/// Offline provider: deterministic sample rivals for the week, merged with the player's real weekly best.
/// The page is flagged `isPreview` and says so on screen.
struct PreviewLeaderboardProvider: LeaderboardProviding {
    static let rivalNames = ["MeadowMabel", "HayHopper", "BarnyardBetty", "TractorTina", "SunflowerSue", "GravelGus", "OrchardOtto", "CornfieldCleo"]

    func weeklyTop(for shift: FarmWeek, player: PlayerStanding, sunflowersLit: Int, now: Date) async throws -> LeaderboardPage {
        var rng = SeededGenerator(seed: DailyCrossing.seed(for: shift.weekKey))
        var entries: [LeaderboardEntry] = Self.rivalNames.shuffled(using: &rng).prefix(6).map { name in
            LeaderboardEntry(rank: 0, name: name, hen: Hen.all.randomElement(using: &rng)?.art ?? "hen_pepper",
                             score: Int.random(in: 180...1_400, using: &rng), isPlayer: false)
        }
        if player.weeklyBest > 0 {
            entries.append(LeaderboardEntry(rank: 0, name: player.name, hen: player.hen, score: player.weeklyBest, isPlayer: true))
        }
        entries.sort { $0.score > $1.score }
        var top = Array(entries.prefix(5))
        for i in top.indices { top[i].rank = i + 1 }
        return LeaderboardPage(
            weekKey: shift.weekKey,
            themeTitle: shift.theme.title,
            themeDetail: shift.theme.detail,
            daysLeft: shift.daysLeft(from: now),
            entries: top,
            rewards: RosterRewardSlot.weekly,
            sunflowersLit: sunflowersLit,
            sunflowersPerWeek: SunflowerRow.sunflowersPerWeek,
            isPreview: true,
            notice: "Preview roster: sample rivals. The live weekly roster and its rewards arrive in a later update."
        )
    }
}
