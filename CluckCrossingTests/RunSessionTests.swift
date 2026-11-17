import Foundation
import Testing
@testable import CluckCrossing

/// An empty lane that never spawns traffic unless the test adds cars.
@MainActor
func quietLane(row: Int, direction: Int = 1, speed: Double = 1, hot: Bool = false) -> LaneState {
    var lane = LaneState(row: row, direction: direction, baseSpeed: speed, minGap: 2, maxGap: 3, busChance: 0, isHot: hot,
                         rng: SeededGenerator(seed: UInt64(row)))
    lane.spawnCountdown = 1_000_000
    return lane
}

@MainActor
func makeSession(_ rows: [RowKind], config: RunConfig = RunConfig(mode: .nightRun), configure: (inout [Int: LaneState]) -> Void = { _ in }) -> RunSession {
    var lanes: [Int: LaneState] = [:]
    for (i, kind) in rows.enumerated() where kind == .lane { lanes[i] = quietLane(row: i) }
    configure(&lanes)
    return RunSession(config: config, rows: rows, lanes: lanes)
}

@MainActor
func hop(_ session: RunSession, _ action: PilotAction) {
    session.update(RunConfig.hopCooldown + 0.01)
    session.hop(action)
}

@MainActor
struct ClutchClimbTests {
    @Test func eachLaneAddsMoreThanTheLast() {
        let s = makeSession([.curb, .lane, .lane, .lane, .island, .lane, .finish])
        hop(s, .forward); hop(s, .forward); hop(s, .forward)
        #expect(s.clutch == 10 + 12 + 14)
        #expect(s.clutchEggs == 3)
        #expect(s.streak == 3)
        #expect(s.banked == 0)
    }

    @Test func roostBanksOnlyOnSafeRows() {
        let s = makeSession([.curb, .lane, .lane, .island, .lane, .finish])
        hop(s, .forward)
        #expect(s.roost() == false)
        hop(s, .forward); hop(s, .forward)
        #expect(s.roost())
        #expect(s.banked == 22)
        #expect(s.clutch == 0)
        #expect(s.streak == 0)
        #expect(s.roost() == false)
    }

    @Test func skippingIslandsKeepsTheMultiplierClimbing() {
        let s = makeSession([.curb, .lane, .lane, .island, .lane, .lane, .finish])
        for _ in 0..<6 { hop(s, .forward) }
        // Streak never reset: 10 + 12 + (island) + 14 + 16, auto-roosted on the far curb.
        #expect(s.outcome == .crossed)
        #expect(s.banked == 52)
    }

    @Test func projectedMultiplierShowsTheLadderAhead() {
        let s = makeSession([.curb, .lane, .lane, .island, .lane, .finish])
        #expect(s.projectedMultiplier(row: 1) == 1.0)
        #expect(s.projectedMultiplier(row: 2) == 1.2)
        #expect(s.projectedMultiplier(row: 3) == nil)
        #expect(abs((s.projectedMultiplier(row: 4) ?? 0) - 1.4) < 0.0001)
    }

    @Test func multiplierIsCapped() {
        let s = makeSession([.curb])
        #expect(s.multiplier(forStreak: 100) == 6)
    }

    @Test func hopsBackDoNotScoreTwice() {
        let s = makeSession([.curb, .lane, .lane, .finish])
        hop(s, .forward); hop(s, .back); hop(s, .forward)
        #expect(s.clutch == 10)
        #expect(s.lanesCrossed == 1)
    }

    @Test func hopCooldownBlocksSpam() {
        let s = makeSession([.curb, .lane, .lane, .finish])
        s.update(0.2)
        #expect(s.hop(.forward))
        #expect(s.hop(.forward) == false)
    }

    @Test func basketUpgradeRaisesEveryLane() {
        var config = RunConfig(mode: .nightRun)
        config.basketBonus = 0.5
        let s = makeSession([.curb, .lane, .island], config: config)
        hop(s, .forward)
        #expect(s.clutch == 15)
    }
}

@MainActor
struct BumpTests {
    @Test func carBumpCostsFeatherAndClutchAndSendsHenBack() {
        let s = makeSession([.curb, .lane, .lane, .island]) { lanes in
            lanes[2]?.cars = [Car(id: 1, kind: .sedan, x: 2.0)]
        }
        hop(s, .forward)
        #expect(s.clutch == 10)
        hop(s, .forward)
        #expect(s.feathers == 2)
        #expect(s.clutch == 0)
        #expect(s.row == 0)
        #expect(s.hits == 1)
        #expect(s.drainEvents().contains(.hit(cause: .car(.sedan), lostClutch: 22)))
    }

    @Test func bumpRespawnsOnLastIslandAndLanesScoreAgain() {
        let s = makeSession([.curb, .lane, .island, .lane, .lane, .finish]) { lanes in
            lanes[4]?.cars = [Car(id: 1, kind: .van, x: 2.0)]
        }
        hop(s, .forward); hop(s, .forward); s.roost()
        hop(s, .forward); hop(s, .forward)
        #expect(s.row == 2)
        #expect(s.isInvulnerable)
        hop(s, .forward)
        #expect(s.clutch == 10)
        #expect(s.lanesCrossed == 3)
    }

    @Test func invulnerabilityWearsOff() {
        let s = makeSession([.curb, .lane, .finish]) { lanes in
            lanes[1]?.cars = [Car(id: 1, kind: .bus, x: 1.0)]
        }
        hop(s, .forward)
        #expect(s.feathers == 2)
        #expect(s.isInvulnerable)
        s.update(2)
        #expect(!s.isInvulnerable)
    }

    @Test func runEndsWhenFeathersRunOut() {
        var config = RunConfig(mode: .nightRun)
        config.feathers = 1
        let s = makeSession([.curb, .lane, .finish], config: config) { lanes in
            lanes[1]?.cars = [Car(id: 1, kind: .sedan, x: 2.0)]
        }
        hop(s, .forward)
        #expect(s.outcome == .outOfFeathers)
        #expect(s.hop(.forward) == false)
    }

    @Test func carsMoveAndHitStandingHen() {
        let s = makeSession([.curb, .lane, .finish]) { lanes in
            lanes[1]?.cars = [Car(id: 1, kind: .sedan, x: -0.5)]
        }
        hop(s, .forward)
        #expect(s.feathers == 3)
        for _ in 0..<30 { s.update(0.1) }
        #expect(s.feathers == 2)
    }
}

@MainActor
struct ManholeTests {
    @Test func phasesCycle() {
        let m = Manhole(column: 1, idleTime: 2, offset: 0)
        #expect(m.phase(at: 1) == .idle)
        #expect(m.phase(at: 2.5) == .glow)
        #expect(m.phase(at: 3.2) == .flare)
        #expect(m.phase(at: m.period + 0.5) == .idle)
    }

    @Test func flareBumpsButGlowDoesNot() {
        let s = makeSession([.curb, .lane, .finish]) { lanes in
            lanes[1]?.manhole = Manhole(column: 2, idleTime: 0.1, offset: 0)
        }
        // At t≈0.12 the lid glows: standing on it is still allowed.
        hop(s, .forward)
        #expect(s.feathers == 3)
        // Glow ends at 1.0 → flare.
        s.update(0.95)
        #expect(s.feathers == 2)
    }

    @Test func otherColumnsAreSafe() {
        let s = makeSession([.curb, .lane, .finish]) { lanes in
            lanes[1]?.manhole = Manhole(column: 0, idleTime: 0.1, offset: 0)
        }
        hop(s, .forward)
        s.update(1.5)
        #expect(s.feathers == 3)
    }
}

@MainActor
struct WhistleTests {
    @Test func grainFillsFromLanesAndKernels() {
        let s = makeSession([.curb, .lane, .lane, .finish])
        hop(s, .forward)
        #expect(abs(s.grain - RunConfig.grainPerLane) < 0.0001)
    }

    @Test func whistleNeedsFullGrain() {
        let s = makeSession([.curb, .lane, .finish])
        #expect(s.whistle() == false)
    }

    @Test func whistleFreezesThreeLanesThenTheyRush() {
        var config = RunConfig(mode: .nightRun)
        config.startGrain = 1
        let s = makeSession([.curb, .lane, .lane, .lane, .lane, .finish], config: config) { lanes in
            for r in 1...4 { lanes[r]?.cars = [Car(id: r, kind: .sedan, x: -1)] }
        }
        s.update(0.01)
        #expect(s.whistle())
        #expect(s.grain == 0)
        #expect(s.whistles == 1)
        let x1 = s.lane(1)!.cars[0].x
        let x4 = s.lane(4)!.cars[0].x
        s.update(1)
        #expect(s.lane(1)!.cars[0].x == x1)
        #expect(s.lane(4)!.cars[0].x > x4)
        s.update(1.2)
        let lane = s.lane(1)!
        #expect(lane.isRushing(at: s.time))
        #expect(lane.speed(at: s.time) == lane.baseSpeed * RunConfig.rushFactor)
        s.update(3.5)
        #expect(s.lane(1)!.speed(at: s.time) == s.lane(1)!.baseSpeed)
    }

    @Test func longWhistleUpgradeExtendsFreeze() {
        let config = RunConfig.make(mode: .nightRun, upgrades: [.longWhistle: 2], hen: Hen.with(id: "pepper"), seed: 1)
        #expect(config.whistleDuration == 3)
    }
}

@MainActor
struct CornTruckTests {
    @Test func truckHonksRollsAndSpillsKernels() {
        let s = makeSession([.curb, .lane, .finish]) { lanes in
            lanes[1]?.truck = .waiting(0.05)
        }
        s.update(0.1)
        #expect(s.drainEvents().contains(.honk(row: 1)))
        #expect(s.lane(1)!.truckHonking)
        for _ in 0..<15 { s.update(0.1) }
        #expect(s.lane(1)!.cars.contains { $0.kind == .cornTruck })
        for _ in 0..<100 { s.update(0.1) }
        #expect(!s.lane(1)!.kernels.isEmpty || s.lane(1)!.cars.contains { $0.kind == .cornTruck })
    }

    @Test func kernelPaysGrainCoinsAndCoolsFeet() {
        var config = RunConfig(mode: .nightRun)
        config.kernelCoins = 3
        let s = makeSession([.curb, .lane, .finish], config: config) { lanes in
            lanes[1]?.kernels = [Kernel(id: 9, column: 2, expires: 100)]
        }
        hop(s, .forward)
        #expect(s.kernels == 1)
        #expect(s.kernelCoins == 3)
        #expect(abs(s.grain - (RunConfig.grainPerKernel + RunConfig.grainPerLane)) < 0.0001)
        #expect(s.lane(1)!.kernels.isEmpty)
    }

    @Test func kernelsExpire() {
        let s = makeSession([.curb, .lane, .finish]) { lanes in
            lanes[1]?.kernels = [Kernel(id: 9, column: 2, expires: 1)]
        }
        s.update(1.5)
        #expect(s.lane(1)!.kernels.isEmpty)
    }
}

@MainActor
struct HotAsphaltTests {
    @Test func heatBuildsOnHotLaneAndForcesHop() {
        var config = RunConfig(mode: .nightRun)
        config.heatRate = 0.5
        let s = makeSession([.curb, .lane, .lane, .finish], config: config) { lanes in
            lanes[1] = quietLane(row: 1, hot: true)
        }
        hop(s, .forward)
        #expect(s.heatActive)
        s.update(1.0)
        #expect(s.heat > 0.4)
        s.update(1.2)
        #expect(s.row == 2)
        #expect(s.forcedHops == 1)
    }

    @Test func islandsCoolTheFeet() {
        var config = RunConfig(mode: .nightRun)
        config.heatRate = 0.5
        let s = makeSession([.curb, .lane, .island, .finish], config: config) { lanes in
            lanes[1] = quietLane(row: 1, hot: true)
        }
        hop(s, .forward)
        s.update(1.0)
        let hot = s.heat
        hop(s, .forward)
        s.update(0.5)
        #expect(s.heat < hot)
    }

    @Test func coolLanesDoNotHeat() {
        let s = makeSession([.curb, .lane, .finish])
        hop(s, .forward)
        s.update(3)
        #expect(s.heat == 0)
    }

    @Test func coolFeetAndSunnyReduceHeatRate() {
        let base = RunConfig.make(mode: .nightRun, upgrades: [:], hen: Hen.with(id: "pepper"), seed: 1)
        let geared = RunConfig.make(mode: .nightRun, upgrades: [.coolFeet: 2], hen: Hen.with(id: "sunny"), seed: 1)
        #expect(geared.heatRate < base.heatRate * 0.65)
    }
}

@MainActor
struct RoadTests {
    @Test func fixedRoadMatchesSections() {
        let s = RunSession(config: RunConfig.make(mode: .crossing(0), upgrades: [:], hen: Hen.with(id: "pepper")))
        let spec = CrossingSpec.all[0]
        #expect(s.rows.filter { $0 == .lane }.count == spec.laneCount)
        #expect(s.rows.first == .curb)
        #expect(s.rows.last == .finish)
        #expect(s.rows.filter { $0 == .island }.count == spec.sections.count - 1)
    }

    @Test func cannotHopPastTheFinish() {
        let s = makeSession([.curb, .lane, .finish])
        hop(s, .forward); hop(s, .forward)
        #expect(s.outcome == .crossed)
        #expect(s.row == 2)
    }

    @Test func nightRunKeepsExtending() {
        let s = RunSession(config: RunConfig.make(mode: .nightRun, upgrades: [:], hen: Hen.with(id: "pepper"), seed: 7))
        let start = s.rows.count
        var steps = 0
        while s.row < 30, steps < 20_000, s.isRunning {
            s.update(1.0 / 30)
            if let action = s.autopilotAction() { s.hop(action) }
            steps += 1
        }
        #expect(s.rows.count >= start)
        #expect(s.rows.count >= s.row + 40 || !s.isRunning)
    }

    @Test func sameSeedSameTraffic() {
        let a = RunSession(config: RunConfig.make(mode: .crossing(10), upgrades: [:], hen: Hen.with(id: "pepper")))
        let b = RunSession(config: RunConfig.make(mode: .crossing(10), upgrades: [:], hen: Hen.with(id: "pepper")))
        #expect(a.rows == b.rows)
        #expect(a.lane(1)?.cars.map(\.x) == b.lane(1)?.cars.map(\.x))
    }

    @Test func lanesAlwaysLeaveCrossableGaps() {
        for spec in CrossingSpec.all {
            let s = RunSession(config: RunConfig.make(mode: .crossing(spec.id), upgrades: [:], hen: Hen.with(id: "pepper")))
            for (_, lane) in s.lanes {
                #expect(lane.minGap >= 1.5)
                #expect(lane.baseSpeed < 4.2)
            }
        }
    }

    @Test func autopilotCanFinishEarlyCrossings() {
        for index in 0..<8 {
            let s = RunSession(config: RunConfig.make(mode: .crossing(index), upgrades: [:], hen: Hen.with(id: "pepper")))
            var steps = 0
            while s.isRunning, steps < 30 * 240 {
                s.update(1.0 / 30)
                if let action = s.autopilotAction() { s.hop(action) }
                steps += 1
            }
            #expect(s.outcome == .crossed, "crossing \(index) not finished")
        }
    }
}
