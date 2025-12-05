import Foundation
import Combine
import Supabase
import Realtime

class SocialViewModel: ObservableObject {
    
    @Published var searchResults: [Profile] = []
    @Published var pendingRequests: [Friendship] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var books: [Book] = []
    @Published var friends: [Profile] = [] // New friends list
    @Published var receivedLetters: [Letter] = [] // Received letters
    @Published var currentUser: Profile?
    @Published var searchText: String = ""
    
    var unreadCount: Int {
        let unreadLetters = receivedLetters.filter { !$0.isRead }.count
        return unreadLetters + pendingRequests.count
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
            group.addTask { await self.fetchCurrentUser() }
            group.addTask { await self.fetchReceivedLetters() }
        }
        
        // Start Realtime Subscription
        await subscribeToRealtimeUpdates()
    }
    
    @MainActor
    func subscribeToRealtimeUpdates() async {
        // Friendships Subscription
        let friendshipsChannel = SupabaseManager.shared.client.channel(AppConstants.Realtime.friendshipsChannel)
        let friendshipChanges = friendshipsChannel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: AppConstants.Table.friendships
        )
        await friendshipsChannel.subscribe()
        
        // Letters Subscription
        let lettersChannel = SupabaseManager.shared.client.channel(AppConstants.Realtime.lettersChannel)
        let letterChanges = lettersChannel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: AppConstants.Table.letters
        )
        await lettersChannel.subscribe()
        
        // Handle Friendships
        Task {
            for await _ in friendshipChanges {
                print("Realtime: Friendship changed")
                await self.fetchPendingRequests()
                await self.fetchBooks()
                await self.fetchFriends()
            }
        }
        
        // Handle Letters
        Task {
            for await _ in letterChanges {
                print("Realtime: Letter received")
                await self.fetchReceivedLetters()
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
    
    @MainActor
    func fetchReceivedLetters() async {
        do {
            self.receivedLetters = try await socialService.getReceivedLetters()
        } catch {
            print("Failed to fetch letters: \(error)")
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
    
    func markLetterAsRead(_ letter: Letter) {
        guard !letter.isRead else { return }
        
        // Optimistic update
        if let index = receivedLetters.firstIndex(where: { $0.id == letter.id }) {
            // Create a new Letter instance with isRead = true
            // Since Letter properties are 'let', we need to recreate it.
            var updatedLetter = Letter(
                id: letter.id,
                senderId: letter.senderId,
                recipientId: letter.recipientId,
                imageUrl: letter.imageUrl,
                isRead: true,
                createdAt: letter.createdAt
            )
            updatedLetter.sender = letter.sender
            receivedLetters[index] = updatedLetter
        }
        
        Task {
            do {
                try await socialService.markLetterAsRead(id: letter.id)
                await fetchReceivedLetters() // Refresh to get updated status
            } catch {
                print("Failed to mark letter as read: \(error)")
            }
        }
    }
    
    func signOut() {
        Task {
            try? await AuthService.shared.signOut()
        }
    }
}
