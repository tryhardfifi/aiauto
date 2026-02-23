import Foundation
import EventKit

struct CreateCalendarEventTool: AgentTool {
    let name = "create_calendar_event"
    let description = "Create a new calendar event with title, start/end dates, optional location and notes."

    let parameters: [[String: Any]] = [
        ["name": "title", "type": "string", "description": "Event title", "required": true],
        ["name": "start_date", "type": "string", "description": "Start date/time in ISO 8601 format (e.g. 2025-01-15T12:00:00)", "required": true],
        ["name": "end_date", "type": "string", "description": "End date/time in ISO 8601 format (e.g. 2025-01-15T13:00:00)", "required": true],
        ["name": "location", "type": "string", "description": "Event location", "required": false],
        ["name": "notes", "type": "string", "description": "Event notes", "required": false],
    ]

    private let store = EKEventStore()

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let title = arguments["title"] as? String, !title.isEmpty else {
            return ToolResult(output: "Error: title is required")
        }
        guard let startStr = arguments["start_date"] as? String else {
            return ToolResult(output: "Error: start_date is required")
        }
        guard let endStr = arguments["end_date"] as? String else {
            return ToolResult(output: "Error: end_date is required")
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Try with fractional seconds first, then without
        var startDate = formatter.date(from: startStr)
        var endDate = formatter.date(from: endStr)

        if startDate == nil || endDate == nil {
            formatter.formatOptions = [.withInternetDateTime]
            startDate = startDate ?? formatter.date(from: startStr)
            endDate = endDate ?? formatter.date(from: endStr)
        }

        // Fallback: try without timezone
        if startDate == nil || endDate == nil {
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withFullDate, .withFullTime]
            startDate = startDate ?? fallback.date(from: startStr + "Z")
            endDate = endDate ?? fallback.date(from: endStr + "Z")
        }

        guard let start = startDate else {
            return ToolResult(output: "Error: could not parse start_date '\(startStr)'. Use ISO 8601 format.")
        }
        guard let end = endDate else {
            return ToolResult(output: "Error: could not parse end_date '\(endStr)'. Use ISO 8601 format.")
        }

        let granted = try await store.requestFullAccessToEvents()
        guard granted else {
            return ToolResult(output: "Calendar access denied. Ask the user to enable it in Settings.")
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.calendar = store.defaultCalendarForNewEvents

        if let location = arguments["location"] as? String {
            event.location = location
        }
        if let notes = arguments["notes"] as? String {
            event.notes = notes
        }

        try store.save(event, span: .thisEvent)

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short

        return ToolResult(
            output: "Event '\(title)' created on \(displayFormatter.string(from: start)).",
            chatSummary: "Calendar event created"
        )
    }
}
