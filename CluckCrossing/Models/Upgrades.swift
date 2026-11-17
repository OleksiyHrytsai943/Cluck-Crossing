import Foundation

/// Items in the Feed Store. Each level makes one mechanic stronger.
enum UpgradeKind: String, CaseIterable, Identifiable, Codable {
    case coolFeet
    case bigBell
    case bigBasket
    case spareFeather
    case cornPouch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coolFeet: "Mud Socks"
        case .bigBell: "Big Brass Bell"
        case .bigBasket: "Wicker Basket"
        case .spareFeather: "Spare Feather"
        case .cornPouch: "Feed Sack"
        }
    }

    var detail: String {
        switch self {
        case .coolFeet: "Feet heat 12% slower per level on hot gravel."
        case .bigBell: "The farm bell holds traffic 0.5 s longer per level."
        case .bigBasket: "Every lane adds 6% more to your basket per level."
        case .spareFeather: "Start each run with one more feather per level."
        case .cornPouch: "Each corn kernel pays +1 coin per level."
        }
    }

    var art: String { "upgrade_\(rawValue)" }

    var maxLevel: Int {
        switch self {
        case .coolFeet, .bigBell: 4
        case .bigBasket: 5
        case .spareFeather: 2
        case .cornPouch: 3
        }
    }

    private var basePrice: Double {
        switch self {
        case .coolFeet: 180
        case .bigBell: 220
        case .bigBasket: 160
        case .spareFeather: 900
        case .cornPouch: 200
        }
    }

    /// Price of the next level, or nil when maxed.
    func price(forLevel current: Int) -> Int? {
        guard current < maxLevel else { return nil }
        let raw = basePrice * pow(Double(current + 1), 1.5)
        return Int((raw / 10).rounded()) * 10
    }

    /// Shelf label in the Feed Store (A1, A2 …).
    var slot: String {
        ["A1", "A2", "B1", "B2", "C1"][Self.allCases.firstIndex(of: self) ?? 0]
    }
}
