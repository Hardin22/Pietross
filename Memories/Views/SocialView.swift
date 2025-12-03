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
// Components have been moved to separate files in Views/Components/
