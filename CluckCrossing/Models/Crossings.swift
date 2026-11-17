import Foundation

/// Which hazards a road uses. Districts switch them on one by one so the first crossings stay gentle.
nonisolated struct HazardSet: Equatable, Codable {
    var cornTrucks: Bool
    var sprinklers: Bool
    var hotGravel: Bool
    /// Foggy road: vehicles away from the hen show only their fog lights (scene effect).
    var fog: Bool

    static let none = HazardSet(cornTrucks: false, sprinklers: false, hotGravel: false, fog: false)
    static let all = HazardSet(cornTrucks: true, sprinklers: true, hotGravel: true, fog: false)
}

/// A farm district: six crossings that introduce one new hazard.
nonisolated struct District: Identifiable, Equatable {
    let id: Int
    let name: String
    let tagline: String
    /// Short explanation of what is new here (shown on the district card before its first crossing).
    let newHazard: String
    let art: String

    static let all: [District] = [
        District(id: 0, name: "Meadow Lane", tagline: "Daisies, cows and slow pickups.",
                 newHazard: "Hop lane by lane, rest on the hay strips and Roost your basket before the traffic gets you.",
                 art: "district_meadow"),
        District(id: 1, name: "Harvest Road", tagline: "Corn season on the county road.",
                 newHazard: "Corn Trucks honk before they roll in. They are long, but they spill corn that fills your farm bell.",
                 art: "district_harvest"),
        District(id: 2, name: "Orchard Row", tagline: "Sprinklers between the apple trees.",
                 newHazard: "Sprinklers gurgle, then shoot a jet of water. Never stand on a gurgling sprinkler.",
                 art: "district_orchard"),
        District(id: 3, name: "Sunbaked Gravel", tagline: "High noon on the dusty road.",
                 newHazard: "Hot Gravel: your feet heat up on the road. When the thermometer is full you hop forward on your own.",
                 art: "district_gravel"),
        District(id: 4, name: "Foggy Hollow", tagline: "Morning fog in the valley.",
                 newHazard: "Fog: far traffic shows only fog lights. Every hazard is active and the tractors are fast.",
                 art: "district_fog"),
    ]
}

/// One campaign crossing: a fixed, seeded road from curb to curb.
nonisolated struct CrossingSpec: Identifiable, Equatable {
    let id: Int
    /// Lanes between hay strips, bottom to top.
    let sections: [Int]
    /// 0 (gentle) … 1 (expressway).
    let difficulty: Double
    let hazards: HazardSet
    let seed: UInt64

    static let perDistrict = 6
    static let count = District.all.count * perDistrict

    var district: District { District.all[id / Self.perDistrict] }
    var numberInDistrict: Int { id % Self.perDistrict + 1 }
    var title: String { "\(district.name) \(numberInDistrict)" }
    var laneCount: Int { sections.reduce(0, +) }

    static let all: [CrossingSpec] = (0..<count).map(make)

    static func make(_ index: Int) -> CrossingSpec {
        let district = index / perDistrict
        let step = index % perDistrict
        var rng = SeededGenerator(seed: UInt64(1217 + index * 7919))
        // Longer roads and wider sections as the county gets busier.
        let total = 5 + index + index / 3
        let maxSection = min(6, 2 + district + step / 3)
        var sections: [Int] = []
        var remaining = total
        while remaining > 0 {
            let size = min(remaining, Int.random(in: 2...max(2, maxSection), using: &rng))
            sections.append(size)
            remaining -= size
        }
        let difficulty = 0.06 + 0.84 * Double(index) / Double(count - 1)
        let hazards = HazardSet(
            cornTrucks: district >= 1,
            sprinklers: district >= 2,
            hotGravel: district >= 3,
            fog: district >= 4
        )
        return CrossingSpec(id: index, sections: sections, difficulty: difficulty, hazards: hazards, seed: UInt64(5_000 + index))
    }
}

/// What the player is running.
enum RunMode: Equatable, Codable, Hashable {
    case crossing(Int)
    case longRoad
    case daily(String)

    var title: String {
        switch self {
        case .crossing(let index): CrossingSpec.all[index].title
        case .longRoad: "Long Road"
        case .daily: "Daily Crossing"
        }
    }

    var isEndless: Bool { self == .longRoad }
}

/// The Daily Crossing is the same road for everyone on the same UTC day.
enum DailyCrossing {
    static let laneCount = 36

    static func key(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func seed(for key: String) -> UInt64 {
        // FNV-1a: stable across launches (unlike Hasher).
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    static func sections(seed: UInt64) -> [Int] {
        var rng = SeededGenerator(seed: seed)
        var sections: [Int] = []
        var remaining = laneCount
        while remaining > 0 {
            let size = min(remaining, Int.random(in: 3...6, using: &rng))
            sections.append(size)
            remaining -= size
        }
        return sections
    }
}
