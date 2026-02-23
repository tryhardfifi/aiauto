import Foundation
import EventKit

struct ReadCalendarTool: AgentTool {
    let name = "read_calendar"
    let description = "Read upcoming calendar events. Returns events for the specified number of days ahead."

    let parameters: [[String: Any]] = [
        ["name": "days_ahead", "type": "integer", "description": "Number of days ahead to fetch events (default 7)", "required": false],
    ]

    private let store = EKEventStore()

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        let daysAhead = (arguments["days_ahead"] as? Int) ?? 7

        let granted = try await store.requestFullAccessToEvents()
        guard granted else {
            return ToolResult(output: "Calendar access denied. Ask the user to enable it in Settings.")
        }

        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: daysAhead, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        if events.isEmpty {
            return ToolResult(output: "No events found in the next \(daysAhead) days.", chatSummary: "Checked calendar")
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let eventList = events.map { event in
            var line = "- \(event.title ?? "Untitled") on \(formatter.string(from: event.startDate))"
            if let location = event.location, !location.isEmpty {
                line += " at \(location)"
            }
            return line
        }.joined(separator: "\n")

        return ToolResult(
            output: "Upcoming events (\(daysAhead) days):\n\(eventList)",
            chatSummary: "Read calendar (\(events.count) events)"
        )
    }
}
