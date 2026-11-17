import SwiftUI
import WebKit

/// TOP PLAYERS: the weekly Farm Week roster rendered by a local HTML template in a WebView,
/// with native Sunflower Row claim buttons underneath.
struct RosterView: View {
    @StateObject private var viewModel: RosterViewModel
    @ObservedObject private var store: ProfileStore
    @ObservedObject var router: AppRouter

    init(viewModel: @autoclosure @escaping () -> RosterViewModel, router: AppRouter) {
        let vm = viewModel()
        _viewModel = StateObject(wrappedValue: vm)
        store = vm.store
        self.router = router
    }

    var body: some View {
        VStack(spacing: 8) {
            FarmHeader(title: "TOP PLAYERS", color: Theme.wheat, coins: store.coins, onBack: router.back)
            ZStack {
                RosterWebView(json: viewModel.pageJSON)
                    .accessibilityIdentifier(AccessibilityID.rosterWeb)
                if let error = viewModel.loadError {
                    Text(error)
                        .font(Theme.body(15))
                        .foregroundColor(.white)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panel))
                }
            }
            .padding(.horizontal, 12)
            sunflowerClaims
        }
        .frame(maxWidth: Theme.maxContentWidth)
        .frame(maxWidth: .infinity)
        .backdrop("billboard_backdrop", dim: 0.1)
        .task { await viewModel.load() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.rosterScreen)
    }

    private var sunflowerClaims: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SUNFLOWER ROW · \(viewModel.sunflowersLit)/\(SunflowerRow.sunflowersPerWeek) IN BLOOM")
                .font(Theme.chalkFont(13))
                .foregroundColor(Theme.pumpkin)
                .accessibilityIdentifier(AccessibilityID.rosterSunflowers)
            HStack(spacing: 8) {
                ForEach(SunflowerRow.tiers) { tier in
                    let claimed = store.isSunflowerTierClaimed(tier)
                    let ready = viewModel.sunflowersLit >= tier.sunflowers && !claimed
                    Button {
                        Task { router.show(toast: await viewModel.claim(tier)) }
                    } label: {
                        VStack(spacing: 1) {
                            Text("\(tier.sunflowers) SUNFLOWERS")
                                .font(Theme.chalkFont(12))
                            HStack(spacing: 3) {
                                Image("coin").resizable().frame(width: 14, height: 14)
                                Text(claimed ? "Claimed" : "\(tier.coins)")
                                    .font(Theme.display(16))
                            }
                        }
                        .foregroundColor(ready ? Theme.ink : .white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(RoundedRectangle(cornerRadius: 14).fill(ready ? Theme.pumpkin : Theme.panel.opacity(0.95)))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.pumpkin.opacity(claimed ? 0.3 : 0.9), lineWidth: 2))
                    }
                    .buttonStyle(WalkSignalButtonStyle())
                    .accessibilityLabel(claimed ? "\(tier.sunflowers) sunflowers reward claimed" : "Claim \(tier.coins) coins for \(tier.sunflowers) sunflowers")
                    .accessibilityValue(ready ? "Ready" : claimed ? "Claimed" : "Locked")
                    .accessibilityIdentifier(AccessibilityID.sunflowerClaim(tier.sunflowers))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.panel.opacity(0.96)))
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}

/// WKWebView showing the bundled `top_players.html` template with the page JSON baked in.
struct RosterWebView: UIViewRepresentable {
    let json: String?

    static let dataPlaceholder = "/*ROSTER_DATA*/null"
    static let imagesPlaceholder = "/*HEN_IMAGES*/{}"

    /// Template with the page JSON and hen portraits (data URIs) injected; nil if the template is missing.
    static func html(json: String?) -> String? {
        guard let url = Bundle.main.url(forResource: "top_players", withExtension: "html"),
              let template = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var images: [String: String] = [:]
        for hen in Hen.all {
            if let file = Bundle.main.url(forResource: "roster_\(hen.art)", withExtension: "png"),
               let data = try? Data(contentsOf: file) {
                images[hen.art] = "data:image/png;base64," + data.base64EncodedString()
            }
        }
        let imagesJSON = (try? JSONEncoder().encode(images)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return template
            .replacingOccurrences(of: dataPlaceholder, with: json ?? "null")
            .replacingOccurrences(of: imagesPlaceholder, with: imagesJSON)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.navigationDelegate = context.coordinator
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        guard !context.coordinator.didLoad || context.coordinator.loadedJSON != json else { return }
        context.coordinator.loadedJSON = json
        context.coordinator.didLoad = true
        if let html = Self.html(json: json) {
            web.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedJSON: String?
        var didLoad = false

        /// The page is local; never navigate away from it.
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            let url = navigationAction.request.url
            decisionHandler(url == nil || url?.isFileURL == true || url?.scheme == "about" ? .allow : .cancel)
        }
    }
}
