import Foundation

// MARK: - Social Graph Models

struct Profile: Codable, Identifiable {
    let id: UUID
    let username: String?
    let fullName: String?
    let avatarUrl: String?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case updatedAt = "updated_at"
    }
}

struct Friendship: Codable, Identifiable {
    let id: UUID
    let userA: UUID
    let userB: UUID
    let status: FriendshipStatus
    let createdAt: Date

    var sender: Profile?  // Populated manually (the user who sent the request)

    enum CodingKeys: String, CodingKey {
        case id
        case userA = "user_a"
        case userB = "user_b"
        case status
        case createdAt = "created_at"
    }
}

enum FriendshipStatus: String, Codable {
    case pending
    case accepted
    case rejected  // Not in DB constraint but useful for UI handling if needed, though DB only has pending/accepted
}

struct Book: Codable, Identifiable {
    let id: UUID
    let friendshipId: UUID?
    var coverUrl: String?
    var title: String?
    var vibe: String?  // Hex color or vibe identifier
    let createdAt: Date
    let isGroup: Bool?
    let ownerId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case friendshipId = "friendship_id"
        case coverUrl = "cover_url"
        case title
        case vibe
        case createdAt = "created_at"
        case isGroup = "is_group"
        case ownerId = "owner_id"
    }
}

struct BookParticipant: Codable, Identifiable {
    let id: UUID
    let bookId: UUID
    let userId: UUID
    let role: String
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case bookId = "book_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
    }
}

struct Page: Codable, Identifiable {
    let id: UUID
    let bookId: UUID
    let authorId: UUID
    let photoUrl: String
    let memoryText: String?
    let photoDate: Date?  // YYYY-MM-DD
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case bookId = "book_id"
        case authorId = "author_id"
        case photoUrl = "photo_url"
        case memoryText = "memory_text"
        case photoDate = "photo_date"
        case createdAt = "created_at"
    }
}
