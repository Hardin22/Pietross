import Combine
import Foundation
import Realtime
import Supabase

class SocialViewModel: ObservableObject {

    @Published var searchResults: [Profile] = []
    @Published var pendingRequests: [Friendship] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var books: [Book] = []
    @Published var friends: [Profile] = []  // New friends list
    @Published var currentUser: Profile?
    @Published var searchText: String = ""
    var unreadCount: Int {
        return pendingRequests.count
    }

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
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchPendingRequests() }
            group.addTask { await self.fetchBooks() }
            group.addTask { await self.fetchFriends() }
            group.addTask { await self.fetchAcceptedFriendships() }
            group.addTask { await self.fetchCurrentUser() }
        }

        // Start Realtime Subscription
        await subscribeToRealtimeUpdates()
    }

    @MainActor
    func subscribeToRealtimeUpdates() async {
        // Friendships Subscription
        let friendshipsChannel = SupabaseManager.shared.client.channel(
            AppConstants.Realtime.friendshipsChannel)
        let friendshipChanges = friendshipsChannel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: AppConstants.Table.friendships
        )
        await friendshipsChannel.subscribe()

        // Handle Friendships
        Task {
            for await _ in friendshipChanges {
                print("Realtime: Friendship changed")
                await self.fetchPendingRequests()
                await self.fetchBooks()
                await self.fetchFriends()
            }
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
        do {
            try await socialService.sendFriendRequest(to: user.id)
            // Optimistically update UI or show success
        } catch {
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

    @Published var acceptedFriendships: [Friendship] = []

    @MainActor
    func fetchAcceptedFriendships() async {
        do {
            // We need a service method to fetch accepted friendships
            // For now, let's assume we can get them.
            // If SocialService doesn't have it, we might need to add it or rely on `friends` list if we can link them.
            // Actually, `getFriends` returns profiles.
            // Let's fetch friendships where status is accepted.

            let currentUserId = SupabaseManager.shared.client.auth.currentUser?.id

            let response: [Friendship] = try await SupabaseManager.shared.client
                .from("friendships")
                .select()
                .eq("status", value: "accepted")
                .or("user_a.eq.\(currentUserId!),user_b.eq.\(currentUserId!)")
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
