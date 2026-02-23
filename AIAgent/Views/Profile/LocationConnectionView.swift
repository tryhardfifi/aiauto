import SwiftUI

struct LocationConnectionView: View {
    @Environment(AppState.self) private var appState
    @State private var currentArea: String?
    @State private var isLoading = false

    private let locationService = LocationService()

    var body: some View {
        List {
            // Status
            Section {
                switch appState.locationConnectionStatus {
                case .notConnected:
                    Button {
                        connect()
                    } label: {
                        Label("Connect Location", systemImage: "location.fill")
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
                Text("Your agent uses your location to suggest nearby meeting spots. Only your general area is shared, not your exact coordinates.")
            }

            // Current Area
            if appState.locationConnectionStatus == .connected {
                Section("Current Area") {
                    if isLoading {
                        ProgressView()
                    } else if let area = currentArea {
                        Label(area, systemImage: "mappin.circle")
                    } else {
                        Text("Unable to determine area")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Location")
        .task {
            refreshStatus()
            if appState.locationConnectionStatus == .connected {
                await loadArea()
            }
        }
    }

    private func connect() {
        let status = locationService.requestAccess()
        appState.locationConnectionStatus = status
        if status == .connected {
            Task { await loadArea() }
        }
    }

    private func refreshStatus() {
        appState.locationConnectionStatus = locationService.authorizationStatus()
    }

    private func loadArea() async {
        isLoading = true
        currentArea = await locationService.getCurrentArea()
        isLoading = false
    }
}
