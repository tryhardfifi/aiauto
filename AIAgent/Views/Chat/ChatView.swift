import PhotosUI
import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @State private var inputText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingImageData: Data?
    @State private var selectedListing: Listing?
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
                                    Text("Ask me anything, send a photo to sell something, or reach out to a contact.")
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
                                ) { content in
                                    // Try to find a matching listing by title
                                    if let listing = appState.listings.first(where: { l in
                                        content.lowercased().contains(l.title.lowercased())
                                    }) {
                                        selectedListing = listing
                                    }
                                }
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

                // Pending image preview
                if pendingImageData != nil {
                    PendingImageBar(imageData: $pendingImageData)
                }

                // Input bar
                if appState.whisperService.isRecording || appState.whisperService.isTranscribing {
                    VoiceRecordingBar()
                } else {
                    TextInputBar(
                        inputText: $inputText,
                        isInputFocused: $isInputFocused,
                        selectedPhoto: $selectedPhoto,
                        pendingImageData: $pendingImageData
                    ) {
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
            .sheet(item: $selectedListing) { listing in
                ListingDetailSheet(listing: listing)
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let newItem, let data = try? await newItem.loadTransferable(type: Data.self) {
                        // Resize + compress for vision API (max 512px side)
                        if let uiImage = UIImage(data: data) {
                            let maxDim: CGFloat = 512
                            let scale = min(maxDim / uiImage.size.width, maxDim / uiImage.size.height, 1.0)
                            let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
                            let renderer = UIGraphicsImageRenderer(size: newSize)
                            let resized = renderer.image { _ in
                                uiImage.draw(in: CGRect(origin: .zero, size: newSize))
                            }
                            pendingImageData = resized.jpegData(compressionQuality: 0.5)
                        }
                        selectedPhoto = nil
                    }
                }
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageData = pendingImageData

        // If there's an image but no text, use a default prompt
        let finalText: String
        if let _ = imageData, text.isEmpty {
            finalText = "Here's a photo. What do you see? If it looks like something I want to sell, create a listing for it."
        } else if let _ = imageData {
            finalText = text
        } else {
            guard !text.isEmpty else { return }
            finalText = text
        }

        inputText = ""
        pendingImageData = nil

        Task {
            await appState.sendMessage(finalText, imageData: imageData)
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

// MARK: - Pending Image Bar

struct PendingImageBar: View {
    @Binding var imageData: Data?

    var body: some View {
        if let data = imageData, let uiImage = UIImage(data: data) {
            HStack {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("Photo attached")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    imageData = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
        }
    }
}

// MARK: - Text Input Bar

struct TextInputBar: View {
    @Environment(AppState.self) private var appState
    @Binding var inputText: String
    var isInputFocused: FocusState<Bool>.Binding
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var pendingImageData: Data?
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Photo picker
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Image(systemName: "photo.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            

            // Mic button
            Button {
                appState.whisperService.startRecording()
            } label: {
                Image(systemName: "mic.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            

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
            .disabled(
                (inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingImageData == nil) ||
                appState.isSending
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Voice Recording Bar

struct VoiceRecordingBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 12) {
            if appState.whisperService.isTranscribing {
                ProgressView()
                    .scaleEffect(0.9)
                Text("Transcribing...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                Button {
                    appState.whisperService.cancelRecording()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.gray)
                }

                AudioWaveformView(level: appState.whisperService.audioLevel)
                    .frame(height: 32)

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
        .background(Color.red.opacity(0.05))
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
    var onTapListing: ((String) -> Void)?

    var body: some View {
        if message.role == .system {
            // System messages — tappable if it's a listing action
            Button {
                onTapListing?(message.content)
            } label: {
                HStack(spacing: 6) {
                    if message.content.contains("📦") || message.content.contains("🛒") ||
                       message.content.contains("📅") || message.content.contains("🏠") ||
                       message.content.contains("🏸") || message.content.contains("👋") ||
                       message.content.contains("👥") || message.content.contains("🎉") ||
                       message.content.contains("✅") || message.content.contains("🗑️") {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text(message.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
            }
            .padding(.horizontal)
        } else {
            HStack(alignment: .top, spacing: 8) {
                if message.role == .user {
                    Spacer(minLength: 60)

                    VStack(alignment: .trailing, spacing: 4) {
                        // Show image if attached
                        if let imageData = message.imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: 200, maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        if !message.content.isEmpty &&
                           message.content != "Here's a photo. What do you see? If it looks like something I want to sell, create a listing for it." {
                            Text(message.content)
                                .textSelection(.enabled)
                                .padding(12)
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                } else {
                    Text(agentAvatar)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 8) {
                        // Parse message for listing references
                        let parts = parseListingReferences(message.content)
                        ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                            switch part {
                            case .text(let text):
                                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(LocalizedStringKey(text))
                                        .textSelection(.enabled)
                                }
                            case .listing(let listing):
                                ListingPreviewCard(listing: listing) {
                                    onTapListing?(listing.title)
                                }
                            }
                        }
                    }
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

// MARK: - Listing Reference Parsing

enum MessagePart {
    case text(String)
    case listing(Listing)
}

func parseListingReferences(_ content: String) -> [MessagePart] {
    let pattern = "\\[\\[listing:(.+?)\\]\\]"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return [.text(content)]
    }

    let nsContent = content as NSString
    let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

    if matches.isEmpty { return [.text(content)] }

    var parts: [MessagePart] = []
    var lastEnd = 0

    // Get listings from UserDefaults
    let allListings: [Listing] = {
        guard let data = UserDefaults.standard.data(forKey: "listings"),
              let listings = try? JSONDecoder().decode([Listing].self, from: data) else { return [] }
        return listings
    }()

    for match in matches {
        let matchRange = match.range
        let titleRange = match.range(at: 1)

        // Text before this match
        if matchRange.location > lastEnd {
            let textRange = NSRange(location: lastEnd, length: matchRange.location - lastEnd)
            parts.append(.text(nsContent.substring(with: textRange)))
        }

        // Find matching listing
        let title = nsContent.substring(with: titleRange).trimmingCharacters(in: .whitespaces)
        if let listing = allListings.first(where: { $0.title.lowercased().contains(title.lowercased()) || title.lowercased().contains($0.title.lowercased()) }) {
            parts.append(.listing(listing))
        } else {
            // No match found, show as text
            parts.append(.text(title))
        }

        lastEnd = matchRange.location + matchRange.length
    }

    // Remaining text
    if lastEnd < nsContent.length {
        parts.append(.text(nsContent.substring(from: lastEnd)))
    }

    return parts
}

// MARK: - Listing Preview Card

struct ListingPreviewCard: View {
    let listing: Listing
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Image or emoji
                if let imageData = listing.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text(listing.category.emoji)
                        .font(.title2)
                        .frame(width: 56, height: 56)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(listing.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let price = listing.price {
                            Text(String(format: "%.0f %@", price, listing.currency))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                        }
                        Text(listing.sellerName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let location = listing.location {
                        Label(location, systemImage: "mappin")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(8)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        }
    }
}
