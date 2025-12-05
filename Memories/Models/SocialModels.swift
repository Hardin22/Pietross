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
    
    var sender: Profile? // Populated manually (the user who sent the request)
    
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
    case rejected // Not in DB constraint but useful for UI handling if needed, though DB only has pending/accepted
}

struct Book: Codable, Identifiable {
    let id: UUID
    let friendshipId: UUID
    let coverUrl: String?
    let title: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case friendshipId = "friendship_id"
        case coverUrl = "cover_url"
        case title
        case createdAt = "created_at"
    }
}

struct Page: Codable, Identifiable {
    let id: UUID
    let bookId: UUID
    let authorId: UUID
    let type: PageType
    let contentJson: Data // JSONB
    let drawingPath: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case bookId = "book_id"
        case authorId = "author_id"
        case type
        case contentJson = "content_json"
        case drawingPath = "drawing_path"
        case createdAt = "created_at"
    }
}

enum PageType: String, Codable {
    case letter
    case memory
}
