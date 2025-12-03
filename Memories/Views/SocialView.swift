import SwiftUI

struct SocialView: View {
    @StateObject private var viewModel = SocialViewModel()
    @State private var selectedBook: Book?
    @State private var showRequests = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                // Removed blocking loader

                
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
                                
                                if let avatarUrl = viewModel.currentUser?.avatarUrl, let url = URL(string: avatarUrl) {
                                    let _ = print("DEBUG: Loading avatar from \(url)")
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        case .failure(let error):
                                            let _ = print("DEBUG: Failed to load avatar: \(error)")
                                            Color.red.opacity(0.5)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                } else {
                                    let _ = print("DEBUG: No avatar URL for user: \(viewModel.currentUser?.username ?? "nil")")
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                        .overlay(Text(viewModel.currentUser?.username?.prefix(1).uppercased() ?? "?"))
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Search Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Find Friends")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                TextField("Search username...", text: $viewModel.searchText)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .submitLabel(.search)
                                
                                if !viewModel.searchText.isEmpty {
                                    Button(action: {
                                        viewModel.searchText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
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
                        
                        // Books Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("My Books")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if viewModel.books.isEmpty {
                                EmptyStateView()
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                    ForEach(viewModel.books) { book in
                                        BookCard(book: book) {
                                            selectedBook = book
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Debug/Test Section
                        VStack(spacing: 12) {
                            Button(action: {
                                // Create a dummy book for testing
                                let dummyBook = Book(
                                    id: UUID(),
                                    friendshipId: UUID(),
                                    coverUrl: nil,
                                    title: "Test Canvas",
                                    createdAt: Date()
                                )
                                selectedBook = dummyBook
                            }) {
                                HStack {
                                    
                                    Text("Test Canvas")
                                }
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.purple)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            
                            Button(action: {
                                viewModel.signOut()
                            }) {
                                Text("Sign Out")
                                    .foregroundColor(.red)
                                    .font(.subheadline)
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
            .fullScreenCover(item: $selectedBook) { book in
                MemoryEditorWrapper(book: book)
                    .ignoresSafeArea(.all)
            }
            .sheet(isPresented: $showRequests) {
                FriendRequestsView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Subviews

struct UserCard: View {
    let user: Profile
    let onAdd: () -> Void
    
    var body: some View {
        VStack {
            if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(Text(user.username?.prefix(1).uppercased() ?? "?"))
            }
            
            Text(user.username ?? "Unknown")
                .font(.caption)
                .lineLimit(1)
            
            Button(action: onAdd) {
                Text("Add")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .frame(width: 100)
    }
}

struct RequestRow: View {
    let request: Friendship
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "person.fill.questionmark")
                .padding(10)
                .background(Color.orange.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text("New Friend Request")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Tap to accept")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: onDecline) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                
                Button(action: onAccept) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct BookCard: View {
    let book: Book
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(0.75, contentMode: .fit)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "book.closed")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
                
                Text(book.title ?? "Untitled")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .padding(10)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("No shared books yet")
                .font(.headline)
            Text("Search for a friend to start creating memories together.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
