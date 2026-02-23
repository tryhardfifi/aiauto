import Foundation
import UIKit

struct OpenURLTool: AgentTool {
    let name = "open_url"
    let description = "Open a URL in Safari."

    let parameters: [[String: Any]] = [
        ["name": "url", "type": "string", "description": "The URL to open", "required": true],
    ]

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let urlString = arguments["url"] as? String, !urlString.isEmpty else {
            return ToolResult(output: "Error: url is required")
        }
        guard let url = URL(string: urlString) else {
            return ToolResult(output: "Error: invalid URL '\(urlString)'")
        }

        await MainActor.run {
            UIApplication.shared.open(url)
        }

        return ToolResult(output: "Opened \(urlString)", chatSummary: "Opened URL")
    }
}
