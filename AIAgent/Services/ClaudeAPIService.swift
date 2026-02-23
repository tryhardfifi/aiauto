import Foundation

actor LLMService {

    struct Message {
        let role: String
        let content: String?
        let toolCalls: [ToolCall]?
        let toolCallId: String?
        let name: String?

        init(role: String, content: String) {
            self.role = role
            self.content = content
            self.toolCalls = nil
            self.toolCallId = nil
            self.name = nil
        }

        init(role: String, content: String?, toolCalls: [ToolCall]?, toolCallId: String?, name: String?) {
            self.role = role
            self.content = content
            self.toolCalls = toolCalls
            self.toolCallId = toolCallId
            self.name = name
        }

        func toJSON() -> [String: Any] {
            var dict: [String: Any] = ["role": role]
            if let content { dict["content"] = content }
            if let toolCalls, !toolCalls.isEmpty {
                dict["tool_calls"] = toolCalls.map(\.toJSON)
            }
            if let toolCallId { dict["tool_call_id"] = toolCallId }
            if let name { dict["name"] = name }
            return dict
        }
    }

    struct ToolCall {
        let id: String
        let functionName: String
        let arguments: String

        var toJSON: [String: Any] {
            [
                "id": id,
                "type": "function",
                "function": [
                    "name": functionName,
                    "arguments": arguments,
                ] as [String: Any],
            ]
        }
    }

    enum LLMResponse {
        case text(String)
        case toolCalls([ToolCall])
    }

    private struct APIError: Codable {
        let error: ErrorDetail?
        struct ErrorDetail: Codable {
            let message: String?
        }
    }

    // MARK: - Tool-calling endpoint

    func sendMessage(
        systemPrompt: String,
        messages: [Message],
        tools: [[String: Any]]? = nil,
        maxTokens: Int = 1024
    ) async throws -> LLMResponse {
        let apiKey = Config.apiKey
        guard !apiKey.isEmpty else {
            return .text("Please set your OpenAI API key in Settings to start chatting.")
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var allMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]
        allMessages.append(contentsOf: messages.map { $0.toJSON() })

        var body: [String: Any] = [
            "model": Config.model,
            "max_tokens": maxTokens,
            "messages": allMessages,
        ]
        if let tools, !tools.isEmpty {
            body["tools"] = tools
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data),
               let message = apiError.error?.message {
                throw NSError(
                    domain: "OpenAI",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
            }
            let raw = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "OpenAI",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "API error (\(httpResponse.statusCode)): \(raw)"]
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let choice = choices.first,
              let message = choice["message"] as? [String: Any]
        else {
            return .text("")
        }

        // Check for tool calls
        if let toolCallsJSON = message["tool_calls"] as? [[String: Any]], !toolCallsJSON.isEmpty {
            let calls = toolCallsJSON.compactMap { tc -> ToolCall? in
                guard let id = tc["id"] as? String,
                      let function = tc["function"] as? [String: Any],
                      let name = function["name"] as? String,
                      let arguments = function["arguments"] as? String
                else { return nil }
                return ToolCall(id: id, functionName: name, arguments: arguments)
            }
            return .toolCalls(calls)
        }

        let content = message["content"] as? String ?? ""
        return .text(content)
    }

    // MARK: - Simple text endpoint (for evolvePrompt, negotiation, etc.)

    func sendMessageText(
        systemPrompt: String,
        messages: [Message],
        maxTokens: Int = 1024
    ) async throws -> String {
        let response = try await sendMessage(
            systemPrompt: systemPrompt,
            messages: messages,
            tools: nil,
            maxTokens: maxTokens
        )
        switch response {
        case .text(let text): return text
        case .toolCalls: return ""
        }
    }
}
