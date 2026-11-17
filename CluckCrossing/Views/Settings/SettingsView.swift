import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var store: ProfileStore
    let sound: SoundService
    let onReplayTutorial: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationView {
            List {
                Section("Sound") {
                    Toggle("Sound effects", isOn: $settings.soundOn)
                    Toggle("Music", isOn: $settings.musicOn)
                        .onChange(of: settings.musicOn) { _ in sound.refreshMusic(default: .menu) }
                    Toggle("Haptics", isOn: $settings.hapticsOn)
                }
                Section {
                    Toggle("Left-handed buttons", isOn: $settings.leftHanded)
                } header: {
                    Text("Controls")
                } footer: {
                    Text("Swaps the BELL and ROOST buttons during a run.")
                }
                Section("Help") {
                    Button("Replay the tutorial", action: onReplayTutorial)
                        .accessibilityIdentifier(AccessibilityID.settingsTutorial)
                }
                Section {
                    Button("Reset progress", role: .destructive) { confirmReset = true }
                        .accessibilityIdentifier(AccessibilityID.settingsReset)
                } footer: {
                    Text("Cluck Crossing is played offline. Coins are earned only by playing and have no real-world value.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier(AccessibilityID.settingsDone)
                }
            }
            .alert("Reset all progress?", isPresented: $confirmReset) {
                Button("Reset", role: .destructive) { store.reset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Stars, coins, upgrades and hens will be cleared.")
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.settingsScreen)
    }
}
