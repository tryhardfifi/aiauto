import Foundation
import EventKit

struct SetReminderTool: AgentTool {
    let name = "set_reminder"
    let description = "Create a reminder with a title, optional due date, and optional notes."

    let parameters: [[String: Any]] = [
        ["name": "title", "type": "string", "description": "Reminder title", "required": true],
        ["name": "due_date", "type": "string", "description": "Due date in ISO 8601 format (e.g. 2025-01-15T09:00:00)", "required": false],
        ["name": "notes", "type": "string", "description": "Reminder notes", "required": false],
    ]

    private let store = EKEventStore()

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let title = arguments["title"] as? String, !title.isEmpty else {
            return ToolResult(output: "Error: title is required")
        }

        let granted = try await store.requestFullAccessToReminders()
        guard granted else {
            return ToolResult(output: "Reminders access denied. Ask the user to enable it in Settings.")
        }

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = store.defaultCalendarForNewReminders()

        if let dueDateStr = arguments["due_date"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dueDateStr) ?? formatter.date(from: dueDateStr + "Z") {
                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: date
                )
                reminder.dueDateComponents = components
            }
        }

        if let notes = arguments["notes"] as? String {
            reminder.notes = notes
        }

        try store.save(reminder, commit: true)
        return ToolResult(output: "Reminder '\(title)' created.", chatSummary: "Reminder set")
    }
}
