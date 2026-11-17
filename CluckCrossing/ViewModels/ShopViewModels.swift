import Combine
import Foundation

/// Vending machine: buys upgrade levels and reports the outcome as a toast message.
@MainActor
final class VendingViewModel: ObservableObject {
    let store: ProfileStore
    private let haptics: HapticsService
    private let sound: SoundService
    @Published var selected: UpgradeKind = .coolFeet
    /// Last vend for the drop animation.
    @Published private(set) var lastVend: UpgradeKind?

    init(store: ProfileStore, haptics: HapticsService, sound: SoundService) {
        self.store = store
        self.haptics = haptics
        self.sound = sound
    }

    func level(_ kind: UpgradeKind) -> Int { store.profile.level(of: kind) }
    func price(_ kind: UpgradeKind) -> Int? { kind.price(forLevel: level(kind)) }

    /// Returns the message to show.
    func buy(_ kind: UpgradeKind) -> String {
        do {
            try store.buy(kind)
            haptics.play(.buy)
            sound.play(.buy)
            lastVend = kind
            return "\(kind.title) — level \(level(kind))!"
        } catch {
            haptics.play(.denied)
            return error.localizedDescription
        }
    }
}

/// Henhouse: adopting and choosing hens.
@MainActor
final class HenhouseViewModel: ObservableObject {
    let store: ProfileStore
    private let haptics: HapticsService
    private let sound: SoundService
    @Published var focused: String

    init(store: ProfileStore, haptics: HapticsService, sound: SoundService) {
        self.store = store
        self.haptics = haptics
        self.sound = sound
        focused = store.profile.selectedHen
    }

    var focusedHen: Hen { Hen.with(id: focused) }
    func isOwned(_ hen: Hen) -> Bool { store.profile.ownedHens.contains(hen.id) }
    func isSelected(_ hen: Hen) -> Bool { store.profile.selectedHen == hen.id }

    func act() -> String {
        let hen = focusedHen
        do {
            if isOwned(hen) {
                try store.select(hen)
                sound.play(.cluck)
                haptics.play(.score)
                return "\(hen.name) is ready to cross."
            } else {
                try store.adopt(hen)
                sound.play(.buy)
                haptics.play(.buy)
                return "\(hen.name) moved in!"
            }
        } catch {
            haptics.play(.denied)
            return error.localizedDescription
        }
    }
}
