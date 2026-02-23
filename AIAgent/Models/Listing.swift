import Foundation

struct Listing: Identifiable, Codable, Equatable {
    var id: String
    var category: Category
    var sellerId: String      // "self" or contact/peer id
    var sellerName: String
    var title: String
    var description: String
    var price: Double?
    var currency: String
    var location: String?
    var tags: [String]
    var imageData: Data?
    var status: ListingStatus
    var createdAt: Date

    // Category-specific fields
    var availability: String?      // For services/sports: "weekday evenings", "Sat 10am"
    var capacity: Int?             // For events/clubs: max people
    var eventDate: Date?           // For events: when it happens
    var url: String?               // For events: Luma/Meetup link
    var requirements: String?      // For apartments: "no pets", for sports: "intermediate level"

    enum Category: String, Codable, CaseIterable {
        case forSale = "for_sale"
        case service = "service"          // Bookable services (nails, barber, etc.)
        case apartment = "apartment"
        case sportActivity = "sport"
        case socialProfile = "social"     // Tinder-like profiles
        case club = "club"                // Communities/groups
        case event = "event"

        var emoji: String {
            switch self {
            case .forSale: return "🛒"
            case .service: return "📅"
            case .apartment: return "🏠"
            case .sportActivity: return "🏸"
            case .socialProfile: return "👋"
            case .club: return "👥"
            case .event: return "🎉"
            }
        }

        var displayName: String {
            switch self {
            case .forSale: return "For Sale"
            case .service: return "Service"
            case .apartment: return "Apartment"
            case .sportActivity: return "Sport"
            case .socialProfile: return "Profile"
            case .club: return "Club"
            case .event: return "Event"
            }
        }
    }

    enum ListingStatus: String, Codable {
        case active
        case sold
        case booked
        case removed
        case expired
    }

    init(
        id: String = UUID().uuidString,
        category: Category = .forSale,
        sellerId: String = "self",
        sellerName: String,
        title: String,
        description: String = "",
        price: Double? = nil,
        currency: String = "EUR",
        location: String? = nil,
        tags: [String] = [],
        imageData: Data? = nil,
        status: ListingStatus = .active,
        createdAt: Date = Date(),
        availability: String? = nil,
        capacity: Int? = nil,
        eventDate: Date? = nil,
        url: String? = nil,
        requirements: String? = nil
    ) {
        self.id = id
        self.category = category
        self.sellerId = sellerId
        self.sellerName = sellerName
        self.title = title
        self.description = description
        self.price = price
        self.currency = currency
        self.location = location
        self.tags = tags
        self.imageData = imageData
        self.status = status
        self.createdAt = createdAt
        self.availability = availability
        self.capacity = capacity
        self.eventDate = eventDate
        self.url = url
        self.requirements = requirements
    }

    var summary: String {
        var parts = ["\(category.emoji) \(title)"]
        if let price {
            parts.append(String(format: "%.0f %@", price, currency))
        }
        if let location {
            parts.append("📍 \(location)")
        }
        if let availability {
            parts.append("🕐 \(availability)")
        }
        if !description.isEmpty {
            parts.append(description)
        }
        parts.append("by \(sellerName)")
        return parts.joined(separator: " — ")
    }
}
