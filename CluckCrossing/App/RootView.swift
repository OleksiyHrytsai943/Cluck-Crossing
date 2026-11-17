import SwiftUI

/// Hosts the farmyard, pushes sections over it and presents runs full screen.
struct RootView: View {
    let dependencies: AppDependencies
    @StateObject private var router = AppRouter()
    @ObservedObject private var store: ProfileStore

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        store = dependencies.store
    }

    var body: some View {
        ZStack {
            CornerView(store: store, router: router, startRun: startRun)
                .zIndex(0)

            if let route = router.route {
                section(route)
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
            }

            if let intro = router.districtIntro {
                DistrictCardView(intro: intro, onStart: {
                    store.markDistrictIntroSeen(intro.district.id)
                    router.districtIntro = nil
                    router.launch = GameLaunch(mode: .crossing(intro.crossing))
                }, onClose: { router.districtIntro = nil })
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = router.toast {
                ToastView(message: toast)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $router.showSettings) {
            SettingsView(settings: dependencies.settings, store: store, sound: dependencies.sound, onReplayTutorial: {
                router.showSettings = false
                router.showTutorial = true
            })
        }
        .fullScreenCover(isPresented: $router.showTutorial) {
            TutorialView(onDone: {
                store.markTutorialSeen()
                router.showTutorial = false
            })
        }
        .fullScreenCover(item: $router.launch) { launch in
            // A fresh identity per launch, so every run gets its own view model.
            GameView(viewModel: GameViewModel(mode: launch.mode, dependencies: dependencies), settings: dependencies.settings, onExit: {
                router.launch = nil
            })
            .id(launch.id)
        }
        .onAppear {
            if !store.profile.tutorialSeen { router.showTutorial = true }
            if let name = dependencies.openRoute {
                if let route = Route(rawValue: name) { router.route = route }
                if name == "run" { router.launch = GameLaunch(mode: .crossing(store.profile.nextCrossing)) }
            }
            dependencies.sound.playMusic(.menu)
        }
        .onChange(of: router.launch) { launch in
            if launch == nil { dependencies.sound.playMusic(.menu) }
        }
    }

    @ViewBuilder
    private func section(_ route: Route) -> some View {
        switch route {
        case .timetable:
            TimetableView(store: store, router: router, startRun: startRun)
        case .vending:
            VendingView(viewModel: VendingViewModel(store: store, haptics: dependencies.haptics, sound: dependencies.sound), store: store, router: router)
        case .henhouse:
            HenhouseView(viewModel: HenhouseViewModel(store: store, haptics: dependencies.haptics, sound: dependencies.sound), store: store, router: router)
        case .roster:
            RosterView(viewModel: RosterViewModel(store: store, provider: dependencies.leaderboard, haptics: dependencies.haptics, sound: dependencies.sound), store: store, router: router)
        case .billboard:
            BillboardView(store: store, router: router)
        case .rulebook:
            RulebookView(router: router, coins: store.coins)
        }
    }

    /// Starts a run, showing the district card first when a new district begins.
    private func startRun(_ mode: RunMode) {
        dependencies.sound.play(.tap)
        if case .crossing(let index) = mode {
            let district = CrossingSpec.all[index].district.id
            if !store.profile.districtIntrosSeen.contains(district) {
                withAnimation { router.districtIntro = AppRouter.DistrictIntro(crossing: index) }
                return
            }
        }
        router.launch = GameLaunch(mode: mode)
    }
}
