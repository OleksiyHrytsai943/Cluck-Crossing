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

// MARK: - Neon & LED text

struct NeonText: View {
    let text: String
    var size: CGFloat = 28
    var color: Color = Theme.neonPink

    var body: some View {
        Text(text)
            .font(Theme.display(size))
            .foregroundColor(.white.opacity(0.95))
            .shadow(color: color, radius: 2)
            .shadow(color: color, radius: 8)
            .shadow(color: color.opacity(0.6), radius: 16)
    }
}

/// Dark panel with an inset LED look; text on it keeps contrast regardless of the backdrop.
struct LEDPanel<Content: View>: View {
    var tint: Color = Theme.neonTeal
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
                    .stroke(tint.opacity(0.85), lineWidth: 2)
                    .shadow(color: tint, radius: 6)
            )
    }
}

// MARK: - Buttons

/// The big pedestrian-signal button (primary action).
struct WalkSignalButtonStyle: ButtonStyle {
    var lit = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Chunky neon pill used for secondary actions (result screen, sheets).
struct NeonPillButtonStyle: ButtonStyle {
    var color: Color = Theme.neonTeal
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
            .overlay(Capsule().stroke(color, lineWidth: 2.5).shadow(color: color, radius: 6))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Yellow crosswalk push-button box: the app-wide "back" control.
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
                    Text("PUSH TO")
                        .font(Theme.headline(10))
                    Text("RETURN")
                        .font(Theme.display(16))
                }
                .lineLimit(1)
                .fixedSize()
                .foregroundColor(Theme.ink)
            }
            .padding(.leading, 6)
            .padding(.trailing, 10)
            .frame(minHeight: 48)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.eggGold))
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
                .font(Theme.led(17))
                .foregroundColor(Theme.eggGold)
                .numericTransition()
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .background(Capsule().fill(Theme.panel.opacity(0.92)))
        .overlay(Capsule().stroke(Theme.eggGold.opacity(0.7), lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(coins) coins")
        .accessibilityValue("\(coins)")
        .accessibilityIdentifier(AccessibilityID.coinsBadge)
    }
}

// MARK: - Screen header

/// Shared header row: back button, neon title, coin badge.
struct StreetHeader: View {
    let title: String
    var color: Color = Theme.neonTeal
    let coins: Int
    let onBack: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            PushBackButton(action: onBack)
            Spacer(minLength: 4)
            NeonText(text: title, size: 24, color: color)
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
            .overlay(Capsule().stroke(Theme.neonPink, lineWidth: 2))
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
