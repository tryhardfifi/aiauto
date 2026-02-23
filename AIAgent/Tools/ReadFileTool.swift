import Foundation

struct ReadFileTool: AgentTool {
    let name = "read_file"
    let description = "Read a file. Use filename 'systemprompt.md' to read the current system prompt. Other filenames are read from the Documents directory."

    let parameters: [[String: Any]] = [
        ["name": "filename", "type": "string", "description": "The filename to read", "required": true],
    ]

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let filename = arguments["filename"] as? String, !filename.isEmpty else {
            return ToolResult(output: "Error: filename is required")
        }

        if filename.lowercased() == "systemprompt.md" {
            let prompt = await MainActor.run { context.getSystemPrompt() }
            return ToolResult(output: prompt, chatSummary: "Read systemprompt.md")
        }

        let fileURL = context.getDocumentsDirectory().appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return ToolResult(output: "Error: file '\(filename)' not found")
        }

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return ToolResult(output: content, chatSummary: "Read \(filename)")
    }
}
