import SwiftUI

struct UsernameInputView: View {
    @Binding var username: String
    let onNext: () -> Void

    private var isValid: Bool {
        username.count >= 3 && username.count <= 20
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Name your agent")
                .font(.title.bold())

            Text("Give your AI agent a name")
                .foregroundStyle(.secondary)

            TextField("Agent name", text: $username)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 40)

            if !username.isEmpty && !isValid {
                Text("Name must be 3-20 characters")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Spacer()

            Button("Next") {
                onNext()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isValid)
            .padding(.bottom, 40)
        }
    }
}
