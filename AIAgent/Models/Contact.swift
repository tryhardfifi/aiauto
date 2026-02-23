import Foundation

struct Contact: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var avatarId: String
    var persona: String
    var notes: String

    init(id: String = UUID().uuidString, name: String, avatarId: String, persona: String, notes: String = "") {
        self.id = id
        self.name = name
        self.avatarId = avatarId
        self.persona = persona
        self.notes = notes
    }

    static let defaultContacts: [Contact] = [
        Contact(
            id: "francescu",
            name: "Francescu",
            avatarId: "🏸",
            persona: "Loves squash, busy on weekday mornings, prefers evenings. Enthusiastic and quick to say yes to sports.",
            notes: ""
        ),
        Contact(
            id: "maria",
            name: "Maria",
            avatarId: "🍕",
            persona: "Foodie, prefers weekends for socializing. Organized planner, suggests restaurants.",
            notes: ""
        ),
        Contact(
            id: "luca",
            name: "Luca",
            avatarId: "🌙",
            persona: "Night owl, works late. Hard to pin down but always up for last-minute plans.",
            notes: ""
        ),
        Contact(
            id: "sofia",
            name: "Sofia",
            avatarId: "🧘",
            persona: "Yoga instructor, early riser. Prefers morning activities, very health-conscious.",
            notes: ""
        ),
        Contact(
            id: "marco",
            name: "Marco",
            avatarId: "💻",
            persona: "Tech nerd, flexible schedule. Always suggests trying new places. Responds fast.",
            notes: ""
        ),
    ]
}
