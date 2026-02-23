import SwiftUI

struct OnboardingContainerView: View {
    @Environment(AppState.self) private var appState
    @State private var step = 0
    @State private var selectedAvatar = ""
    @State private var username = ""

    private let forwardTransition: AnyTransition = .asymmetric(
        insertion: .move(edge: .trailing),
        removal: .move(edge: .leading)
    )

    var body: some View {
        ZStack {
            switch step {
            case 0:
                AvatarPickerView(selectedAvatar: $selectedAvatar) {
                    step = 1
                }
                .transition(forwardTransition)
            case 1:
                UsernameInputView(username: $username) {
                    step = 2
                }
                .transition(forwardTransition)
            default:
                OnboardingDoneView(avatarId: selectedAvatar, username: username) {
                    appState.completeOnboarding(username: username, avatarId: selectedAvatar)
                }
                .transition(forwardTransition)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
    }
}
