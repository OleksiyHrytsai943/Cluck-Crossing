import Foundation

/// Passive bonus a hen brings to every run.
struct HenPerk: Equatable {
    var extraFeathers = 0
    var heatFactor = 1.0
    var multiplierStepBonus = 0.0
    var startGrain = 0.0
    var invulnerabilityBonus = 0.0
    var kernelCoinBonus = 0
}

struct Hen: Identifiable, Equatable {
    let id: String
    let name: String
    let breed: String
    let perkTitle: String
    let perkText: String
    let price: Int
    let perk: HenPerk

    var art: String { "hen_\(id)" }

    static let starter = "pepper"

    static let all: [Hen] = [
        Hen(id: "pepper", name: "Pepper", breed: "White Leghorn", perkTitle: "Street Smart",
            perkText: "Balanced. No tricks, no weaknesses.", price: 0, perk: HenPerk()),
        Hen(id: "dot", name: "Dot", breed: "Speckled Sussex", perkTitle: "Full Crop",
            perkText: "Starts every run with the whistle half full.", price: 450, perk: HenPerk(startGrain: 0.5)),
        Hen(id: "sunny", name: "Sunny", breed: "Buff Orpington", perkTitle: "Thick Socks",
            perkText: "Feet heat up 20% slower on hot asphalt.", price: 900, perk: HenPerk(heatFactor: 0.8)),
        Hen(id: "comet", name: "Comet", breed: "Red Rooster Racer", perkTitle: "Daredevil",
            perkText: "Clutch multiplier climbs +0.05 faster per lane.", price: 1_400, perk: HenPerk(multiplierStepBonus: 0.05)),
        Hen(id: "inkwell", name: "Inkwell", breed: "Black Australorp", perkTitle: "Shadow Step",
            perkText: "Stays untouchable 1 second longer after a bump.", price: 2_000, perk: HenPerk(invulnerabilityBonus: 1)),
        Hen(id: "duchess", name: "Duchess", breed: "Silkie", perkTitle: "Fluffy Armor",
            perkText: "One extra feather. Corn kernels pay +1 coin.", price: 2_800, perk: HenPerk(extraFeathers: 1, kernelCoinBonus: 1)),
    ]

    static func with(id: String) -> Hen {
        all.first { $0.id == id } ?? all[0]
    }
}
