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

                // Input bar
                HStack(spacing: 8) {
                    // Voice input button
                    VoiceInputButton(inputText: $inputText)

                    TextField("Type a message...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                        .onSubmit { sendMessage() }

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isSending)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
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

// MARK: - Voice Input Button

struct VoiceInputButton: View {
    @Environment(AppState.self) private var appState
    @Binding var inputText: String

    var body: some View {
        let whisper = appState.whisperService

        Button {
            if whisper.isRecording {
                Task {
                    if let text = await whisper.stopRecording() {
                        inputText = text
                    }
                }
            } else {
                whisper.startRecording()
            }
        } label: {
            Group {
                if whisper.isTranscribing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: whisper.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                        .foregroundStyle(whisper.isRecording ? .red : .blue)
                        .symbolEffect(.pulse, isActive: whisper.isRecording)
                }
            }
        }
        .disabled(whisper.isTranscribing || appState.isSending)
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
