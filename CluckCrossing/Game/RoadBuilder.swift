import Foundation

/// Lays out rows and generates lane traffic. Fixed roads (crossings, daily) are built up front;
/// the Long Road keeps appending segments with rising difficulty.
struct RoadBuilder {
    enum Plan: Equatable {
        case fixed(sections: [Int], difficulty: Double, hazards: HazardSet)
        case endless
    }

    let plan: Plan
    private var rng: SeededGenerator
    private var lastDirection = 1

    init(plan: Plan, seed: UInt64) {
        self.plan = plan
        rng = SeededGenerator(seed: seed)
    }

    static func plan(for mode: RunMode) -> Plan {
        switch mode {
        case .crossing(let index):
            let spec = CrossingSpec.all[index]
            return .fixed(sections: spec.sections, difficulty: spec.difficulty, hazards: spec.hazards)
        case .daily(let key):
            return .fixed(sections: DailyCrossing.sections(seed: DailyCrossing.seed(for: key)), difficulty: 0.62,
                          hazards: HazardSet(cornTrucks: true, sprinklers: true, hotGravel: true, fog: false))
        case .longRoad:
            return .endless
        }
    }

    /// Long Road ramps from gentle to expressway over ~150 rows and unlocks hazards on the way.
    static func endlessDifficulty(row: Int) -> Double { min(1, 0.08 + Double(row) / 160) }

    static func endlessHazards(row: Int) -> HazardSet {
        HazardSet(cornTrucks: row >= 14, sprinklers: row >= 28, hotGravel: row >= 45, fog: false)
    }

    /// Builds the whole fixed road, or the first stretch of an endless one.
    mutating func start(rows: inout [RowKind], lanes: inout [Int: LaneState]) {
        rows = [.curb]
        switch plan {
        case .fixed(let sections, let difficulty, let hazards):
            let total = Double(sections.reduce(0, +))
            var laneIndex = 0
            for (i, size) in sections.enumerated() {
                for _ in 0..<size {
                    let row = rows.count
                    rows.append(.lane)
                    // Slight ramp toward the far curb.
                    let d = min(1, difficulty + 0.06 * Double(laneIndex) / max(1, total))
                    lanes[row] = makeLane(row: row, difficulty: d, hazards: hazards)
                    laneIndex += 1
                }
                rows.append(i == sections.count - 1 ? .finish : .island)
            }
        case .endless:
            extend(rows: &rows, lanes: &lanes, until: 40)
        }
    }

    /// Appends endless segments until the road is at least `count` rows long.
    mutating func extend(rows: inout [RowKind], lanes: inout [Int: LaneState], until count: Int) {
        guard plan == .endless else { return }
        while rows.count < count {
            let difficulty = Self.endlessDifficulty(row: rows.count)
            let size = Int.random(in: 2...(2 + Int(difficulty * 4)), using: &rng)
            for _ in 0..<size {
                let row = rows.count
                rows.append(.lane)
                lanes[row] = makeLane(row: row, difficulty: Self.endlessDifficulty(row: row), hazards: Self.endlessHazards(row: row))
            }
            rows.append(.island)
        }
    }

    mutating func makeLane(row: Int, difficulty d: Double, hazards: HazardSet) -> LaneState {
        let direction = rng.chance(0.7) ? -lastDirection : lastDirection
        lastDirection = direction
        let minGap = max(1.5, 3.4 - 1.8 * d)
        var lane = LaneState(
            row: row,
            direction: direction,
            baseSpeed: (1.0 + 2.5 * d) * rng.double(in: 0.85...1.15),
            minGap: minGap,
            maxGap: minGap + max(1.2, 3.4 - 1.6 * d),
            combineChance: d > 0.35 ? 0.1 + 0.2 * d : 0,
            isHot: hazards.hotGravel,
            rng: SeededGenerator(seed: rng.next())
        )
        if hazards.sprinklers, rng.chance(0.4 + 0.25 * d) {
            lane.sprinkler = Sprinkler(
                column: Int.random(in: 0..<RunConfig.columns, using: &rng),
                idleTime: max(1.2, 3.0 - 1.4 * d) * rng.double(in: 0.9...1.2),
                offset: rng.double(in: 0...5)
            )
        }
        // Pre-roll traffic so the lane is already busy when it scrolls into view.
        var ids = row * 10_000
        for _ in 0..<50 {
            RoadBuilder.advance(&lane, by: 0.15, time: -100, nextID: &ids)
        }
        if hazards.cornTrucks, rng.chance(0.35 + 0.2 * d) {
            lane.truck = .waiting(rng.double(in: 2...9))
        }
        return lane
    }

    /// Moves traffic in one lane. Returns kernels dropped this step (handled by the session).
    @discardableResult
    static func advance(_ lane: inout LaneState, by dt: Double, time: Double, nextID: inout Int, onHonk: (() -> Void)? = nil) -> Int {
        let speed = lane.speed(at: time)
        let dx = Double(lane.direction) * speed * dt
        var dropped = 0
        for i in lane.cars.indices {
            lane.cars[i].x += dx
            if lane.cars[i].kind == .cornTruck {
                let center = lane.cars[i].x + lane.cars[i].length / 2
                for column in lane.spillColumns where !lane.cars[i].spilled.contains(column) {
                    let passed = lane.direction > 0 ? center >= Double(column) + 0.5 : center <= Double(column) + 0.5
                    if passed {
                        lane.cars[i].spilled.insert(column)
                        nextID += 1
                        lane.kernels.removeAll { $0.column == column }
                        lane.kernels.append(Kernel(id: nextID, column: column, expires: time + 7))
                        dropped += 1
                    }
                }
            }
        }
        let snapshot = lane
        let leaving = lane.cars.filter { snapshot.isOffRoad($0) }
        lane.cars.removeAll { snapshot.isOffRoad($0) }
        lane.kernels.removeAll { $0.expires <= time }

        // Corn truck cycle.
        switch lane.truck {
        case .none:
            break
        case .waiting(let remaining):
            lane.truck = remaining - dt <= 0 ? .honking(1.3) : .waiting(remaining - dt)
            if case .honking = lane.truck { onHonk?() }
        case .honking(let remaining):
            // Roll in once the entry edge is clear of other cars.
            let edgeClear = lane.cars.allSatisfy { lane.direction > 0 ? $0.x > 0.5 : $0.x + $0.length < Double(RunConfig.columns) - 0.5 }
            if remaining - dt <= 0, edgeClear {
                nextID += 1
                let truck = Car(id: nextID, kind: .cornTruck, x: lane.direction > 0 ? -CarKind.cornTruck.length - 0.5 : Double(RunConfig.columns) + 0.5)
                lane.cars.append(truck)
                var columns = Array(0..<RunConfig.columns)
                columns.shuffle(using: &lane.rng)
                lane.spillColumns = Array(columns.prefix(Int.random(in: 2...3, using: &lane.rng)))
                lane.truck = .rolling(carID: truck.id)
                lane.spawnCountdown = max(lane.spawnCountdown, truck.length + lane.minGap)
            } else {
                lane.truck = .honking(max(0, remaining - dt))
            }
        case .rolling(let id):
            if leaving.contains(where: { $0.id == id }) || !lane.cars.contains(where: { $0.id == id }) {
                lane.truck = .waiting(Double.random(in: 6...11, using: &lane.rng))
            }
        }

        // Regular traffic; held back while the truck honks so it has room to roll in.
        lane.spawnCountdown -= speed * dt
        if lane.spawnCountdown <= 0, !lane.truckHonking {
            let kind: CarKind
            if lane.rng.chance(lane.combineChance) {
                kind = .combine
            } else {
                kind = [.pickup, .pickup, .tractor, .milkVan].randomElement(using: &lane.rng) ?? .pickup
            }
            nextID += 1
            let x = lane.direction > 0 ? -kind.length - 0.5 : Double(RunConfig.columns) + 0.5
            lane.cars.append(Car(id: nextID, kind: kind, x: x))
            lane.spawnCountdown = kind.length + Double.random(in: lane.minGap...lane.maxGap, using: &lane.rng)
        }
        return dropped
    }
}
