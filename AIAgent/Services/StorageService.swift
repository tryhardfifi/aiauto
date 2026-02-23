import Foundation

final class StorageService {
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let userProfile = "userProfile"
        static let chatMessages = "chatMessages"
        static let threads = "threads"
        static let contacts = "contacts"
        static let listings = "listings"
        static let apiKey = "openAIAPIKey"
        static let availabilityPreferences = "availabilityPreferences"
    }

    // MARK: - User Profile

    func saveProfile(_ profile: UserProfile) {
        if let data = try? encoder.encode(profile) {
            defaults.set(data, forKey: Keys.userProfile)
        }
    }

    func loadProfile() -> UserProfile? {
        guard let data = defaults.data(forKey: Keys.userProfile) else { return nil }
        return try? decoder.decode(UserProfile.self, from: data)
    }

    // MARK: - Chat Messages

    func saveChatMessages(_ messages: [ChatMessage]) {
        if let data = try? encoder.encode(messages) {
            defaults.set(data, forKey: Keys.chatMessages)
        }
    }

    func loadChatMessages() -> [ChatMessage] {
        guard let data = defaults.data(forKey: Keys.chatMessages) else { return [] }
        return (try? decoder.decode([ChatMessage].self, from: data)) ?? []
    }

    // MARK: - Threads

    func saveThreads(_ threads: [AgentThread]) {
        if let data = try? encoder.encode(threads) {
            defaults.set(data, forKey: Keys.threads)
        }
    }

    func loadThreads() -> [AgentThread] {
        guard let data = defaults.data(forKey: Keys.threads) else { return [] }
        return (try? decoder.decode([AgentThread].self, from: data)) ?? []
    }

    // MARK: - Contacts

    func saveContacts(_ contacts: [Contact]) {
        if let data = try? encoder.encode(contacts) {
            defaults.set(data, forKey: Keys.contacts)
        }
    }

    func loadContacts() -> [Contact] {
        guard let data = defaults.data(forKey: Keys.contacts) else {
            // First launch — seed defaults
            let defaults = Contact.defaultContacts
            saveContacts(defaults)
            return defaults
        }
        return (try? decoder.decode([Contact].self, from: data)) ?? Contact.defaultContacts
    }

    // MARK: - Listings

    func saveListings(_ listings: [Listing]) {
        if let data = try? encoder.encode(listings) {
            defaults.set(data, forKey: Keys.listings)
        }
    }

    func loadListings() -> [Listing] {
        guard let data = defaults.data(forKey: Keys.listings) else {
            // First launch — seed with mock data
            let seed = Listing.seedListings
            saveListings(seed)
            return seed
        }
        return (try? decoder.decode([Listing].self, from: data)) ?? Listing.seedListings
    }

    // MARK: - API Key

    func saveAPIKey(_ key: String) {
        defaults.set(key, forKey: Keys.apiKey)
    }

    func loadAPIKey() -> String {
        defaults.string(forKey: Keys.apiKey) ?? ""
    }

    // MARK: - Availability Preferences

    func saveAvailabilityPreferences(_ prefs: AvailabilityPreferences) {
        if let data = try? encoder.encode(prefs) {
            defaults.set(data, forKey: Keys.availabilityPreferences)
        }
    }

    func loadAvailabilityPreferences() -> AvailabilityPreferences {
        guard let data = defaults.data(forKey: Keys.availabilityPreferences) else {
            return .empty
        }
        return (try? decoder.decode(AvailabilityPreferences.self, from: data)) ?? .empty
    }
}
