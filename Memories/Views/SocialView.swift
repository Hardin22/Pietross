import Supabase
import SwiftUI

enum EditorConfig: Identifiable {
    case letter(Profile)
    case book(Book)

    var id: String {
        switch self {
        case .letter(let p): return "letter_\(p.id)"
        case .book(let b): return "book_\(b.id)"
        }
    }
}

struct SocialView: View {
    @StateObject private var viewModel = SocialViewModel()
    @State private var editorConfig: EditorConfig?
    @State private var showFriendships = false
    @State private var showProfile = false
    @State private var showMemoriesList = false
    @State private var showGroupMemoriesList = false
    @State private var showCreateGroupBook = false
    @State private var showNotifications = false

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        HStack {
            Text("MoMo")
            Spacer()
            HStack {
                // Notifications Bell
                Button(action: {
                    showNotifications = true
                }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.title3)
                            .foregroundColor(.primary)

                        if viewModel.unreadCount > 0 {
                            Text("\(viewModel.unreadCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
                }

                Button(action: {
                    showFriendships = true
                }) {
                    Image(systemName: "person.2")
                        .foregroundColor(.primary)
                }
                Button(action: {
                    showProfile = true
                }) {
                    Image(systemName: "person.crop.circle")
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Memories Section (Individual)
                        Button(action: {
                            showMemoriesList = true
                        }) {
                            HStack {
                                Text("My Memories")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.top)
                        }

                        let individualBooks = viewModel.books.filter { $0.isGroup != true }
                        if individualBooks.isEmpty {
                            EmptyStateView(
                                iconName: "book.closed",
                                title: "No Memories Yet",
                                message: "Start a book with a friend to see it here."
                            )
                            .padding(.top, 20)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 20) {
                                    ForEach(individualBooks, id: \Book.id) { (book: Book) in
                                        Button(action: {
                                            editorConfig = .book(book)
                                        }) {
                                            BookCardView(
                                                book: book,
                                                partner: viewModel.getPartner(for: book),
                                                participants: nil
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Group Memories Section
                        HStack {
                            Button(action: {
                                showGroupMemoriesList = true
                            }) {
                                HStack {
                                    Text("Group Memories")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button(action: {
                                showCreateGroupBook = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal)

                        let groupBooks = viewModel.books.filter { $0.isGroup == true }
                        if groupBooks.isEmpty {
                            EmptyStateView(
                                iconName: "person.3",
                                title: "No Group Memories Yet",
                                message:
                                    "Create a group book to start sharing memories with friends."
                            )
                            .padding(.top, 20)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 20) {
                                    ForEach(groupBooks, id: \Book.id) { (book: Book) in
                                        Button(action: {
                                            editorConfig = .book(book)
                                        }) {
                                            BookCardView(
                                                book: book,
                                                partner: nil,
                                                participants: viewModel.groupBookParticipants[
                                                    book.id]
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 100)  // Space for FAB
                }

                // Notification Overlay
                if let notification = viewModel.currentNotification {
                    VStack {
                        NotificationBanner(
                            author: notification.author,
                            bookTitle: notification.book.title ?? "Memory Book",
                            onTap: {
                                // Navigate to book
                                editorConfig = .book(notification.book)
                                // Dismiss
                                withAnimation {
                                    viewModel.currentNotification = nil
                                }
                            },
                            onDismiss: {
                                withAnimation {
                                    viewModel.currentNotification = nil
                                }
                            }
                        )
                        .padding(.top, 8)

                        Spacer()
                    }
                    .transition(.move(edge: .top))
                    .zIndex(100)  // Ensure it's on top
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadData()
            }
            .fullScreenCover(item: $editorConfig) { config in
                switch config {
                case .letter(let recipient):
                    MemoryEditorWrapper(recipient: recipient)
                        .ignoresSafeArea(.all)
                case .book(let book):
                    BookDetailView(book: book)
                        .ignoresSafeArea(.all)
                }
            }
            .fullScreenCover(isPresented: $showFriendships) {
                FriendshipsView()
            }
            .fullScreenCover(isPresented: $showProfile) {
                ProfileView()
            }
            .fullScreenCover(isPresented: $showMemoriesList) {
                MemoriesListView(viewModel: viewModel)
            }
            .fullScreenCover(isPresented: $showGroupMemoriesList) {
                GroupMemoriesListView(viewModel: viewModel)
            }
            .fullScreenCover(isPresented: $showCreateGroupBook) {
                CreateGroupBookView(socialViewModel: viewModel)
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView(
                    viewModel: viewModel,
                    onNavigateToBook: { book in
                        // Slight delay to allow sheet to dismiss smoothly
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            editorConfig = .book(book)
                        }
                    }
                )
            }
        }
    }
}

// Extracted Book Card for reuse
struct BookCardView: View {
    let book: Book
    let partner: Profile?
    let participants: [Profile]?

    var body: some View {
        VStack(spacing: 12) {
            // Book Card (Postmark Style)
            ZStack {
                // 1. Vibe Background
                Color(hex: book.vibe ?? "#FFB7B2")

                // 2. Postmark Frame
                Image("postmark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(20)

                // 3. Cover Image
                if let coverUrl = book.coverUrl,
                    let url = URL(string: coverUrl)
                {
                    CachedImage(
                        url: url,
                        content: { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        },
                        placeholder: {
                            Color.gray.opacity(0.3)
                        }
                    )
                    .frame(width: 100, height: 140)
                    .clipped()
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 180, height: 260)
            .clipped()
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            // Title & Partner/Group Info
            VStack(spacing: 4) {
                Text(book.title ?? "Untitled")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let partner = partner {
                    HStack(spacing: 4) {
                        // AvatarView already shows username if passed, but we want to control it or rely on it.
                        // AvatarView implementation shows Text(username) if username is passed.
                        // User wants single display.
                        // If we pass username to AvatarView, it shows it.
                        // If we pass nil, it shows initial.
                        // Let's rely on AvatarView for the image, but maybe we want the text outside?
                        // AvatarView code:
                        // if avatarUrl... HStack { Image... Text(username) }
                        // So if we pass username, it shows it inside.
                        // The previous code had AvatarView(...) AND Text(partner.username). That caused double.
                        // So we should just use AvatarView.
                        AvatarView(
                            avatarUrl: partner.avatarUrl, username: partner.username, size: 20)
                    }
                } else if book.isGroup == true, let participants = participants {
                    // Avatar Stack
                    HStack(spacing: -8) {
                        // Filter out current user
                        let currentUserId = SupabaseManager.shared.client.auth.currentUser?.id
                        let filteredParticipants = participants.filter { $0.id != currentUserId }

                        let displayParticipants = Array(filteredParticipants.prefix(4))
                        let remainingCount = filteredParticipants.count - 4

                        ForEach(displayParticipants) { participant in
                            AvatarView(
                                avatarUrl: participant.avatarUrl,
                                username: nil,  // Hide username for group stack
                                size: 24
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color(UIColor.systemGroupedBackground), lineWidth: 2)
                            )
                        }

                        if remainingCount > 0 {
                            Text("+\(remainingCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .frame(width: 24, height: 24)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            Color(UIColor.systemGroupedBackground), lineWidth: 2)
                                )
                                .padding(.leading, 4)
                        }
                    }
                }
            }
        }
    }
}
