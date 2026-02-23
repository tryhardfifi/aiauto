import Foundation

struct Contact: Identifiable, Codable {
    let id: String
    let name: String
    let avatarId: String
    let persona: String

    static let fakeContacts: [Contact] = [
        Contact(
            id: "francescu",
            name: "Francescu",
            avatarId: "🏸",
            persona: "Loves squash, busy on weekday mornings, prefers evenings. Enthusiastic and quick to say yes to sports."
        ),
        Contact(
            id: "maria",
            name: "Maria",
            avatarId: "🍕",
            persona: "Foodie, prefers weekends for socializing. Organized planner, suggests restaurants."
        ),
        Contact(
            id: "luca",
            name: "Luca",
            avatarId: "🌙",
            persona: "Night owl, works late. Hard to pin down but always up for last-minute plans."
        ),
        Contact(
            id: "sofia",
            name: "Sofia",
            avatarId: "🧘",
            persona: "Yoga instructor, early riser. Prefers morning activities, very health-conscious."
        ),
        Contact(
            id: "marco",
            name: "Marco",
            avatarId: "💻",
            persona: "Tech nerd, flexible schedule. Always suggests trying new places. Responds fast."
        ),
    ]
}
