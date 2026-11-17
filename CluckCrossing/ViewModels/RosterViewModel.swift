import Combine
import Foundation

/// Top Players: loads the weekly roster page from a `LeaderboardProviding` and handles Lamp Lighter claims.
@MainActor
final class RosterViewModel: ObservableObject {
    let store: ProfileStore
    private let provider: LeaderboardProviding
    private let haptics: HapticsService
    private let sound: SoundService

    @Published private(set) var page: LeaderboardPage?
    @Published private(set) var loadError: String?

    init(store: ProfileStore, provider: LeaderboardProviding, haptics: HapticsService, sound: SoundService) {
        self.store = store
        self.provider = provider
        self.haptics = haptics
        self.sound = sound
    }

    var shift: NightShift { store.shift }
    var lampsLit: Int { store.lampsLitThisWeek }

    func load() async {
        let standing = PlayerStanding(name: "You · \(store.hen.name)", hen: store.hen.art, weeklyBest: store.weeklyBest)
        do {
            page = try await provider.weeklyTop(for: shift, player: standing, lampsLit: lampsLit, now: store.currentDate)
            loadError = nil
        } catch {
            loadError = "The roster could not load. \(error.localizedDescription)"
        }
    }

    /// JSON handed to the HTML template.
    var pageJSON: String? {
        guard let page, let data = try? JSONEncoder().encode(page) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func claim(_ tier: LampLighter.Tier) async -> String {
        do {
            try store.claimLamps(tier)
            haptics.play(.buy)
            sound.play(.buy)
            await load()
            return "+\(tier.coins) coins from the Lamp Lighter!"
        } catch {
            haptics.play(.denied)
            return error.localizedDescription
        }
    }
}
