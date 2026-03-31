import Combine
import Foundation
import Realtime
import Supabase
import SwiftUI
import UIKit

class SocialViewModel: ObservableObject {

    @Published var searchResults: [Profile] = []
    @Published var pendingRequests: [Friendship] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var books: [Book] = []
    @Published var friends: [Profile] = []  // New friends list
    @Published var currentUser: Profile?
    @Published var searchText: String = ""

    private let socialService = SocialService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                if query.isEmpty {
                    self.searchResults = []
                } else {
                    Task { await self.search(query: query) }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    @MainActor
    func loadData() async {
        // Parallel execution
        // Parallel execution for independent tasks
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchPendingRequests() }
            group.addTask { await self.fetchFriends() }
            group.addTask { await self.fetchAcceptedFriendships() }
            group.addTask { await self.fetchCurrentUser() }
        }

        // Fetch books first, then participants (dependent)
        await self.fetchBooks()
        await self.fetchGroupParticipants()

        // Start Realtime Subscription
        await subscribeToRealtimeUpdates()
    }

    struct InAppNotification: Identifiable {
        let id = UUID()
        let author: Profile
        let book: Book
        let timestamp = Date()
    }

    @Published var currentNotification: InAppNotification?
    @Published var recentNotifications: [InAppNotification] = []

    var unreadCount: Int {
        return pendingRequests.count + recentNotifications.count
    }

    @MainActor
    func subscribeToRealtimeUpdates() async {
        let client = SupabaseManager.shared.client
        print("🔌 Subscribing to Realtime updates...")

        // 1. Friendships Subscription
        let friendshipsChannel = client.channel(AppConstants.Realtime.friendshipsChannel)
        let friendshipChanges = friendshipsChannel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: AppConstants.Table.friendships
        )
        await friendshipsChannel.subscribe()

        // 2. Pages Subscription (for Notifications)
        let pagesChannel = client.channel("public:pages")
        let pageChanges = pagesChannel.postgresChange(
            InsertAction.self,  // Only listen for inserts
            schema: "public",
            table: "pages"
        )
        let status = await pagesChannel.subscribe()
        print("🔌 Pages subscription status: \(status)")

        // Handle Realtime Events
        Task {
            // We need to handle multiple streams.
            // Since Swift concurrency doesn't support `select` like Go, we spawn separate tasks or use a merge approach.
            // For simplicity, let's spawn two tasks.

            // Task A: Friendships
            Task {
                for await _ in friendshipChanges {
                    print("🔔 Realtime: Friendship table changed, refreshing data...")
                    await self.fetchPendingRequests()
                    await self.fetchFriends()
                    await self.fetchAcceptedFriendships()
                    await self.fetchBooks()
                }
            }

            // Task B: Pages
            Task.detached { [weak self] in
                print("👂 Listening for page inserts (Detached)...")
                for await change in pageChanges {
                    print("🔔 Realtime: New page inserted!")
                    // Break down the steps to see where it hangs
                    let record = change.record
                    print("📦 Payload extracted: \(record)")

                    if let self = self {
                        print("▶️ Calling handleNewPage...")
                        await self.handleNewPage(payload: record)
                        print("⏹️ handleNewPage returned")
                    }
                }
            }
        }
    }

    @MainActor
    private func handleNewPage(payload: [String: AnyJSON]) async {
        print("🕵️ Handling new page payload...")
        // 1. Extract IDs
        guard
            let bookIdStr = payload["book_id"]?.stringValue,
            let bookId = UUID(uuidString: bookIdStr),
            let authorIdStr = payload["author_id"]?.stringValue,
            let authorId = UUID(uuidString: authorIdStr),
            let currentUserId = socialService.currentUser?.id
        else {
            print("❌ Failed to parse IDs from payload: \(payload)")
            return
        }

        print("📖 Book ID: \(bookId), Author ID: \(authorId), Current User: \(currentUserId)")

        // 2. Ignore own posts
        if authorId == currentUserId {
            print("🚫 Ignoring own post")
            return
        }

        // 3. Check if we have this book (meaning we are a participant)
        guard let book = books.first(where: { $0.id == bookId }) else {
            print(
                "🚫 Book not found in local list (user might not be a participant). Book ID: \(bookId)"
            )
            return
        }

        // 4. Fetch Author Profile
        // Check if it's a friend first
        var author = friends.first(where: { $0.id == authorId })

        if author == nil {
            // If not a friend (e.g. group member), try to find in group participants
            if let participants = groupBookParticipants[bookId] {
                author = participants.first(where: { $0.id == authorId })
            }
        }

        if author == nil {
            print("⚠️ Author not found locally, fetching from DB...")
            // Fallback: Fetch from DB
            do {
                author = try await SupabaseManager.shared.client
                    .from(AppConstants.Table.profiles)
                    .select()
                    .eq("id", value: authorId)
                    .single()
                    .execute()
                    .value
            } catch {
                print("❌ Failed to fetch author for notification: \(error)")
            }
        }

        guard let notificationAuthor = author else {
            print("❌ Could not resolve author profile")
            return
        }

        print(
            "✅ Triggering notification for \(notificationAuthor.username ?? "unknown") in \(book.title ?? "unknown")"
        )

        print(
            "✅ Triggering notification for \(notificationAuthor.username ?? "unknown") in \(book.title ?? "unknown")"
        )

        // 5. Trigger Notification
        let notification = InAppNotification(author: notificationAuthor, book: book)

        withAnimation {
            // Show banner
            self.currentNotification = notification
            // Add to list (prepend to show newest first)
            self.recentNotifications.insert(notification, at: 0)
        }

        // Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    @MainActor
    func dismissNotification(id: UUID) {
        withAnimation {
            recentNotifications.removeAll(where: { $0.id == id })
        }
    }

    @MainActor
    func fetchCurrentUser() async {
        do {
            self.currentUser = try await socialService.getCurrentProfile()
        } catch {
            print("Failed to fetch current user: \(error)")
        }
    }

    @MainActor
    func fetchPendingRequests() async {
        do {
            self.pendingRequests = try await socialService.getPendingRequests()
        } catch {
            print("Failed to fetch requests: \(error)")
        }
    }

    @MainActor
    func fetchBooks() async {
        do {
            // Fetch all books the user has access to (RLS handles visibility)
            // This includes individual books (via friendship) and group books (via participation)
            self.books = try await socialService.getBooks()
        } catch {
            print("Failed to fetch books: \(error)")
        }
    }

    @MainActor
    func fetchFriends() async {
        do {
            self.friends = try await socialService.getFriends()
        } catch {
            print("Failed to fetch friends: \(error)")
        }
    }

    // MARK: - Actions

    @MainActor
    func search(query: String) async {
        guard !query.isEmpty else {
            self.searchResults = []
            return
        }

        // We don't set global isLoading for search to avoid flickering the whole screen
        // The view can use a local spinner if needed

        do {
            self.searchResults = try await socialService.searchUsers(query: query)
        } catch {
            print("Search failed: \(error)")
        }
    }

    @MainActor
    func sendRequest(to user: Profile) async {
        print("⚡️ ViewModel: sendRequest called for \(user.username ?? "unknown")")
        do {
            try await socialService.sendFriendRequest(to: user.id)
            print("✅ ViewModel: Request sent successfully")
            // Optimistically update UI or show success
        } catch {
            print("❌ ViewModel: Failed to send request: \(error)")
            self.errorMessage = "Failed to send request: \(error.localizedDescription)"
        }
    }

    @MainActor
    func accept(request: Friendship) async {
        do {
            let _ = try await socialService.acceptFriendRequest(friendshipId: request.id)
            await loadData()
        } catch {
            self.errorMessage = "Failed to accept request: \(error.localizedDescription)"
        }
    }

    @MainActor
    func decline(request: Friendship) async {
        do {
            try await socialService.declineFriendRequest(friendshipId: request.id)
            await fetchPendingRequests()
        } catch {
            self.errorMessage = "Failed to decline request: \(error.localizedDescription)"
        }
    }

    @MainActor
    func deleteFriend(friendId: UUID) async {
        do {
            // Find the friendship ID for this friend
            guard
                let friendship = acceptedFriendships.first(where: { friendship in
                    friendship.userA == friendId || friendship.userB == friendId
                })
            else {
                self.errorMessage = "Friendship not found"
                return
            }

            try await socialService.deleteFriendship(friendshipId: friendship.id)
            await loadData()
        } catch {
            self.errorMessage = "Failed to delete friend: \(error.localizedDescription)"
        }
    }

    @Published var acceptedFriendships: [Friendship] = []
    @Published var groupBookParticipants: [UUID: [Profile]] = [:]

    @MainActor
    func fetchGroupParticipants() async {
        let groupBooks = books.filter { $0.isGroup == true }
        if groupBooks.isEmpty { return }

        // Collect all book IDs
        let bookIds = groupBooks.map { $0.id }

        do {
            // We need to fetch participants for these books.
            // Since we can't easily do a nested join in one simple query that maps perfectly to our dict structure without custom decoding,
            // we will fetch all participants for these books in one go.

            struct ParticipantRow: Decodable {
                let bookId: UUID
                let profile: Profile

                enum CodingKeys: String, CodingKey {
                    case bookId = "book_id"
                    case profile = "profiles"  // Nested resource
                }
            }

            // Query: select book_id, profiles(*) from book_participants where book_id in (ids)
            let rows: [ParticipantRow] = try await SupabaseManager.shared.client
                .from("book_participants")
                .select("book_id, profiles(*)")
                .in("book_id", values: bookIds)
                .execute()
                .value

            // Group by bookId
            var newParticipants: [UUID: [Profile]] = [:]
            for row in rows {
                if newParticipants[row.bookId] == nil {
                    newParticipants[row.bookId] = []
                }
                newParticipants[row.bookId]?.append(row.profile)
            }

            self.groupBookParticipants = newParticipants

        } catch {
            print("Failed to fetch group participants: \(error)")
        }
    }

    @MainActor
    func fetchAcceptedFriendships() async {
        do {
            let currentUserId = SupabaseManager.shared.client.auth.currentUser?.id

            guard let uid = currentUserId else { return }

            let response: [Friendship] = try await SupabaseManager.shared.client
                .from("friendships")
                .select()
                .eq("status", value: "accepted")
                .or("user_a.eq.\(uid),user_b.eq.\(uid)")
                .execute()
                .value

            self.acceptedFriendships = response
        } catch {
            print("Failed to fetch accepted friendships: \(error)")
        }
    }

    func getPartner(for book: Book) -> Profile? {
        // 1. Find the friendship
        guard let friendship = acceptedFriendships.first(where: { $0.id == book.friendshipId })
        else {
            return nil
        }

        // 2. Find the partner ID
        let currentUserId = SupabaseManager.shared.client.auth.currentUser?.id
        let partnerId = (friendship.userA == currentUserId) ? friendship.userB : friendship.userA

        // 3. Find the profile in `friends` list (which contains profiles of accepted friends)
        return friends.first(where: { $0.id == partnerId })
    }

    func signOut() {
        Task {
            try? await AuthService.shared.signOut()
        }
    }
}
