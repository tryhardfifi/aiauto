import Foundation

struct AgentThread: Identifiable, Codable {
    let id: UUID
    let targetContactId: String
    let targetName: String
    let goal: String
    var status: Status
    var messages: [ThreadMessage]
    var result: String?
    let createdAt: Date

    enum Status: String, Codable {
        case negotiating
        case agreed
        case failed
    }

    struct ThreadMessage: Identifiable, Codable {
        let id: UUID
        let sender: Sender
        let content: String
        let timestamp: Date

        enum Sender: String, Codable {
            case myAgent = "my_agent"
            case theirAgent = "their_agent"
        }

        init(sender: Sender, content: String) {
            self.id = UUID()
            self.sender = sender
            self.content = content
            self.timestamp = Date()
        }
    }

    init(id: UUID = UUID(), targetContactId: String, targetName: String, goal: String) {
        self.id = id
        self.targetContactId = targetContactId
        self.targetName = targetName
        self.goal = goal
        self.status = .negotiating
        self.messages = []
        self.result = nil
        self.createdAt = Date()
    }
}
