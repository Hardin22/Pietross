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

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        HStack {
            Text("MoMo")
            Spacer()
            HStack {
                Image(systemName: "bell")
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
                        // Header
                        Text("My Memories")
                            .font(.title2)  // Reduced from largeTitle
                            .fontWeight(.bold)
                            .padding(.horizontal)
                            .padding(.top)

                        if viewModel.books.isEmpty {
                            EmptyStateView(
                                iconName: "book.closed",
                                title: "No Memories Yet",
                                message: "Start a book with a friend to see it here."
                            )
                            .padding(.top, 50)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 20) {
                                    ForEach(viewModel.books, id: \Book.id) { (book: Book) in
                                        Button(action: {
                                            editorConfig = .book(book)
                                        }) {
                                            VStack(alignment: .leading, spacing: 12) {
                                                // Book Card (Postmark Style)
                                                ZStack {
                                                    // 1. Vibe Background
                                                    Color(hex: book.vibe ?? "#FFB7B2")

                                                    // 2. Postmark Frame
                                                    Image("postmark")
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .padding(20)  // Padding for the vibe color to show around? Or maybe postmark is the border.
                                                    // Based on user image: Red background (vibe), White Stamp (postmark), Photo inside.
                                                    // So Postmark should be white stamp.

                                                    // 3. Cover Image (Centered inside postmark)
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
                                                        .frame(width: 100, height: 140)  // Adjust based on postmark hole
                                                        .clipped()
                                                    } else {
                                                        Image(systemName: "photo")
                                                            .font(.largeTitle)
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                                .frame(width: 180, height: 260)  // Card size
                                                .clipped()  // No border radius requested for the container itself
                                                .shadow(
                                                    color: .black.opacity(0.1), radius: 4, x: 0,
                                                    y: 2)

                                                // Title & Partner
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(book.title ?? "Untitled")
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)

                                                    if let partner = viewModel.getPartner(for: book) {
                                                        AvatarView(
                                                            avatarUrl: partner.avatarUrl,
                                                            username: partner.username,
                                                            size: 24
                                                        )
                                                    }
                                                }

                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 20)
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
        }

    }
}
