import SwiftUI

// MARK: - Unified Activity Item

enum ActivityItem: Identifiable {
    case listing(Listing)
    case thread(AgentThread)

    var id: String {
        switch self {
        case .listing(let l): return "listing-\(l.id)"
        case .thread(let t): return "thread-\(t.id.uuidString)"
        }
    }

    var date: Date {
        switch self {
        case .listing(let l): return l.createdAt
        case .thread(let t): return t.createdAt
        }
    }
}

// MARK: - Activity List

struct ActivityListView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedListing: Listing?

    private var activityItems: [ActivityItem] {
        var items: [ActivityItem] = []
        items.append(contentsOf: appState.listings.map { .listing($0) })
        items.append(contentsOf: appState.threads.map { .thread($0) })
        return items.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if activityItems.isEmpty {
                    ContentUnavailableView(
                        "No activity yet",
                        systemImage: "sparkles",
                        description: Text("Post something for sale, join a club, or let your agent negotiate — it'll all show up here.")
                    )
                } else {
                    List(activityItems) { item in
                        switch item {
                        case .listing(let listing):
                            Button {
                                selectedListing = listing
                            } label: {
                                ListingRow(listing: listing)
                            }
                        case .thread(let thread):
                            NavigationLink(destination: ThreadDetailView(thread: thread)) {
                                ThreadRow(thread: thread, contacts: appState.contacts)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .sheet(item: $selectedListing) { listing in
                ListingDetailSheet(listing: listing)
            }
        }
    }
}

// MARK: - Listing Row

struct ListingRow: View {
    let listing: Listing

    var body: some View {
        HStack(spacing: 12) {
            // Image or category emoji
            if let imageData = listing.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Text(listing.category.emoji)
                    .font(.system(size: 32))
                    .frame(width: 50, height: 50)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(listing.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    StatusBadge(listing: listing)
                }

                HStack(spacing: 8) {
                    Text(listing.category.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())

                    if let price = listing.price {
                        Text(String(format: "%.0f %@", price, listing.currency))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }

                    if let location = listing.location {
                        Label(location, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(listing.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let listing: Listing

    var body: some View {
        let (text, color): (String, Color) = {
            switch listing.status {
            case .active: return ("Active", .green)
            case .sold: return ("Sold", .orange)
            case .booked: return ("Booked", .blue)
            case .removed: return ("Removed", .gray)
            case .expired: return ("Expired", .gray)
            }
        }()

        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Listing Detail Sheet

struct ListingDetailSheet: View {
    let listing: Listing
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Image
                    if let imageData = listing.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        HStack {
                            Spacer()
                            Text(listing.category.emoji)
                                .font(.system(size: 80))
                            Spacer()
                        }
                        .padding(.vertical, 20)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Title + Price
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(listing.title)
                                .font(.title2.bold())
                            StatusBadge(listing: listing)
                        }
                        Spacer()
                        if let price = listing.price {
                            Text(String(format: "%.0f %@", price, listing.currency))
                                .font(.title2.bold())
                                .foregroundStyle(.blue)
                        }
                    }

                    // Category
                    HStack(spacing: 6) {
                        Text(listing.category.emoji)
                        Text(listing.category.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Description
                    if !listing.description.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(listing.description)
                        }
                    }

                    // Details grid
                    VStack(alignment: .leading, spacing: 8) {
                        if let location = listing.location {
                            Label(location, systemImage: "mappin.circle.fill")
                                .font(.subheadline)
                        }
                        if let availability = listing.availability {
                            Label(availability, systemImage: "clock.fill")
                                .font(.subheadline)
                        }
                        if let eventDate = listing.eventDate {
                            Label(eventDate.formatted(date: .long, time: .shortened), systemImage: "calendar")
                                .font(.subheadline)
                        }
                        if let capacity = listing.capacity {
                            Label("\(capacity) spots", systemImage: "person.3.fill")
                                .font(.subheadline)
                        }
                        if let requirements = listing.requirements {
                            Label(requirements, systemImage: "info.circle.fill")
                                .font(.subheadline)
                        }
                        if let url = listing.url {
                            Link(destination: URL(string: url) ?? URL(string: "about:blank")!) {
                                Label("Open link", systemImage: "link")
                                    .font(.subheadline)
                            }
                        }
                    }
                    .foregroundStyle(.secondary)

                    // Tags
                    if !listing.tags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(listing.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    // Seller + time
                    HStack {
                        Text("Posted by \(listing.sellerName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(listing.createdAt.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Simple Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

// MARK: - Thread Row (existing, for negotiations)

struct ThreadRow: View {
    let thread: AgentThread
    let contacts: [Contact]

    private var contactAvatar: String {
        contacts.first { $0.id == thread.targetContactId }?.avatarId ?? "🤝"
    }

    private var statusLabel: String {
        switch thread.status {
        case .negotiating: return "Negotiating..."
        case .agreed: return "Agreed"
        case .failed: return "Failed"
        }
    }

    private var statusColor: Color {
        switch thread.status {
        case .negotiating: return .orange
        case .agreed: return .green
        case .failed: return .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(contactAvatar)
                .font(.system(size: 32))
                .frame(width: 50, height: 50)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(thread.targetName)
                        .font(.headline)
                    Spacer()
                    Text(statusLabel)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(thread.goal)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(thread.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
