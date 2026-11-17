import SwiftUI

/// One page of the rules, shared by the Almanac and the first-launch tutorial.
struct RulePage: Identifiable {
    let id: Int
    let art: String
    let title: String
    let text: String

    static let all: [RulePage] = [
        RulePage(id: 0, art: "tut_hop", title: "Hop the lanes",
                 text: "Tap to hop forward. Swipe left or right to sidestep, swipe down to hop back. Tractors and trucks only hurt you in your own lane."),
        RulePage(id: 1, art: "tut_roost", title: "Basket Climb & Roost",
                 text: "Every new lane lays an egg. The wooden sign shows the multiplier: it climbs the longer you go without roosting. Tap ROOST on a hay strip to bank the basket. A bump loses everything unbanked."),
        RulePage(id: 2, art: "tut_bell", title: "Farm Bell",
                 text: "Lanes and corn fill the grain sack. Ring the bell to hold your lane and the next two. When the hold ends those lanes rush at full speed, so be across by then."),
        RulePage(id: 3, art: "tut_truck", title: "Corn Truck Spill",
                 text: "A honk and HONK arrows warn of a long corn truck. It spills kernels behind it: grain for the bell, coins, and cool feet."),
        RulePage(id: 4, art: "tut_sprinkler", title: "Sprinkler Bursts",
                 text: "Sprinklers gurgle and drip first, then shoot a jet of water. Never stand on a gurgling sprinkler; step aside and wait for it to stop."),
        RulePage(id: 5, art: "tut_heat", title: "Hot Gravel",
                 text: "On sunbaked roads your feet heat up while you stand still. When the thermometer fills, you hop forward on your own. Hay strips and corn cool you down."),
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
                .foregroundColor(Theme.wheat)
            Text(page.text)
                .font(Theme.body(16))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.panel.opacity(0.96)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.meadow.opacity(0.6), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }
}

/// The Almanac: every mechanic plus district and scoring notes.
struct RulebookView: View {
    @ObservedObject var router: AppRouter
    let coins: Int

    var body: some View {
        VStack(spacing: 10) {
            FarmHeader(title: "ALMANAC", color: Theme.wheat, coins: coins, onBack: router.back)
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(RulePage.all) { page in
                        RulePageView(page: page)
                    }
                    PlankPanel(tint: Theme.wheat) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Stars & coins")
                                .font(Theme.display(22))
                                .foregroundColor(Theme.wheat)
                            Text("★ Reach the coop on the far side.\n★★ Bank at least par (roosting on every hay strip).\n★★★ Bank a daring score — only possible by skipping hay strips.\n\nBanked eggs convert to coins 8:1, kernels pay coins, finishing adds 25. Spend coins in the Feed Store and the Henhouse.")
                                .font(Theme.body(15))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    PlankPanel(tint: Theme.pumpkin) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Districts")
                                .font(Theme.display(22))
                                .foregroundColor(Theme.pumpkin)
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
        .backdrop("timetable_backdrop", dim: 0.1)
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
                        .fill(page.id == index ? Theme.meadow : Color.white.opacity(0.25))
                        .frame(width: 9, height: 9)
                }
            }
            .accessibilityHidden(true)
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                Button("Skip", action: onDone)
                    .buttonStyle(FarmButtonStyle(color: Theme.mutedText))
                Button(index == RulePage.all.count - 1 ? "Let's cross" : "Next") {
                    if index == RulePage.all.count - 1 {
                        onDone()
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) { index += 1 }
                    }
                }
                .buttonStyle(FarmButtonStyle(color: Theme.meadow, filled: true))
                .accessibilityIdentifier(AccessibilityID.tutorialNext)
            }
        }
        .padding(20)
        .frame(maxWidth: Theme.maxContentWidth)
        .frame(maxWidth: .infinity)
        .backdrop("corner_backdrop", dim: 0.15)
        .preferredColorScheme(.light)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.tutorialScreen)
    }
}
