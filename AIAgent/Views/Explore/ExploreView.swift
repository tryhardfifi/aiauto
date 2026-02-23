import SwiftUI

struct ExploreView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedCategory: Listing.Category?
    @State private var selectedListing: Listing?

    private var filteredListings: [Listing] {
        let active = appState.listings.filter { $0.status == .active }
        if let cat = selectedCategory {
            return active.filter { $0.category == cat }
        }
        return active
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Category pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            CategoryPill(title: "All", emoji: "✨", isSelected: selectedCategory == nil) {
                                selectedCategory = nil
                            }
                            ForEach(Listing.Category.allCases, id: \.self) { cat in
                                let count = appState.listings.filter { $0.status == .active && $0.category == cat }.count
                                if count > 0 {
                                    CategoryPill(
                                        title: cat.displayName,
                                        emoji: cat.emoji,
                                        isSelected: selectedCategory == cat
                                    ) {
                                        selectedCategory = selectedCategory == cat ? nil : cat
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Featured events (if any)
                    let upcomingEvents = appState.listings.filter {
                        $0.category == .event && $0.status == .active && $0.eventDate != nil
                    }.sorted { ($0.eventDate ?? .distantFuture) < ($1.eventDate ?? .distantFuture) }

                    if !upcomingEvents.isEmpty && selectedCategory == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Upcoming Events")
                                .font(.headline)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(upcomingEvents.prefix(5)) { event in
                                        EventCard(listing: event)
                                            .onTapGesture { selectedListing = event }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Listings grid
                    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredListings) { listing in
                            ExploreCard(listing: listing)
                                .onTapGesture { selectedListing = listing }
                        }
                    }
                    .padding(.horizontal)

                    if filteredListings.isEmpty {
                        ContentUnavailableView(
                            "Nothing here yet",
                            systemImage: "magnifyingglass",
                            description: Text("No listings in this category. Ask your agent to find something!")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Explore")
            .sheet(item: $selectedListing) { listing in
                ListingDetailSheet(listing: listing)
            }
        }
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Event Card (horizontal scroll)

struct EventCard: View {
    let listing: Listing

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(listing.category.emoji)
                    .font(.title2)
                Spacer()
                if let date = listing.eventDate {
                    Text(date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                }
            }

            Text(listing.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)

            if let location = listing.location {
                Label(location, systemImage: "mappin")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let capacity = listing.capacity {
                Label("\(capacity) spots", systemImage: "person.2")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 180)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Explore Card (grid)

struct ExploreCard: View {
    let listing: Listing

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image or emoji
            if let imageData = listing.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                HStack {
                    Spacer()
                    Text(listing.category.emoji)
                        .font(.system(size: 40))
                    Spacer()
                }
                .frame(height: 80)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Text(listing.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)

            HStack {
                if let price = listing.price {
                    Text(String(format: "%.0f %@", price, listing.currency))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                }

                Spacer()

                Text(listing.category.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }

            Text(listing.sellerName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}
