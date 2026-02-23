import Foundation

// MARK: - Create Listing Tool (universal)

struct CreateListingTool: AgentTool {
    let name = "create_listing"
    let description = """
    Create a new listing. Use this for ALL types:
    - "for_sale": selling an item (vintage lamp, phone, etc.)
    - "service": offering a bookable service (nails, barber, tutoring)
    - "apartment": listing an apartment for rent/swap
    - "sport": looking for or offering to play a sport
    - "social": creating a social/dating profile to meet people
    - "club": creating or advertising a community/group
    - "event": posting an event (meetup, party, workshop)
    """
    let parameters: [[String: Any]] = [
        ["name": "category", "type": "string", "description": "One of: for_sale, service, apartment, sport, social, club, event", "required": true,
         "enum": ["for_sale", "service", "apartment", "sport", "social", "club", "event"]],
        ["name": "title", "type": "string", "description": "Title/name of the listing", "required": true],
        ["name": "description", "type": "string", "description": "Detailed description"],
        ["name": "price", "type": "number", "description": "Price (if applicable)"],
        ["name": "currency", "type": "string", "description": "Currency code (default EUR)"],
        ["name": "location", "type": "string", "description": "Location (neighborhood, city, address)"],
        ["name": "tags", "type": "string", "description": "Comma-separated tags (e.g. 'vintage,furniture,lamp')"],
        ["name": "availability", "type": "string", "description": "When available (e.g. 'weekday evenings', 'Sat 10am-2pm')"],
        ["name": "capacity", "type": "number", "description": "Max capacity (for events/clubs)"],
        ["name": "event_date", "type": "string", "description": "Event date/time (ISO 8601 or natural language)"],
        ["name": "url", "type": "string", "description": "External link (Luma, website, etc.)"],
        ["name": "requirements", "type": "string", "description": "Requirements (e.g. 'intermediate level', 'no pets', '21+')"],
    ]

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let categoryStr = arguments["category"] as? String,
              let category = Listing.Category(rawValue: categoryStr),
              let title = arguments["title"] as? String
        else {
            return ToolResult(output: "Error: category and title are required")
        }

        let price = arguments["price"] as? Double ?? (arguments["price"] as? Int).map(Double.init)
        let currency = arguments["currency"] as? String ?? "EUR"
        let description = arguments["description"] as? String ?? ""
        let location = arguments["location"] as? String
        let tagsStr = arguments["tags"] as? String ?? ""
        let tags = tagsStr.isEmpty ? [] : tagsStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let availability = arguments["availability"] as? String
        let capacity = arguments["capacity"] as? Int ?? (arguments["capacity"] as? Double).map(Int.init)
        let url = arguments["url"] as? String
        let requirements = arguments["requirements"] as? String

        // Parse event date if provided
        var eventDate: Date? = nil
        if let dateStr = arguments["event_date"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            eventDate = formatter.date(from: dateStr)
            if eventDate == nil {
                // Try a simpler format
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd'T'HH:mm"
                eventDate = df.date(from: dateStr)
            }
        }

        // Grab the user's photo if they sent one
        let imageData = await MainActor.run { context.getLastImageData() }

        let listing = Listing(
            category: category,
            sellerName: "You",
            title: title,
            description: description,
            price: price,
            currency: currency,
            location: location,
            tags: tags,
            imageData: imageData,
            availability: availability,
            capacity: capacity,
            eventDate: eventDate,
            url: url,
            requirements: requirements
        )

        await MainActor.run {
            context.addListing(listing)
        }

        var confirmParts = ["\(category.emoji) Created \(category.displayName): \"\(title)\""]
        if let price { confirmParts.append(String(format: "%.0f %@", price, currency)) }
        if let location { confirmParts.append("📍 \(location)") }
        let confirm = confirmParts.joined(separator: " — ")

        return ToolResult(
            output: "Listing created successfully. \(confirm)",
            chatSummary: confirm
        )
    }
}

// MARK: - Search Listings Tool (universal)

struct SearchListingsTool: AgentTool {
    let name = "search_listings"
    let description = """
    Search available listings across all categories. Use when your human is looking for something:
    - Items to buy, services to book, apartments, sports partners, people to meet, clubs to join, events to attend.
    You can filter by category, price, location, and keywords.
    """
    let parameters: [[String: Any]] = [
        ["name": "query", "type": "string", "description": "What to search for", "required": true],
        ["name": "category", "type": "string", "description": "Filter by category: for_sale, service, apartment, sport, social, club, event",
         "enum": ["for_sale", "service", "apartment", "sport", "social", "club", "event"]],
        ["name": "max_price", "type": "number", "description": "Maximum price filter"],
        ["name": "location", "type": "string", "description": "Location filter"],
    ]

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let query = arguments["query"] as? String else {
            return ToolResult(output: "Error: query is required")
        }
        let maxPrice = arguments["max_price"] as? Double
        let categoryFilter = (arguments["category"] as? String).flatMap(Listing.Category.init(rawValue:))
        let locationFilter = (arguments["location"] as? String)?.lowercased()

        let stored = UserDefaults.standard.data(forKey: "listings")
        guard let stored, let listings = try? JSONDecoder().decode([Listing].self, from: stored) else {
            return ToolResult(output: "No listings available yet. Ask your contacts to list things or check back later.")
        }

        let queryLower = query.lowercased()
        let results = listings.filter { listing in
            guard listing.status == .active else { return false }
            if let categoryFilter, listing.category != categoryFilter { return false }
            if let maxPrice, let price = listing.price, price > maxPrice { return false }

            let textMatch = listing.title.lowercased().contains(queryLower) ||
                            listing.description.lowercased().contains(queryLower) ||
                            listing.tags.contains { $0.lowercased().contains(queryLower) } ||
                            listing.category.displayName.lowercased().contains(queryLower)
            return textMatch
        }

        if results.isEmpty {
            let suggestion: String
            if categoryFilter != nil {
                suggestion = "Try broadening to all categories."
            } else {
                suggestion = "Try different keywords or check back later."
            }
            return ToolResult(output: "No listings found matching \"\(query)\". \(suggestion)")
        }

        let formatted = results.prefix(10).map(\.summary).joined(separator: "\n")
        return ToolResult(output: "Found \(results.count) listing(s):\n\(formatted)")
    }
}

// MARK: - My Listings Tool

struct MyListingsTool: AgentTool {
    let name = "my_listings"
    let description = "List all of your human's current active listings across all categories."
    let parameters: [[String: Any]] = [
        ["name": "category", "type": "string", "description": "Filter by category (optional)",
         "enum": ["for_sale", "service", "apartment", "sport", "social", "club", "event"]],
    ]

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let data = UserDefaults.standard.data(forKey: "listings"),
              let listings = try? JSONDecoder().decode([Listing].self, from: data)
        else {
            return ToolResult(output: "You don't have any listings yet.")
        }

        let categoryFilter = (arguments["category"] as? String).flatMap(Listing.Category.init(rawValue:))
        var mine = listings.filter { $0.sellerId == "self" && $0.status == .active }
        if let categoryFilter { mine = mine.filter { $0.category == categoryFilter } }

        if mine.isEmpty {
            return ToolResult(output: "You don't have any active listings\(categoryFilter != nil ? " in that category" : "").")
        }

        let formatted = mine.map(\.summary).joined(separator: "\n")
        return ToolResult(output: "Your active listings (\(mine.count)):\n\(formatted)")
    }
}

// MARK: - Remove/Update Listing Tool

struct RemoveListingTool: AgentTool {
    let name = "remove_listing"
    let description = "Remove, mark as sold/booked, or update one of your listings."
    let parameters: [[String: Any]] = [
        ["name": "title", "type": "string", "description": "Title of the listing to update", "required": true],
        ["name": "action", "type": "string", "description": "What to do: remove, sold, booked",
         "enum": ["remove", "sold", "booked"]],
    ]

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let title = arguments["title"] as? String else {
            return ToolResult(output: "Error: title is required")
        }
        let action = arguments["action"] as? String ?? "remove"
        let titleLower = title.lowercased()

        guard var listings = loadListings() else {
            return ToolResult(output: "No listings found.")
        }

        if let idx = listings.firstIndex(where: {
            $0.title.lowercased().contains(titleLower) && $0.sellerId == "self" && $0.status == .active
        }) {
            switch action {
            case "sold": listings[idx].status = .sold
            case "booked": listings[idx].status = .booked
            default: listings[idx].status = .removed
            }
            saveListings(listings)

            let statusText: String
            switch action {
            case "sold": statusText = "✅ Marked \"\(listings[idx].title)\" as sold"
            case "booked": statusText = "📅 Marked \"\(listings[idx].title)\" as booked"
            default: statusText = "🗑️ Removed \"\(listings[idx].title)\""
            }
            return ToolResult(output: statusText, chatSummary: statusText)
        }

        return ToolResult(output: "Could not find an active listing matching \"\(title)\".")
    }

    private func loadListings() -> [Listing]? {
        guard let data = UserDefaults.standard.data(forKey: "listings") else { return nil }
        return try? JSONDecoder().decode([Listing].self, from: data)
    }

    private func saveListings(_ listings: [Listing]) {
        if let data = try? JSONEncoder().encode(listings) {
            UserDefaults.standard.set(data, forKey: "listings")
        }
    }
}

// MARK: - Book Service Tool

struct BookServiceTool: AgentTool {
    let name = "book_service"
    let description = "Book a service or RSVP to an event. Initiates negotiation with the provider's agent."
    let parameters: [[String: Any]] = [
        ["name": "listing_title", "type": "string", "description": "Title of the service/event to book", "required": true],
        ["name": "preferred_time", "type": "string", "description": "When you'd like to book"],
        ["name": "message", "type": "string", "description": "Any message/request for the provider"],
    ]

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let title = arguments["listing_title"] as? String else {
            return ToolResult(output: "Error: listing_title is required")
        }
        let preferredTime = arguments["preferred_time"] as? String ?? "anytime"
        let message = arguments["message"] as? String ?? ""

        // Find the listing
        guard let data = UserDefaults.standard.data(forKey: "listings"),
              let listings = try? JSONDecoder().decode([Listing].self, from: data),
              let listing = listings.first(where: {
                  $0.title.lowercased().contains(title.lowercased()) && $0.status == .active
              })
        else {
            return ToolResult(output: "Could not find an active listing matching \"\(title)\".")
        }

        // This will trigger a negotiation with the seller's agent
        let bookingRequest = """
        Booking request for: \(listing.title)
        Category: \(listing.category.displayName)
        Provider: \(listing.sellerName)
        Preferred time: \(preferredTime)
        \(message.isEmpty ? "" : "Note: \(message)")
        \(listing.price != nil ? "Listed price: \(String(format: "%.0f %@", listing.price!, listing.currency))" : "")
        
        To complete this booking, reach out to \(listing.sellerName) with a [CONTACT_AGENT] block.
        """

        return ToolResult(output: bookingRequest)
    }
}

// MARK: - Discover People Tool (Tinder-like)

struct DiscoverPeopleTool: AgentTool {
    let name = "discover_people"
    let description = """
    Find people to meet based on interests, activities, or just vibes. 
    Works like a smart matchmaker — searches social profiles, sports partners, club members.
    """
    let parameters: [[String: Any]] = [
        ["name": "interest", "type": "string", "description": "What kind of person or activity (e.g. 'hiking', 'AI enthusiast', 'squash player')", "required": true],
        ["name": "intent", "type": "string", "description": "What for: dating, friendship, sports, networking",
         "enum": ["dating", "friendship", "sports", "networking", "any"]],
        ["name": "location", "type": "string", "description": "Area to search"],
    ]

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let interest = arguments["interest"] as? String else {
            return ToolResult(output: "Error: interest is required")
        }
        let intent = arguments["intent"] as? String ?? "any"
        let interestLower = interest.lowercased()

        guard let data = UserDefaults.standard.data(forKey: "listings"),
              let listings = try? JSONDecoder().decode([Listing].self, from: data)
        else {
            return ToolResult(output: "No profiles or activities found yet. As more people join, you'll see matches here.")
        }

        // Search across social profiles, sports, clubs, events
        let relevantCategories: [Listing.Category] = [.socialProfile, .sportActivity, .club, .event]
        let matches = listings.filter { listing in
            guard listing.status == .active, relevantCategories.contains(listing.category) else { return false }
            return listing.title.lowercased().contains(interestLower) ||
                   listing.description.lowercased().contains(interestLower) ||
                   listing.tags.contains { $0.lowercased().contains(interestLower) }
        }

        if matches.isEmpty {
            return ToolResult(output: "No matches found for \"\(interest)\" (\(intent)). Try broader terms or check back as more people join.")
        }

        let formatted = matches.prefix(10).map(\.summary).joined(separator: "\n")
        return ToolResult(
            output: "Found \(matches.count) match(es) for \"\(interest)\" (\(intent)):\n\(formatted)\n\nWant me to reach out to any of them?"
        )
    }
}

// end of file
