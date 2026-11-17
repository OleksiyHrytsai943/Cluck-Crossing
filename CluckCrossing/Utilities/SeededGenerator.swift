import Foundation

/// Deterministic SplitMix64 generator so a crossing (and the Daily Crossing) is the same for everyone with the same seed.
nonisolated struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func double(in range: ClosedRange<Double>) -> Double {
        Double.random(in: range, using: &self)
    }

    mutating func chance(_ probability: Double) -> Bool {
        probability > 0 && Double.random(in: 0..<1, using: &self) < probability
    }
}
