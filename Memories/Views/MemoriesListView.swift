import SwiftUI

struct MemoriesListView: View {
    @ObservedObject var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editorConfig: EditorConfig?
    @State private var searchText = ""

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Description
                        Text(
                            "A private space for the moments that matter most. Create shared postcards between you and one close friend, capturing memories, details, and experiences that tell a story only the two of you share."
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top)

                        // Search Bar
                        SearchBar(
                            text: $searchText,
                            onClear: {
                                searchText = ""
                            }
                        )
                        .padding(.horizontal)

                        // Filtered Books
                        let filteredBooks = viewModel.books.filter { book in
                            // 1. Must be individual book
                            guard book.isGroup != true else { return false }

                            // 2. Search filter
                            if searchText.isEmpty { return true }

                            let titleMatch =
                                book.title?.localizedCaseInsensitiveContains(searchText) ?? false
                            let partner = viewModel.getPartner(for: book)
                            let partnerMatch =
                                partner?.username?.localizedCaseInsensitiveContains(searchText)
                                ?? false

                            return titleMatch || partnerMatch
                        }

                        // Books Grid
                        if filteredBooks.isEmpty {
                            EmptyStateView(
                                iconName: "book.closed",
                                title: "No Memories Found",
                                message: searchText.isEmpty
                                    ? "Start a book with a friend to see it here."
                                    : "Try a different search term."
                            )
                            .padding(.top, 50)
                        } else {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(filteredBooks, id: \Book.id) { book in
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
                                                    .padding(20)

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
                                            .shadow(
                                                color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

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
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Memories")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                    }
                }
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
        }
    }
}
