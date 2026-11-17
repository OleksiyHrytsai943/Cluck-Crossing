import SwiftUI

/// Home: a sunny farmyard. A wooden signpost by the barn leads to the sections,
/// the big GO! sign starts the next crossing.
struct CornerView: View {
    @ObservedObject var store: ProfileStore
    @ObservedObject var router: AppRouter
    let startRun: (RunMode) -> Void

    private var profile: PlayerProfile { store.profile }
    private var next: CrossingSpec { CrossingSpec.all[profile.nextCrossing] }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Image("logo_wordmark")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 330, minHeight: 60, maxHeight: 118)
                .padding(.top, 2)
                .accessibilityLabel("Cluck Crossing")
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .bottom, spacing: 0) {
                signpost
                Spacer(minLength: 0)
                hen
            }
            .padding(.top, 6)
            .layoutPriority(1)

            Spacer(minLength: 8)
            bottomControls
        }
        .frame(maxWidth: Theme.maxContentWidth)
        .frame(maxWidth: .infinity)
        .backdrop("corner_backdrop")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.cornerScreen)
    }

    private var topBar: some View {
        HStack {
            Button {
                router.showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.panel.opacity(0.85)))
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier(AccessibilityID.settingsButton)
            Spacer()
            CoinBadge(coins: profile.coins)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: Signpost

    private var signpost: some View {
        ZStack(alignment: .topLeading) {
            // The fence post the signs hang on.
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(colors: [Color(red: 0.62, green: 0.42, blue: 0.24), Color(red: 0.38, green: 0.24, blue: 0.13)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 12)
                .padding(.leading, 26)
                .padding(.bottom, -40)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Route.allCases) { route in
                    Button {
                        router.open(route)
                    } label: {
                        SignPlank(route: route)
                    }
                    .buttonStyle(WalkSignalButtonStyle())
                    .accessibilityLabel("\(route.signTitle), \(route.signSubtitle)")
                    .accessibilityIdentifier(AccessibilityID.sign(route.rawValue))
                }
            }
            .padding(.leading, 16)
        }
    }

    private var hen: some View {
        VStack(spacing: 2) {
            Image(store.hen.art)
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
            Text(store.hen.name)
                .font(Theme.headline(14))
                .foregroundColor(Theme.cream)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.panel.opacity(0.9)))
        }
        .padding(.trailing, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your hen: \(store.hen.name)")
    }

    // MARK: Bottom controls (thumb zone)

    private var bottomControls: some View {
        VStack(spacing: 10) {
            shiftStrip
            Button {
                startRun(.crossing(profile.nextCrossing))
            } label: {
                HStack(spacing: 14) {
                    Image("signal_walk")
                        .resizable()
                        .frame(width: 74, height: 74)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GO!")
                            .font(Theme.display(34))
                            .foregroundColor(Theme.meadow)
                        Text(next.title)
                            .font(Theme.headline(17))
                            .foregroundColor(.white)
                        StarRow(stars: profile.stars[next.id], size: 15)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.meadow)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.panel.opacity(0.95)))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.meadow, lineWidth: 2.5).shadow(color: Theme.ink.opacity(0.3), radius: 2, x: 0, y: 2))
            }
            .buttonStyle(WalkSignalButtonStyle())
            .accessibilityLabel("Go: start \(next.title)")
            .accessibilityIdentifier(AccessibilityID.walkButton)

            HStack(spacing: 10) {
                modeTile(title: "Long Road", detail: profile.bestLongRoadLanes > 0 ? "Best \(profile.bestLongRoadLanes) lanes" : "Endless field road",
                         color: Theme.pumpkin, id: AccessibilityID.longRoadButton) {
                    startRun(.longRoad)
                }
                modeTile(title: "Daily", detail: dailyDetail, color: Theme.wheat, id: AccessibilityID.dailyButton) {
                    startRun(.daily(store.todayKey))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    /// This week's Farm Week rule and the Sunflower Row progress (opens Top Players).
    private var shiftStrip: some View {
        let shift = store.shift
        return Button {
            router.open(.roster)
        } label: {
            HStack(spacing: 8) {
                ArtIcon(name: shift.theme.art, size: 28, tint: Color.white.opacity(0.1))
                VStack(alignment: .leading, spacing: 0) {
                    Text("FARM WEEK · \(shift.theme.title.uppercased())")
                        .font(Theme.chalkFont(11))
                        .foregroundColor(Theme.pumpkin)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(shift.theme.detail)
                        .font(Theme.body(12))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 4)
                HStack(spacing: 2) {
                    ForEach(0..<SunflowerRow.sunflowersPerWeek, id: \.self) { i in
                        Circle()
                            .fill(i < store.sunflowersLitThisWeek ? Theme.pumpkin : Color.white.opacity(0.18))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.panel.opacity(0.92)))
            .overlay(Capsule().stroke(Theme.pumpkin.opacity(0.6), lineWidth: 1.5))
        }
        .buttonStyle(WalkSignalButtonStyle())
        .accessibilityLabel("Farm Week: \(shift.theme.title). \(shift.theme.detail) \(store.sunflowersLitThisWeek) of 7 sunflowers in bloom.")
        .accessibilityIdentifier(AccessibilityID.shiftStrip)
    }

    private var dailyDetail: String {
        if let best = profile.dailyBest[store.todayKey] { return "Today \(Formatters.number(best))" }
        return "Same road for all"
    }

    private func modeTile(title: String, detail: String, color: Color, id: String, action: @escaping () -> Void) -> some View {
        let unlocked = profile.longRoadUnlocked
        return Button {
            if unlocked { action() } else { router.show(toast: "Clear all of Meadow Lane to open \(title).") }
        } label: {
            HStack(spacing: 8) {
                Image(unlocked ? "signal_walk" : "signal_stop")
                    .resizable()
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(Theme.display(19))
                        .foregroundColor(unlocked ? color : Theme.mutedText)
                    Text(unlocked ? detail : "Locked")
                        .font(Theme.body(12))
                        .foregroundColor(Theme.mutedText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.panel.opacity(0.95)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(unlocked ? 0.9 : 0.3), lineWidth: 2))
        }
        .buttonStyle(WalkSignalButtonStyle())
        .accessibilityLabel(unlocked ? "\(title), \(detail)" : "\(title), locked")
        .accessibilityIdentifier(id)
    }
}

/// One wooden finger sign pointing right, with generated art and the section name.
struct SignPlank: View {
    let route: Route

    var body: some View {
        HStack(spacing: 8) {
            ArtIcon(name: route.art, size: 30, tint: Color.white.opacity(0.18))
            VStack(alignment: .leading, spacing: -2) {
                Text(route.signTitle.uppercased())
                    .font(Theme.display(20))
                    .foregroundColor(.white)
                Text(route.signSubtitle)
                    .font(Theme.body(11))
                    .foregroundColor(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 12)
        .padding(.trailing, 34)
        .frame(width: 214, height: 46, alignment: .leading)
        .background(
            Image("sign_plank")
                .resizable()
        )
        .shadow(color: .black.opacity(0.5), radius: 4, y: 3)
    }
}
