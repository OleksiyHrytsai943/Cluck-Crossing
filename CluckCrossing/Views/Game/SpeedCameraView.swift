import SwiftUI

/// End of run: a speed-camera snapshot of the hen with a flash, a timestamped data strip
/// and the reward below.
struct SpeedCameraView: View {
    let result: RunResult
    let reward: RunReward?
    let hen: Hen
    let nextMode: RunMode?
    let onAgain: () -> Void
    let onNext: () -> Void
    let onHome: () -> Void

    @State private var flash = 1.0

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    photo
                    stats
                    if let reward, !reward.newAchievements.isEmpty {
                        achievements(reward.newAchievements)
                    }
                    buttons
                }
                .padding(16)
                .frame(maxWidth: Theme.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { flash = 0 }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.resultScreen)
    }

    private var headline: String {
        if result.crossed { return result.mode == .nightRun ? "NIGHT RUN OVER" : "SAFE ACROSS" }
        return result.mode == .nightRun ? "NIGHT RUN OVER" : "OUT OF FEATHERS"
    }

    private var photo: some View {
        Image("camera_frame")
            .resizable()
            .scaledToFit()
            .overlay(
                GeometryReader { proxy in
                    let w = proxy.size.width, h = proxy.size.height
                    ZStack(alignment: .topLeading) {
                        // The "photo" subject.
                        Image(hen.art)
                            .resizable()
                            .scaledToFit()
                            .frame(width: w * 0.42)
                            .position(x: w * 0.5, y: h * 0.47)
                            .rotationEffect(.degrees(result.crossed ? 0 : -8))
                        // Stamp.
                        Text(headline)
                            .font(Theme.display(w * 0.07))
                            .foregroundColor(result.crossed ? Theme.neonTeal : Theme.neonRed)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 2)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(result.crossed ? Theme.neonTeal : Theme.neonRed, lineWidth: 3))
                            .rotationEffect(.degrees(-8))
                            .position(x: w * 0.3, y: h * 0.17)
                        // Data strip.
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Formatters.shortDate.string(from: Date()))  ·  \(result.mode.title.uppercased())")
                            Text("BANKED \(Formatters.number(result.banked))  ·  LANES \(result.lanesCrossed)  ·  \(Formatters.duration(result.duration))")
                        }
                        .font(Theme.led(w * 0.034))
                        .foregroundColor(Theme.led)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(width: w * 0.86, alignment: .leading)
                        .position(x: w * 0.5, y: h * 0.865)
                    }
                }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(headline). Banked \(result.banked) eggs over \(result.lanesCrossed) lanes.")
    }

    private var stats: some View {
        LEDPanel(tint: Theme.eggGold) {
            VStack(spacing: 8) {
                if case .crossing = result.mode, result.crossed {
                    StarRow(stars: result.stars, size: 34)
                    if let reward, reward.stars > reward.previousStars, reward.previousStars > 0 {
                        Text("New best stars!")
                            .font(Theme.headline(15))
                            .foregroundColor(Theme.eggGold)
                    }
                }
                if reward?.isNewBest == true {
                    Text("NEW RECORD")
                        .font(Theme.display(18))
                        .foregroundColor(Theme.neonPink)
                }
                statRow("egg", "Banked eggs", Formatters.number(result.banked))
                statRow("plaque", "Best streak", "\(result.bestStreak) lanes")
                statRow("nest", "Biggest roost", Formatters.number(result.bestRoost))
                statRow("kernel", "Corn kernels", "\(result.kernels)")
                statRow("grain_token", "Whistles", "\(result.whistles)")
                statRow("feather", "Bumps", "\(result.hits)")
                Divider().background(Color.white.opacity(0.2))
                HStack {
                    Image("coin").resizable().frame(width: 30, height: 30)
                    Text("Coins earned")
                        .font(Theme.headline(18))
                        .foregroundColor(.white)
                    Spacer()
                    Text("+\(Formatters.number(reward?.coins ?? result.coinsEarned))")
                        .font(Theme.led(22))
                        .foregroundColor(Theme.eggGold)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AccessibilityID.resultCoins)
                if let unlocked = reward?.unlockedCrossing {
                    Text("Unlocked: \(CrossingSpec.all[unlocked].title)")
                        .font(Theme.headline(15))
                        .foregroundColor(Theme.neonTeal)
                }
            }
        }
    }

    private func statRow(_ art: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            ArtIcon(name: art, size: 28, tint: Color.white.opacity(0.08))
            Text(title)
                .font(Theme.body(15))
                .foregroundColor(Theme.mutedText)
            Spacer()
            Text(value)
                .font(Theme.led(16))
                .foregroundColor(.white)
        }
        .accessibilityElement(children: .combine)
    }

    private func achievements(_ list: [Achievement]) -> some View {
        VStack(spacing: 8) {
            NeonText(text: "NEW NEON SIGNS", size: 20, color: Theme.neonPink)
            ForEach(list) { a in
                Text(a.title.uppercased())
                    .font(Theme.display(18))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Image("neon_on_\(a.tint)").resizable())
            }
        }
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            if nextMode != nil {
                Button("Next crossing", action: onNext)
                    .buttonStyle(NeonPillButtonStyle(color: Theme.neonTeal, filled: true))
                    .accessibilityIdentifier(AccessibilityID.resultNext)
            }
            HStack(spacing: 10) {
                Button("Try again", action: onAgain)
                    .buttonStyle(NeonPillButtonStyle(color: Theme.eggGold, filled: nextMode == nil))
                    .accessibilityIdentifier(AccessibilityID.resultAgain)
                Button("Street corner", action: onHome)
                    .buttonStyle(NeonPillButtonStyle(color: Theme.mutedText))
                    .accessibilityIdentifier(AccessibilityID.resultHome)
            }
        }
    }
}
