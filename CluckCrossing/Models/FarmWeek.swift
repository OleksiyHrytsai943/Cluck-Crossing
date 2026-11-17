import Foundation

/// Weekly theme ("Farm Week") that bends one rule for every run that week.
/// Rotates by ISO week number, so it works offline and is the same for every player.
enum ShiftTheme: String, CaseIterable, Codable {
    case cornHarvest, bellWeek, eggBasket, marketDay

    var title: String {
        switch self {
        case .cornHarvest: "Corn Harvest Week"
        case .bellWeek: "Bell Ringer Week"
        case .eggBasket: "Egg Basket Week"
        case .marketDay: "Market Day Week"
        }
    }

    var detail: String {
        switch self {
        case .cornHarvest: "Corn kernels pay +2 coins."
        case .bellWeek: "The farm bell holds traffic 1 s longer."
        case .eggBasket: "Every lane adds 10% more to your basket."
        case .marketDay: "The basket multiplier climbs +0.05 faster."
        }
    }

    var art: String {
        switch self {
        case .cornHarvest: "kernel"
        case .bellWeek: "grain_token"
        case .eggBasket: "nest"
        case .marketDay: "car_tractor"
        }
    }

    /// Applies this week's rule to a run.
    func apply(to config: inout RunConfig) {
        switch self {
        case .cornHarvest: config.kernelCoins += 2
        case .bellWeek: config.bellDuration += 1
        case .eggBasket: config.basketBonus += 0.1
        case .marketDay: config.multiplierStep += 0.05
        }
    }
}

struct FarmWeek: Equatable {
    /// ISO week key, e.g. "2026-W47".
    let weekKey: String
    let theme: ShiftTheme
    /// Start of next week (UTC Monday 00:00).
    let endsAt: Date

    private static var calendar: Calendar {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = TimeZone(identifier: "UTC") ?? .current
        return c
    }

    static func current(at date: Date) -> FarmWeek {
        let c = calendar
        let week = c.component(.weekOfYear, from: date)
        let year = c.component(.yearForWeekOfYear, from: date)
        let start = c.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let end = c.date(byAdding: .day, value: 7, to: start) ?? date
        let theme = ShiftTheme.allCases[week % ShiftTheme.allCases.count]
        return FarmWeek(weekKey: String(format: "%04d-W%02d", year, week), theme: theme, endsAt: end)
    }

    func daysLeft(from date: Date) -> Int {
        max(0, Int(ceil(endsAt.timeIntervalSince(date) / 86_400)))
    }
}

/// Sunflower Row: each day (UTC) with at least one run makes one sunflower bloom along the farm fence.
/// Reaching 3 / 5 / 7 sunflowers in a week unlocks a coin bundle, claimable once per week.
enum SunflowerRow {
    struct Tier: Equatable, Identifiable {
        let sunflowers: Int
        let coins: Int
        var id: Int { sunflowers }
    }

    static let sunflowersPerWeek = 7
    static let tiers: [Tier] = [Tier(sunflowers: 3, coins: 120), Tier(sunflowers: 5, coins: 260), Tier(sunflowers: 7, coins: 520)]

    static func claimKey(week: String, sunflowers: Int) -> String { "\(week)#\(sunflowers)" }
}

/// Weekly roster reward slots. Shown on the Top Players board; paid out by the online roster
/// once it exists (see `LeaderboardProviding`).
struct RosterRewardSlot: Equatable, Codable {
    let ranks: String
    let title: String
    let coins: Int

    static let weekly: [RosterRewardSlot] = [
        RosterRewardSlot(ranks: "1", title: "Golden Comb", coins: 800),
        RosterRewardSlot(ranks: "2–3", title: "Golden Feather", coins: 400),
        RosterRewardSlot(ranks: "4–5", title: "Brass Bell Pin", coins: 200),
    ]
}
