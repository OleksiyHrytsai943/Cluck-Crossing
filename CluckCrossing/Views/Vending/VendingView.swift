import SwiftUI

/// Upgrades in a country Feed Store: goods sit on wooden shelves,
/// the counter shows the selected item, its level pegs and the BUY key.
struct VendingView: View {
    @StateObject private var viewModel: VendingViewModel
    @ObservedObject private var store: ProfileStore
    @ObservedObject var router: AppRouter

    init(viewModel: @autoclosure @escaping () -> VendingViewModel, store: ProfileStore, router: AppRouter) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.store = store
        self.router = router
    }

    var body: some View {
        VStack(spacing: 10) {
            FarmHeader(title: "FEED STORE", color: Theme.wheat, coins: store.coins, onBack: router.back)
            ScrollView {
                VStack(spacing: 0) {
                    machineTop
                    glassFront
                    controlPanel
                    tray
                }
                .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.barnRed))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.ink, lineWidth: 3))
                .shadow(color: Theme.ink.opacity(0.3), radius: 2, x: 0, y: 2)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: Theme.maxContentWidth)
        .frame(maxWidth: .infinity)
        .backdrop("vending_backdrop")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.vendingScreen)
    }

    private var machineTop: some View {
        HStack {
            PaintedText(text: "FEED & SUPPLY", size: 22, color: Theme.wheat)
            Spacer()
            Text("EST. 1952")
                .font(Theme.chalkFont(14))
                .foregroundColor(Theme.meadow)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private var glassFront: some View {
        VStack(spacing: 8) {
            ForEach(UpgradeKind.allCases) { kind in
                productRow(kind)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [Color(red: 0.42, green: 0.28, blue: 0.16), Color(red: 0.30, green: 0.19, blue: 0.10)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            // Glass sheen.
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [Color.white.opacity(0.10), .clear], startPoint: .topLeading, endPoint: .center))
                .allowsHitTesting(false)
        )
        .padding(.horizontal, 12)
    }

    private func productRow(_ kind: UpgradeKind) -> some View {
        let level = viewModel.level(kind)
        let selected = viewModel.selected == kind
        return Button {
            viewModel.selected = kind
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    // Spiral coil behind the product.
                    Circle()
                        .stroke(Color.gray.opacity(0.6), style: StrokeStyle(lineWidth: 3, dash: [4, 3]))
                        .frame(width: 58, height: 58)
                    Image(kind.art)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 54, height: 54)
                        .offset(y: viewModel.lastVend == kind ? 4 : 0)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.title)
                        .font(Theme.headline(17))
                        .foregroundColor(.white)
                    LevelDots(level: level, max: kind.maxLevel)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Level \(level) of \(kind.maxLevel)")
                        .accessibilityValue("\(level)")
                        .accessibilityIdentifier(AccessibilityID.vendingLevel(kind))
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(kind.slot)
                        .font(Theme.chalkFont(13))
                        .foregroundColor(Theme.meadow)
                    if let price = kind.price(forLevel: level) {
                        HStack(spacing: 3) {
                            Image("coin").resizable().frame(width: 14, height: 14)
                            Text(Formatters.number(price))
                                .font(Theme.chalkFont(13))
                                .foregroundColor(Theme.wheat)
                        }
                    } else {
                        Text("SOLD OUT")
                            .font(Theme.chalkFont(11))
                            .foregroundColor(Theme.tomato)
                    }
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Theme.meadow.opacity(0.16) : Color.white.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Theme.meadow : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.title), level \(level) of \(kind.maxLevel)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var controlPanel: some View {
        let kind = viewModel.selected
        let price = viewModel.price(kind)
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(kind.slot) · \(kind.title.uppercased())")
                    .font(Theme.chalkFont(13))
                    .foregroundColor(Theme.meadow)
                Text(kind.detail)
                    .font(Theme.body(14))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.chalkboard))
            Button {
                router.show(toast: viewModel.buy(kind))
            } label: {
                VStack(spacing: 2) {
                    Text(price == nil ? "MAX" : "BUY")
                        .font(Theme.display(22))
                    if let price {
                        Text(Formatters.number(price))
                            .font(Theme.chalkFont(12))
                    }
                }
                .foregroundColor(Theme.ink)
                .frame(width: 78, height: 70)
                .background(RoundedRectangle(cornerRadius: 14).fill(price == nil ? Color.gray : Theme.wheat))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink, lineWidth: 2))
            }
            .buttonStyle(WalkSignalButtonStyle())
            .disabled(price == nil)
            .accessibilityLabel(price.map { "Buy \(kind.title) for \($0) coins" } ?? "\(kind.title) is maxed")
            .accessibilityIdentifier(AccessibilityID.vendingBuy(kind))
        }
        .padding(12)
    }

    private var tray: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Theme.chalkboard)
            .frame(height: 34)
            .overlay(Text("THANK YOU, COME AGAIN").font(Theme.chalkFont(11)).foregroundColor(Theme.chalk))
            .padding(.horizontal, 60)
            .padding(.bottom, 14)
            .accessibilityHidden(true)
    }
}

/// Wooden pegs for an upgrade level.
struct LevelDots: View {
    let level: Int
    let max: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<max, id: \.self) { i in
                Circle()
                    .fill(i < level ? Theme.meadow : Color.white.opacity(0.15))
                    .frame(width: 10, height: 10)
                    .shadow(color: Theme.ink.opacity(0.3), radius: 2, x: 0, y: 2)
            }
        }
    }
}
