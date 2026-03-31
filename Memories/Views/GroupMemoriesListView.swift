import SwiftUI

struct GroupMemoriesListView: View {
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
                            "A shared space for your group's best moments. Create collaborative books where everyone can contribute photos and memories."
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
                            // 1. Must be group book
                            guard book.isGroup == true else { return false }

                            // 2. Search filter
                            if searchText.isEmpty { return true }

                            let titleMatch =
                                book.title?.localizedCaseInsensitiveContains(searchText) ?? false
                            // Optional: Search by participant names if needed, but title is primary for groups
                            return titleMatch
                        }

                        // Books Grid
                        if filteredBooks.isEmpty {
                            EmptyStateView(
                                iconName: "person.3",
                                title: "No Group Memories Found",
                                message: searchText.isEmpty
                                    ? "Create a group book to start sharing memories."
                                    : "Try a different search term."
                            )
                            .padding(.top, 50)
                        } else {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(filteredBooks, id: \Book.id) { book in
                                    Button(action: {
                                        editorConfig = .book(book)
                                    }) {
                                        BookCardView(
                                            book: book,
                                            partner: nil,
                                            participants: viewModel.groupBookParticipants[book.id]
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Group Memories")
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
