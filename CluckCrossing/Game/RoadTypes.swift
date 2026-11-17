import Foundation

/// A horizontal strip of the road. The hen moves bottom → top through these.
enum RowKind: Equatable {
    case curb
    case lane
    /// Hay strip: safe, cools the feet, the only place to Roost.
    case island
    case finish

    var isSafe: Bool { self != .lane }
}

enum CarKind: String, CaseIterable {
    case pickup, tractor, milkVan, combine, cornTruck

    /// Length in road columns (the hen is one column wide).
    var length: Double {
        switch self {
        case .pickup, .tractor: 1.15
        case .milkVan: 1.5
        case .combine: 2.3
        case .cornTruck: 2.6
        }
    }
}

struct Car: Identifiable, Equatable {
    let id: Int
    let kind: CarKind
    /// Left edge in columns; the visible road spans 0…5.
    var x: Double
    /// Columns the corn truck has already dropped kernels on.
    var spilled: Set<Int> = []

    var length: Double { kind.length }
}

enum SprinklerPhase: Equatable { case idle, gurgle, spray }

/// Sprinkler Bursts: a sprinkler on one column that gurgles (warning) and then sprays (dangerous) on a loop.
struct Sprinkler: Equatable {
    static let gurgleTime = 0.9
    static let sprayTime = 0.8

    let column: Int
    let idleTime: Double
    let offset: Double

    var period: Double { idleTime + Self.gurgleTime + Self.sprayTime }

    func phase(at time: Double) -> SprinklerPhase {
        let p = (time + offset).truncatingRemainder(dividingBy: period)
        if p < idleTime { return .idle }
        if p < idleTime + Self.gurgleTime { return .gurgle }
        return .spray
    }
}

/// Corn Truck Spill cycle for a lane.
enum TruckPhase: Equatable {
    case none
    case waiting(Double)
    /// Horn telegraph before the truck rolls in.
    case honking(Double)
    case rolling(carID: Int)
}

struct Kernel: Identifiable, Equatable {
    let id: Int
    let column: Int
    let expires: Double
}

struct LaneState {
    let row: Int
    /// +1 drives to the right, −1 to the left.
    let direction: Int
    let baseSpeed: Double
    let minGap: Double
    let maxGap: Double
    let combineChance: Double
    /// Hot Gravel heats the feet on this lane.
    let isHot: Bool
    var cars: [Car] = []
    var spawnCountdown = 0.0
    var sprinkler: Sprinkler?
    var truck: TruckPhase = .none
    var spillColumns: [Int] = []
    var kernels: [Kernel] = []
    var frozenUntil = -Double.infinity
    var rushUntil = -Double.infinity
    var rng: SeededGenerator

    func isFrozen(at time: Double) -> Bool { time < frozenUntil }
    func isRushing(at time: Double) -> Bool { time >= frozenUntil && time < rushUntil }

    func speed(at time: Double) -> Double {
        if isFrozen(at: time) { return 0 }
        return isRushing(at: time) ? baseSpeed * RunConfig.rushFactor : baseSpeed
    }

    func isOffRoad(_ car: Car) -> Bool {
        direction > 0 ? car.x > Double(RunConfig.columns) + 1 : car.x + car.length < -1
    }

    var truckHonking: Bool {
        if case .honking = truck { return true }
        return false
    }
}

enum HitCause: Equatable {
    case car(CarKind)
    case spray
}

/// Things that happened during an update; the scene turns them into effects and sounds.
enum RunEvent: Equatable {
    case hop(row: Int, column: Int, forced: Bool)
    case laneScored(row: Int, points: Int, multiplier: Double)
    case roosted(amount: Int)
    case kernel(row: Int, column: Int)
    case bell(rows: [Int])
    case honk(row: Int)
    case hit(cause: HitCause, lostClutch: Int)
    case finished
    case outOfFeathers
}

enum RunOutcome: Equatable {
    case crossed
    case outOfFeathers
}

enum PilotAction: Equatable {
    case forward, back, left, right, roost, bell
}
