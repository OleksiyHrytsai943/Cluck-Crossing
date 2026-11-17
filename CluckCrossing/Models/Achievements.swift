import Foundation

/// Fair ribbons pinned to the barn wall. Coloured when earned.
enum Achievement: String, CaseIterable, Identifiable, Codable {
    case firstSteps
    case meadowLane, harvestRoad, orchardRow, sunbakedGravel, foggyHollow
    case tenInARow
    case heavyBasket
    case bellRinger
    case cornCollector
    case starHarvest
    case longHauler
    case dailyChores
    case notAScratch
    case fullCoop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstSteps: "First Steps"
        case .meadowLane: "Meadow Lane"
        case .harvestRoad: "Harvest Road"
        case .orchardRow: "Orchard Row"
        case .sunbakedGravel: "Sunbaked Gravel"
        case .foggyHollow: "Foggy Hollow"
        case .tenInARow: "Ten in a Row"
        case .heavyBasket: "Heavy Basket"
        case .bellRinger: "Bell Ringer"
        case .cornCollector: "Corn Collector"
        case .starHarvest: "Star Harvest"
        case .longHauler: "Long Hauler"
        case .dailyChores: "Daily Chores"
        case .notAScratch: "Not a Scratch"
        case .fullCoop: "Full Coop"
        }
    }

    var detail: String {
        switch self {
        case .firstSteps: "Finish your first crossing."
        case .meadowLane: "Finish every crossing on Meadow Lane."
        case .harvestRoad: "Finish every crossing on Harvest Road."
        case .orchardRow: "Finish every crossing on Orchard Row."
        case .sunbakedGravel: "Finish every crossing on Sunbaked Gravel."
        case .foggyHollow: "Finish every crossing in Foggy Hollow."
        case .tenInARow: "Cross 10 lanes in one streak without roosting."
        case .heavyBasket: "Roost a basket worth 300 or more."
        case .bellRinger: "Ring the farm bell 25 times."
        case .cornCollector: "Pick up 100 corn kernels."
        case .starHarvest: "Collect 45 stars."
        case .longHauler: "Cross 60 lanes in one Long Road."
        case .dailyChores: "Finish a Daily Crossing."
        case .notAScratch: "Finish a crossing from Harvest Road on without a bump."
        case .fullCoop: "Adopt every hen."
        }
    }

    /// Prize ribbon colour (art name suffix).
    var tint: Int { (Self.allCases.firstIndex(of: self) ?? 0) % 4 }

    static func district(_ index: Int) -> Achievement {
        [.meadowLane, .harvestRoad, .orchardRow, .sunbakedGravel, .foggyHollow][index]
    }
}
