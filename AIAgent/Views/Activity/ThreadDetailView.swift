import SwiftUI

struct ThreadDetailView: View {
    let thread: AgentThread

    private var statusText: String {
        switch thread.status {
        case .negotiating: return "Negotiating..."
        case .agreed: return "Agreed"
        case .failed: return "Failed"
        }
    }

    private var statusColor: Color {
        switch thread.status {
        case .negotiating: return .orange
        case .agreed: return .green
        case .failed: return .red
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header card
                VStack(alignment: .leading, spacing: 8) {
                    Label("Goal", systemImage: "target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(thread.goal)
                        .font(.body)

                    Divider()

                    HStack {
                        Text("Status")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(statusText)
                            .foregroundStyle(statusColor)
                            .bold()
                    }
                    .font(.subheadline)

                    if let result = thread.result {
                        Divider()
                        Label("Result", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(result)
                            .font(.body)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Conversation
                if !thread.messages.isEmpty {
                    Text("Conversation")
                        .font(.headline)
                        .padding(.top, 8)

                    ForEach(thread.messages) { message in
                        NegotiationBubble(message: message, targetName: thread.targetName)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(thread.targetName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NegotiationBubble: View {
    let message: AgentThread.ThreadMessage
    let targetName: String

    private var isMyAgent: Bool { message.sender == .myAgent }

    private var cleanContent: String {
        message.content
            .replacingOccurrences(of: "[AGREED]", with: "")
            .replacingOccurrences(of: "[FAILED]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: isMyAgent ? .trailing : .leading, spacing: 4) {
            Text(isMyAgent ? "Your agent" : "\(targetName)'s agent")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(cleanContent)
                .padding(12)
                .background(isMyAgent ? Color.blue.opacity(0.12) : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: isMyAgent ? .trailing : .leading)
    }
}
