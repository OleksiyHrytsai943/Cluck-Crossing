import Combine
import Foundation

enum ProfileError: LocalizedError, Equatable {
    case notEnoughCoins(needed: Int)
    case maxedOut
    case alreadyOwned
    case notOwned
    case sunflowersNotLit(needed: Int)
    case alreadyClaimed

    var errorDescription: String? {
        switch self {
        case .notEnoughCoins(let needed): "Not enough coins. You need \(needed) more."
        case .maxedOut: "This item is already at its top level."
        case .alreadyOwned: "This hen already lives with you."
        case .notOwned: "Adopt this hen first."
        case .sunflowersNotLit(let needed): "Light \(needed) more sunflowers this week to claim."
        case .alreadyClaimed: "Already claimed this week."
        }
    }
}

/// What the result screen shows after a run is recorded.
struct RunReward: Equatable {
    var coins: Int
    var stars: Int
    var previousStars: Int
    var isNewBest: Bool
    var newAchievements: [Achievement]
    var unlockedCrossing: Int?
}

/// All profile mutations go through here; every change is saved immediately.
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profile: PlayerProfile
    private let storage: ProfileStorage
    private let now: () -> Date

    init(storage: ProfileStorage, now: @escaping () -> Date = Date.init) {
        self.storage = storage
        self.now = now
        profile = storage.load() ?? PlayerProfile()
    }

    var coins: Int { profile.coins }
    var hen: Hen { Hen.with(id: profile.selectedHen) }
    var todayKey: String { DailyCrossing.key(for: now()) }
    var shift: FarmWeek { FarmWeek.current(at: now()) }
    var currentDate: Date { now() }
    var sunflowersLitThisWeek: Int { profile.sunflowersLit(week: shift.weekKey) }
    var weeklyBest: Int { profile.weeklyBest[shift.weekKey] ?? 0 }

    private func commit(_ change: (inout PlayerProfile) -> Void) {
        var copy = profile
        change(&copy)
        profile = copy
        storage.save(copy)
    }

    // MARK: Vending machine

    func buy(_ upgrade: UpgradeKind) throws {
        let level = profile.level(of: upgrade)
        guard let price = upgrade.price(forLevel: level) else { throw ProfileError.maxedOut }
        guard profile.coins >= price else { throw ProfileError.notEnoughCoins(needed: price - profile.coins) }
        commit {
            $0.coins -= price
            $0.upgrades[upgrade.rawValue] = level + 1
        }
    }

    // MARK: Henhouse

    func adopt(_ hen: Hen) throws {
        guard !profile.ownedHens.contains(hen.id) else { throw ProfileError.alreadyOwned }
        guard profile.coins >= hen.price else { throw ProfileError.notEnoughCoins(needed: hen.price - profile.coins) }
        commit {
            $0.coins -= hen.price
            $0.ownedHens.append(hen.id)
            $0.selectedHen = hen.id
        }
        awardIfNeeded(.fullCoop, when: Hen.all.allSatisfy { profile.ownedHens.contains($0.id) })
    }

    func select(_ hen: Hen) throws {
        guard profile.ownedHens.contains(hen.id) else { throw ProfileError.notOwned }
        commit { $0.selectedHen = hen.id }
    }

    // MARK: Runs

    /// Run tunables: upgrades, hen perk and this week's Farm Week rule.
    func runConfig(for mode: RunMode, seed: UInt64? = nil) -> RunConfig {
        var config = RunConfig.make(mode: mode, upgrades: profile.upgradeLevels, hen: hen, seed: seed)
        shift.theme.apply(to: &config)
        return config
    }

    // MARK: Sunflower Row

    func isSunflowerTierClaimed(_ tier: SunflowerRow.Tier) -> Bool {
        profile.claimedSunflowers.contains(SunflowerRow.claimKey(week: shift.weekKey, sunflowers: tier.sunflowers))
    }

    func claimSunflowers(_ tier: SunflowerRow.Tier) throws {
        let week = shift.weekKey
        guard !isSunflowerTierClaimed(tier) else { throw ProfileError.alreadyClaimed }
        let lit = profile.sunflowersLit(week: week)
        guard lit >= tier.sunflowers else { throw ProfileError.sunflowersNotLit(needed: tier.sunflowers - lit) }
        commit {
            $0.coins += tier.coins
            $0.claimedSunflowers.append(SunflowerRow.claimKey(week: week, sunflowers: tier.sunflowers))
        }
    }

    @discardableResult
    func record(_ result: RunResult) -> RunReward {
        var reward = RunReward(coins: result.coinsEarned, stars: result.stars, previousStars: 0,
                               isNewBest: false, newAchievements: [], unlockedCrossing: nil)
        commit { p in
            p.coins += reward.coins
            p.stats.runs += 1
            p.stats.lanes += result.lanesCrossed
            p.stats.eggsBanked += result.eggsBanked
            p.stats.kernels += result.kernels
            p.stats.bells += result.bells
            p.stats.bumps += result.hits
            p.stats.roosts += result.roosts
            p.stats.forcedHops += result.forcedHops
            p.stats.bestStreak = max(p.stats.bestStreak, result.bestStreak)
            p.stats.bestRoost = max(p.stats.bestRoost, result.bestRoost)
            p.stats.coinsEarned += reward.coins

            switch result.mode {
            case .crossing(let index):
                reward.previousStars = p.stars[index]
                reward.isNewBest = result.crossed && result.banked > p.bestScores[index]
                if result.crossed {
                    p.stars[index] = max(p.stars[index], result.stars)
                    p.bestScores[index] = max(p.bestScores[index], result.banked)
                    if reward.previousStars == 0, index + 1 < CrossingSpec.count {
                        reward.unlockedCrossing = index + 1
                    }
                }
            case .longRoad:
                reward.isNewBest = result.banked > p.bestLongRoadScore
                p.bestLongRoadScore = max(p.bestLongRoadScore, result.banked)
                p.bestLongRoadLanes = max(p.bestLongRoadLanes, result.lanesCrossed)
            case .daily(let key):
                reward.isNewBest = result.banked > (p.dailyBest[key] ?? 0)
                p.dailyBest[key] = max(p.dailyBest[key] ?? 0, result.banked)
            }

            // Farm Week weekly best and tonight's sunflower.
            let week = FarmWeek.current(at: now()).weekKey
            p.weeklyBest[week] = max(p.weeklyBest[week] ?? 0, result.banked)
            let night = DailyCrossing.key(for: now())
            if !(p.sunflowerNights[week] ?? []).contains(night) {
                p.sunflowerNights[week, default: []].append(night)
            }
            // Keep only the last few weeks.
            for key in p.sunflowerNights.keys.sorted().dropLast(4) { p.sunflowerNights[key] = nil }

            p.history.insert(RunRecord(date: now(), mode: result.mode, banked: result.banked, lanes: result.lanesCrossed,
                                       crossed: result.crossed, stars: result.stars), at: 0)
            if p.history.count > PlayerProfile.historyLimit {
                p.history.removeLast(p.history.count - PlayerProfile.historyLimit)
            }
        }

        var earned: [Achievement] = []
        func check(_ a: Achievement, _ condition: Bool) {
            if condition, !profile.has(a) { earned.append(a) }
        }
        check(.firstSteps, profile.stars[0] > 0)
        for district in District.all {
            let range = (district.id * CrossingSpec.perDistrict)..<((district.id + 1) * CrossingSpec.perDistrict)
            check(.district(district.id), profile.stars[range].allSatisfy { $0 > 0 })
        }
        check(.tenInARow, result.bestStreak >= 10)
        check(.heavyBasket, result.bestRoost >= 300)
        check(.bellRinger, profile.stats.bells >= 25)
        check(.cornCollector, profile.stats.kernels >= 100)
        check(.starHarvest, profile.totalStars >= 45)
        check(.longHauler, result.mode == .longRoad && result.lanesCrossed >= 60)
        if case .daily = result.mode { check(.dailyChores, result.crossed) }
        if case .crossing(let index) = result.mode {
            check(.notAScratch, result.crossed && result.hits == 0 && index >= CrossingSpec.perDistrict)
        }
        if !earned.isEmpty {
            commit { $0.achievements.append(contentsOf: earned.map(\.rawValue)) }
        }
        reward.newAchievements = earned
        return reward
    }

    // MARK: Onboarding & settings

    func markTutorialSeen() {
        guard !profile.tutorialSeen else { return }
        commit { $0.tutorialSeen = true }
    }

    func markDistrictIntroSeen(_ district: Int) {
        guard !profile.districtIntrosSeen.contains(district) else { return }
        commit { $0.districtIntrosSeen.append(district) }
    }

    func reset() {
        let keepTutorial = profile.tutorialSeen
        commit {
            $0 = PlayerProfile()
            $0.tutorialSeen = keepTutorial
        }
    }

    private func awardIfNeeded(_ achievement: Achievement, when condition: Bool) {
        guard condition, !profile.has(achievement) else { return }
        commit { $0.achievements.append(achievement.rawValue) }
    }

    // MARK: Test & tour seeding

    func seed(coins: Int? = nil, clearedCrossings: Int = 0, stars: Int = 2, introsSeen: Bool = true) {
        commit { p in
            if let coins { p.coins = coins }
            for i in 0..<min(clearedCrossings, CrossingSpec.count) {
                p.stars[i] = max(p.stars[i], stars)
                p.bestScores[i] = max(p.bestScores[i], StarRule.thresholds(for: CrossingSpec.all[i]).two)
            }
            if introsSeen { p.districtIntrosSeen = Array(0..<District.all.count) }
        }
    }

    /// Tour/test helper: pretend the player already played `nights` nights this week.
    func seedSunflowers(_ nights: Int) {
        let week = shift.weekKey
        commit { p in
            p.sunflowerNights[week] = (0..<min(nights, SunflowerRow.sunflowersPerWeek)).map { "seed-\($0)" }
        }
    }
}
