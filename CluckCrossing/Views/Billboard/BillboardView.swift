import SwiftUI

/// Records on the barn wall: a chalkboard of lifetime stats, county-fair ribbons
/// (coloured when earned) and the trip log of recent runs.
struct BillboardView: View {
    @ObservedObject var store: ProfileStore
    @ObservedObject var router: AppRouter

    private var profile: PlayerProfile { store.profile }
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 10) {
            FarmHeader(title: "BARN WALL", color: Theme.wheat, coins: store.coins, onBack: router.back)
            ScrollView {
                VStack(spacing: 18) {
                    ledBoard
                    section("RIBBONS", detail: "\(profile.achievements.count)/\(Achievement.allCases.count) won")
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Achievement.allCases) { a in
                            ribbon(a)
                        }
                    }
                    section("TRIP LOG", detail: profile.history.isEmpty ? "No trips yet" : "Last \(profile.history.count)")
                    tripLog
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: Theme.maxContentWidth)
        .frame(maxWidth: .infinity)
        .backdrop("billboard_backdrop")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.billboardScreen)
    }

    private func section(_ title: String, detail: String) -> some View {
        HStack(alignment: .lastTextBaseline) {
            PaintedText(text: title, size: 22, color: Theme.meadow)
            Spacer()
            Text(detail)
                .font(Theme.chalkFont(13))
                .foregroundColor(Theme.mutedText)
        }
    }

    private var ledBoard: some View {
        let stats = profile.stats
        let items: [(String, String, String)] = [
            ("star_on", "STARS", "\(profile.totalStars)/\(CrossingSpec.count * 3)"),
            ("egg", "EGGS BANKED", Formatters.number(stats.eggsBanked)),
            ("nest", "BEST ROOST", Formatters.number(stats.bestRoost)),
            ("plaque", "BEST STREAK", "\(stats.bestStreak) lanes"),
            ("signal_walk", "LONG ROAD", "\(profile.bestLongRoadLanes) lanes"),
            ("kernel", "KERNELS", Formatters.number(stats.kernels)),
            ("grain_token", "BELLS RUNG", Formatters.number(stats.bells)),
            ("feather", "BUMPS", Formatters.number(stats.bumps)),
            ("coin", "COINS EARNED", Formatters.number(stats.coinsEarned)),
            ("hen_pepper", "RUNS", Formatters.number(stats.runs)),
        ]
        return VStack(spacing: 0) {
            ForEach(items, id: \.1) { item in
                HStack(spacing: 10) {
                    ArtIcon(name: item.0, size: 30, tint: Color.white.opacity(0.08))
                    Text(item.1)
                        .font(Theme.chalkFont(13))
                        .foregroundColor(Theme.chalk.opacity(0.85))
                    Spacer()
                    Text(item.2)
                        .font(Theme.chalkFont(17))
                        .foregroundColor(Theme.chalk)
                }
                .padding(.vertical, 5)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.chalkboard))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red: 0.55, green: 0.38, blue: 0.2), lineWidth: 8))
    }

    /// A county-fair ribbon pinned to the barn: coloured when won, faded paper when not.
    private func ribbon(_ a: Achievement) -> some View {
        let won = profile.has(a)
        return VStack(spacing: 4) {
            Image(won ? "ribbon_\(a.tint)" : "ribbon_off")
                .resizable()
                .scaledToFit()
                .frame(height: 64)
            Text(a.title.uppercased())
                .font(Theme.display(16))
                .foregroundColor(won ? .white : Theme.mutedText.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(a.detail)
                .font(Theme.body(11))
                .foregroundColor(won ? Theme.cream : Theme.mutedText.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panel.opacity(won ? 0.95 : 0.8)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(won ? Theme.wheat : Color.clear, lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityValue(won ? "Earned" : "Locked")
        .accessibilityIdentifier(AccessibilityID.achievement(a))
    }

    private var tripLog: some View {
        VStack(spacing: 0) {
            if profile.history.isEmpty {
                Text("Your crossings will be logged here.")
                    .font(Theme.body(14))
                    .foregroundColor(Theme.mutedText)
                    .padding(16)
            }
            ForEach(profile.history) { record in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(record.mode.title)
                            .font(Theme.headline(16))
                            .foregroundColor(.white)
                        Text(Formatters.shortDate.string(from: record.date))
                            .font(Theme.body(11))
                            .foregroundColor(Theme.mutedText)
                    }
                    Spacer()
                    if record.stars > 0 { StarRow(stars: record.stars, size: 13) }
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Formatters.number(record.banked))
                            .font(Theme.chalkFont(15))
                            .foregroundColor(Theme.wheat)
                        Text(record.crossed ? "CROSSED" : "\(record.lanes) LANES")
                            .font(Theme.chalkFont(10))
                            .foregroundColor(record.crossed ? Theme.meadow : Theme.mutedText)
                    }
                    .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .overlay(Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1), alignment: .bottom)
                .accessibilityElement(children: .combine)
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panel.opacity(0.95)))
    }
}
