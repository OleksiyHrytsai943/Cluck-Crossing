import AVFoundation
import Foundation

/// Generated sound effects (see `Artwork/generate_sounds.swift`).
enum SoundEffect: String, CaseIterable {
    case hop = "sfx_hop"
    case cluck = "sfx_cluck"
    case score = "sfx_score"
    case roost = "sfx_roost"
    case kernel = "sfx_kernel"
    case whistle = "sfx_whistle"
    case honk = "sfx_honk"
    case flare = "sfx_flare"
    case bump = "sfx_bump"
    case tap = "sfx_tap"
    case buy = "sfx_buy"
    case star = "sfx_star"
    case finish = "sfx_finish"
    case gameOver = "sfx_gameover"
    case count = "sfx_count"
    case go = "sfx_go"

    var voices: Int {
        switch self {
        case .hop, .score, .kernel: 4
        default: 2
        }
    }
}

enum MusicTrack: String {
    case menu = "music_menu"
    case run = "music_run"
}

/// Plays effects and looping music. Ambient session: mixes with other audio and honours the silent switch.
@MainActor
final class SoundService {
    private var pools: [SoundEffect: [AVAudioPlayer]] = [:]
    private var nextVoice: [SoundEffect: Int] = [:]
    private var music: AVAudioPlayer?
    private var currentTrack: MusicTrack?
    private let soundEnabled: () -> Bool
    private let musicEnabled: () -> Bool
    private var isPrepared = false

    static let silent = SoundService(soundEnabled: { false }, musicEnabled: { false })

    init(soundEnabled: @escaping () -> Bool, musicEnabled: @escaping () -> Bool) {
        self.soundEnabled = soundEnabled
        self.musicEnabled = musicEnabled
    }

    private func prepareIfNeeded() {
        guard !isPrepared else { return }
        isPrepared = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for effect in SoundEffect.allCases {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else { continue }
            pools[effect] = (0..<effect.voices).compactMap { _ in
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
                return player
            }
        }
    }

    func play(_ effect: SoundEffect, volume: Float = 1) {
        guard soundEnabled() else { return }
        prepareIfNeeded()
        guard let pool = pools[effect], !pool.isEmpty else { return }
        let index = (nextVoice[effect] ?? 0) % pool.count
        nextVoice[effect] = index + 1
        let player = pool[index]
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    func playMusic(_ track: MusicTrack) {
        guard musicEnabled() else { stopMusic(); return }
        prepareIfNeeded()
        if currentTrack == track, music?.isPlaying == true { return }
        music?.stop()
        guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1
        player.volume = 0
        player.play()
        player.setVolume(track == .run ? 0.4 : 0.32, fadeDuration: 0.8)
        music = player
        currentTrack = track
    }

    func stopMusic() {
        music?.stop()
        music = nil
        currentTrack = nil
    }

    func pauseMusic() { music?.pause() }

    func resumeMusic() {
        guard musicEnabled() else { return }
        music?.play()
    }

    func refreshMusic(default track: MusicTrack) {
        if musicEnabled() { playMusic(currentTrack ?? track) } else { stopMusic() }
    }
}
