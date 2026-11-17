import Combine
import SpriteKit
import SwiftUI

/// Drives one run: countdown, input, HUD snapshot, banners, pause and the result.
@MainActor
final class GameViewModel: ObservableObject {
    enum Phase: Equatable {
        case countdown(Int)
        case running
        case paused
        case finished
    }

    struct Banner: Equatable, Identifiable {
        let id = UUID()
        let text: String
        let color: Color
    }

    @Published private(set) var mode: RunMode
    let isAutopilot: Bool
    let store: ProfileStore
    let settings: SettingsStore
    private let haptics: HapticsService
    private let sound: SoundService
    private let seed: UInt64?

    @Published private(set) var phase: Phase = .countdown(3)
    @Published var snapshot = RunSnapshot()
    @Published private(set) var banner: Banner?
    @Published private(set) var result: RunResult?
    @Published private(set) var reward: RunReward?
    /// Shows the "tap / swipe" hint during the first seconds of the first crossings.
    @Published private(set) var showControlsHint = false
    /// District card shown when "Next crossing" enters a district the player has not seen yet.
    @Published private(set) var districtIntro: AppRouter.DistrictIntro?

    private(set) var session: RunSession
    private var scene: CrossingScene?
    private var countdownTask: Task<Void, Never>?
    private var bannerTask: Task<Void, Never>?

    init(mode: RunMode, dependencies: AppDependencies) {
        self.mode = mode
        isAutopilot = dependencies.isAutopilot
        store = dependencies.store
        settings = dependencies.settings
        haptics = dependencies.haptics
        sound = dependencies.sound
        seed = dependencies.seed
        session = RunSession(config: dependencies.store.runConfig(for: mode, seed: dependencies.seed))
        snapshot = session.snapshot
    }

    var isRunning: Bool { phase == .running }
    var hazards: HazardSet {
        switch mode {
        case .crossing(let index): CrossingSpec.all[index].hazards
        case .daily: HazardSet(cornTrucks: true, sprinklers: true, hotGravel: true, fog: false)
        case .longRoad: .all
        }
    }

    /// Next crossing offered on the result screen.
    var nextMode: RunMode? {
        guard case .crossing(let index) = mode, result?.crossed == true, index + 1 < CrossingSpec.count else { return nil }
        return .crossing(index + 1)
    }

    func scene(size: CGSize) -> CrossingScene {
        if let scene { return scene }
        let scene = CrossingScene(size: size, viewModel: self)
        self.scene = scene
        return scene
    }

    // MARK: Lifecycle

    func start() {
        guard countdownTask == nil, phase != .finished else { return }
        sound.playMusic(.run)
        if case .crossing(let index) = mode, index < 3 { showControlsHint = true }
        countdownTask = Task { [weak self] in
            for n in stride(from: 3, through: 1, by: -1) {
                guard let self, !Task.isCancelled else { return }
                self.phase = .countdown(n)
                self.sound.play(.count)
                try? await Task.sleep(ms: self.isAutopilot ? 250 : 650)
            }
            guard let self, !Task.isCancelled else { return }
            self.phase = .running
            self.sound.play(.go)
            self.countdownTask = nil
            try? await Task.sleep(ms: 4_000)
            self.showControlsHint = false
        }
    }

    func pause() {
        guard phase == .running else { return }
        phase = .paused
        sound.pauseMusic()
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .running
        sound.resumeMusic()
    }

    /// Ends the run from the pause menu. Banked eggs still count.
    func quitRun() {
        session.forfeit()
        finish()
    }

    func restart() {
        load(mode)
        start()
    }

    /// "Next crossing" on the result card: switches to the next road without leaving the game screen.
    func playNext() {
        guard let next = nextMode else { return }
        load(next)
        if case .crossing(let index) = next {
            let district = CrossingSpec.all[index].district.id
            if !store.profile.districtIntrosSeen.contains(district) {
                districtIntro = AppRouter.DistrictIntro(crossing: index)
                return
            }
        }
        start()
    }

    func startAfterIntro() {
        if let intro = districtIntro { store.markDistrictIntroSeen(intro.district.id) }
        districtIntro = nil
        start()
    }

    /// Fresh session for `newMode`; the scene rebuilds its rows for the new road.
    private func load(_ newMode: RunMode) {
        countdownTask?.cancel()
        countdownTask = nil
        bannerTask?.cancel()
        mode = newMode
        session = RunSession(config: store.runConfig(for: newMode, seed: seed))
        snapshot = session.snapshot
        result = nil
        reward = nil
        banner = nil
        phase = .countdown(3)
        scene?.reset()
    }

    // MARK: Input

    func input(_ action: PilotAction) {
        guard phase == .running else { return }
        if session.hop(action) {
            switch action {
            case .roost, .bell: break
            default: haptics.play(.hop)
            }
        } else if action == .roost {
            show(session.kind.isSafe ? "Basket is empty: cross a lane first" : "Roost only on a hay strip", color: Theme.mutedText)
        } else if action == .bell {
            show("The bell needs a full sack of grain", color: Theme.mutedText)
        }
        snapshot = session.snapshot
    }

    // MARK: Events from the scene

    func handle(_ events: [RunEvent]) {
        for event in events {
            switch event {
            case .hop(_, _, let forced):
                if forced {
                    sound.play(.spray, volume: 0.6)
                    show("Hot feet! Forced hop", color: Theme.pumpkin)
                } else {
                    sound.play(.hop, volume: 0.5)
                }
            case .laneScored:
                sound.play(.score, volume: 0.6)
            case .roosted(let amount):
                sound.play(.roost)
                haptics.play(.roost)
                show("+\(Formatters.number(amount)) banked", color: Theme.wheat)
            case .kernel:
                sound.play(.kernel, volume: 0.7)
                haptics.play(.kernel)
            case .bell(let rows):
                sound.play(.bell)
                haptics.play(.bell)
                show("Ding! \(rows.count) lanes held", color: Theme.meadow)
            case .honk:
                sound.play(.honk, volume: 0.7)
                haptics.play(.honk)
            case .hit(let cause, let lost):
                sound.play(cause == .spray ? .spray : .bump)
                haptics.play(.bump)
                let what = cause == .spray ? "Soaked!" : "Bumped!"
                show(lost > 0 ? "\(what) Lost \(Formatters.number(lost)) eggs" : what, color: Theme.tomato)
            case .finished:
                sound.play(.finish)
                haptics.play(.finish)
                finish()
            case .outOfFeathers:
                sound.play(.gameOver)
                finish()
            }
        }
    }

    private func finish() {
        guard phase != .finished else { return }
        let result = session.makeResult()
        self.result = result
        reward = store.record(result)
        snapshot = session.snapshot
        phase = .finished
        sound.stopMusic()
        if (reward?.stars ?? 0) > 0 { sound.play(.star) }
    }

    private func show(_ text: String, color: Color) {
        bannerTask?.cancel()
        banner = Banner(text: text, color: color)
        bannerTask = Task { [weak self] in
            try? await Task.sleep(ms: 2_200)
            guard !Task.isCancelled else { return }
            self?.banner = nil
        }
    }
}
