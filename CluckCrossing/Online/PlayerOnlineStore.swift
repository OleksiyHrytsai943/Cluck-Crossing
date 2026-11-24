import Foundation
import Combine
import UIKit
import WebKit

private nonisolated struct ScoreAck: Decodable, Sendable { let accepted: Bool }

@MainActor
final class PlayerOnlineStore: ObservableObject {
    static let shared = PlayerOnlineStore()
    @Published private(set) var launch: LaunchDecision?
    @Published private(set) var players: [TopPlayer] = []
    @Published private(set) var leaderboardMessage: String?
    @Published var syncMessage: String? = nil
    @Published private(set) var isLoading = false
    @Published var playerName: String {
        didSet { defaults.set(playerName, forKey: "online.playerName"); Task { await updateProfile() } }
    }
    let config = OnlineConfiguration.bundled
    private let api: PlayerAPI?
    private let defaults = UserDefaults.standard
    private var appid: String { Bundle.main.bundleIdentifier ?? "" }
    private var identity: String? { UIDevice.current.identifierForVendor?.uuidString }


    init() {
        api = config.map(PlayerAPI.init(config:))
        playerName = defaults.string(forKey: "online.playerName") ?? "Farmer \(UUID().uuidString.prefix(4))"
    }

    func resolveLaunch() async {
        guard let config, let api, let identity,
              var parts = URLComponents(string: config.checkURL) else {
            launch = .temporaryGame; return
        }
        async let pushToken = PushRegistration.shared.token(timeout: 10)
        async let attribution = AdjustAttributionStore.shared.currentPayload()
        let userAgent = await WKWebView().evaluateUserAgent()
        let naming = await attribution
        parts.queryItems = [
            URLQueryItem(name: "appid", value: appid),
            URLQueryItem(name: "idfv", value: identity),
            URLQueryItem(name: "deviceName", value: UIDevice.current.name),
            URLQueryItem(name: "pushToken", value: await pushToken),
            URLQueryItem(name: "userAgent", value: userAgent),
            URLQueryItem(name: "appVersion", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
        ]
        guard let requestURL = parts.url?.absoluteString else { launch = .temporaryGame; return }
        nonisolated struct Request: Encodable, Sendable {
            let appid, ad_id, request_url, name, avatar: String
            let adjust_json: String
            let deeplink: String
        }
        do {
            let response = try await api.call("resolve-player", body: Request(appid: appid, ad_id: identity, request_url: requestURL, name: playerName, avatar: "clover", adjust_json: naming.namingJSON, deeplink: naming.deeplink), as: LaunchDecision.self)
            launch = response.isValid(using: config) ? response : .temporaryGame
        } catch { launch = .temporaryGame }
        await updateProfile()
    }

    func updateProfile() async {
        guard let api, let identity else { return }
        nonisolated struct Body: Encodable, Sendable { let appid, ad_id, name: String }
        nonisolated struct Ack: Decodable, Sendable { let updated: Bool }
        _ = try? await api.call("player-profile", body: Body(appid: appid, ad_id: identity, name: playerName), as: Ack.self)
    }

    func submitResult(_ result: RunResult) async {
        guard let api, let identity else { return }
        let mode: String
        switch result.mode {
        case .crossing(let index): mode = "route-\(index)"
        case .longRoad: mode = "endless"
        case .daily: return
        }
        nonisolated struct ScoreSubmission: Encodable, Sendable {
            let appid, ad_id, gameId, completedAt, mode, avatar: String
            let score, meters, corn: Int
            let duration: Double
        }
        let payload = ScoreSubmission(
            appid: appid,
            ad_id: identity,
            gameId: UUID().uuidString.lowercased(),
            completedAt: ISO8601DateFormatter().string(from: Date()),
            mode: mode,
            avatar: "clover",
            score: result.banked,
            meters: result.lanesCrossed,
            corn: result.kernels,
            duration: result.duration
        )
        do {
            let _: ScoreAck = try await api.call("submit-score", body: payload, as: ScoreAck.self)
            await refreshLeaderboard()
        } catch {
            leaderboardMessage = "Score could not sync yet."
        }
    }

    func realLeaderboard() async throws -> [TopPlayer] {
        guard let api else { throw OnlineError.unavailable }
        return try await api.leaderboard(appid: appid).filter { $0.best_score > 0 }
    }

    func refreshLeaderboard() async {
        guard !isLoading else { return }
        let cacheKey = "online.leaderboard.\(appid)"
        if players.isEmpty, let data = defaults.data(forKey: cacheKey), let cached = try? JSONDecoder().decode([TopPlayer].self, from: data) { players = cached.filter { $0.best_score > 0 } }
        guard let api else { leaderboardMessage = "Online leaderboard is not configured."; return }
        isLoading = true; defer { isLoading = false }
        do {
            players = try await realLeaderboard()
            defaults.set(try JSONEncoder().encode(players), forKey: cacheKey)
            leaderboardMessage = nil
        } catch { leaderboardMessage = "Offline — showing the last saved leaderboard." }
    }
}


private extension WKWebView {
    func evaluateUserAgent() async -> String {
        await withCheckedContinuation { continuation in
            evaluateJavaScript("navigator.userAgent") { value, _ in
                continuation.resume(returning: value as? String ?? "")
            }
        }
    }
}
