import Foundation
import Testing
import UIKit
@testable import CluckCrossing

@MainActor
private func result(_ mode: RunMode, crossed: Bool = true, banked: Int = 100, lanes: Int = 5, streak: Int = 3,
                    roost: Int = 50, kernels: Int = 0, bells: Int = 0, hits: Int = 0) -> RunResult {
    RunResult(mode: mode, crossed: crossed, banked: banked, lanesCrossed: lanes, bestStreak: streak, bestRoost: roost,
              eggsBanked: lanes, kernels: kernels, kernelCoins: kernels, bells: bells, hits: hits, roosts: 2,
              forcedHops: 0, duration: 30)
}

@MainActor
struct ProfileStoreTests {
    @Test func freshProfile() {
        let store = ProfileStore(storage: .inMemory())
        #expect(store.coins == PlayerProfile.startingCoins)
        #expect(store.hen.id == Hen.starter)
        #expect(store.profile.isUnlocked(crossing: 0))
        #expect(!store.profile.isUnlocked(crossing: 1))
        #expect(!store.profile.longRoadUnlocked)
    }

    @Test func buyingUpgradeSpendsCoinsAndLevelsUp() throws {
        let store = ProfileStore(storage: .inMemory())
        store.seed(coins: 1_000)
        let price = try #require(UpgradeKind.coolFeet.price(forLevel: 0))
        try store.buy(.coolFeet)
        #expect(store.coins == 1_000 - price)
        #expect(store.profile.level(of: .coolFeet) == 1)
    }

    @Test func buyingWithoutCoinsIsRefused() {
        let store = ProfileStore(storage: .inMemory())
        store.seed(coins: 10)
        #expect(throws: ProfileError.self) { try store.buy(.spareFeather) }
        #expect(store.coins == 10)
        #expect(store.profile.level(of: .spareFeather) == 0)
    }

    @Test func maxedUpgradeIsRefused() throws {
        let store = ProfileStore(storage: .inMemory())
        store.seed(coins: 100_000)
        for _ in 0..<UpgradeKind.spareFeather.maxLevel { try store.buy(.spareFeather) }
        #expect(throws: ProfileError.maxedOut) { try store.buy(.spareFeather) }
    }

    @Test func upgradePricesRise() {
        for kind in UpgradeKind.allCases {
            var last = 0
            for level in 0..<kind.maxLevel {
                let price = kind.price(forLevel: level) ?? 0
                #expect(price > last)
                last = price
            }
            #expect(kind.price(forLevel: kind.maxLevel) == nil)
        }
    }

    @Test func adoptAndSelectHens() throws {
        let store = ProfileStore(storage: .inMemory())
        let dot = Hen.with(id: "dot")
        #expect(throws: ProfileError.self) { try store.select(dot) }
        store.seed(coins: 1_000)
        try store.adopt(dot)
        #expect(store.hen.id == "dot")
        #expect(store.coins == 1_000 - dot.price)
        #expect(throws: ProfileError.alreadyOwned) { try store.adopt(dot) }
        try store.select(Hen.with(id: "pepper"))
        #expect(store.hen.id == "pepper")
    }

    @Test func adoptingEveryHenEarnsFullCoop() throws {
        let store = ProfileStore(storage: .inMemory())
        store.seed(coins: 100_000)
        for hen in Hen.all.dropFirst() { try store.adopt(hen) }
        #expect(store.profile.has(.fullCoop))
    }

    @Test func crossingUnlocksNextAndKeepsBestStars() {
        let store = ProfileStore(storage: .inMemory())
        let spec = CrossingSpec.all[0]
        let three = StarRule.thresholds(for: spec).three
        let reward = store.record(result(.crossing(0), banked: three))
        #expect(reward.stars == 3)
        #expect(reward.unlockedCrossing == 1)
        #expect(reward.newAchievements.contains(.firstSteps))
        #expect(store.profile.isUnlocked(crossing: 1))
        store.record(result(.crossing(0), banked: 10))
        #expect(store.profile.stars[0] == 3)
    }

    @Test func failedCrossingKeepsCoinsButNoStars() {
        let store = ProfileStore(storage: .inMemory())
        let reward = store.record(result(.crossing(0), crossed: false, banked: 80))
        #expect(reward.stars == 0)
        #expect(reward.coins == 10)
        #expect(store.coins == PlayerProfile.startingCoins + 10)
        #expect(!store.profile.isUnlocked(crossing: 1))
    }

    @Test func coinsFormula() {
        let r = result(.crossing(0), banked: 160, kernels: 4)
        #expect(r.coinsEarned == 20 + 4 + 25)
    }

    @Test func longRoadAndDailyBests() {
        let store = ProfileStore(storage: .inMemory())
        store.record(result(.longRoad, crossed: false, banked: 400, lanes: 64))
        #expect(store.profile.bestLongRoadScore == 400)
        #expect(store.profile.bestLongRoadLanes == 64)
        #expect(store.profile.has(.longHauler))
        let reward = store.record(result(.daily("2026-11-17"), banked: 300))
        #expect(reward.isNewBest)
        #expect(store.profile.dailyBest["2026-11-17"] == 300)
        #expect(store.profile.has(.dailyChores))
    }

    @Test func districtAchievementAndLongRoadUnlock() {
        let store = ProfileStore(storage: .inMemory())
        for i in 0..<CrossingSpec.perDistrict { store.record(result(.crossing(i))) }
        #expect(store.profile.has(.meadowLane))
        #expect(store.profile.longRoadUnlocked)
    }

    @Test func notAScratchNeedsLaterDistrict() {
        let store = ProfileStore(storage: .inMemory())
        store.record(result(.crossing(0), hits: 0))
        #expect(!store.profile.has(.notAScratch))
        store.record(result(.crossing(6), hits: 0))
        #expect(store.profile.has(.notAScratch))
    }

    @Test func historyIsTrimmed() {
        let store = ProfileStore(storage: .inMemory())
        for _ in 0..<(PlayerProfile.historyLimit + 5) { store.record(result(.longRoad, crossed: false)) }
        #expect(store.profile.history.count == PlayerProfile.historyLimit)
        #expect(store.profile.stats.runs == PlayerProfile.historyLimit + 5)
    }

    @Test func profileSurvivesRelaunch() throws {
        let storage = ProfileStorage.inMemory()
        let first = ProfileStore(storage: storage)
        first.seed(coins: 2_000)
        try first.buy(.bigBasket)
        first.record(result(.crossing(0)))
        let second = ProfileStore(storage: storage)
        #expect(second.profile == first.profile)
    }

    @Test func resetKeepsTutorialFlag() {
        let store = ProfileStore(storage: .inMemory())
        store.markTutorialSeen()
        store.record(result(.crossing(0)))
        store.reset()
        #expect(store.profile.stars[0] == 0)
        #expect(store.coins == PlayerProfile.startingCoins)
        #expect(store.profile.tutorialSeen)
    }

    @Test func runConfigUsesUpgradesAndHen() throws {
        let store = ProfileStore(storage: .inMemory())
        store.seed(coins: 100_000)
        try store.buy(.spareFeather)
        try store.adopt(Hen.with(id: "duchess"))
        let config = store.runConfig(for: .crossing(0))
        #expect(config.feathers == 5)
        #expect(config.kernelCoins == 2 + (store.shift.theme == .cornHarvest ? 2 : 0))
    }

    @Test func settingsPersist() {
        let defaults = UserDefaults(suiteName: "CluckCrossing.tests.settings")!
        defaults.removePersistentDomain(forName: "CluckCrossing.tests.settings")
        let a = SettingsStore(defaults: defaults)
        #expect(a.soundOn)
        a.soundOn = false
        a.leftHanded = true
        let b = SettingsStore(defaults: defaults)
        #expect(!b.soundOn)
        #expect(b.leftHanded)
    }
}

@MainActor
struct CatalogTests {
    @Test func thirtyCrossingsInFiveDistricts() {
        #expect(CrossingSpec.all.count == 30)
        #expect(District.all.count == 5)
    }

    @Test func difficultyAndLengthRise() {
        for i in 1..<CrossingSpec.count {
            #expect(CrossingSpec.all[i].difficulty > CrossingSpec.all[i - 1].difficulty)
            #expect(CrossingSpec.all[i].laneCount >= CrossingSpec.all[i - 1].laneCount)
        }
    }

    @Test func firstDistrictIsGentle() {
        for spec in CrossingSpec.all.prefix(6) {
            #expect(spec.hazards == .none)
            #expect(spec.laneCount <= 13)
        }
    }

    @Test func hazardsArriveOneDistrictAtATime() {
        #expect(CrossingSpec.all[6].hazards.cornTrucks && !CrossingSpec.all[6].hazards.sprinklers)
        #expect(CrossingSpec.all[12].hazards.sprinklers && !CrossingSpec.all[12].hazards.hotGravel)
        #expect(CrossingSpec.all[18].hazards.hotGravel && !CrossingSpec.all[18].hazards.fog)
        #expect(CrossingSpec.all[24].hazards.fog)
    }

    @Test func starsNeedRisk() {
        for spec in CrossingSpec.all {
            let t = StarRule.thresholds(for: spec)
            #expect(t.three > t.two)
            #expect(StarRule.noRoost(sections: spec.sections) >= t.three)
        }
    }

    @Test func dailyIsStablePerDay() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let key = DailyCrossing.key(for: date)
        #expect(key == DailyCrossing.key(for: date.addingTimeInterval(60)))
        #expect(DailyCrossing.seed(for: key) == DailyCrossing.seed(for: key))
        #expect(DailyCrossing.sections(seed: DailyCrossing.seed(for: key)).reduce(0, +) == DailyCrossing.laneCount)
    }

    @Test func generatedArtExists() {
        var names = ["logo_wordmark", "corner_backdrop", "coin", "egg", "feather", "kernel", "grain_token", "sprinkler", "sprinkler_gurgle", "spray",
                     "car_pickup", "car_tractor", "car_milkVan", "car_combine", "car_cornTruck", "plaque", "billboard_backdrop",
                     "vending_backdrop", "henhouse_backdrop", "timetable_backdrop", "photo_frame", "ribbon_0", "ribbon_off"]
        names += Hen.all.map(\.art)
        names += UpgradeKind.allCases.map(\.art)
        names += District.all.map(\.art)
        for name in names {
            #expect(UIImage(named: name) != nil, "missing asset \(name)")
        }
    }
}
