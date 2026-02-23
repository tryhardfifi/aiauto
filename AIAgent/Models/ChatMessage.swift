import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    var imageData: Data?  // JPEG data if user attached a photo

    enum Role: String, Codable {
        case user
        case agent
        case system
    }

    init(role: Role, content: String, imageData: Data? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.imageData = imageData
    }
}
