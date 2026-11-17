import Combine
import Foundation

/// Simple switches stored in UserDefaults.
@MainActor
final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults

    @Published var soundOn: Bool { didSet { defaults.set(soundOn, forKey: Keys.sound) } }
    @Published var musicOn: Bool { didSet { defaults.set(musicOn, forKey: Keys.music) } }
    @Published var hapticsOn: Bool { didSet { defaults.set(hapticsOn, forKey: Keys.haptics) } }
    /// Left-handed layout swaps the BELL and ROOST buttons.
    @Published var leftHanded: Bool { didSet { defaults.set(leftHanded, forKey: Keys.leftHanded) } }

    private enum Keys {
        static let sound = "settings.sound"
        static let music = "settings.music"
        static let haptics = "settings.haptics"
        static let leftHanded = "settings.leftHanded"
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        soundOn = defaults.object(forKey: Keys.sound) as? Bool ?? true
        musicOn = defaults.object(forKey: Keys.music) as? Bool ?? true
        hapticsOn = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        leftHanded = defaults.object(forKey: Keys.leftHanded) as? Bool ?? false
    }
}
