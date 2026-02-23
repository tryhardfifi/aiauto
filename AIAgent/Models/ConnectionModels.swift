import Foundation

// MARK: - Calendar

enum CalendarConnectionStatus: String, Codable {
    case notConnected
    case connected
    case denied
}

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
}

// MARK: - Reminders

struct ReminderItem: Identifiable {
    let id: String
    let title: String
    let dueDate: Date?
    let isCompleted: Bool
    let notes: String?
}

// MARK: - Location

enum LocationConnectionStatus: String, Codable {
    case notConnected
    case connected
    case denied
}

// MARK: - Availability Preferences

struct AvailabilityPreferences: Codable {
    var notes: String // e.g. "prefer evenings", "free on weekends"

    static let empty = AvailabilityPreferences(notes: "")
}
