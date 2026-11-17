import Foundation

/// Snapshot for the HUD (updated ~10 times a second).
struct RunSnapshot: Equatable {
    var banked = 0
    var clutch = 0
    var clutchEggs = 0
    var nextMultiplier = 1.0
    var streak = 0
    var feathers = 3
    var maxFeathers = 3
    var grain = 0.0
    var heat = 0.0
    var heatActive = false
    var canRoost = false
    var canWhistle = false
    var onSafeRow = true
    var lanesCrossed = 0
    /// 0…1 for fixed roads, nil in the Night Run.
    var progress: Double?
    var isInvulnerable = false
}

/// The full rules of one run, free of SpriteKit/SwiftUI so it can be unit-tested.
///
/// Signature mechanics:
/// 1. Clutch Climb & Roost – every new lane lays an egg worth more the longer the streak; only Roosting on an island banks it.
/// 2. Manhole Flares – lids glow, then flare.
/// 3. Crossing Guard Whistle – grain fills it; it freezes this lane and the next two, which then rush at 1.6×.
/// 4. Corn Truck Spill – a horn telegraphs a long truck that drops kernels (grain, coins, cool feet).
/// 5. Hot Asphalt – standing on a hot lane heats the feet; at full heat the hen hops forward on her own.
final class RunSession {
    let config: RunConfig
    private(set) var rows: [RowKind] = []
    private(set) var lanes: [Int: LaneState] = [:]
    private var builder: RoadBuilder

    private(set) var time = 0.0
    private(set) var row = 0
    private(set) var column = RunConfig.columns / 2
    private(set) var feathers: Int
    private(set) var banked = 0
    private(set) var clutch = 0.0
    private(set) var clutchEggs = 0
    private(set) var streak = 0
    private(set) var grain: Double
    private(set) var heat = 0.0
    private(set) var lastSafeRow = 0
    private(set) var scoredRow = 0
    private(set) var furthestRow = 0
    private(set) var invulnerableUntil = 0.0
    private var nextHopTime = 0.0
    private(set) var outcome: RunOutcome?

    // Stats for the result and achievements.
    private(set) var lanesCrossed = 0
    private(set) var bestStreak = 0
    private(set) var kernels = 0
    private(set) var kernelCoins = 0
    private(set) var whistles = 0
    private(set) var hits = 0
    private(set) var roosts = 0
    private(set) var bestRoost = 0
    private(set) var eggsBanked = 0
    private(set) var forcedHops = 0

    private var events: [RunEvent] = []
    private var nextID = 1

    init(config: RunConfig) {
        self.config = config
        feathers = config.feathers
        grain = min(1, config.startGrain)
        builder = RoadBuilder(plan: RoadBuilder.plan(for: config.mode), seed: config.seed)
        builder.start(rows: &rows, lanes: &lanes)
    }

    /// Test hook: build a session around a hand-made road.
    init(config: RunConfig, rows: [RowKind], lanes: [Int: LaneState]) {
        self.config = config
        feathers = config.feathers
        grain = min(1, config.startGrain)
        builder = RoadBuilder(plan: .fixed(sections: [], difficulty: 0, hazards: .none), seed: config.seed)
        self.rows = rows
        self.lanes = lanes
    }

    // MARK: Queries

    var isRunning: Bool { outcome == nil }
    var isFixedRoad: Bool { builder.plan != .endless }
    var kind: RowKind { kind(of: row) }
    var finishRow: Int? { isFixedRoad ? rows.count - 1 : nil }

    func kind(of row: Int) -> RowKind {
        guard row >= 0 else { return .curb }
        return row < rows.count ? rows[row] : .curb
    }

    func lane(_ row: Int) -> LaneState? { lanes[row] }

    /// Multiplier for the n-th lane of the current streak (1st lane ×1.0).
    func multiplier(forStreak n: Int) -> Double {
        min(6, 1 + config.multiplierStep * Double(max(0, n - 1)))
    }

    /// Multiplier shown on the plaque above an upcoming lane if the hen keeps going without roosting.
    func projectedMultiplier(row target: Int) -> Double? {
        guard kind(of: target) == .lane else { return nil }
        if target <= scoredRow { return nil }
        var n = streak
        for r in (scoredRow + 1)...target where kind(of: r) == .lane { n += 1 }
        return multiplier(forStreak: n)
    }

    var canRoost: Bool { kind.isSafe && clutch > 0 && isRunning }
    var canWhistle: Bool { grain >= 1 && isRunning }
    var isInvulnerable: Bool { time < invulnerableUntil }
    var heatActive: Bool { lanes[row]?.isHot == true && config.heatRate > 0 }

    var snapshot: RunSnapshot {
        RunSnapshot(
            banked: banked,
            clutch: Int(clutch.rounded()),
            clutchEggs: clutchEggs,
            nextMultiplier: multiplier(forStreak: streak + 1),
            streak: streak,
            feathers: feathers,
            maxFeathers: config.feathers,
            grain: grain,
            heat: heat,
            heatActive: heatActive,
            canRoost: canRoost,
            canWhistle: canWhistle,
            onSafeRow: kind.isSafe,
            lanesCrossed: lanesCrossed,
            progress: finishRow.map { Double(furthestRow) / Double(max(1, $0)) },
            isInvulnerable: isInvulnerable
        )
    }

    func drainEvents() -> [RunEvent] {
        defer { events.removeAll() }
        return events
    }

    // MARK: Simulation

    func update(_ dt: Double) {
        guard isRunning, dt > 0 else { return }
        time += dt
        builder.extend(rows: &rows, lanes: &lanes, until: row + 40)

        // Only lanes near the hen move; far lanes keep their pre-rolled traffic until they matter.
        for r in max(0, row - 10)...(row + 26) {
            guard var lane = lanes[r] else { continue }
            var honked = false
            RoadBuilder.advance(&lane, by: dt, time: time, nextID: &nextID) { honked = true }
            lanes[r] = lane
            if honked { events.append(.honk(row: r)) }
        }

        // Hot Asphalt.
        if heatActive {
            heat += config.heatRate * dt
            if heat >= 1 {
                heat = 0.3
                forcedHops += 1
                move(rowDelta: 1, columnDelta: 0, forced: true)
                guard isRunning else { return }
            }
        } else {
            heat = max(0, heat - 0.6 * dt)
        }

        checkHit()
    }

    // MARK: Player actions

    @discardableResult
    func hop(_ action: PilotAction) -> Bool {
        guard isRunning, time >= nextHopTime else { return false }
        switch action {
        case .forward: return move(rowDelta: 1, columnDelta: 0, forced: false)
        case .back: return move(rowDelta: -1, columnDelta: 0, forced: false)
        case .left: return move(rowDelta: 0, columnDelta: -1, forced: false)
        case .right: return move(rowDelta: 0, columnDelta: 1, forced: false)
        case .roost: return roost()
        case .whistle: return whistle()
        }
    }

    @discardableResult
    private func move(rowDelta: Int, columnDelta: Int, forced: Bool) -> Bool {
        let targetRow = row + rowDelta
        let targetColumn = column + columnDelta
        guard targetRow >= 0, (0..<RunConfig.columns).contains(targetColumn) else { return false }
        if let finishRow, targetRow > finishRow { return false }
        row = targetRow
        column = targetColumn
        nextHopTime = time + RunConfig.hopCooldown
        events.append(.hop(row: row, column: column, forced: forced))
        arrive()
        return true
    }

    private func arrive() {
        let here = kind
        if var lane = lanes[row], let index = lane.kernels.firstIndex(where: { $0.column == column }) {
            lane.kernels.remove(at: index)
            lanes[row] = lane
            kernels += 1
            kernelCoins += config.kernelCoins
            grain = min(1, grain + RunConfig.grainPerKernel)
            heat = max(0, heat + RunConfig.heatPerKernel)
            events.append(.kernel(row: row, column: column))
        }
        if row > scoredRow {
            for r in (scoredRow + 1)...row where kind(of: r) == .lane {
                streak += 1
                bestStreak = max(bestStreak, streak)
                let mult = multiplier(forStreak: streak)
                let points = RunConfig.lanePoints * mult * (1 + config.basketBonus)
                clutch += points
                clutchEggs += 1
                grain = min(1, grain + RunConfig.grainPerLane)
                events.append(.laneScored(row: r, points: Int(points.rounded()), multiplier: mult))
            }
            scoredRow = row
        }
        if row > furthestRow {
            for r in (furthestRow + 1)...row where kind(of: r) == .lane { lanesCrossed += 1 }
            furthestRow = row
        }
        if here.isSafe { lastSafeRow = row }
        if here == .finish {
            roost()
            outcome = .crossed
            events.append(.finished)
            return
        }
        checkHit()
    }

    @discardableResult
    func roost() -> Bool {
        guard kind.isSafe, clutch > 0 else { return false }
        let amount = Int(clutch.rounded())
        banked += amount
        bestRoost = max(bestRoost, amount)
        eggsBanked += clutchEggs
        roosts += 1
        clutch = 0
        clutchEggs = 0
        streak = 0
        events.append(.roosted(amount: amount))
        return true
    }

    @discardableResult
    func whistle() -> Bool {
        guard canWhistle else { return false }
        grain = 0
        whistles += 1
        var frozen: [Int] = []
        for r in row...(row + 2) {
            guard var lane = lanes[r] else { continue }
            lane.frozenUntil = time + config.whistleDuration
            lane.rushUntil = lane.frozenUntil + config.rushDuration
            lanes[r] = lane
            frozen.append(r)
        }
        events.append(.whistle(rows: frozen))
        return true
    }

    // MARK: Collisions

    private static let henHalfWidth = 0.28

    private func checkHit() {
        guard isRunning, !isInvulnerable, let lane = lanes[row] else { return }
        let left = Double(column) + 0.5 - Self.henHalfWidth
        let right = Double(column) + 0.5 + Self.henHalfWidth
        if let car = lane.cars.first(where: { $0.x < right && $0.x + $0.length > left }) {
            hit(.car(car.kind))
        } else if let manhole = lane.manhole, manhole.column == column, manhole.phase(at: time) == .flare {
            hit(.flare)
        }
    }

    private func hit(_ cause: HitCause) {
        hits += 1
        feathers -= 1
        let lost = Int(clutch.rounded())
        clutch = 0
        clutchEggs = 0
        streak = 0
        heat = 0
        events.append(.hit(cause: cause, lostClutch: lost))
        if feathers <= 0 {
            outcome = .outOfFeathers
            events.append(.outOfFeathers)
            return
        }
        // Back to the last island; the lanes since then can be scored again.
        row = lastSafeRow
        column = RunConfig.columns / 2
        scoredRow = lastSafeRow
        invulnerableUntil = time + config.invulnerability
    }

    /// Ends the run from the pause menu; banked eggs still count.
    func forfeit() {
        guard isRunning else { return }
        outcome = .outOfFeathers
    }

    // MARK: Prediction & autopilot

    /// True when the cell stays clear of cars and flares for the next `window` seconds.
    func isSafe(row target: Int, column c: Int, within window: Double) -> Bool {
        guard (0..<RunConfig.columns).contains(c) else { return false }
        guard let lane = lanes[target] else { return target >= 0 }
        let margin = 0.12
        let left = Double(c) + 0.5 - Self.henHalfWidth - margin
        let right = Double(c) + 0.5 + Self.henHalfWidth + margin
        var t = 0.0
        while t <= window {
            let at = time + t
            let dx = Double(lane.direction) * lane.speed(at: at) * t
            for car in lane.cars where car.x + dx < right && car.x + dx + car.length > left {
                return false
            }
            if let manhole = lane.manhole, manhole.column == c, manhole.phase(at: at) != .idle {
                return false
            }
            t += 0.05
        }
        // A corn truck about to roll in from the near edge.
        if lane.truckHonking {
            let entering = lane.direction > 0 ? c == 0 : c == RunConfig.columns - 1
            if entering { return false }
        }
        return true
    }

    /// A careful bot used by `--autopilot` (UI tests, store screenshots).
    func autopilotAction() -> PilotAction? {
        guard isRunning, time >= nextHopTime else { return nil }
        if kind.isSafe, clutch > 0, streak >= 3 || kind(of: row + 1).isSafe { return .roost }
        let forwardSafe = isSafe(row: row + 1, column: column, within: 0.6)
        if forwardSafe { return .forward }
        if canWhistle, kind(of: row + 1) == .lane { return .whistle }
        let hereSafe = isSafe(row: row, column: column, within: 0.4)
        let sideOrder: [PilotAction] = column >= RunConfig.columns / 2 ? [.left, .right] : [.right, .left]
        for side in sideOrder {
            let c = column + (side == .left ? -1 : 1)
            if isSafe(row: row, column: c, within: 0.45), isSafe(row: row + 1, column: c, within: 0.8) { return side }
        }
        if !hereSafe {
            if isSafe(row: row - 1, column: column, within: 0.5) { return .back }
            for side in sideOrder {
                let c = column + (side == .left ? -1 : 1)
                if isSafe(row: row, column: c, within: 0.45) { return side }
            }
        }
        return nil
    }

    // MARK: Result

    func makeResult() -> RunResult {
        RunResult(
            mode: config.mode,
            crossed: outcome == .crossed,
            banked: banked,
            lanesCrossed: lanesCrossed,
            bestStreak: bestStreak,
            bestRoost: bestRoost,
            eggsBanked: eggsBanked,
            kernels: kernels,
            kernelCoins: kernelCoins,
            whistles: whistles,
            hits: hits,
            roosts: roosts,
            forcedHops: forcedHops,
            duration: time
        )
    }
}
