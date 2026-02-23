import Foundation

struct WriteFileTool: AgentTool {
    let name = "write_file"
    let description = "Write content to a file. Use filename 'systemprompt.md' to update the live system prompt. Other filenames are written to the Documents directory."

    let parameters: [[String: Any]] = [
        ["name": "filename", "type": "string", "description": "The filename to write", "required": true],
        ["name": "content", "type": "string", "description": "The content to write", "required": true],
    ]

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let filename = arguments["filename"] as? String, !filename.isEmpty else {
            return ToolResult(output: "Error: filename is required")
        }
        guard let content = arguments["content"] as? String else {
            return ToolResult(output: "Error: content is required")
        }

        if filename.lowercased() == "systemprompt.md" {
            let setPrompt = context.setSystemPrompt
            return ToolResult(
                output: "System prompt updated successfully.",
                chatSummary: "Behavior updated",
                sideEffect: { setPrompt(content) }
            )
        }

        let fileURL = context.getDocumentsDirectory().appendingPathComponent(filename)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return ToolResult(output: "File '\(filename)' written successfully.", chatSummary: "Wrote \(filename)")
    }
}
