import SwiftUI

/// Records on a rooftop: an LED ticker board with lifetime stats, neon-sign achievements
/// (lit when earned) and the trip log of recent runs.
struct BillboardView: View {
    @ObservedObject var store: ProfileStore
    @ObservedObject var router: AppRouter

    private var profile: PlayerProfile { store.profile }
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 10) {
            StreetHeader(title: "BILLBOARD", color: Theme.neonPink, coins: store.coins, onBack: router.back)
            ScrollView {
                VStack(spacing: 18) {
                    ledBoard
                    section("NEON SIGNS", detail: "\(profile.achievements.count)/\(Achievement.allCases.count) lit")
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Achievement.allCases) { a in
                            neonSign(a)
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
            NeonText(text: title, size: 22, color: Theme.neonTeal)
            Spacer()
            Text(detail)
                .font(Theme.led(13))
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
            ("signal_walk", "NIGHT RUN", "\(profile.bestNightLanes) lanes"),
            ("kernel", "KERNELS", Formatters.number(stats.kernels)),
            ("grain_token", "WHISTLES", Formatters.number(stats.whistles)),
            ("feather", "BUMPS", Formatters.number(stats.bumps)),
            ("coin", "COINS EARNED", Formatters.number(stats.coinsEarned)),
            ("hen_pepper", "RUNS", Formatters.number(stats.runs)),
        ]
        return VStack(spacing: 0) {
            ForEach(items, id: \.1) { item in
                HStack(spacing: 10) {
                    ArtIcon(name: item.0, size: 30, tint: Color.white.opacity(0.08))
                    Text(item.1)
                        .font(Theme.led(13))
                        .foregroundColor(Theme.led.opacity(0.85))
                    Spacer()
                    Text(item.2)
                        .font(Theme.led(17))
                        .foregroundColor(Theme.led)
                }
                .padding(.vertical, 5)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(white: 0.3), lineWidth: 6))
    }

    private func neonSign(_ a: Achievement) -> some View {
        let lit = profile.has(a)
        let colors = [Theme.neonPink, Theme.neonTeal, Theme.eggGold, Theme.neonRed]
        return VStack(spacing: 4) {
            Text(a.title.uppercased())
                .font(Theme.display(17))
                .foregroundColor(lit ? .white : Color(white: 0.45))
                .shadow(color: lit ? colors[a.tint] : .clear, radius: 6)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(a.detail)
                .font(Theme.body(11))
                .foregroundColor(lit ? Theme.cream : Color(white: 0.55))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 96)
        .background(
            Image(lit ? "neon_on_\(a.tint)" : "neon_off")
                .resizable()
        )
        .accessibilityElement(children: .combine)
        .accessibilityValue(lit ? "Earned" : "Locked")
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
                            .font(Theme.led(15))
                            .foregroundColor(Theme.eggGold)
                        Text(record.crossed ? "CROSSED" : "\(record.lanes) LANES")
                            .font(Theme.led(10))
                            .foregroundColor(record.crossed ? Theme.neonTeal : Theme.mutedText)
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
