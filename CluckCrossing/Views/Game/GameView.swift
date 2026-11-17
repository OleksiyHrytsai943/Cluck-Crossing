import SpriteKit
import SwiftUI

/// Full-screen run: SpriteKit road + SwiftUI HUD styled like farm signs.
struct GameView: View {
    @StateObject private var viewModel: GameViewModel
    @ObservedObject private var settings: SettingsStore
    let onExit: () -> Void

    init(viewModel: @autoclosure @escaping () -> GameViewModel, settings: SettingsStore, onExit: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.settings = settings
        self.onExit = onExit
    }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                SpriteView(scene: viewModel.scene(size: proxy.size), preferredFramesPerSecond: 60)
                    .ignoresSafeArea()
            }
            .ignoresSafeArea()

            VStack(spacing: 6) {
                topHUD
                if let banner = viewModel.banner {
                    BannerView(banner: banner)
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                if viewModel.showControlsHint, viewModel.isRunning {
                    Text("TAP to hop · SWIPE ← → to sidestep · SWIPE ↓ to step back")
                        .font(Theme.headline(14))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(10)
                        .background(Capsule().fill(Theme.panel.opacity(0.9)))
                        .padding(.horizontal, 20)
                        .allowsHitTesting(false)
                }
                bottomHUD
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.banner)

            if case .countdown(let n) = viewModel.phase, viewModel.districtIntro == nil {
                CountdownView(number: n, title: viewModel.mode.title)
            }
            if viewModel.phase == .paused {
                PauseView(mode: viewModel.mode, onResume: viewModel.resume, onQuit: viewModel.quitRun)
            }
            if viewModel.phase == .finished, let result = viewModel.result {
                PrizeCardView(
                    result: result,
                    reward: viewModel.reward,
                    hen: viewModel.store.hen,
                    nextMode: viewModel.nextMode,
                    onAgain: viewModel.restart,
                    onNext: viewModel.playNext,
                    onHome: onExit
                )
                .transition(.move(edge: .bottom))
            }
            if let intro = viewModel.districtIntro {
                // New district reached via "Next crossing": explain its hazard before the countdown.
                DistrictCardView(intro: intro, onStart: viewModel.startAfterIntro, onClose: onExit)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase)
        .preferredColorScheme(.light)
        .statusBarHidden(true)
        .onAppear { viewModel.start() }
        .accessibilityElement(children: .contain)
        .accessibilityValue(viewModel.mode.title)
        .accessibilityIdentifier(AccessibilityID.gameScreen)
    }

    // MARK: Top: taxi-roof sign with score and basket, pause hand, feathers

    private var topHUD: some View {
        let s = viewModel.snapshot
        return VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Button(action: viewModel.pause) {
                    Image("signal_stop")
                        .resizable()
                        .frame(width: 48, height: 48)
                }
                .accessibilityLabel("Pause")
                .accessibilityIdentifier(AccessibilityID.pauseButton)
                .disabled(!viewModel.isRunning)

                WoodSign(snapshot: s)

                FeatherRow(feathers: s.feathers, max: s.maxFeathers)
            }
            if let progress = s.progress {
                ProgressBar(progress: progress)
                    .frame(height: 6)
                    .padding(.horizontal, 64)
                    .accessibilityLabel("Crossing progress")
                    .accessibilityValue("\(Int(progress * 100)) percent")
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
    }

    // MARK: Bottom: meters + WHISTLE / ROOST

    private var bottomHUD: some View {
        let s = viewModel.snapshot
        let bell = HUDButton(title: "BELL", art: "grain_token", fill: s.grain, ready: s.canRing, color: Theme.meadow,
                                caption: s.canRing ? "Freeze 3 lanes" : "\(Int(s.grain * 100))% grain") {
            viewModel.input(.bell)
        }
        .accessibilityIdentifier(AccessibilityID.bellButton)
        let roost = HUDButton(title: "ROOST", art: "nest", fill: s.onSafeRow ? 1 : 0, ready: s.canRoost, color: Theme.wheat,
                              caption: s.canRoost ? "Bank \(Formatters.number(s.clutch))" : s.onSafeRow ? "Basket empty" : "Hay strips only") {
            viewModel.input(.roost)
        }
        .accessibilityIdentifier(AccessibilityID.roostButton)

        return HStack(alignment: .bottom, spacing: 10) {
            if settings.leftHanded { roost } else { bell }
            if viewModel.hazards.hotGravel || s.heat > 0 {
                HeatGauge(heat: s.heat, active: s.heatActive)
            } else {
                Spacer().frame(width: 0)
            }
            Spacer(minLength: 0)
            if settings.leftHanded { bell } else { roost }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}

// MARK: - HUD parts

/// Wheat-yellow wooden sign: banked score, current basket and the next multiplier.
struct WoodSign: View {
    let snapshot: RunSnapshot

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Image("egg").resizable().frame(width: 18, height: 18)
                Text(Formatters.number(snapshot.banked))
                    .font(Theme.chalkFont(22))
                    .foregroundColor(Theme.ink)
                    .numericTransition()
                    .accessibilityLabel("Banked \(snapshot.banked)")
                    .accessibilityValue("\(snapshot.banked)")
                    .accessibilityIdentifier(AccessibilityID.scoreLabel)
            }
            HStack(spacing: 4) {
                Text("BASKET \(Formatters.number(snapshot.clutch))")
                    .accessibilityLabel("Basket \(snapshot.clutch)")
                    .accessibilityValue("\(snapshot.clutch)")
                    .accessibilityIdentifier(AccessibilityID.clutchLabel)
                Text("·")
                Text("NEXT \(Formatters.multiplier(snapshot.nextMultiplier))")
            }
            .font(Theme.chalkFont(12))
            .foregroundColor(Theme.ink.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.4), Theme.wheat], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.ink, lineWidth: 2.5))
    }
}

struct FeatherRow: View {
    let feathers: Int
    let max: Int

    var body: some View {
        HStack(spacing: -6) {
            ForEach(0..<max, id: \.self) { i in
                Image(i < feathers ? "feather" : "feather_empty")
                    .resizable()
                    .frame(width: 26, height: 26)
            }
        }
        .padding(.horizontal, 6)
        .frame(minHeight: 48)
        .background(Capsule().fill(Theme.panel.opacity(0.85)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(feathers) feathers left")
        .accessibilityValue("\(feathers)")
        .accessibilityIdentifier(AccessibilityID.feathers)
    }
}

struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.panel.opacity(0.7))
                Capsule().fill(Theme.meadow)
                    .frame(width: proxy.size.width * CGFloat(min(1, max(0, progress))))
                    .shadow(color: Theme.ink.opacity(0.3), radius: 2, x: 0, y: 2)
            }
        }
    }
}

/// Big round action button with a fill ring (bell grain) and a caption.
struct HUDButton: View {
    let title: String
    let art: String
    let fill: Double
    let ready: Bool
    let color: Color
    let caption: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack {
                    Circle().fill(Theme.panel.opacity(0.94))
                    Circle()
                        .trim(from: 0, to: CGFloat(min(1, fill)))
                        .stroke(color.opacity(ready ? 1 : 0.55), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(3)
                    Image(art)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                        .opacity(ready ? 1 : 0.5)
                }
                .frame(width: 84, height: 84)
                .shadow(color: Theme.ink.opacity(0.3), radius: 2, x: 0, y: 2)
                Text(title)
                    .font(Theme.display(17))
                    .foregroundColor(ready ? color : .white.opacity(0.7))
                Text(caption)
                    .font(Theme.body(11))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 104)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.panel.opacity(0.75)))
        }
        .buttonStyle(WalkSignalButtonStyle())
        .accessibilityLabel("\(title), \(caption)")
        .accessibilityValue(ready ? "Ready" : "Not ready")
    }
}

/// Barn thermometer for Hot Gravel.
struct HeatGauge: View {
    let heat: Double
    let active: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .bottom) {
                Capsule().fill(Color.white.opacity(0.9)).frame(width: 18, height: 86)
                Capsule()
                    .fill(heat > 0.75 ? Theme.tomato : Theme.pumpkin)
                    .frame(width: 10, height: max(10, 82 * CGFloat(min(1, heat))))
                    .padding(.bottom, 2)
            }
            .overlay(Capsule().stroke(Theme.ink, lineWidth: 2))
            Text(active ? "HOT" : "FEET")
                .font(Theme.chalkFont(11))
                .foregroundColor(active ? Theme.tomato : .white)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panel.opacity(0.85)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Feet heat")
        .accessibilityValue("\(Int(heat * 100)) percent")
    }
}

struct BannerView: View {
    let banner: GameViewModel.Banner

    var body: some View {
        Text(banner.text)
            .font(Theme.display(22))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.panel.opacity(0.92)))
            .overlay(Capsule().stroke(banner.color, lineWidth: 2.5).shadow(color: Theme.ink.opacity(0.3), radius: 2, x: 0, y: 2))
            .allowsHitTesting(false)
            .accessibilityIdentifier(AccessibilityID.toast)
    }
}

struct CountdownView: View {
    let number: Int
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title.uppercased())
                .font(Theme.display(26))
                .foregroundColor(.white)
            Image("signal_stop")
                .resizable()
                .frame(width: 110, height: 110)
            PaintedText(text: "\(number)", size: 90, color: Theme.pumpkin)
                .id(number)
                .transition(.scale.combined(with: .opacity))
            Text("Wait for the GO sign…")
                .font(Theme.body(15))
                .foregroundColor(Theme.mutedText)
        }
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 28).fill(Theme.panel.opacity(0.9)))
        .allowsHitTesting(false)
    }
}

struct PauseView: View {
    let mode: RunMode
    let onResume: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Theme.soil.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Image("signal_stop")
                    .resizable()
                    .frame(width: 90, height: 90)
                PaintedText(text: "HOLD UP", size: 34, color: Theme.barnRed)
                Text(mode.title)
                    .font(Theme.headline(18))
                    .foregroundColor(.white)
                Text("Quitting ends the run: banked eggs still pay coins, the basket is lost.")
                    .font(Theme.body(14))
                    .foregroundColor(Theme.mutedText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Resume", action: onResume)
                    .buttonStyle(FarmButtonStyle(color: Theme.meadow, filled: true))
                    .accessibilityIdentifier(AccessibilityID.resumeButton)
                Button("End run", action: onQuit)
                    .buttonStyle(FarmButtonStyle(color: Theme.tomato))
                    .accessibilityIdentifier(AccessibilityID.quitButton)
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 26).fill(Theme.panel))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(Theme.pumpkin, lineWidth: 2))
            .padding(28)
            .frame(maxWidth: Theme.maxContentWidth)
        }
    }
}
