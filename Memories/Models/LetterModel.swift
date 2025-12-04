import Foundation

struct Letter: Codable, Identifiable {
    let id: UUID
    let senderId: UUID
    let recipientId: UUID
    let imageUrl: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case imageUrl = "image_url"
        case createdAt = "created_at"
    }
}
