import Foundation

/// Neon signs on the Billboard roof. Lit when earned.
enum Achievement: String, CaseIterable, Identifiable, Codable {
    case firstSteps
    case sleepyLane, marketStreet, steamQuarter, neonBoulevard, midnightExpressway
    case tenInARow
    case heavyBasket
    case crossingGuard
    case cornCollector
    case starryNight
    case nightOwl
    case dailyCommuter
    case notAScratch
    case fullCoop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstSteps: "First Steps"
        case .sleepyLane: "Sleepy Lane"
        case .marketStreet: "Market Street"
        case .steamQuarter: "Steam Quarter"
        case .neonBoulevard: "Neon Boulevard"
        case .midnightExpressway: "Expressway"
        case .tenInARow: "Ten in a Row"
        case .heavyBasket: "Heavy Basket"
        case .crossingGuard: "Crossing Guard"
        case .cornCollector: "Corn Collector"
        case .starryNight: "Starry Night"
        case .nightOwl: "Night Owl"
        case .dailyCommuter: "Commuter"
        case .notAScratch: "Not a Scratch"
        case .fullCoop: "Full Coop"
        }
    }

    var detail: String {
        switch self {
        case .firstSteps: "Finish your first crossing."
        case .sleepyLane: "Finish every crossing in Sleepy Lane."
        case .marketStreet: "Finish every crossing in Market Street."
        case .steamQuarter: "Finish every crossing in Steam Quarter."
        case .neonBoulevard: "Finish every crossing in Neon Boulevard."
        case .midnightExpressway: "Finish every crossing on the Midnight Expressway."
        case .tenInARow: "Cross 10 lanes in one streak without roosting."
        case .heavyBasket: "Roost a clutch worth 300 or more."
        case .crossingGuard: "Blow the whistle 25 times."
        case .cornCollector: "Pick up 100 corn kernels."
        case .starryNight: "Collect 45 stars."
        case .nightOwl: "Cross 60 lanes in one Night Run."
        case .dailyCommuter: "Finish a Daily Crossing."
        case .notAScratch: "Finish a crossing from Market Street on without a bump."
        case .fullCoop: "Adopt every hen."
        }
    }

    /// The neon sign colour family (scene art name suffix).
    var tint: Int { (Self.allCases.firstIndex(of: self) ?? 0) % 4 }

    static func district(_ index: Int) -> Achievement {
        [.sleepyLane, .marketStreet, .steamQuarter, .neonBoulevard, .midnightExpressway][index]
    }
}
