import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.fill")
                }
                .tag(0)

            ActivityListView()
                .tabItem {
                    Label("Activity", systemImage: "list.bullet")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(2)
        }
        .onAppear {
            appState.startP2P()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                appState.startP2P()
            case .background:
                appState.stopP2P()
                Task {
                    await appState.evolvePrompt()
                }
            default:
                break
            }
        }
    }
}
