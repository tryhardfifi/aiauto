import SwiftUI

struct ContactsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            // Nearby peers via P2P
            if !appState.p2pService.connectedPeers.isEmpty {
                Section {
                    ForEach(appState.p2pService.connectedPeers) { peer in
                        Button {
                            appState.reachOutToPeer(peer)
                        } label: {
                            HStack(spacing: 12) {
                                Text(peer.avatarId)
                                    .font(.system(size: 36))

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(peer.username)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Circle()
                                            .fill(.green)
                                            .frame(width: 8, height: 8)
                                    }
                                    Text("Nearby — tap to reach out")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Nearby")
                }
            }

            // Fake contacts
            Section {
                ForEach(appState.contacts) { contact in
                    Button {
                        appState.reachOutTo(contact)
                    } label: {
                        HStack(spacing: 12) {
                            Text(contact.avatarId)
                                .font(.system(size: 36))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Tap to reach out")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                if !appState.p2pService.connectedPeers.isEmpty {
                    Text("Contacts")
                }
            }
        }
        .navigationTitle("Contacts")
    }
}
