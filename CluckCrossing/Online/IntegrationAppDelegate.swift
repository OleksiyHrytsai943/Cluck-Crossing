import AdjustSdk
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

@MainActor
final class IntegrationAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate, AdjustDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().isAutoInitEnabled = true
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        let config = ADJConfig(appToken: "buzif5nomsxs", environment: Self.adjustEnvironment)
        config?.delegate = self
        if let config { Adjust.initSdk(config) }
        return true
    }

    #if DEBUG
    private static let adjustEnvironment = ADJEnvironmentSandbox
    #else
    private static let adjustEnvironment = ADJEnvironmentProduction
    #endif

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        Messaging.messaging().token { token, _ in
            Task { @MainActor in PushRegistration.shared.receive(token) }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushRegistration.shared.registrationFailed()
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        PushRegistration.shared.receive(fcmToken)
    }

    func adjustAttributionChanged(_ attribution: ADJAttribution?) {
        AdjustAttributionStore.shared.update(attribution)
    }

    func adjustDeferredDeeplinkReceived(_ deeplink: URL?) -> Bool {
        AdjustAttributionStore.shared.receive(deeplink)
        return false
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        AdjustAttributionStore.shared.receive(url)
        return true
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        AdjustAttributionStore.shared.receivePush(userInfo)
    }

    /// Only the main WebView may rotate; the game and every other screen stay portrait.
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationGate.shared.allowsAll ? [.portrait, .landscapeLeft, .landscapeRight] : .portrait
    }
}

/// Switched on while the main WebView is on screen, off everywhere else, so the
/// app delegate can widen the allowed orientations for that screen only.
@MainActor
final class OrientationGate {
    static let shared = OrientationGate()
    private(set) var allowsAll = false

    func setAllowsAll(_ value: Bool) {
        guard allowsAll != value else { return }
        allowsAll = value
        if #available(iOS 16.0, *) {
            for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
                scene.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
            }
        } else {
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
}

@MainActor
final class PushRegistration {
    static let shared = PushRegistration()
    private(set) var token: String?
    private var failed = false

    func requestPermissionAndRegister() async {
        // Ask for permission but ignore the result: the FCM token must be issued
        // regardless of consent, so APNs registration is unconditional.
        Messaging.messaging().isAutoInitEnabled = true
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
        UIApplication.shared.registerForRemoteNotifications()
    }

    func receive(_ token: String?) {
        guard let token, !token.isEmpty else { return }
        self.token = token
        UserDefaults.standard.set(token, forKey: "online.firebase.fcmToken")
    }

    func registrationFailed() { failed = true }

    func token(timeout seconds: Double = 10) async -> String {
        let start = DispatchTime.now().uptimeNanoseconds
        let limit = UInt64(seconds * 1_000_000_000)
        while token == nil && !failed && !Task.isCancelled {
            if DispatchTime.now().uptimeNanoseconds - start >= limit { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return token ?? UserDefaults.standard.string(forKey: "online.firebase.fcmToken") ?? ""
    }
}

@MainActor
final class AdjustAttributionStore {
    static let shared = AdjustAttributionStore()
    private(set) var deeplink = ""
    private var namingJSON: String { UserDefaults.standard.string(forKey: "online.adjust.naming") ?? "{}" }

    func update(_ attribution: ADJAttribution?) {
        guard let attribution,
              let object = (attribution.jsonResponse as? [String: Any]) ?? (attribution.dictionary() as? [String: Any]),
              JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let value = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(value, forKey: "online.adjust.naming")
    }

    func receive(_ url: URL?) {
        guard let url, url.absoluteString.count <= 4096 else { return }
        deeplink = url.absoluteString
    }

    func receivePush(_ payload: [AnyHashable: Any]) {
        if let raw = payload["adjust_deeplink"] as? String, let url = URL(string: raw) { receive(url) }
    }

    func currentPayload() async -> (namingJSON: String, deeplink: String) {
        if storedNamingIsValid { return (namingJSON, deeplink) }
        let resolved = await fetchAttributionJSON()
        return (resolved, deeplink)
    }

    private var storedNamingIsValid: Bool {
        guard let raw = UserDefaults.standard.string(forKey: "online.adjust.naming"),
              let data = raw.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else { return false }
        return true
    }

    /// Nothing cached yet: ask Adjust for the current attribution (up to 20s) and persist it,
    /// rather than waiting passively for the delegate callback to land in time.
    private func fetchAttributionJSON() async -> String {
        await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            Adjust.attribution(withTimeout: 20_000) { [weak self] attribution in
                Task { @MainActor in
                    self?.update(attribution)
                    continuation.resume(returning: self?.namingJSON ?? "{}")
                }
            }
        }
    }
}
