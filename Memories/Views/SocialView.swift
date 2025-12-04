import SwiftUI

struct SocialView: View {
    @StateObject private var viewModel = SocialViewModel()
    @State private var selectedFriend: Profile?
    @State private var showCanvas = false
    @State private var showRequests = false
    @State private var letterRecipient: Profile? // Specific for sending letters
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Welcome Back,")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(viewModel.currentUser?.username ?? "Friend")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 16) {
                                // Friend Requests Icon
                                Button(action: {
                                    showRequests = true
                                }) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "envelope.fill")
                                            .font(.title2)
                                            .foregroundColor(.primary)
                                            .padding(8)
                                            .background(Color(UIColor.secondarySystemGroupedBackground))
                                            .clipShape(Circle())
                                        
                                        if !viewModel.pendingRequests.isEmpty {
                                            Text("\(viewModel.pendingRequests.count)")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(4)
                                                .background(Color.red)
                                                .clipShape(Circle())
                                                .offset(x: 5, y: -5)
                                        }
                                    }
                                }
                                
                                AvatarView(
                                    avatarUrl: viewModel.currentUser?.avatarUrl,
                                    username: viewModel.currentUser?.username,
                                    size: 50
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Search Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Find Friends")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            SearchBar(text: $viewModel.searchText) {
                                viewModel.searchText = ""
                            }
                            .padding(.horizontal)
                            
                            if !viewModel.searchResults.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(viewModel.searchResults) { user in
                                            UserCard(user: user) {
                                                Task { await viewModel.sendRequest(to: user) }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        // Friends Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("My Friends")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if viewModel.friends.isEmpty {
                                Text("No friends yet. Search to add some!")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 20) {
                                        ForEach(viewModel.friends) { friend in
                                            Button(action: {
                                                selectedFriend = friend
                                            }) {
                                                VStack {
                                                    AvatarView(
                                                        avatarUrl: friend.avatarUrl,
                                                        username: friend.username,
                                                        size: 64
                                                    )
                                                    Text(friend.username ?? "Unknown")
                                                        .font(.caption)
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        // Debug/Test Section
                        VStack(spacing: 12) {
                            SignOutButton {
                                viewModel.signOut()
                            }
                        }
                        .padding(.top, 20)
                    }
                    .padding(.vertical)
                }
            }
            .navigationBarHidden(true)
            .navigationBarHidden(true)
            .task {
                await viewModel.loadData()
            }
            .sheet(item: $selectedFriend) { friend in
                FriendDetailSheet(friend: friend) { action in
                    selectedFriend = nil // Close sheet
                    
                    switch action {
                    case .openBook:
                        // Open book logic (placeholder for now)
                        showCanvas = true
                        letterRecipient = nil
                    case .sendLetter:
                        letterRecipient = friend
                        showCanvas = true
                    }
                }
                .presentationDetents([.fraction(0.4)])
            }
            .fullScreenCover(isPresented: $showCanvas) {
                if let recipient = letterRecipient {
                    MemoryEditorWrapper(recipient: recipient)
                        .ignoresSafeArea(.all)
                } else {
                    let dummyBook = Book(id: UUID(), friendshipId: UUID(), coverUrl: nil, title: "Memories", createdAt: Date())
                    MemoryEditorWrapper(book: dummyBook)
                        .ignoresSafeArea(.all)
                }
            }
            .sheet(isPresented: $showRequests) {
                InboxView(viewModel: viewModel)
            }
        }
    }
}

enum FriendAction {
    case openBook
    case sendLetter
}

struct FriendDetailSheet: View {
    let friend: Profile
    let onAction: (FriendAction) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            
            VStack(spacing: 8) {
                AvatarView(avatarUrl: friend.avatarUrl, username: friend.username, size: 80)
                
                Text(friend.username ?? "Unknown")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let fullName = friend.fullName {
                    Text(fullName)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                Button(action: { onAction(.openBook) }) {
                    VStack {
                        Image(systemName: "book.fill")
                            .font(.title2)
                        Text("Memories Book")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }
                
                Button(action: { onAction(.sendLetter) }) {
                    VStack {
                        Image(systemName: "envelope.fill")
                            .font(.title2)
                        Text("Send Letter")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Subviews
// Components have been moved to separate files in Views/Components/
