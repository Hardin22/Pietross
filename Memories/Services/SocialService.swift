import Foundation
import Supabase

class SocialService {
    static let shared = SocialService()
    
    private let client = SupabaseManager.shared.client
    
    private init() {}
    
    // MARK: - User Search
    
    func searchUsers(query: String) async throws -> [Profile] {
        guard !query.isEmpty else { return [] }
        guard let currentUserId = client.auth.currentUser?.id else { return [] }
        
        let response: [Profile] = try await client
            .from(AppConstants.Table.profiles)
            .select()
            .ilike("username", pattern: "%\(query)%")
            .neq("id", value: currentUserId) // Exclude current user
            .execute()
            .value
            
        return response
    }
    
    // MARK: - Friend Requests
    
    func sendFriendRequest(to userId: UUID) async throws {
        guard let currentUser = client.auth.currentUser else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        // Determine user_a and user_b based on UUID sort order
        let (userA, userB) = currentUser.id.uuidString < userId.uuidString 
            ? (currentUser.id, userId) 
            : (userId, currentUser.id)
        
        // Check if friendship already exists (optional but good practice)
        // For now relying on DB constraint if any, or just insert.
        
        let friendship = Friendship(
            id: UUID(),
            userA: userA,
            userB: userB,
            status: .pending,
            createdAt: Date()
        )
        
        try await client
            .from(AppConstants.Table.friendships)
            .insert(friendship)
            .execute()
    }
    
    func getPendingRequests() async throws -> [Friendship] {
        guard let currentUser = client.auth.currentUser else { return [] }
        
        var requests: [Friendship] = try await client
            .from(AppConstants.Table.friendships)
            .select()
            .or("user_a.eq.\(currentUser.id),user_b.eq.\(currentUser.id)")
            .eq("status", value: "pending")
            .execute()
            .value
            
        if requests.isEmpty { return [] }
        
        // Identify the "other" user (the sender of the request)
        // If I am userA, sender is userB. If I am userB, sender is userA.
        // Wait, "pending" request means someone sent it TO me.
        // But the DB doesn't strictly say who initiated.
        // Usually we assume the one who created it is the initiator.
        // But here we just want to show the "other" person.
        
        var senderIds: [UUID] = []
        for req in requests {
            if req.userA == currentUser.id {
                senderIds.append(req.userB)
            } else {
                senderIds.append(req.userA)
            }
        }
        
        let profiles: [Profile] = try await client
            .from(AppConstants.Table.profiles)
            .select()
            .in("id", values: senderIds)
            .execute()
            .value
            
        // Map senders
        for i in 0..<requests.count {
            let otherId = requests[i].userA == currentUser.id ? requests[i].userB : requests[i].userA
            requests[i].sender = profiles.first(where: { $0.id == otherId })
        }
            
        return requests
    }
    
    func declineFriendRequest(friendshipId: UUID) async throws {
        try await client
            .from(AppConstants.Table.friendships)
            .delete() // Or update to 'rejected' if we want history
            .eq("id", value: friendshipId)
            .execute()
    }
    
    // MARK: - Realtime
    
    // Realtime logic is currently handled in SocialViewModel using postgresChange stream.
    // We can add a centralized stream here later if needed.
    
    // MARK: - Accept Request & Create Book
    
    func acceptFriendRequest(friendshipId: UUID) async throws -> Book {
        // 1. Update friendship status to accepted
        try await client
            .from(AppConstants.Table.friendships)
            .update(["status": "accepted"])
            .eq("id", value: friendshipId)
            .execute()
            
        // 2. Create the shared book
        let book = Book(
            id: UUID(),
            friendshipId: friendshipId,
            coverUrl: nil,
            title: "Our Memories",
            createdAt: Date()
        )
        
        try await client
            .from(AppConstants.Table.books)
            .insert(book)
            .execute()
            
        return book
    }
    
    func getBooks() async throws -> [Book] {
        guard let currentUser = client.auth.currentUser else { return [] }
        
        // Fetch books where the user is part of the friendship.
        // This requires a join or a two-step query since 'books' only has 'friendship_id'.
        // Step 1: Get all friendship IDs for the user.
        let friendships: [Friendship] = try await client
            .from(AppConstants.Table.friendships)
            .select()
            .or("user_a.eq.\(currentUser.id),user_b.eq.\(currentUser.id)")
            .eq("status", value: "accepted")
            .execute()
            .value
            
        let friendshipIds = friendships.map { $0.id }
        
        if friendshipIds.isEmpty { return [] }
        
        // Step 2: Get books for these friendships
        let books: [Book] = try await client
            .from(AppConstants.Table.books)
            .select()
            .in("friendship_id", values: friendshipIds)
            .execute()
            .value
            
        return books
    }
    
    func getFriends() async throws -> [Profile] {
        guard let currentUser = client.auth.currentUser else { return [] }
        
        // 1. Get accepted friendships
        let friendships: [Friendship] = try await client
            .from(AppConstants.Table.friendships)
            .select()
            .or("user_a.eq.\(currentUser.id),user_b.eq.\(currentUser.id)")
            .eq("status", value: "accepted")
            .execute()
            .value
        
        if friendships.isEmpty { return [] }
        
        // 2. Extract friend IDs
        let friendIds = friendships.map { friendship -> UUID in
            return friendship.userA == currentUser.id ? friendship.userB : friendship.userA
        }
        
        // 3. Fetch profiles
        let profiles: [Profile] = try await client
            .from(AppConstants.Table.profiles)
            .select()
            .in("id", values: friendIds)
            .execute()
            .value
            
        return profiles
    }
    // MARK: - Profile Management
    
    func updateProfile(id: UUID, username: String, fullName: String?, avatarUrl: String?) async throws {
        var updates: [String: String] = [
            "username": username,
            "updated_at": Date().ISO8601Format()
        ]
        
        if let fullName = fullName {
            updates["full_name"] = fullName
        }
        
        if let avatarUrl = avatarUrl {
            updates["avatar_url"] = avatarUrl
        }
        
        try await client
            .from(AppConstants.Table.profiles)
            .update(updates)
            .eq("id", value: id)
            .execute()
    }
    
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let count = try await client
            .from(AppConstants.Table.profiles)
            .select("id", head: true, count: .exact)
            .eq("username", value: username)
            .execute()
            .count
            
        return (count ?? 0) == 0
    }
    
    func getCurrentProfile() async throws -> Profile? {
        guard let currentUser = client.auth.currentUser else { return nil }
        
        let profile: Profile = try await client
            .from(AppConstants.Table.profiles)
            .select()
            .eq("id", value: currentUser.id)
            .single()
            .execute()
            .value
            
        return profile
    }
    func uploadAvatar(userId: UUID, data: Data) async throws -> String {
        let fileName = "\(userId.uuidString).jpg"
        let fileOptions = FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
        
        try await client.storage
            .from(AppConstants.Storage.bucket)
            .upload("\(AppConstants.Storage.avatarsPath)/\(fileName)", data: data, options: fileOptions)
            
        // The bucket appears to be private, so we must use a signed URL.
        // We generate a URL with a very long expiration (10 years) to act as a permanent link.
        let signedUrl = try await client.storage
            .from(AppConstants.Storage.bucket)
            .createSignedURL(path: "\(AppConstants.Storage.avatarsPath)/\(fileName)", expiresIn: 315360000) // 10 years
            
        return signedUrl.absoluteString
    }
    
    // MARK: - Letters
    
    func sendLetter(recipientId: UUID, imageData: Data) async throws {
        guard let currentUser = client.auth.currentUser else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        let letterId = UUID()
        let fileName = "\(letterId.uuidString).jpg"
        let fileOptions = FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: false)
        
        // 1. Upload Image
        try await client.storage
            .from(AppConstants.Storage.bucket)
            .upload("\(AppConstants.Storage.lettersPath)/\(fileName)", data: imageData, options: fileOptions)
            
        // 2. Get Public URL (or Signed URL if private)
        let signedUrl = try await client.storage
            .from(AppConstants.Storage.bucket)
            .createSignedURL(path: "\(AppConstants.Storage.lettersPath)/\(fileName)", expiresIn: 315360000) // 10 years
            
        // 3. Create Letter Record
        let letter = Letter(
            id: letterId,
            senderId: currentUser.id,
            recipientId: recipientId,
            imageUrl: signedUrl.absoluteString,
            isRead: false,
            createdAt: Date()
        )
        
        try await client
            .from(AppConstants.Table.letters)
            .insert(letter)
            .execute()
    }
    
    func getReceivedLetters() async throws -> [Letter] {
        guard let currentUser = client.auth.currentUser else { return [] }
        
        var letters: [Letter] = try await client
            .from(AppConstants.Table.letters)
            .select()
            .eq("recipient_id", value: currentUser.id)
            .order("created_at", ascending: false)
            .execute()
            .value
            
        if letters.isEmpty { return [] }
        
        // Fetch senders
        let senderIds = Array(Set(letters.map { $0.senderId }))
        let profiles: [Profile] = try await client
            .from(AppConstants.Table.profiles)
            .select()
            .in("id", values: senderIds)
            .execute()
            .value
            
        // Map senders to letters
        for i in 0..<letters.count {
            letters[i].sender = profiles.first(where: { $0.id == letters[i].senderId })
        }
            
        return letters
    }
    
    func markLetterAsRead(id: UUID) async throws {
        try await client
            .from(AppConstants.Table.letters)
            .update(["is_read": true])
            .eq("id", value: id)
            .execute()
    }
}
