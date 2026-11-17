import UIKit

/// Game-level haptic vocabulary (own enum so callers do not need UIKit types).
enum HapticCue {
    case hop, score, roost, kernel, whistle, honk, bump, finish, buy, denied
}

@MainActor
final class HapticsService {
    private let isEnabled: () -> Bool
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    init(isEnabled: @escaping () -> Bool) {
        self.isEnabled = isEnabled
    }

    func play(_ cue: HapticCue) {
        guard isEnabled() else { return }
        switch cue {
        case .hop: light.impactOccurred(intensity: 0.5)
        case .score, .kernel: light.impactOccurred()
        case .roost, .buy: notification.notificationOccurred(.success)
        case .whistle, .honk: medium.impactOccurred()
        case .bump: heavy.impactOccurred()
        case .finish: notification.notificationOccurred(.success)
        case .denied: notification.notificationOccurred(.warning)
        }
    }
}
