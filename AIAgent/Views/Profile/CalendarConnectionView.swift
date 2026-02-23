import SwiftUI

struct CalendarConnectionView: View {
    @Environment(AppState.self) private var appState
    @State private var events: [CalendarEvent] = []
    @State private var isLoading = false

    private let calendarService = CalendarService()

    var body: some View {
        List {
            // Status
            Section {
                switch appState.calendarConnectionStatus {
                case .notConnected:
                    Button {
                        Task { await connect() }
                    } label: {
                        Label("Connect Calendar", systemImage: "calendar.badge.plus")
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
                Text("Your agent reads upcoming events to know your availability when coordinating plans. No events are modified.")
            }

            // Events
            if appState.calendarConnectionStatus == .connected {
                Section("Upcoming Events") {
                    if isLoading {
                        ProgressView()
                    } else if events.isEmpty {
                        Text("No upcoming events")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(events) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .font(.headline)
                                HStack {
                                    if event.isAllDay {
                                        Text("All day")
                                    } else {
                                        Text(event.startDate, style: .date)
                                        Text(event.startDate, style: .time)
                                        Text("–")
                                        Text(event.endDate, style: .time)
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                if let location = event.location {
                                    Text(location)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle("Calendar")
        .task {
            refreshStatus()
            if appState.calendarConnectionStatus == .connected {
                await loadEvents()
            }
        }
    }

    private func connect() async {
        let status = await calendarService.requestCalendarAccess()
        appState.calendarConnectionStatus = status
        if status == .connected {
            await loadEvents()
        }
    }

    private func refreshStatus() {
        appState.calendarConnectionStatus = calendarService.calendarAuthorizationStatus()
    }

    private func loadEvents() async {
        isLoading = true
        events = calendarService.fetchUpcomingEvents()
        isLoading = false
    }
}
