import SwiftUI

/// Crossing select as a chalk route board by the farm mailbox, grouped by district.
struct TimetableView: View {
    @ObservedObject var store: ProfileStore
    @ObservedObject var router: AppRouter
    let startRun: (RunMode) -> Void

    var body: some View {
        VStack(spacing: 10) {
            FarmHeader(title: "ROUTE BOARD", color: Theme.wheat, coins: store.coins, onBack: router.back)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14, pinnedViews: []) {
                        ForEach(District.all) { district in
                            districtBoard(district)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
                .onAppear {
                    proxy.scrollTo(store.profile.nextCrossing, anchor: .center)
                }
            }
        }
        .frame(maxWidth: Theme.maxContentWidth)
        .frame(maxWidth: .infinity)
        .backdrop("timetable_backdrop")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.timetableScreen)
    }

    private func districtBoard(_ district: District) -> some View {
        let specs = CrossingSpec.all.filter { $0.district.id == district.id }
        let cleared = specs.filter { store.profile.stars[$0.id] > 0 }.count
        return VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Image(district.art)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 92)
                    .clipped()
                    // scaledToFill overflows its frame for hit-testing; without this the
                    // postcard swallows taps on the last row of the district above.
                    .allowsHitTesting(false)
                LinearGradient(colors: [.clear, Theme.panel], startPoint: .top, endPoint: .bottom)
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("ROUTE \(district.id + 1)")
                            .font(Theme.chalkFont(12))
                            .foregroundColor(Theme.chalk)
                        Text(district.name.uppercased())
                            .font(Theme.display(24))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("\(cleared)/\(specs.count)")
                        .font(Theme.chalkFont(15))
                        .foregroundColor(Theme.chalk)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
            Text(district.tagline)
                .font(Theme.body(13))
                .foregroundColor(Theme.mutedText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            columnHeader
            ForEach(specs) { spec in
                row(spec)
                    .id(spec.id)
            }
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.panel.opacity(0.96)))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.chalk.opacity(0.5), lineWidth: 1.5))
    }

    private var columnHeader: some View {
        HStack {
            Text("NO.").frame(width: 34, alignment: .leading)
            Text("CROSSING")
            Spacer()
            Text("LANES").frame(width: 50)
            Text("STATUS").frame(width: 70, alignment: .trailing)
        }
        .font(Theme.chalkFont(11))
        .foregroundColor(Theme.chalk.opacity(0.7))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .accessibilityHidden(true)
    }

    private func row(_ spec: CrossingSpec) -> some View {
        let unlocked = store.profile.isUnlocked(crossing: spec.id)
        let stars = store.profile.stars[spec.id]
        let best = store.profile.bestScores[spec.id]
        return Button {
            if unlocked {
                startRun(.crossing(spec.id))
            } else {
                router.show(toast: "Finish the crossing before it to unlock this one.")
            }
        } label: {
            HStack(spacing: 8) {
                FlapText(text: String(format: "%02d", spec.id + 1), width: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(spec.title.uppercased())
                        .font(Theme.headline(17))
                        .foregroundColor(unlocked ? .white : Theme.mutedText.opacity(0.6))
                    if best > 0 {
                        Text("Best \(Formatters.number(best)) · ★★ at \(StarRule.thresholds(for: spec).two) · ★★★ at \(StarRule.thresholds(for: spec).three)")
                            .font(Theme.body(11))
                            .foregroundColor(Theme.mutedText)
                    } else if unlocked {
                        Text("★★ at \(StarRule.thresholds(for: spec).two) · ★★★ at \(StarRule.thresholds(for: spec).three)")
                            .font(Theme.body(11))
                            .foregroundColor(Theme.mutedText)
                    }
                }
                Spacer(minLength: 4)
                FlapText(text: "\(spec.laneCount)", width: 42)
                Group {
                    if unlocked {
                        StarRow(stars: stars, size: 18)
                    } else {
                        Image("lock").resizable().frame(width: 24, height: 24)
                    }
                }
                .frame(width: 66, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 54)
            .background(spec.id == store.profile.nextCrossing ? Theme.chalk.opacity(0.12) : Color.clear)
            .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1), alignment: .top)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unlocked ? "\(spec.title), \(spec.laneCount) lanes, \(stars) stars" : "\(spec.title), locked")
        .accessibilityIdentifier(AccessibilityID.crossing(spec.id))
    }
}

/// Chalk numbers on a small slate.
struct FlapText: View {
    let text: String
    var width: CGFloat

    var body: some View {
        Text(text)
            .font(Theme.chalkFont(16))
            .foregroundColor(Theme.chalk)
            .frame(width: width, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Theme.chalkboard)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(red: 0.55, green: 0.38, blue: 0.2), lineWidth: 2))
            )
    }
}

/// Postcard shown before the first crossing of a new district: explains its new hazard.
struct DistrictCardView: View {
    let intro: AppRouter.DistrictIntro
    let onStart: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Theme.soil.opacity(0.6).ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(spacing: 14) {
                Image(intro.district.art)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Text("NOW ENTERING")
                    .font(Theme.chalkFont(13))
                    .foregroundColor(Theme.chalk)
                PaintedText(text: intro.district.name.uppercased(), size: 32, color: Theme.barnRed)
                    .multilineTextAlignment(.center)
                Text(intro.district.newHazard)
                    .font(Theme.body(16))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Cross \(CrossingSpec.all[intro.crossing].title)", action: onStart)
                    .buttonStyle(FarmButtonStyle(color: Theme.meadow, filled: true))
                    .accessibilityIdentifier(AccessibilityID.districtStart)
                Button("Not now", action: onClose)
                    .font(Theme.headline(16))
                    .foregroundColor(Theme.mutedText)
                    .frame(minHeight: 44)
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.panel))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.barnRed, lineWidth: 2))
            .padding(22)
            .frame(maxWidth: Theme.maxContentWidth)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.districtCard)
        }
    }
}
