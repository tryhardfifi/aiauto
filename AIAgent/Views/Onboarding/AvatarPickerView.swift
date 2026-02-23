import SwiftUI

struct AvatarPickerView: View {
    @Binding var selectedAvatar: String
    let onNext: () -> Void

    private let avatars = ["🤖", "🦊", "🐱", "🐶", "🦁", "🐸", "🐼", "🐨", "🦉", "🐙", "🦋", "🌟"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Pick your agent's look")
                .font(.title.bold())

            Text("Choose an avatar for your AI agent")
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(avatars, id: \.self) { avatar in
                    Text(avatar)
                        .font(.system(size: 48))
                        .frame(width: 72, height: 72)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedAvatar == avatar ? Color.blue.opacity(0.2) : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selectedAvatar == avatar ? Color.blue : Color.clear, lineWidth: 3)
                        )
                        .onTapGesture {
                            selectedAvatar = avatar
                        }
                }
            }
            .padding(.horizontal)

            Spacer()

            Button("Next") {
                onNext()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedAvatar.isEmpty)
            .padding(.bottom, 40)
        }
    }
}
