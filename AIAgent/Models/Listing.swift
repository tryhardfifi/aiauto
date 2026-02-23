import Foundation

struct Listing: Identifiable, Codable, Equatable {
    var id: String
    var sellerId: String      // contact id or "self"
    var sellerName: String
    var title: String
    var description: String
    var price: Double
    var currency: String
    var imageData: Data?      // JPEG data if photo attached
    var status: ListingStatus
    var createdAt: Date

    enum ListingStatus: String, Codable {
        case active
        case sold
        case removed
    }

    init(
        id: String = UUID().uuidString,
        sellerId: String = "self",
        sellerName: String,
        title: String,
        description: String = "",
        price: Double,
        currency: String = "EUR",
        imageData: Data? = nil,
        status: ListingStatus = .active,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sellerId = sellerId
        self.sellerName = sellerName
        self.title = title
        self.description = description
        self.price = price
        self.currency = currency
        self.imageData = imageData
        self.status = status
        self.createdAt = createdAt
    }
}
