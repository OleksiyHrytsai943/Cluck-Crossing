import SwiftUI

// MARK: - Backgrounds

/// Full-screen generated backdrop that never widens the layout (see skill pitfalls).
struct Backdrop: ViewModifier {
    let image: String
    var dim: Double = 0

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Image(image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay(Color.black.opacity(dim))
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        }
    }
}

extension View {
    func backdrop(_ image: String, dim: Double = 0) -> some View {
        modifier(Backdrop(image: image, dim: dim))
    }
}

// MARK: - Painted sign text

/// Hand-painted sign lettering: colour fill with a dark ink outline so it reads on sky, wood or fields.
struct PaintedText: View {
    let text: String
    var size: CGFloat = 28
    var color: Color = Theme.barnRed

    var body: some View {
        Text(text)
            .font(Theme.display(size))
            .foregroundColor(color)
            .shadow(color: Theme.ink, radius: 0, x: 1.5, y: 1.5)
            .shadow(color: Theme.ink, radius: 0, x: -1, y: -1)
            .shadow(color: Theme.ink.opacity(0.35), radius: 3, x: 0, y: 3)
    }
}

/// Walnut sign board; light text on it keeps contrast regardless of the backdrop.
struct PlankPanel<Content: View>: View {
    var tint: Color = Theme.meadow
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.panel.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .stroke(tint.opacity(0.9), lineWidth: 3)
            )
            .shadow(color: Theme.ink.opacity(0.3), radius: 3, x: 0, y: 3)
    }
}

// MARK: - Buttons

/// Press feedback for sign-shaped buttons.
struct WalkSignalButtonStyle: ButtonStyle {
    var lit = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Chunky painted pill used for secondary actions (result card, sheets).
struct FarmButtonStyle: ButtonStyle {
    var color: Color = Theme.meadow
    var filled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(20))
            .foregroundColor(filled ? Theme.ink : .white)
            .padding(.horizontal, 20)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(filled ? color : Theme.panel.opacity(0.92))
            )
            .overlay(Capsule().stroke(filled ? Theme.ink : color, lineWidth: 2.5))
            .shadow(color: Theme.ink.opacity(0.3), radius: 2, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Little wooden gate sign: the app-wide "back" control.
struct PushBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image("push_button")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 32)
                VStack(alignment: .leading, spacing: -2) {
                    Text("BACK TO")
                        .font(Theme.headline(10))
                    Text("FARMYARD")
                        .font(Theme.display(15))
                }
                .lineLimit(1)
                .fixedSize()
                .foregroundColor(Theme.ink)
            }
            .padding(.leading, 6)
            .padding(.trailing, 10)
            .frame(minHeight: 48)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.wheat))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
        .accessibilityIdentifier(AccessibilityID.backButton)
    }
}

// MARK: - Coins

struct CoinBadge: View {
    let coins: Int

    var body: some View {
        HStack(spacing: 6) {
            Image("coin")
                .resizable()
                .frame(width: 24, height: 24)
            Text(Formatters.number(coins))
                .font(Theme.chalkFont(17))
                .foregroundColor(Theme.wheat)
                .numericTransition()
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .background(Capsule().fill(Theme.panel.opacity(0.92)))
        .overlay(Capsule().stroke(Theme.wheat.opacity(0.7), lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(coins) coins")
        .accessibilityValue("\(coins)")
        .accessibilityIdentifier(AccessibilityID.coinsBadge)
    }
}

// MARK: - Screen header

/// Shared header row: back gate, painted title, coin badge.
struct FarmHeader: View {
    let title: String
    var color: Color = Theme.meadow
    let coins: Int
    let onBack: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            PushBackButton(action: onBack)
            Spacer(minLength: 4)
            PaintedText(text: title, size: 24, color: color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .layoutPriority(-1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 4)
            CoinBadge(coins: coins)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}

// MARK: - Toast

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(Theme.headline(17))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Capsule().fill(Theme.panel.opacity(0.96)))
            .overlay(Capsule().stroke(Theme.barnRed, lineWidth: 2))
            .padding(.horizontal, 24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(message)
            .accessibilityIdentifier(AccessibilityID.toast)
    }
}

/// Tiny image on a tinted disc so light art reads on light or dark backgrounds.
struct ArtIcon: View {
    let name: String
    var size: CGFloat = 36
    var tint: Color = Theme.panel

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .padding(size * 0.12)
            .frame(width: size, height: size)
            .background(Circle().fill(tint))
            .accessibilityHidden(true)
    }
}

/// Row of star images (0–3).
struct StarRow: View {
    let stars: Int
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(i < stars ? "star_on" : "star_off")
                    .resizable()
                    .frame(width: size, height: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stars) of 3 stars")
    }
}
