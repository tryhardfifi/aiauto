import SwiftUI

@main
struct AIAgentApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isOnboarded {
                    MainTabView()
                } else {
                    OnboardingContainerView()
                }
            }
            .environment(appState)
        }
    }
}
