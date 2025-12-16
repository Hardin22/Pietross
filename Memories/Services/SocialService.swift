import Foundation
import Supabase

class SocialService {
    static let shared = SocialService()

    private let client = SupabaseManager.shared.client

    private init() {}

    var currentUser: User? {
        client.auth.currentUser
    }

    // MARK: - User Search

    func searchUsers(query: String) async throws -> [Profile] {
        guard !query.isEmpty else { return [] }
        guard let currentUserId = client.auth.currentUser?.id else { return [] }

        let response: [Profile] =
            try await client
            .from(AppConstants.Table.profiles)
            .select()
            .ilike("username", pattern: "%\(query)%")
            .neq("id", value: currentUserId)  // Exclude current user
            .execute()
            .value

        return response
    }

    // MARK: - Friend Requests

    func sendFriendRequest(to userId: UUID) async throws {
        guard let currentUser = client.auth.currentUser else {
            throw NSError(
                domain: "Auth", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }

        // Explicitly set user_a as sender (current user) and user_b as recipient (target user)
        let userA = currentUser.id
        let userB = userId

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

        // Only fetch requests where I am the recipient (user_b)
        var requests: [Friendship] =
            try await client
            .from(AppConstants.Table.friendships)
            .select()
            .eq("user_b", value: currentUser.id)
            .eq("status", value: "pending")
            .execute()
            .value

        if requests.isEmpty { return [] }

        // Sender is always user_a
        let senderIds = requests.map { $0.userA }

        let profiles: [Profile] =
            try await client
            .from(AppConstants.Table.profiles)
            .select()
            .in("id", values: senderIds)
            .execute()
            .value

        // Map senders
        for i in 0..<requests.count {
            requests[i].sender = profiles.first(where: { $0.id == requests[i].userA })
        }

        return requests
    }

    func declineFriendRequest(friendshipId: UUID) async throws {
        try await client
            .from(AppConstants.Table.friendships)
            .delete()  // Or update to 'rejected' if we want history
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
            vibe: nil,
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
        let friendships: [Friendship] =
            try await client
            .from(AppConstants.Table.friendships)
            .select()
            .or("user_a.eq.\(currentUser.id),user_b.eq.\(currentUser.id)")
            .eq("status", value: "accepted")
            .execute()
            .value

        let friendshipIds = friendships.map { $0.id }

        if friendshipIds.isEmpty { return [] }

        // Step 2: Get books for these friendships
        let books: [Book] =
            try await client
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
        let friendships: [Friendship] =
            try await client
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
        let profiles: [Profile] =
            try await client
            .from(AppConstants.Table.profiles)
            .select()
            .in("id", values: friendIds)
            .execute()
            .value

        return profiles
    }
    // MARK: - Profile Management

    func updateProfile(id: UUID, username: String, fullName: String?, avatarUrl: String?)
        async throws
    {
        var updates: [String: String] = [
            "username": username,
            "updated_at": Date().ISO8601Format(),
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
        let count =
            try await client
            .from(AppConstants.Table.profiles)
            .select("id", head: true, count: .exact)
            .eq("username", value: username)
            .execute()
            .count

        return (count ?? 0) == 0
    }

    func getCurrentProfile() async throws -> Profile? {
        guard let currentUser = client.auth.currentUser else { return nil }

        let profile: Profile =
            try await client
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
            .upload(
                "\(AppConstants.Storage.avatarsPath)/\(fileName)", data: data, options: fileOptions)

        // The bucket appears to be private, so we must use a signed URL.
        // We generate a URL with a very long expiration (10 years) to act as a permanent link.
        let signedUrl = try await client.storage
            .from(AppConstants.Storage.bucket)
            .createSignedURL(
                path: "\(AppConstants.Storage.avatarsPath)/\(fileName)", expiresIn: 315_360_000)  // 10 years

        return signedUrl.absoluteString
    }

    // MARK: - Book Management

    func updateBook(id: UUID, title: String?, coverData: Data?, vibe: String?) async throws {
        var updates: [String: String] = [:]

        if let title = title {
            updates["title"] = title
        }

        if let vibe = vibe {
            updates["vibe"] = vibe
        }

        if let coverData = coverData {
            let fileName = "\(id.uuidString)_cover.jpg"
            let fileOptions = FileOptions(
                cacheControl: "3600", contentType: "image/jpeg", upsert: true)

            try await client.storage
                .from(AppConstants.Storage.bucket)
                .upload(
                    "\(AppConstants.Storage.avatarsPath)/\(fileName)", data: coverData,
                    options: fileOptions)  // Reusing avatars path or create 'covers'

            let signedUrl = try await client.storage
                .from(AppConstants.Storage.bucket)
                .createSignedURL(
                    path: "\(AppConstants.Storage.avatarsPath)/\(fileName)", expiresIn: 315_360_000)

            updates["cover_url"] = signedUrl.absoluteString
        }

        guard !updates.isEmpty else { return }

        try await client
            .from(AppConstants.Table.books)
            .update(updates)
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Page Management

    func addPage(bookId: UUID, authorId: UUID, photoData: Data, memoryText: String, photoDate: Date)
        async throws
    {
        let pageId = UUID()
        let fileName = "\(pageId.uuidString).jpg"
        let fileOptions = FileOptions(
            cacheControl: "3600", contentType: "image/jpeg", upsert: false)

        // 1. Upload Photo
        try await client.storage
            .from(AppConstants.Storage.bucket)
            .upload("pages/\(fileName)", data: photoData, options: fileOptions)

        let signedUrl = try await client.storage
            .from(AppConstants.Storage.bucket)
            .createSignedURL(path: "pages/\(fileName)", expiresIn: 315_360_000)

        // 2. Create Page Record
        let page = Page(
            id: pageId,
            bookId: bookId,
            authorId: authorId,
            photoUrl: signedUrl.absoluteString,
            memoryText: memoryText,
            photoDate: photoDate,
            createdAt: Date()
        )

        try await client
            .from("pages")  // Hardcoded table name for now or add to AppConstants
            .insert(page)
            .execute()
    }

    func getPages(bookId: UUID) async throws -> [Page] {
        let pages: [Page] =
            try await client
            .from("pages")
            .select()
            .eq("book_id", value: bookId)
            .order("photo_date", ascending: true)  // Chronological order by photo date
            .execute()
            .value

        return pages
    }

    // MARK: - Letters (Legacy)

    func sendLetter(recipientId: UUID, imageData: Data) async throws {
        // ... legacy implementation ...
    }
    func getPartnerProfile(friendshipId: UUID) async throws -> Profile? {
        guard let currentUser = client.auth.currentUser else { return nil }

        // 1. Get the friendship
        let friendship: Friendship =
            try await client
            .from(AppConstants.Table.friendships)
            .select()
            .eq("id", value: friendshipId)
            .single()
            .execute()
            .value

        // 2. Determine partner ID
        let partnerId = (friendship.userA == currentUser.id) ? friendship.userB : friendship.userA

        // 3. Fetch partner profile
        let profile: Profile =
            try await client
            .from(AppConstants.Table.profiles)
            .select()
            .eq("id", value: partnerId)
            .single()
            .execute()
            .value

        return profile
    }
}
