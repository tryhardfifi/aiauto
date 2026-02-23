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
    var imageURL: String?
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
        imageURL: String? = nil,
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
        self.imageURL = imageURL
        self.status = status
        self.createdAt = createdAt
        self.availability = availability
        self.capacity = capacity
        self.eventDate = eventDate
        self.url = url
        self.requirements = requirements
    }

    // MARK: - Seed Data

    static let seedListings: [Listing] = [
        // For Sale
        Listing(category: .forSale, sellerId: "francescu", sellerName: "Francescu", title: "Vintage Desk Lamp", description: "Mid-century brass lamp, works perfectly. Slight patina adds character.", price: 25, location: "11th arrondissement", tags: ["vintage", "lamp", "furniture", "brass"], imageURL: "https://images.unsplash.com/photo-1507473885765-e6ed057ab6fe?w=400"),
        Listing(category: .forSale, sellerId: "maria", sellerName: "Maria", title: "Le Creuset Dutch Oven", description: "Orange, 5.5qt, barely used. Moving and can't take it.", price: 80, location: "Marais", tags: ["kitchen", "cookware", "le creuset"], imageURL: "https://images.unsplash.com/photo-1585442738801-4f7e90b98187?w=400"),
        Listing(category: .forSale, sellerId: "marco", sellerName: "Marco", title: "iPhone 14 Pro", description: "128GB, space black, perfect condition with case. Upgrading.", price: 450, location: "Bastille", tags: ["phone", "apple", "tech"], imageURL: "https://images.unsplash.com/photo-1678685888221-cda773a3dcdb?w=400"),
        Listing(category: .forSale, sellerId: "sofia", sellerName: "Sofia", title: "Yoga Mat + Blocks Set", description: "Manduka PRO mat (purple) + 2 cork blocks. Used 3 months.", price: 40, location: "Canal Saint-Martin", tags: ["yoga", "fitness", "sports"], imageURL: "https://images.unsplash.com/photo-1601925260368-ae2f83cf8b7f?w=400"),
        Listing(category: .forSale, sellerId: "luca", sellerName: "Luca", title: "Vinyl Record Collection", description: "~50 records, mostly jazz and 70s rock. Will sell individually too.", price: 120, location: "Oberkampf", tags: ["vinyl", "music", "jazz", "vintage"], imageURL: "https://images.unsplash.com/photo-1539375665275-f9de415ef9ac?w=400"),

        // Services
        Listing(category: .service, sellerId: "sofia", sellerName: "Sofia", title: "Private Yoga Session", description: "1-hour personalized yoga class. All levels welcome. I come to you or we meet at the park.", price: 35, location: "Paris", tags: ["yoga", "fitness", "wellness"], imageURL: "https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400", availability: "Mornings 7-11am, Mon-Sat"),
        Listing(category: .service, sellerId: "maria", sellerName: "Maria", title: "Italian Cooking Class", description: "Learn to make fresh pasta from scratch! Small group (max 4). Includes ingredients and wine.", price: 45, location: "Maria's kitchen, 3rd arr.", tags: ["cooking", "italian", "pasta", "class"], imageURL: "https://images.unsplash.com/photo-1556910103-1c02745aae4d?w=400", availability: "Saturday afternoons", capacity: 4),
        Listing(category: .service, sellerId: "marco", sellerName: "Marco", title: "Tech Setup & Troubleshooting", description: "I'll fix your wifi, set up your smart home, or help with any tech issues.", price: 30, location: "Paris area", tags: ["tech", "help", "smart home"], imageURL: "https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?w=400", availability: "Evenings & weekends"),

        // Apartments
        Listing(category: .apartment, sellerId: "luca", sellerName: "Luca", title: "Cozy Studio near Père Lachaise", description: "30m², furnished, bright with balcony. Available March 1st. 6-month minimum.", price: 950, location: "20th arrondissement", tags: ["studio", "furnished", "balcony"], imageURL: "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=400", requirements: "No smoking, references required"),
        Listing(category: .apartment, sellerId: "francescu", sellerName: "Francescu", title: "Room in Shared Apt — Belleville", description: "Private room in 3BR apartment. Chill roommates, great rooftop. All bills included.", price: 650, location: "Belleville", tags: ["shared", "room", "rooftop", "bills included"], imageURL: "https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=400", availability: "Available now"),

        // Sports
        Listing(category: .sportActivity, sellerId: "francescu", sellerName: "Francescu", title: "Squash Partner Wanted", description: "Looking for regular squash partner, intermediate level. I play at Club Squash Montmartre.", tags: ["squash", "sports", "weekly"], imageURL: "https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=400", availability: "Tue/Thu evenings", requirements: "Intermediate level"),
        Listing(category: .sportActivity, sellerId: "sofia", sellerName: "Sofia", title: "Morning Run Group", description: "We run 5-8km along Canal Saint-Martin every morning. All paces welcome!", location: "Canal Saint-Martin", tags: ["running", "morning", "group"], imageURL: "https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=400", availability: "Every day 7am", capacity: 10),
        Listing(category: .sportActivity, sellerId: "marco", sellerName: "Marco", title: "5-a-side Football — Need Players", description: "Weekly pickup game, we're short 2 players. Fun and friendly, not too competitive.", location: "Stade Charléty", tags: ["football", "soccer", "weekly"], imageURL: "https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=400", availability: "Sunday 3pm", capacity: 10),

        // Social Profiles
        Listing(category: .socialProfile, sellerId: "maria", sellerName: "Maria", title: "Maria — Foodie & Wine Lover", description: "New to Paris, looking to meet people who love exploring restaurants, wine bars, and hidden gems. Always down for a spontaneous dinner!", location: "Paris", tags: ["foodie", "wine", "restaurants", "social"], imageURL: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=400"),
        Listing(category: .socialProfile, sellerId: "luca", sellerName: "Luca", title: "Luca — Night Owl & Music Nerd", description: "DJ on weekends, work in film during the week. Looking for people to hit up jazz bars, late-night spots, and vinyl shops.", location: "Paris", tags: ["music", "nightlife", "jazz", "vinyl", "dj"], imageURL: "https://images.unsplash.com/photo-1571266028243-3716f02d2d2e?w=400"),

        // Clubs
        Listing(category: .club, sellerId: "sofia", sellerName: "Sofia", title: "Paris Sunrise Yoga Club", description: "We practice yoga at sunrise in parks around Paris. Beginners welcome! Bring your own mat.", location: "Various parks", tags: ["yoga", "morning", "community", "wellness"], imageURL: "https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=400", availability: "Sat & Sun 6:30am", capacity: 20),
        Listing(category: .club, sellerId: "marco", sellerName: "Marco", title: "Paris Tech & AI Meetup", description: "Monthly meetup for anyone into AI, startups, and tech. Demos, talks, and beers after.", location: "Station F", tags: ["tech", "ai", "startups", "networking"], imageURL: "https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=400", availability: "First Thursday of the month", capacity: 50),
        Listing(category: .club, sellerId: "maria", sellerName: "Maria", title: "Cookbook Club Paris", description: "Every month we pick a cookbook, everyone makes a recipe, and we eat together. Currently doing Ottolenghi.", location: "Rotating hosts", tags: ["cooking", "books", "social", "food"], imageURL: "https://images.unsplash.com/photo-1466637574441-749b8f19452f?w=400", availability: "Last Sunday of the month", capacity: 8),

        // Events
        Listing(category: .event, sellerId: "marco", sellerName: "Marco", title: "AI Demos Night @ Station F", description: "Live demos of cool AI projects, 5-min pitches, networking with free drinks after. Come show what you're building!", location: "Station F, 13th arr.", tags: ["ai", "demos", "networking", "tech"], imageURL: "https://images.unsplash.com/photo-1591115765373-5207764f72e7?w=400", capacity: 80, eventDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()), url: "https://lu.ma/ai-paris"),
        Listing(category: .event, sellerId: "francescu", sellerName: "Francescu", title: "Squash Tournament — Spring Open", description: "Annual spring tournament at Club Montmartre. All levels, prizes for winners. Sign up through me!", location: "Club Squash Montmartre", tags: ["squash", "tournament", "sports"], imageURL: "https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=400", capacity: 32, eventDate: Calendar.current.date(byAdding: .day, value: 12, to: Date())),
        Listing(category: .event, sellerId: "maria", sellerName: "Maria", title: "Natural Wine Tasting Evening", description: "Tasting 8 natural wines from small French producers. Cheese board included. Limited spots!", price: 25, location: "Le Verre Volé, 10th arr.", tags: ["wine", "tasting", "natural", "social"], imageURL: "https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=400", capacity: 15, eventDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())),
        Listing(category: .event, sellerId: "luca", sellerName: "Luca", title: "Vinyl Swap Meet", description: "Bring your duplicate records, trade with other collectors. Jazz, rock, electronic, whatever. No entry fee.", location: "Café Charbon, Oberkampf", tags: ["vinyl", "music", "swap", "free"], imageURL: "https://images.unsplash.com/photo-1483412033650-1015ddeb83d1?w=400", capacity: 40, eventDate: Calendar.current.date(byAdding: .day, value: 8, to: Date())),
    ]

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
