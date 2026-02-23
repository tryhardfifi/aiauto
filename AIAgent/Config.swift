import Foundation

enum Config {
    static var apiKey: String {
        // UserDefaults override (set in Settings), then build-time embedded key
        let saved = UserDefaults.standard.string(forKey: "openAIAPIKey") ?? ""
        if !saved.isEmpty { return saved }
        return Secrets.openAIKey
    }
    static let model = "gpt-4o-mini"
    static let maxChatHistory = 20
    static let maxNegotiationRounds = 3
}
