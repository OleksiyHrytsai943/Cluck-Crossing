import Foundation

struct LifetimeStats: Equatable, Codable {
    var runs = 0
    var lanes = 0
    var eggsBanked = 0
    var kernels = 0
    var whistles = 0
    var bumps = 0
    var roosts = 0
    var bestStreak = 0
    var bestRoost = 0
    var coinsEarned = 0
    var forcedHops = 0
}

/// One line in the run history.
struct RunRecord: Equatable, Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var mode: RunMode
    var banked: Int
    var lanes: Int
    var crossed: Bool
    var stars: Int
}

/// The whole save file (JSON in Application Support).
struct PlayerProfile: Equatable, Codable {
    static let startingCoins = 150
    static let historyLimit = 25

    var coins = startingCoins
    var selectedHen = Hen.starter
    var ownedHens: [String] = [Hen.starter]
    var upgrades: [String: Int] = [:]
    /// Best stars per crossing (index = crossing id).
    var stars: [Int] = Array(repeating: 0, count: CrossingSpec.count)
    var bestScores: [Int] = Array(repeating: 0, count: CrossingSpec.count)
    var bestNightLanes = 0
    var bestNightScore = 0
    var dailyBest: [String: Int] = [:]
    var stats = LifetimeStats()
    var achievements: [String] = []
    var history: [RunRecord] = []
    var tutorialSeen = false
    var districtIntrosSeen: [Int] = []
    /// Night Shift: best banked score per ISO week.
    var weeklyBest: [String: Int] = [:]
    /// Lamp Lighter: UTC day keys with a run, per ISO week.
    var lampNights: [String: [String]] = [:]
    /// Claimed Lamp Lighter tiers ("2026-W47#3").
    var claimedLamps: [String] = []

    func level(of upgrade: UpgradeKind) -> Int { upgrades[upgrade.rawValue] ?? 0 }

    var upgradeLevels: [UpgradeKind: Int] {
        Dictionary(uniqueKeysWithValues: UpgradeKind.allCases.map { ($0, level(of: $0)) })
    }

    var totalStars: Int { stars.reduce(0, +) }

    func isUnlocked(crossing index: Int) -> Bool {
        index == 0 || (index > 0 && index < stars.count && stars[index - 1] > 0)
    }

    /// First crossing that is unlocked but not yet finished (or the last one).
    var nextCrossing: Int {
        stars.firstIndex(of: 0) ?? CrossingSpec.count - 1
    }

    /// Night Run and Daily open after Sleepy Lane is cleared.
    var nightRunUnlocked: Bool { stars.prefix(CrossingSpec.perDistrict).allSatisfy { $0 > 0 } }

    func has(_ achievement: Achievement) -> Bool { achievements.contains(achievement.rawValue) }

    func lampsLit(week: String) -> Int { min(LampLighter.lampsPerWeek, lampNights[week]?.count ?? 0) }
}
