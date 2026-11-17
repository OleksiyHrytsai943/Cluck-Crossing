import Foundation
import Testing
@testable import CluckCrossing

@MainActor
final class Clock {
    var date: Date
    init(_ date: Date) { self.date = date }
}

/// Wednesday 2026-11-18 12:00 UTC (ISO week 47).
private let wednesday = Date(timeIntervalSince1970: 1_795_003_200)

@MainActor
private func crossing(banked: Int) -> RunResult {
    RunResult(mode: .crossing(0), crossed: true, banked: banked, lanesCrossed: 5, bestStreak: 3, bestRoost: 40, eggsBanked: 5,
              kernels: 0, kernelCoins: 0, whistles: 0, hits: 0, roosts: 1, forcedHops: 0, duration: 20)
}

@MainActor
struct NightShiftTests {
    @Test func weekKeyAndThemeAreStableWithinAWeek() {
        let a = NightShift.current(at: wednesday)
        let b = NightShift.current(at: wednesday.addingTimeInterval(2 * 86_400))
        #expect(a == b)
        #expect(a.weekKey == "2026-W47")
        #expect(a.daysLeft(from: wednesday) == 5)
    }

    @Test func themeRotatesWeekly() {
        let themes = (0..<4).map { NightShift.current(at: wednesday.addingTimeInterval(Double($0) * 7 * 86_400)).theme }
        #expect(Set(themes).count == 4)
    }

    @Test func everyThemeChangesTheRunConfig() {
        let base = RunConfig(mode: .nightRun)
        for theme in ShiftTheme.allCases {
            var config = base
            theme.apply(to: &config)
            #expect(config != base, "\(theme) changes nothing")
        }
    }

    @Test func storeAppliesThisWeeksTheme() {
        let clock = Clock(wednesday)
        let store = ProfileStore(storage: .inMemory(), now: { clock.date })
        var expected = RunConfig.make(mode: .crossing(0), upgrades: [:], hen: Hen.with(id: "pepper"))
        store.shift.theme.apply(to: &expected)
        #expect(store.runConfig(for: .crossing(0)) == expected)
    }

    @Test func runsLightOneLampPerNightAndTrackWeeklyBest() {
        let clock = Clock(wednesday)
        let store = ProfileStore(storage: .inMemory(), now: { clock.date })
        store.record(crossing(banked: 100))
        store.record(crossing(banked: 300))
        #expect(store.lampsLitThisWeek == 1)
        #expect(store.weeklyBest == 300)
        clock.date = wednesday.addingTimeInterval(86_400)
        store.record(crossing(banked: 50))
        #expect(store.lampsLitThisWeek == 2)
        #expect(store.weeklyBest == 300)
        // Next week starts dark.
        clock.date = wednesday.addingTimeInterval(7 * 86_400)
        #expect(store.lampsLitThisWeek == 0)
        #expect(store.weeklyBest == 0)
    }

    @Test func lampTiersClaimOncePerWeek() throws {
        let clock = Clock(wednesday)
        let store = ProfileStore(storage: .inMemory(), now: { clock.date })
        let tier = LampLighter.tiers[0]
        #expect(throws: ProfileError.lampsNotLit(needed: 3)) { try store.claimLamps(tier) }
        store.seedLamps(3)
        let before = store.coins
        try store.claimLamps(tier)
        #expect(store.coins == before + tier.coins)
        #expect(throws: ProfileError.alreadyClaimed) { try store.claimLamps(tier) }
        #expect(throws: ProfileError.lampsNotLit(needed: 2)) { try store.claimLamps(LampLighter.tiers[1]) }
    }

    @Test func previewRosterIsTopFiveWithThePlayerAndFlagged() async throws {
        let shift = NightShift.current(at: wednesday)
        let provider = PreviewLeaderboardProvider()
        let page = try await provider.weeklyTop(for: shift, player: PlayerStanding(name: "You", hen: "hen_dot", weeklyBest: 5_000),
                                                lampsLit: 2, now: wednesday)
        #expect(page.isPreview)
        #expect(page.entries.count == 5)
        #expect(page.entries.map(\.rank) == [1, 2, 3, 4, 5])
        #expect(page.entries.first?.isPlayer == true)
        #expect(page.entries.map(\.score) == page.entries.map(\.score).sorted(by: >))
        #expect(page.rewards == RosterRewardSlot.weekly)
        #expect(page.lampsLit == 2)
    }

    @Test func previewRosterHidesPlayerWithoutRuns() async throws {
        let shift = NightShift.current(at: wednesday)
        let page = try await PreviewLeaderboardProvider().weeklyTop(for: shift, player: PlayerStanding(name: "You", hen: "hen_dot", weeklyBest: 0),
                                                                     lampsLit: 0, now: wednesday)
        #expect(!page.entries.contains { $0.isPlayer })
    }

    @Test func rosterTemplateIsBundled() {
        let app = Bundle(for: ProfileStore.self)
        #expect(app.url(forResource: "top_players", withExtension: "html") != nil)
        for hen in Hen.all {
            #expect(app.url(forResource: "roster_\(hen.art)", withExtension: "png") != nil)
        }
    }
}
