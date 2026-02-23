import Foundation

struct Peer: Identifiable, Codable, Hashable {
    let id: String          // Stable UUID persisted per device
    let username: String
    let avatarId: String
}

struct P2PEnvelope: Codable {
    let type: MessageType
    let threadId: UUID
    let senderPeer: Peer
    let content: String
    let goal: String
    let status: String?     // "agreed" / "failed" / nil
    let round: Int

    enum MessageType: String, Codable {
        case negotiationStart       // Initiator's first message
        case negotiationMessage     // Subsequent rounds
        case negotiationEnd         // Final message with resolution
    }
}
