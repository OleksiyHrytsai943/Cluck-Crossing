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

/// Loads real, scored player profiles from the authenticated Supabase leaderboard.
struct SupabaseLeaderboardProvider: LeaderboardProviding {
    func weeklyTop(for shift: FarmWeek, player: PlayerStanding, sunflowersLit: Int, now: Date) async throws -> LeaderboardPage {
        let users = try await PlayerOnlineStore.shared.realLeaderboard()
        let artByAvatar: [String: String] = [
            "clover": "hen_pepper",
            "pip": "hen_dot",
            "rusty": "hen_comet",
            "mabel": "hen_inkwell",
            "nova": "hen_sunny",
            "duchess": "hen_duchess",
            "zippy": "hen_pepper"
        ]
        let entries = users.prefix(5).enumerated().map { index, user in
            LeaderboardEntry(rank: index + 1, name: user.name,
                             hen: artByAvatar[user.avatar ?? ""] ?? "hen_pepper",
                             score: user.best_score, isPlayer: false)
        }
        return LeaderboardPage(
            weekKey: shift.weekKey,
            themeTitle: shift.theme.title,
            themeDetail: shift.theme.detail,
            daysLeft: shift.daysLeft(from: now),
            entries: Array(entries),
            rewards: RosterRewardSlot.weekly,
            sunflowersLit: sunflowersLit,
            sunflowersPerWeek: SunflowerRow.sunflowersPerWeek,
            isPreview: false,
            notice: users.isEmpty ? "No scored players yet. Complete a crossing to appear here." : "Top 5 Cluck Crossing players"
        )
    }
}
