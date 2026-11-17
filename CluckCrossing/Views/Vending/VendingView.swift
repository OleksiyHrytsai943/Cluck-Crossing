import SwiftUI

/// Upgrades as a glowing all-night vending machine: products sit on coils behind glass,
/// the side panel shows the selected product, its LED level dots and the BUY key.
struct VendingView: View {
    @StateObject private var viewModel: VendingViewModel
    @ObservedObject private var store: ProfileStore
    @ObservedObject var router: AppRouter

    init(viewModel: @autoclosure @escaping () -> VendingViewModel, router: AppRouter) {
        let vm = viewModel()
        _viewModel = StateObject(wrappedValue: vm)
        store = vm.store
        self.router = router
    }

    var body: some View {
        VStack(spacing: 10) {
            StreetHeader(title: "VENDING", color: Theme.neonPink, coins: store.coins, onBack: router.back)
            ScrollView {
                VStack(spacing: 0) {
                    machineTop
                    glassFront
                    controlPanel
                    tray
                }
                .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color(red: 0.62, green: 0.08, blue: 0.2)))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.ink, lineWidth: 3))
                .shadow(color: Theme.neonPink.opacity(0.5), radius: 20)
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
            NeonText(text: "SNACKS & GEAR", size: 22, color: Theme.eggGold)
            Spacer()
            Text("24/7")
                .font(Theme.led(14))
                .foregroundColor(Theme.neonTeal)
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
                .fill(LinearGradient(colors: [Color(red: 0.1, green: 0.12, blue: 0.2), Color(red: 0.05, green: 0.06, blue: 0.12)], startPoint: .top, endPoint: .bottom))
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
                        .font(Theme.led(13))
                        .foregroundColor(Theme.neonTeal)
                    if let price = kind.price(forLevel: level) {
                        HStack(spacing: 3) {
                            Image("coin").resizable().frame(width: 14, height: 14)
                            Text(Formatters.number(price))
                                .font(Theme.led(13))
                                .foregroundColor(Theme.eggGold)
                        }
                    } else {
                        Text("SOLD OUT")
                            .font(Theme.led(11))
                            .foregroundColor(Theme.neonRed)
                    }
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Theme.neonTeal.opacity(0.16) : Color.white.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Theme.neonTeal : Color.clear, lineWidth: 2))
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
                    .font(Theme.led(13))
                    .foregroundColor(Theme.neonTeal)
                Text(kind.detail)
                    .font(Theme.body(14))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black))
            Button {
                router.show(toast: viewModel.buy(kind))
            } label: {
                VStack(spacing: 2) {
                    Text(price == nil ? "MAX" : "BUY")
                        .font(Theme.display(22))
                    if let price {
                        Text(Formatters.number(price))
                            .font(Theme.led(12))
                    }
                }
                .foregroundColor(Theme.ink)
                .frame(width: 78, height: 70)
                .background(RoundedRectangle(cornerRadius: 14).fill(price == nil ? Color.gray : Theme.eggGold))
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
            .fill(Color.black.opacity(0.85))
            .frame(height: 34)
            .overlay(Text("PUSH").font(Theme.led(12)).foregroundColor(.gray))
            .padding(.horizontal, 60)
            .padding(.bottom, 14)
            .accessibilityHidden(true)
    }
}

/// LED dots for an upgrade level.
struct LevelDots: View {
    let level: Int
    let max: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<max, id: \.self) { i in
                Circle()
                    .fill(i < level ? Theme.neonTeal : Color.white.opacity(0.15))
                    .frame(width: 10, height: 10)
                    .shadow(color: i < level ? Theme.neonTeal : .clear, radius: 4)
            }
        }
    }
}
