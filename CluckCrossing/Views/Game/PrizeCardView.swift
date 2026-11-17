import SwiftUI

/// End of run: a county-fair photo of the hen pinned to a board with a prize ribbon,
/// a hand-written caption and the reward below.
struct PrizeCardView: View {
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
            Theme.sky.opacity(0.9).ignoresSafeArea()
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
        if result.crossed { return result.mode == .longRoad ? "LONG ROAD DONE" : "SAFE HOME" }
        return result.mode == .longRoad ? "LONG ROAD DONE" : "OUT OF FEATHERS"
    }

    private var photo: some View {
        Image("photo_frame")
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
                            .foregroundColor(result.crossed ? Theme.signGreen : Theme.barnRed)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.cream.opacity(0.92)))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(result.crossed ? Theme.signGreen : Theme.barnRed, lineWidth: 3))
                            .rotationEffect(.degrees(-8))
                            .position(x: w * 0.3, y: h * 0.17)
                        // Data strip.
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Formatters.shortDate.string(from: Date()))  ·  \(result.mode.title.uppercased())")
                            Text("BANKED \(Formatters.number(result.banked))  ·  LANES \(result.lanesCrossed)  ·  \(Formatters.duration(result.duration))")
                        }
                        .font(Theme.chalkFont(w * 0.034))
                        .foregroundColor(Theme.chalk)
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
        PlankPanel(tint: Theme.wheat) {
            VStack(spacing: 8) {
                if case .crossing = result.mode, result.crossed {
                    StarRow(stars: result.stars, size: 34)
                    if let reward, reward.stars > reward.previousStars, reward.previousStars > 0 {
                        Text("New best stars!")
                            .font(Theme.headline(15))
                            .foregroundColor(Theme.wheat)
                    }
                }
                if reward?.isNewBest == true {
                    Text("NEW RECORD")
                        .font(Theme.display(18))
                        .foregroundColor(Theme.pumpkin)
                }
                statRow("egg", "Banked eggs", Formatters.number(result.banked))
                statRow("plaque", "Best streak", "\(result.bestStreak) lanes")
                statRow("nest", "Biggest roost", Formatters.number(result.bestRoost))
                statRow("kernel", "Corn kernels", "\(result.kernels)")
                statRow("grain_token", "Bells", "\(result.bells)")
                statRow("feather", "Bumps", "\(result.hits)")
                Divider().background(Color.white.opacity(0.2))
                HStack {
                    Image("coin").resizable().frame(width: 30, height: 30)
                    Text("Coins earned")
                        .font(Theme.headline(18))
                        .foregroundColor(.white)
                    Spacer()
                    Text("+\(Formatters.number(reward?.coins ?? result.coinsEarned))")
                        .font(Theme.chalkFont(22))
                        .foregroundColor(Theme.wheat)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AccessibilityID.resultCoins)
                if let unlocked = reward?.unlockedCrossing {
                    Text("Unlocked: \(CrossingSpec.all[unlocked].title)")
                        .font(Theme.headline(15))
                        .foregroundColor(Theme.meadow)
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
                .font(Theme.chalkFont(16))
                .foregroundColor(.white)
        }
        .accessibilityElement(children: .combine)
    }

    private func achievements(_ list: [Achievement]) -> some View {
        VStack(spacing: 8) {
            PaintedText(text: "NEW RIBBONS", size: 20, color: Theme.wheat)
            ForEach(list) { a in
                HStack(spacing: 12) {
                    Image("ribbon_\(a.tint)")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 56)
                    Text(a.title.uppercased())
                        .font(Theme.display(18))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panel.opacity(0.95)))
            }
        }
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            if nextMode != nil {
                Button("Next crossing", action: onNext)
                    .buttonStyle(FarmButtonStyle(color: Theme.meadow, filled: true))
                    .accessibilityIdentifier(AccessibilityID.resultNext)
            }
            HStack(spacing: 10) {
                Button("Try again", action: onAgain)
                    .buttonStyle(FarmButtonStyle(color: Theme.wheat, filled: nextMode == nil))
                    .accessibilityIdentifier(AccessibilityID.resultAgain)
                Button("Farmyard", action: onHome)
                    .buttonStyle(FarmButtonStyle(color: Theme.mutedText))
                    .accessibilityIdentifier(AccessibilityID.resultHome)
            }
        }
    }
}
