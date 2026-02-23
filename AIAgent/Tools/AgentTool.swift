import Foundation

// MARK: - Tool Result

struct ToolResult {
    let output: String
    let chatSummary: String?
    let sideEffect: (@MainActor () -> Void)?

    init(output: String, chatSummary: String? = nil, sideEffect: (@MainActor () -> Void)? = nil) {
        self.output = output
        self.chatSummary = chatSummary
        self.sideEffect = sideEffect
    }
}

// MARK: - Tool Context

struct ToolContext {
    let getSystemPrompt: @MainActor () -> String
    let setSystemPrompt: @MainActor (String) -> Void
    let getDocumentsDirectory: () -> URL
    let addListing: @MainActor (Listing) -> Void
    let getLastImageData: @MainActor () -> Data?
}

// MARK: - Agent Tool Protocol

protocol AgentTool {
    var name: String { get }
    var description: String { get }
    var parameters: [[String: Any]] { get }
    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult
}

extension AgentTool {
    var definition: [String: Any] {
        var props: [String: Any] = [:]
        var required: [String] = []

        for param in parameters {
            guard let paramName = param["name"] as? String else { continue }
            var propDef: [String: Any] = [:]
            propDef["type"] = param["type"] as? String ?? "string"
            if let desc = param["description"] as? String {
                propDef["description"] = desc
            }
            if let enumValues = param["enum"] as? [String] {
                propDef["enum"] = enumValues
            }
            props[paramName] = propDef
            if param["required"] as? Bool == true {
                required.append(paramName)
            }
        }

        var schema: [String: Any] = [
            "type": "object",
            "properties": props,
        ]
        if !required.isEmpty {
            schema["required"] = required
        }

        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": schema,
            ] as [String: Any],
        ]
    }
}

// MARK: - Tool Registry

final class ToolRegistry {
    private var tools: [String: AgentTool] = [:]

    func register(_ tool: AgentTool) {
        tools[tool.name] = tool
    }

    func tool(named name: String) -> AgentTool? {
        tools[name]
    }

    var definitions: [[String: Any]] {
        tools.values.map(\.definition)
    }
}
