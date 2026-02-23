import SwiftUI

struct OnboardingDoneView: View {
    let avatarId: String
    let username: String
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text(avatarId)
                .font(.system(size: 80))

            Text("Your agent is ready!")
                .font(.title.bold())

            Text("@\(username)")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Start chatting") {
                onStart()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 40)
        }
    }
}
