import Combine
import SwiftUI

/// Sections reachable from the signpost in the farmyard.
enum Route: String, CaseIterable, Identifiable {
    case timetable, roster, vending, henhouse, billboard, rulebook

    var id: String { rawValue }

    var signTitle: String {
        switch self {
        case .timetable: "Route Board"
        case .roster: "Top Players"
        case .vending: "Feed Store"
        case .henhouse: "Henhouse"
        case .billboard: "Barn Wall"
        case .rulebook: "Almanac"
        }
    }

    var signSubtitle: String {
        switch self {
        case .timetable: "Pick a crossing"
        case .roster: "Weekly roster"
        case .vending: "Upgrades"
        case .henhouse: "Your hens"
        case .billboard: "Ribbons & records"
        case .rulebook: "How to play"
        }
    }

    var art: String {
        switch self {
        case .timetable: "star_on"
        case .roster: "ribbon_0"
        case .vending: "upgrade_cornPouch"
        case .henhouse: "hen_pepper"
        case .billboard: "ribbon_2"
        case .rulebook: "egg"
        }
    }
}

/// A run to present full screen.
struct GameLaunch: Identifiable, Equatable {
    let id = UUID()
    let mode: RunMode
}

/// Navigation state for the whole app (iOS 15: a custom stack instead of NavigationStack).
@MainActor
final class AppRouter: ObservableObject {
    @Published var route: Route?
    @Published var launch: GameLaunch?
    @Published var showSettings = false
    @Published var showTutorial = false
    /// District card shown before the first crossing of a district.
    @Published var districtIntro: DistrictIntro?
    @Published private(set) var toast: String?

    private var toastTask: Task<Void, Never>?

    struct DistrictIntro: Identifiable, Equatable {
        let crossing: Int
        var id: Int { crossing }
        var district: District { CrossingSpec.all[crossing].district }
    }

    func open(_ route: Route) {
        withAnimation(.easeInOut(duration: 0.28)) { self.route = route }
    }

    func back() {
        withAnimation(.easeInOut(duration: 0.28)) { route = nil }
    }

    func show(toast message: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { toast = message }
        toastTask = Task { [weak self] in
            try? await Task.sleep(ms: 2_400)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { self?.toast = nil }
        }
    }
}
