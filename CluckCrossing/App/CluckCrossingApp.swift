import SwiftUI

@main
struct CluckCrossingApp: App {
    private let launch: Result<AppDependencies, Error>

    init() {
        launch = Result { try AppDependencies() }
    }

    var body: some Scene {
        WindowGroup {
            switch launch {
            case .success(let dependencies):
                RootView(dependencies: dependencies)
            case .failure(let error):
                LaunchErrorView(message: error.localizedDescription)
            }
        }
    }
}

/// Shown only if the save folder cannot be opened.
struct LaunchErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Text("Cluck Crossing could not start")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundColor(.white)
        .background(Color.black.ignoresSafeArea())
    }
}
