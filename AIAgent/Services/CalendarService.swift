import EventKit
import Foundation

final class CalendarService {
    private let store = EKEventStore()

    // MARK: - Calendar Access

    func requestCalendarAccess() async -> CalendarConnectionStatus {
        do {
            let granted = try await store.requestFullAccessToEvents()
            return granted ? .connected : .denied
        } catch {
            return .denied
        }
    }

    func calendarAuthorizationStatus() -> CalendarConnectionStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .connected
        case .denied, .restricted: return .denied
        default: return .notConnected
        }
    }

    // MARK: - Reminders Access

    func requestRemindersAccess() async -> CalendarConnectionStatus {
        do {
            let granted = try await store.requestFullAccessToReminders()
            return granted ? .connected : .denied
        } catch {
            return .denied
        }
    }

    func remindersAuthorizationStatus() -> CalendarConnectionStatus {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess: return .connected
        case .denied, .restricted: return .denied
        default: return .notConnected
        }
    }

    // MARK: - Fetch Events

    func fetchUpcomingEvents(days: Int = 14) -> [CalendarEvent] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }

        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: days, to: now)!
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        return ekEvents.map { event in
            CalendarEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location
            )
        }
    }

    // MARK: - Fetch Reminders

    func fetchIncompleteReminders() async -> [ReminderItem] {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return [] }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { ekReminders in
                let items = (ekReminders ?? []).map { reminder in
                    ReminderItem(
                        id: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "Untitled",
                        dueDate: reminder.dueDateComponents?.date,
                        isCompleted: reminder.isCompleted,
                        notes: reminder.notes
                    )
                }
                continuation.resume(returning: items)
            }
        }
    }

    // MARK: - Formatted for Agent Prompt

    func formattedSchedule() -> String {
        let events = fetchUpcomingEvents()
        guard !events.isEmpty else { return "" }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE h:mma"

        let lines = events.prefix(20).map { event in
            let start = formatter.string(from: event.startDate)
            let end = DateFormatter.localizedString(from: event.endDate, dateStyle: .none, timeStyle: .short)
            let loc = event.location.map { " at \($0)" } ?? ""
            if event.isAllDay {
                let day = DateFormatter.localizedString(from: event.startDate, dateStyle: .medium, timeStyle: .none)
                return "- \(day): \(event.title) (all day)\(loc)"
            }
            return "- \(start)-\(end): \(event.title)\(loc)"
        }

        return "Upcoming calendar events:\n\(lines.joined(separator: "\n"))"
    }

    func formattedReminders() async -> String {
        let reminders = await fetchIncompleteReminders()
        guard !reminders.isEmpty else { return "" }

        let lines = reminders.prefix(15).map { item in
            let due = item.dueDate.map {
                " by \(DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none))"
            } ?? ""
            return "- \(item.title)\(due)"
        }

        return "Pending reminders:\n\(lines.joined(separator: "\n"))"
    }
}
