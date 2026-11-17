import SwiftUI

/// Hens live in the windows of a night apartment block. Lit windows are adopted hens;
/// tapping a window draws its curtain and shows that hen on the porch panel below.
struct HenhouseView: View {
    @StateObject private var viewModel: HenhouseViewModel
    @ObservedObject private var store: ProfileStore
    @ObservedObject var router: AppRouter

    init(viewModel: @autoclosure @escaping () -> HenhouseViewModel, router: AppRouter) {
        let vm = viewModel()
        _viewModel = StateObject(wrappedValue: vm)
        store = vm.store
        self.router = router
    }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        VStack(spacing: 8) {
            StreetHeader(title: "HENHOUSE", color: Theme.eggGold, coins: store.coins, onBack: router.back)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Hen.all) { hen in
                        window(hen)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 70)
                .padding(.bottom, 12)
            }
            porch
        }
        .frame(maxWidth: Theme.maxContentWidth)
        .frame(maxWidth: .infinity)
        .backdrop("henhouse_backdrop")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.henhouseScreen)
    }

    private func window(_ hen: Hen) -> some View {
        let owned = viewModel.isOwned(hen)
        let focused = viewModel.focused == hen.id
        let selected = viewModel.isSelected(hen)
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { viewModel.focused = hen.id }
        } label: {
            ZStack(alignment: .bottom) {
                // Window light: warm if adopted, cold blue if empty.
                RoundedRectangle(cornerRadius: 6)
                    .fill(owned
                          ? LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.5), Theme.sodium], startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [Color(red: 0.12, green: 0.16, blue: 0.3), Color(red: 0.05, green: 0.07, blue: 0.15)], startPoint: .top, endPoint: .bottom))
                Image(hen.art)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .opacity(owned ? 1 : 0.35)
                    .colorMultiply(owned ? .white : Color(red: 0.4, green: 0.45, blue: 0.7))
                // Curtains part for the focused window.
                HStack(spacing: 0) {
                    Rectangle().fill(Theme.neonRed.opacity(0.85))
                        .frame(width: focused ? 10 : 40)
                    Spacer(minLength: 0)
                    Rectangle().fill(Theme.neonRed.opacity(0.85))
                        .frame(width: focused ? 10 : 40)
                }
                // Window cross bar & sill.
                Rectangle().fill(Theme.ink).frame(height: 5).offset(y: -60)
                Rectangle().fill(Color(white: 0.75)).frame(height: 8).offset(y: 4)
                if selected {
                    Text("OUT TONIGHT")
                        .font(Theme.led(10))
                        .foregroundColor(Theme.ink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.neonTeal))
                        .offset(y: -6)
                }
            }
            .frame(height: 140)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(focused ? Theme.neonTeal : Theme.ink, lineWidth: focused ? 4 : 5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(owned ? "\(hen.name)\(selected ? ", chosen" : "")" : "\(hen.name), \(hen.price) coins")
        .accessibilityIdentifier(AccessibilityID.henWindow(hen.id))
    }

    private var porch: some View {
        let hen = viewModel.focusedHen
        let owned = viewModel.isOwned(hen)
        let selected = viewModel.isSelected(hen)
        return HStack(alignment: .center, spacing: 12) {
            Image(hen.art)
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
            VStack(alignment: .leading, spacing: 3) {
                Text(hen.name)
                    .font(Theme.display(24))
                    .foregroundColor(.white)
                Text(hen.breed)
                    .font(Theme.body(12))
                    .foregroundColor(Theme.mutedText)
                Text("\(hen.perkTitle): \(hen.perkText)")
                    .font(Theme.body(14))
                    .foregroundColor(Theme.cream)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    router.show(toast: viewModel.act())
                } label: {
                    HStack(spacing: 6) {
                        if !owned {
                            Image("coin").resizable().frame(width: 18, height: 18)
                        }
                        Text(selected ? "Chosen" : owned ? "Take her out" : "Adopt \(Formatters.number(hen.price))")
                    }
                }
                .buttonStyle(NeonPillButtonStyle(color: owned ? Theme.neonTeal : Theme.eggGold, filled: !selected))
                .disabled(selected)
                .padding(.top, 4)
                .accessibilityIdentifier(AccessibilityID.henAction)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.panel.opacity(0.97)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.eggGold.opacity(0.8), lineWidth: 2))
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }
}
