import Foundation

/// Weekly theme ("Night Shift") that bends one rule for every run that week.
/// Rotates by ISO week number, so it works offline and is the same for every player.
enum ShiftTheme: String, CaseIterable, Codable {
    case cornHarvest, guardWeek, lampLighters, rushHour

    var title: String {
        switch self {
        case .cornHarvest: "Corn Harvest Week"
        case .guardWeek: "Crossing Guard Week"
        case .lampLighters: "Lamp Lighters Week"
        case .rushHour: "Rush Hour Week"
        }
    }

    var detail: String {
        switch self {
        case .cornHarvest: "Corn kernels pay +2 coins."
        case .guardWeek: "The whistle freezes traffic 1 s longer."
        case .lampLighters: "Every lane adds 10% more to your basket."
        case .rushHour: "The clutch multiplier climbs +0.05 faster."
        }
    }

    var art: String {
        switch self {
        case .cornHarvest: "kernel"
        case .guardWeek: "grain_token"
        case .lampLighters: "nest"
        case .rushHour: "car_taxi"
        }
    }

    /// Applies this week's rule to a run.
    func apply(to config: inout RunConfig) {
        switch self {
        case .cornHarvest: config.kernelCoins += 2
        case .guardWeek: config.whistleDuration += 1
        case .lampLighters: config.basketBonus += 0.1
        case .rushHour: config.multiplierStep += 0.05
        }
    }
}

struct NightShift: Equatable {
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

    static func current(at date: Date) -> NightShift {
        let c = calendar
        let week = c.component(.weekOfYear, from: date)
        let year = c.component(.yearForWeekOfYear, from: date)
        let start = c.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let end = c.date(byAdding: .day, value: 7, to: start) ?? date
        let theme = ShiftTheme.allCases[week % ShiftTheme.allCases.count]
        return NightShift(weekKey: String(format: "%04d-W%02d", year, week), theme: theme, endsAt: end)
    }

    func daysLeft(from date: Date) -> Int {
        max(0, Int(ceil(endsAt.timeIntervalSince(date) / 86_400)))
    }
}

/// Lamp Lighter: each night (UTC day) with at least one run lights one lamp on your block.
/// Reaching 3 / 5 / 7 lamps in a week unlocks a coin bundle, claimable once per week.
enum LampLighter {
    struct Tier: Equatable, Identifiable {
        let lamps: Int
        let coins: Int
        var id: Int { lamps }
    }

    static let lampsPerWeek = 7
    static let tiers: [Tier] = [Tier(lamps: 3, coins: 120), Tier(lamps: 5, coins: 260), Tier(lamps: 7, coins: 520)]

    static func claimKey(week: String, lamps: Int) -> String { "\(week)#\(lamps)" }
}

/// Weekly roster reward slots. Shown on the Top Players board; paid out by the online roster
/// once it exists (see `LeaderboardProviding`).
struct RosterRewardSlot: Equatable, Codable {
    let ranks: String
    let title: String
    let coins: Int

    static let weekly: [RosterRewardSlot] = [
        RosterRewardSlot(ranks: "1", title: "Golden Comb", coins: 800),
        RosterRewardSlot(ranks: "2–3", title: "Neon Feather", coins: 400),
        RosterRewardSlot(ranks: "4–5", title: "Brass Whistle Pin", coins: 200),
    ]
}
