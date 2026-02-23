import Foundation
import UserNotifications

struct NotificationTool: AgentTool {
    let name = "send_push_notification"
    let description = "Send a local push notification to the user with a title and body."

    let parameters: [[String: Any]] = [
        ["name": "title", "type": "string", "description": "Notification title", "required": true],
        ["name": "body", "type": "string", "description": "Notification body", "required": true],
    ]

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let title = arguments["title"] as? String, !title.isEmpty else {
            return ToolResult(output: "Error: title is required")
        }
        guard let body = arguments["body"] as? String, !body.isEmpty else {
            return ToolResult(output: "Error: body is required")
        }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                return ToolResult(output: "Notification permission denied by user.")
            }
        } else if settings.authorizationStatus == .denied {
            return ToolResult(output: "Notification permission is denied. Ask the user to enable it in Settings.")
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        try await center.add(request)
        return ToolResult(output: "Notification sent.", chatSummary: "Notification sent")
    }
}
