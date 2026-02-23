import SwiftUI

struct ActivityListView: View {
    @Environment(AppState.self) private var appState

    private var sortedThreads: [AgentThread] {
        appState.threads.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if appState.threads.isEmpty {
                    ContentUnavailableView(
                        "No activity yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("When your agent talks to other agents, conversations will appear here.")
                    )
                } else {
                    List(sortedThreads) { thread in
                        NavigationLink(destination: ThreadDetailView(thread: thread)) {
                            ThreadRow(thread: thread, contacts: appState.contacts)
                        }
                    }
                }
            }
            .navigationTitle("Activity")
        }
    }
}

struct ThreadRow: View {
    let thread: AgentThread
    let contacts: [Contact]

    private var contactAvatar: String {
        contacts.first { $0.id == thread.targetContactId }?.avatarId ?? "👤"
    }

    private var statusLabel: String {
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
        HStack(spacing: 12) {
            Text(contactAvatar)
                .font(.system(size: 36))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(thread.targetName)
                        .font(.headline)
                    Spacer()
                    Text(statusLabel)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                        .bold()
                }

                Text(thread.goal)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(thread.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
