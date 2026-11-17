import Foundation

/// Everything the app needs at launch. Launch arguments keep UI tests and screenshot tours deterministic:
/// `--uitesting`, `--autopilot`, `--coins=N`, `--cleared=N`, `--lamps=N`, `--open=<route>`, `--show-tutorial`, `--seed=N`.
@MainActor
final class AppDependencies {
    let store: ProfileStore
    let settings: SettingsStore
    let haptics: HapticsService
    let sound: SoundService
    let isUITesting: Bool
    let isAutopilot: Bool
    let seed: UInt64?
    /// Section to open at launch (`--open=roster`), UI tests and screenshot tours only.
    let openRoute: String?
    let leaderboard: LeaderboardProviding = PreviewLeaderboardProvider()

    init(arguments: [String] = ProcessInfo.processInfo.arguments) throws {
        isUITesting = arguments.contains("--uitesting")
        isAutopilot = arguments.contains("--autopilot")
        seed = Self.value(of: "--seed=", in: arguments).flatMap(UInt64.init)
        openRoute = arguments.contains("--uitesting") ? Self.value(of: "--open=", in: arguments) : nil

        let defaults: UserDefaults
        if isUITesting {
            let suite = "CluckCrossing.uitests"
            UserDefaults().removePersistentDomain(forName: suite)
            defaults = UserDefaults(suiteName: suite) ?? .standard
        } else {
            defaults = .standard
        }

        let storage: ProfileStorage = isUITesting ? .inMemory() : try .onDisk()
        store = ProfileStore(storage: storage)
        let settings = SettingsStore(defaults: defaults)
        self.settings = settings
        haptics = HapticsService { settings.hapticsOn }
        sound = isUITesting ? .silent : SoundService(soundEnabled: { settings.soundOn }, musicEnabled: { settings.musicOn })

        if isUITesting {
            if !arguments.contains("--show-tutorial") { store.markTutorialSeen() }
            store.seed(
                coins: Self.value(of: "--coins=", in: arguments).flatMap(Int.init) ?? 5_000,
                clearedCrossings: Self.value(of: "--cleared=", in: arguments).flatMap(Int.init) ?? 0
            )
            if let lamps = Self.value(of: "--lamps=", in: arguments).flatMap(Int.init) { store.seedLamps(lamps) }
        }
    }

    private static func value(of prefix: String, in arguments: [String]) -> String? {
        arguments.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
    }
}
