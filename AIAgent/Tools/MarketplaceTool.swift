import Foundation

// MARK: - Create Listing Tool

struct CreateListingTool: AgentTool {
    let name = "create_listing"
    let description = "Create a new listing to sell something. Your human wants to sell an item."
    let parameters: [[String: Any]] = [
        ["name": "title", "type": "string", "description": "Item name/title", "required": true],
        ["name": "price", "type": "number", "description": "Price amount", "required": true],
        ["name": "currency", "type": "string", "description": "Currency code (default EUR)"],
        ["name": "description", "type": "string", "description": "Item description"],
    ]

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let title = arguments["title"] as? String,
              let price = arguments["price"] as? Double ?? (arguments["price"] as? Int).map(Double.init)
        else {
            return ToolResult(output: "Error: title and price are required")
        }

        let currency = arguments["currency"] as? String ?? "EUR"
        let description = arguments["description"] as? String ?? ""

        let listing = Listing(
            sellerName: "You",
            title: title,
            description: description,
            price: price,
            currency: currency
        )

        // Store via notification — AppState picks it up
        await MainActor.run {
            NotificationCenter.default.post(
                name: .listingCreated,
                object: nil,
                userInfo: ["listing": listing]
            )
        }

        let priceStr = String(format: "%.2f %@", price, currency)
        return ToolResult(
            output: "Listing created: \(title) for \(priceStr)",
            chatSummary: "📦 Listed \"\(title)\" for \(priceStr)"
        )
    }
}

// MARK: - Search Listings Tool

struct SearchListingsTool: AgentTool {
    let name = "search_listings"
    let description = "Search available listings from contacts and nearby people. Use when your human is looking to buy something."
    let parameters: [[String: Any]] = [
        ["name": "query", "type": "string", "description": "What to search for", "required": true],
        ["name": "max_price", "type": "number", "description": "Maximum price filter"],
    ]

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let query = arguments["query"] as? String else {
            return ToolResult(output: "Error: query is required")
        }
        let maxPrice = arguments["max_price"] as? Double

        // Get listings via notification
        var allListings: [Listing] = []
        await MainActor.run {
            let result = NotificationCenter.default
            allListings = (result as AnyObject).value(forKey: "_unused") as? [Listing] ?? []
            // Actually use a sync approach — post and read from AppState
        }

        // For now, search through locally stored listings (own + received from peers)
        // The actual filtering happens in AppState
        var results: [[String: String]] = []

        await MainActor.run {
            NotificationCenter.default.post(
                name: .listingSearchRequested,
                object: nil,
                userInfo: ["query": query, "maxPrice": maxPrice as Any]
            )
        }

        // Since we can't easily async-await NotificationCenter, we'll use a simpler approach:
        // Return all active listings and let the LLM filter
        let stored = UserDefaults.standard.data(forKey: "listings")
        if let stored, let listings = try? JSONDecoder().decode([Listing].self, from: stored) {
            let active = listings.filter { $0.status == .active }
            let queryLower = query.lowercased()

            for listing in active {
                let matches = listing.title.lowercased().contains(queryLower) ||
                              listing.description.lowercased().contains(queryLower)
                let priceOk = maxPrice == nil || listing.price <= maxPrice!

                if matches && priceOk {
                    results.append([
                        "id": listing.id,
                        "title": listing.title,
                        "price": String(format: "%.2f %@", listing.price, listing.currency),
                        "seller": listing.sellerName,
                        "description": listing.description,
                    ])
                }
            }
        }

        if results.isEmpty {
            return ToolResult(output: "No listings found matching \"\(query)\". Try broadening your search or checking back later.")
        }

        let formatted = results.map { item in
            "• \(item["title"]!) — \(item["price"]!) (from \(item["seller"]!))\(item["description"]!.isEmpty ? "" : " — \(item["description"]!)")"
        }.joined(separator: "\n")

        return ToolResult(output: "Found \(results.count) listing(s):\n\(formatted)")
    }
}

// MARK: - Remove Listing Tool

struct RemoveListingTool: AgentTool {
    let name = "remove_listing"
    let description = "Remove or mark as sold one of your listings."
    let parameters: [[String: Any]] = [
        ["name": "title", "type": "string", "description": "Title of the listing to remove", "required": true],
        ["name": "mark_sold", "type": "string", "description": "Set to 'true' to mark as sold instead of removing"],
    ]

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let title = arguments["title"] as? String else {
            return ToolResult(output: "Error: title is required")
        }

        let markSold = (arguments["mark_sold"] as? String) == "true"
        let titleLower = title.lowercased()

        guard var listings = loadListings() else {
            return ToolResult(output: "No listings found.")
        }

        if let idx = listings.firstIndex(where: {
            $0.title.lowercased().contains(titleLower) && $0.sellerId == "self" && $0.status == .active
        }) {
            listings[idx].status = markSold ? .sold : .removed
            saveListings(listings)
            let action = markSold ? "marked as sold" : "removed"
            return ToolResult(
                output: "Listing \"\(listings[idx].title)\" \(action).",
                chatSummary: markSold ? "✅ Marked \"\(listings[idx].title)\" as sold" : "🗑️ Removed \"\(listings[idx].title)\""
            )
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

// MARK: - My Listings Tool

struct MyListingsTool: AgentTool {
    let name = "my_listings"
    let description = "List all of your human's current listings (things they're selling)."
    let parameters: [[String: Any]] = []

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let data = UserDefaults.standard.data(forKey: "listings"),
              let listings = try? JSONDecoder().decode([Listing].self, from: data)
        else {
            return ToolResult(output: "You don't have any listings yet.")
        }

        let mine = listings.filter { $0.sellerId == "self" && $0.status == .active }
        if mine.isEmpty {
            return ToolResult(output: "You don't have any active listings.")
        }

        let formatted = mine.map { listing in
            "• \(listing.title) — \(String(format: "%.2f %@", listing.price, listing.currency))\(listing.description.isEmpty ? "" : " (\(listing.description))")"
        }.joined(separator: "\n")

        return ToolResult(output: "Your active listings (\(mine.count)):\n\(formatted)")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let listingCreated = Notification.Name("listingCreated")
    static let listingSearchRequested = Notification.Name("listingSearchRequested")
}
