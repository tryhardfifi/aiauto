import SwiftUI

struct RemindersConnectionView: View {
    @Environment(AppState.self) private var appState
    @State private var reminders: [ReminderItem] = []
    @State private var isLoading = false

    private let calendarService = CalendarService()

    var body: some View {
        List {
            // Status
            Section {
                switch appState.remindersConnectionStatus {
                case .notConnected:
                    Button {
                        Task { await connect() }
                    } label: {
                        Label("Connect Reminders", systemImage: "checklist")
                    }
                case .connected:
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .denied:
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Access Denied", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.subheadline)
                    }
                }
            } header: {
                Text("Status")
            } footer: {
                Text("Your agent reads pending reminders to stay aware of your tasks and commitments. No reminders are modified.")
            }

            // Reminders
            if appState.remindersConnectionStatus == .connected {
                Section("Pending Reminders") {
                    if isLoading {
                        ProgressView()
                    } else if reminders.isEmpty {
                        Text("No pending reminders")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(reminders) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                if let dueDate = item.dueDate {
                                    Text("Due \(dueDate, style: .date)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let notes = item.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle("Reminders")
        .task {
            refreshStatus()
            if appState.remindersConnectionStatus == .connected {
                await loadReminders()
            }
        }
    }

    private func connect() async {
        let status = await calendarService.requestRemindersAccess()
        appState.remindersConnectionStatus = status
        if status == .connected {
            await loadReminders()
        }
    }

    private func refreshStatus() {
        appState.remindersConnectionStatus = calendarService.remindersAuthorizationStatus()
    }

    private func loadReminders() async {
        isLoading = true
        reminders = await calendarService.fetchIncompleteReminders()
        isLoading = false
    }
}
