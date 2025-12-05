import Foundation

struct Letter: Codable, Identifiable {
    let id: UUID
    let senderId: UUID
    let recipientId: UUID
    let imageUrl: String
    let isRead: Bool
    let createdAt: Date
    
    var sender: Profile? // Populated manually
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case imageUrl = "image_url"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}
