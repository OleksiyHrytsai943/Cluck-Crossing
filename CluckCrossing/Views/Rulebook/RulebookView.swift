import SwiftUI

/// One page of the rules, shared by the Rulebook and the first-launch tutorial.
struct RulePage: Identifiable {
    let id: Int
    let art: String
    let title: String
    let text: String

    static let all: [RulePage] = [
        RulePage(id: 0, art: "tut_hop", title: "Hop the lanes",
                 text: "Tap to hop forward. Swipe left or right to sidestep, swipe down to hop back. Cars only hurt you in your own lane."),
        RulePage(id: 1, art: "tut_roost", title: "Clutch Climb & Roost",
                 text: "Every new lane lays an egg. The neon plaque shows the multiplier: it climbs the longer you go without roosting. Tap ROOST on a traffic island to bank the clutch. A bump loses everything unbanked."),
        RulePage(id: 2, art: "tut_whistle", title: "Crossing Guard Whistle",
                 text: "Lanes and corn fill the whistle. Blow it to freeze your lane and the next two. When the freeze ends those lanes rush at full speed, so be across by then."),
        RulePage(id: 3, art: "tut_truck", title: "Corn Truck Spill",
                 text: "A honk and amber arrows warn of a long corn truck. It spills kernels behind it: grain for the whistle, coins, and cool feet."),
        RulePage(id: 4, art: "tut_manhole", title: "Manhole Flares",
                 text: "Lids glow orange, then shoot fire. Never stand on a glowing lid; step aside and wait for it to cool."),
        RulePage(id: 5, art: "tut_heat", title: "Hot Asphalt",
                 text: "On hot roads your feet heat up while you stand still. When the thermometer fills, you hop forward on your own. Islands and corn cool you down."),
    ]
}

struct RulePageView: View {
    let page: RulePage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(page.art)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            Text(page.title)
                .font(Theme.display(24))
                .foregroundColor(Theme.eggGold)
            Text(page.text)
                .font(Theme.body(16))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.panel.opacity(0.96)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.neonTeal.opacity(0.6), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }
}

/// The rulebook: every mechanic plus district and scoring notes.
struct RulebookView: View {
    @ObservedObject var router: AppRouter
    let coins: Int

    var body: some View {
        VStack(spacing: 10) {
            StreetHeader(title: "RULEBOOK", color: Theme.neonTeal, coins: coins, onBack: router.back)
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(RulePage.all) { page in
                        RulePageView(page: page)
                    }
                    LEDPanel(tint: Theme.eggGold) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Stars & coins")
                                .font(Theme.display(22))
                                .foregroundColor(Theme.eggGold)
                            Text("★ Reach the far curb.\n★★ Bank at least par (roosting on every island).\n★★★ Bank a daring score — only possible by skipping islands.\n\nBanked eggs convert to coins 8:1, kernels pay coins, finishing adds 25. Spend coins in the Vending machine and the Henhouse.")
                                .font(Theme.body(15))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    LEDPanel(tint: Theme.neonPink) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Districts")
                                .font(Theme.display(22))
                                .foregroundColor(Theme.neonPink)
                            ForEach(District.all) { d in
                                Text("\(d.name): \(d.newHazard)")
                                    .font(Theme.body(14))
                                    .foregroundColor(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: Theme.maxContentWidth)
        .frame(maxWidth: .infinity)
        .backdrop("timetable_backdrop", dim: 0.3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.rulebookScreen)
    }
}

/// First-launch walkthrough: the same rule pages, one at a time.
struct TutorialView: View {
    let onDone: () -> Void
    @State private var index = 0

    var body: some View {
        VStack(spacing: 16) {
            Image("logo_wordmark")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 260)
                .accessibilityLabel("Cluck Crossing")
            Spacer(minLength: 0)
            RulePageView(page: RulePage.all[index])
                .id(index)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
            HStack(spacing: 8) {
                ForEach(RulePage.all) { page in
                    Circle()
                        .fill(page.id == index ? Theme.neonTeal : Color.white.opacity(0.25))
                        .frame(width: 9, height: 9)
                }
            }
            .accessibilityHidden(true)
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                Button("Skip", action: onDone)
                    .buttonStyle(NeonPillButtonStyle(color: Theme.mutedText))
                Button(index == RulePage.all.count - 1 ? "Let's cross" : "Next") {
                    if index == RulePage.all.count - 1 {
                        onDone()
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) { index += 1 }
                    }
                }
                .buttonStyle(NeonPillButtonStyle(color: Theme.neonTeal, filled: true))
                .accessibilityIdentifier(AccessibilityID.tutorialNext)
            }
        }
        .padding(20)
        .frame(maxWidth: Theme.maxContentWidth)
        .frame(maxWidth: .infinity)
        .backdrop("corner_backdrop", dim: 0.45)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.tutorialScreen)
    }
}
