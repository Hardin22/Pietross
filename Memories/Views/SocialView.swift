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

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        Text("My Memories")
                            .font(.largeTitle)
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
                                HStack(spacing: 16) {
                                    ForEach(viewModel.books, id: \Book.id) { (book: Book) in
                                        Button(action: {
                                            editorConfig = .book(book)
                                        }) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                // Book Cover
                                                ZStack {
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
                                                                ZStack {
                                                                    Color.gray.opacity(0.1)
                                                                    ProgressView()
                                                                }
                                                            }
                                                        )
                                                        .aspectRatio(0.75, contentMode: .fill)
                                                        .frame(width: 120, height: 160)
                                                        .clipped()
                                                    } else {
                                                        ZStack {
                                                            Color.blue.opacity(0.1)
                                                            Image(systemName: "book.closed.fill")
                                                                .font(.largeTitle)
                                                                .foregroundColor(.blue)
                                                        }
                                                        .frame(width: 120, height: 160)
                                                    }
                                                }
                                                .cornerRadius(12)
                                                .shadow(
                                                    color: .black.opacity(0.1), radius: 4, x: 0,
                                                    y: 2)

                                                // Book Title
                                                Text(book.title ?? "Untitled Book")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                    .frame(width: 120, alignment: .leading)
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
        }
    }
}
