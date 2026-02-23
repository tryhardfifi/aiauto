import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showAvatarPicker = false
    @State private var showPromptEditor = false
    @State private var editedPrompt = ""
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Profile
                Section("Profile") {
                    HStack(spacing: 16) {
                        Text(appState.userProfile?.avatarId ?? "🤖")
                            .font(.system(size: 48))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("@\(appState.userProfile?.username ?? "")")
                                .font(.headline)
                            Text("Tap to change avatar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showAvatarPicker = true
                    }
                }

                // Connections
                Section {
                    NavigationLink {
                        ContactsView()
                    } label: {
                        Label("Contacts", systemImage: "person.2.fill")
                    }

                    NavigationLink {
                        CalendarConnectionView()
                    } label: {
                        HStack {
                            Label("Calendar", systemImage: "calendar")
                            Spacer()
                            ConnectionBadge(status: appState.calendarConnectionStatus)
                        }
                    }

                    NavigationLink {
                        RemindersConnectionView()
                    } label: {
                        HStack {
                            Label("Reminders", systemImage: "checklist")
                            Spacer()
                            ConnectionBadge(status: appState.remindersConnectionStatus)
                        }
                    }

                    NavigationLink {
                        LocationConnectionView()
                    } label: {
                        HStack {
                            Label("Location", systemImage: "location.fill")
                            Spacer()
                            LocationBadge(status: appState.locationConnectionStatus)
                        }
                    }
                } header: {
                    Text("Connections")
                } footer: {
                    Text("Data your agent uses to coordinate plans on your behalf.")
                }

                // API Configuration
                Section {
                    SecureField("OpenAI API Key", text: Binding(
                        get: { appState.apiKey },
                        set: { appState.saveAPIKey($0) }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                } header: {
                    Text("API Configuration")
                } footer: {
                    Text("Enter your OpenAI API key. Get one at platform.openai.com")
                }

                // Agent Personality
                Section {
                    Button {
                        editedPrompt = appState.userProfile?.systemPrompt ?? ""
                        showPromptEditor = true
                    } label: {
                        HStack {
                            Label("Agent Personality", systemImage: "brain")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } footer: {
                    Text("Your agent's personality evolves as you chat. View and edit what it knows about you.")
                }

                // Data
                Section("Data") {
                    Button("Clear Chat History", role: .destructive) {
                        appState.clearChatHistory()
                    }

                    Button("Reset Everything", role: .destructive) {
                        showResetConfirmation = true
                    }
                }
            }
            .navigationTitle("Profile")
            .alert("Reset Everything?", isPresented: $showResetConfirmation) {
                Button("Reset", role: .destructive) {
                    appState.clearAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all data and restart onboarding. This cannot be undone.")
            }
            .sheet(isPresented: $showAvatarPicker) {
                AvatarChangeSheet()
            }
            .sheet(isPresented: $showPromptEditor) {
                PromptEditorSheet(prompt: $editedPrompt) {
                    if var profile = appState.userProfile {
                        profile.systemPrompt = editedPrompt
                        appState.updateProfile(profile)
                    }
                }
            }
        }
    }
}

// MARK: - Avatar Change Sheet

struct AvatarChangeSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selected = ""

    private let avatars = ["🤖", "🦊", "🐱", "🐶", "🦁", "🐸", "🐼", "🐨", "🦉", "🐙", "🦋", "🌟"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    var body: some View {
        NavigationStack {
            VStack {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(avatars, id: \.self) { avatar in
                        Text(avatar)
                            .font(.system(size: 48))
                            .frame(width: 72, height: 72)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selected == avatar ? Color.blue.opacity(0.2) : Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selected == avatar ? Color.blue : Color.clear, lineWidth: 3)
                            )
                            .onTapGesture {
                                selected = avatar
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Change Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if var profile = appState.userProfile, !selected.isEmpty {
                            profile.avatarId = selected
                            appState.updateProfile(profile)
                        }
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .onAppear {
                selected = appState.userProfile?.avatarId ?? ""
            }
        }
    }
}

// MARK: - Prompt Editor Sheet

struct PromptEditorSheet: View {
    @Binding var prompt: String
    @Environment(\.dismiss) private var dismiss
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            TextEditor(text: $prompt)
                .font(.system(.body, design: .monospaced))
                .padding()
                .navigationTitle("Agent Personality")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave()
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Connection Badges

struct ConnectionBadge: View {
    let status: CalendarConnectionStatus

    var body: some View {
        switch status {
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .denied:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
        case .notConnected:
            EmptyView()
        }
    }
}

struct LocationBadge: View {
    let status: LocationConnectionStatus

    var body: some View {
        switch status {
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .denied:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
        case .notConnected:
            EmptyView()
        }
    }
}
