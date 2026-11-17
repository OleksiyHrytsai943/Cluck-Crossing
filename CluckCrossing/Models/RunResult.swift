import Foundation

/// Everything a finished run reports to the profile.
struct RunResult: Equatable, Codable {
    var mode: RunMode
    var crossed: Bool
    var banked: Int
    var lanesCrossed: Int
    var bestStreak: Int
    var bestRoost: Int
    var eggsBanked: Int
    var kernels: Int
    var kernelCoins: Int
    var whistles: Int
    var hits: Int
    var roosts: Int
    var forcedHops: Int
    var duration: Double

    /// Coins: banked eggs convert 8:1, kernels pay their own coins, finishing a crossing adds a bonus.
    var coinsEarned: Int {
        banked / 8 + kernelCoins + (crossed ? 25 : 0)
    }

    /// Campaign stars: 1 for crossing, 2 for reaching par, 3 for a daring score (only possible by skipping islands).
    var stars: Int {
        guard crossed, case .crossing(let index) = mode else { return 0 }
        return StarRule.stars(banked: banked, spec: CrossingSpec.all[index])
    }
}

enum StarRule {
    /// Score of a careful player who roosts on every island, with no upgrades.
    static func par(sections: [Int]) -> Int {
        var total = 0.0
        for size in sections {
            for n in 1...max(1, size) {
                total += RunConfig.lanePoints * (1 + 0.2 * Double(n - 1))
            }
        }
        return Int(total.rounded())
    }

    /// Score of a daredevil who never roosts until the far curb.
    static func noRoost(sections: [Int]) -> Int {
        let lanes = sections.reduce(0, +)
        var total = 0.0
        for n in 1...max(1, lanes) {
            total += RunConfig.lanePoints * min(6, 1 + 0.2 * Double(n - 1))
        }
        return Int(total.rounded())
    }

    /// Two stars = par; three stars = halfway between par and the no-roost score.
    static func thresholds(for spec: CrossingSpec) -> (two: Int, three: Int) {
        let par = par(sections: spec.sections)
        let daring = noRoost(sections: spec.sections)
        return (par, par + max(1, (daring - par) / 2))
    }

    static func stars(banked: Int, spec: CrossingSpec) -> Int {
        let t = thresholds(for: spec)
        if banked >= t.three { return 3 }
        if banked >= t.two { return 2 }
        return 1
    }
}
