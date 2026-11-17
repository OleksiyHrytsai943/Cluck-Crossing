import Foundation

/// Items in the Vending Machine. Each level makes one mechanic stronger.
enum UpgradeKind: String, CaseIterable, Identifiable, Codable {
    case coolFeet
    case longWhistle
    case bigBasket
    case spareFeather
    case cornPouch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coolFeet: "Cool Feet Gel"
        case .longWhistle: "Brass Whistle"
        case .bigBasket: "Wicker Basket"
        case .spareFeather: "Spare Feather"
        case .cornPouch: "Corn Pouch"
        }
    }

    var detail: String {
        switch self {
        case .coolFeet: "Feet heat 12% slower per level on hot asphalt."
        case .longWhistle: "Whistle freezes traffic 0.5 s longer per level."
        case .bigBasket: "Every lane adds 6% more to your clutch per level."
        case .spareFeather: "Start each run with one more feather per level."
        case .cornPouch: "Each corn kernel pays +1 coin per level."
        }
    }

    var art: String { "upgrade_\(rawValue)" }

    var maxLevel: Int {
        switch self {
        case .coolFeet, .longWhistle: 4
        case .bigBasket: 5
        case .spareFeather: 2
        case .cornPouch: 3
        }
    }

    private var basePrice: Double {
        switch self {
        case .coolFeet: 180
        case .longWhistle: 220
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

    /// Slot label on the machine (A1, A2 …).
    var slot: String {
        ["A1", "A2", "B1", "B2", "C1"][Self.allCases.firstIndex(of: self) ?? 0]
    }
}
