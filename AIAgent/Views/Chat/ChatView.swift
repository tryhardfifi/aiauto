import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if appState.chatMessages.isEmpty {
                                VStack(spacing: 16) {
                                    Text(appState.userProfile?.avatarId ?? "🤖")
                                        .font(.system(size: 64))
                                    Text("Hey! I'm your AI agent.")
                                        .font(.headline)
                                    Text("Ask me anything, or tell me to reach out to one of your contacts.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, 80)
                                .padding(.horizontal, 40)
                            }

                            ForEach(appState.chatMessages) { message in
                                ChatBubble(
                                    message: message,
                                    agentAvatar: appState.userProfile?.avatarId ?? "🤖"
                                )
                                .id(message.id)
                            }

                            if appState.isSending {
                                HStack {
                                    TypingIndicator(avatar: appState.userProfile?.avatarId ?? "🤖")
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("typing")
                            }
                        }
                        .padding(.vertical)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: appState.chatMessages.count) {
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: appState.isSending) {
                        if appState.isSending {
                            withAnimation {
                                proxy.scrollTo("typing", anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Input bar — switches between text input and voice recording
                if appState.whisperService.isRecording || appState.whisperService.isTranscribing {
                    VoiceRecordingBar()
                } else {
                    TextInputBar(inputText: $inputText, isInputFocused: $isInputFocused) {
                        sendMessage()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Text(appState.userProfile?.avatarId ?? "🤖")
                            .font(.title2)
                        Text("Your Agent")
                            .font(.headline)
                    }
                }
            }
            .onAppear {
                if let pending = appState.pendingChatMessage {
                    inputText = pending
                    appState.pendingChatMessage = nil
                    isInputFocused = true
                }
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        Task {
            await appState.sendMessage(text)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            if let last = appState.chatMessages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Text Input Bar

struct TextInputBar: View {
    @Environment(AppState.self) private var appState
    @Binding var inputText: String
    var isInputFocused: FocusState<Bool>.Binding
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Mic button
            Button {
                appState.whisperService.startRecording()
            } label: {
                Image(systemName: "mic.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .disabled(appState.isSending)

            TextField("Type a message...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused(isInputFocused)
                .onSubmit { onSend() }

            Button {
                onSend()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isSending)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Voice Recording Bar (with waveform)

struct VoiceRecordingBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 12) {
            if appState.whisperService.isTranscribing {
                // Transcribing state
                ProgressView()
                    .scaleEffect(0.9)
                Text("Transcribing...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                // Recording state
                Button {
                    appState.whisperService.cancelRecording()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.gray)
                }

                // Waveform
                AudioWaveformView(level: appState.whisperService.audioLevel)
                    .frame(height: 32)

                // Stop & send
                Button {
                    Task {
                        if let text = await appState.whisperService.stopRecording() {
                            await appState.sendMessage(text)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            appState.whisperService.isRecording ?
                Color.red.opacity(0.05) : Color.clear
        )
    }
}

// MARK: - Audio Waveform View

struct AudioWaveformView: View {
    let level: Float
    @State private var levels: [CGFloat] = Array(repeating: 0.05, count: 30)

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<levels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: 3, height: max(3, levels[index] * 32))
            }
        }
        .onChange(of: level) { _, newLevel in
            withAnimation(.linear(duration: 0.05)) {
                levels.removeFirst()
                levels.append(CGFloat(newLevel))
            }
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    let agentAvatar: String

    var body: some View {
        if message.role == .system {
            HStack {
                Spacer()
                Text(message.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
        } else {
            HStack(alignment: .top, spacing: 8) {
                if message.role == .user {
                    Spacer(minLength: 60)

                    Text(message.content)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Text(agentAvatar)
                        .font(.title3)

                    Text(message.content)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Spacer(minLength: 60)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    let avatar: String
    @State private var phase = 0

    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            Text(avatar)
                .font(.title3)

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .opacity(phase % 3 == index ? 1.0 : 0.3)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .onReceive(timer) { _ in
            phase += 1
        }
    }
}
