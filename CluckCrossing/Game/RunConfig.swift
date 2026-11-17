import Foundation

/// Tunables for one run, derived from the mode, upgrades and the chosen hen.
struct RunConfig: Equatable {
    var mode: RunMode
    var feathers = 3
    /// Heat gained per second on hot gravel (0 disables Hot Gravel for this road).
    var heatRate = 0.16
    var bellDuration = 2.0
    /// Seconds a frozen lane rushes at 1.6× after the bell wears off.
    var rushDuration = 3.0
    var basketBonus = 0.0
    var multiplierStep = 0.2
    var startGrain = 0.0
    var invulnerability = 1.5
    var kernelCoins = 1
    /// Practice-free knobs used by tests.
    var seed: UInt64 = 1

    static let columns = 5
    static let lanePoints = 10.0
    static let grainPerLane = 0.06
    static let grainPerKernel = 0.25
    static let heatPerKernel = -0.3
    static let rushFactor = 1.6
    static let hopCooldown = 0.11

    /// Builds the config the game uses for a real run.
    static func make(mode: RunMode, upgrades: [UpgradeKind: Int], hen: Hen, seed: UInt64? = nil) -> RunConfig {
        func level(_ kind: UpgradeKind) -> Int { upgrades[kind] ?? 0 }
        var config = RunConfig(mode: mode)
        config.feathers = 3 + level(.spareFeather) + hen.perk.extraFeathers
        config.heatRate = 0.16 * (1 - 0.12 * Double(level(.coolFeet))) * hen.perk.heatFactor
        config.bellDuration = 2.0 + 0.5 * Double(level(.bigBell))
        config.basketBonus = 0.06 * Double(level(.bigBasket))
        config.multiplierStep = 0.2 + hen.perk.multiplierStepBonus
        config.startGrain = hen.perk.startGrain
        config.invulnerability = 1.5 + hen.perk.invulnerabilityBonus
        config.kernelCoins = 1 + level(.cornPouch) + hen.perk.kernelCoinBonus
        switch mode {
        case .crossing(let index): config.seed = seed ?? CrossingSpec.all[index].seed
        case .daily(let key): config.seed = seed ?? DailyCrossing.seed(for: key)
        case .longRoad: config.seed = seed ?? UInt64.random(in: 1...UInt64.max)
        }
        return config
    }
}
