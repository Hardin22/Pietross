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
        let channel = SupabaseManager.shared.client.channel(AppConstants.Realtime.friendshipsChannel)
        
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: AppConstants.Table.friendships
        )
        
        await channel.subscribe()
        
        Task {
            for await _ in changes {
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
    
    func signOut() {
        Task {
            try? await AuthService.shared.signOut()
        }
    }
}
