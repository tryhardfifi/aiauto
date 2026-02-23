import SwiftUI

struct ContactsView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddContact = false
    @State private var editingContact: Contact?

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

            // Contacts
            Section {
                ForEach(appState.contacts) { contact in
                    Button {
                        editingContact = contact
                    } label: {
                        HStack(spacing: 12) {
                            Text(contact.avatarId)
                                .font(.system(size: 36))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(contact.persona)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { indexSet in
                    appState.deleteContacts(at: indexSet)
                }
            } header: {
                if !appState.p2pService.connectedPeers.isEmpty {
                    Text("Contacts")
                }
            }
        }
        .navigationTitle("Contacts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddContact = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddContact) {
            ContactEditorSheet(contact: nil) { newContact in
                appState.addContact(newContact)
            }
        }
        .sheet(item: $editingContact) { contact in
            ContactEditorSheet(contact: contact) { updated in
                appState.updateContact(updated)
            }
        }
    }
}

// MARK: - Contact Editor Sheet

struct ContactEditorSheet: View {
    let contact: Contact?
    let onSave: (Contact) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var avatarId: String = ""
    @State private var persona: String = ""
    @State private var notes: String = ""
    @State private var showAvatarPicker = false

    private let avatars = ["😀", "😎", "🤓", "🏸", "🍕", "🌙", "🧘", "💻", "🎸", "🎨", "📚", "🏃", "🌟", "🦊", "🐱", "🐶", "🦁", "🐸", "🎯", "🔥", "💎", "🌈", "🎭", "🍷"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var isNew: Bool { contact == nil }

    var body: some View {
        NavigationStack {
            Form {
                // Avatar
                Section {
                    HStack {
                        Spacer()
                        Button {
                            showAvatarPicker.toggle()
                        } label: {
                            Text(avatarId.isEmpty ? "🤖" : avatarId)
                                .font(.system(size: 64))
                        }
                        Spacer()
                    }

                    if showAvatarPicker {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(avatars, id: \.self) { emoji in
                                Text(emoji)
                                    .font(.system(size: 32))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(avatarId == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                    )
                                    .onTapGesture {
                                        avatarId = emoji
                                        showAvatarPicker = false
                                    }
                            }
                        }
                    }
                }

                // Name
                Section("Name") {
                    TextField("Contact name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                // System Prompt / Persona
                Section {
                    TextEditor(text: $persona)
                        .frame(minHeight: 100)
                } header: {
                    Text("System Prompt")
                } footer: {
                    Text("How the AI agent should behave when acting as this contact. Personality, preferences, availability, etc.")
                }

                // Notes
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Any extra info about this contact (for your reference).")
                }
            }
            .navigationTitle(isNew ? "New Contact" : "Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = Contact(
                            id: contact?.id ?? UUID().uuidString,
                            name: name,
                            avatarId: avatarId.isEmpty ? "🤖" : avatarId,
                            persona: persona,
                            notes: notes
                        )
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let contact {
                    name = contact.name
                    avatarId = contact.avatarId
                    persona = contact.persona
                    notes = contact.notes
                }
            }
        }
    }
}
