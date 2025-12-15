import SwiftUI
import SwiftData
import PencilKit

/// Main library view showing all user's books
struct BookLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: BookLibraryViewModel
    @State private var selectedBook: LocalBook?
    @State private var showingNewBookDialog = false
    @State private var newBookTitle = ""
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: BookLibraryViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.filteredBooks.isEmpty {
                    emptyStateView
                } else {
                    bookGridView
                }
            }
            .navigationTitle("My Books")
            .searchable(text: $viewModel.searchText, prompt: "Search books")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNewBookDialog = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Book", isPresented: $showingNewBookDialog) {
                TextField("Book Title", text: $newBookTitle)
                Button("Cancel", role: .cancel) {
                    newBookTitle = ""
                }
                Button("Create") {
                    let book = viewModel.createNewBook(title: newBookTitle.isEmpty ? "Untitled Book" : newBookTitle)
                    newBookTitle = ""
                    selectedBook = book
                }
            } message: {
                Text("Enter a title for your new book")
            }
            .fullScreenCover(item: $selectedBook) { book in
                BookEditorScreen(book: book, modelContext: modelContext)
            }
            .onAppear {
                viewModel.fetchBooks()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Books Yet")
                .font(.title2.weight(.medium))
            
            Text("Create your first book to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                showingNewBookDialog = true
            }) {
                Label("Create Book", systemImage: "plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
    }
    
    private var bookGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(viewModel.filteredBooks) { book in
                    BookCoverCard(book: book)
                        .onTapGesture {
                            selectedBook = book
                        }
                        .contextMenu {
                            Button(action: {
                                selectedBook = book
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button(action: {
                                viewModel.duplicateBook(book)
                            }) {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive, action: {
                                viewModel.deleteBook(book)
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
    }
}

/// Card view showing a book's cover in the library grid
struct BookCoverCard: View {
    let book: LocalBook

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover preview
            coverPreview
                .frame(height: 200)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            // Book title
            Text(book.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .foregroundColor(.primary)
        }
    }
    
    @ViewBuilder
    private var coverPreview: some View {
        let coverElements = book.coverElements
        
        if coverElements.isEmpty {
            // Default cover appearance
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(book.title)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
        } else {
            // Render cover elements as preview
            CoverPreviewRenderer(elements: coverElements)
        }
    }
}

/// Renders cover elements at a small scale for preview
struct CoverPreviewRenderer: View {
    let elements: [PageElement]

    var body: some View {
        GeometryReader { geometry in
            // Calculate scale to fit virtual canvas into preview area
            let scaleX = geometry.size.width / CanvasConstants.virtualSize.width
            let scaleY = geometry.size.height / CanvasConstants.virtualSize.height
            let scale = min(scaleX, scaleY)

            // Center the scaled canvas in the available space
            let scaledWidth = CanvasConstants.virtualSize.width * scale
            let scaledHeight = CanvasConstants.virtualSize.height * scale
            let offsetX = (geometry.size.width - scaledWidth) / 2
            let offsetY = (geometry.size.height - scaledHeight) / 2

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: scaledWidth, height: scaledHeight)

                ForEach(elements.sorted(by: { $0.zIndex < $1.zIndex })) { element in
                    elementPreview(element, scale: scale)
                }
            }
            .frame(width: scaledWidth, height: scaledHeight)
            .offset(x: offsetX, y: offsetY)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func elementPreview(_ element: PageElement, scale: CGFloat) -> some View {
        switch element {
        case .text(let textElement):
            Text(textElement.content)
                .font(.system(size: max(8, textElement.fontSize * scale))) // Minimum font size for readability
                .fontWeight(textElement.isBold ? .bold : .regular)
                .foregroundColor(Color(hex: textElement.textColor))
                .frame(width: textElement.size.width * scale, height: textElement.size.height * scale)
                .rotationEffect(Angle(radians: textElement.rotation))
                .position(
                    x: textElement.position.x * scale,
                    y: textElement.position.y * scale
                )

        case .image(let imageElement):
            if let uiImage = UIImage(data: imageElement.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: imageElement.size.width * scale, height: imageElement.size.height * scale)
                    .clipped()
                    .rotationEffect(Angle(radians: imageElement.rotation))
                    .position(
                        x: imageElement.position.x * scale,
                        y: imageElement.position.y * scale
                    )
            }

        case .drawing(let drawingElement):
            DrawingElementView(element: drawingElement)
                .frame(width: drawingElement.size.width * scale, height: drawingElement.size.height * scale)
                .rotationEffect(Angle(radians: drawingElement.rotation))
                .position(
                    x: drawingElement.position.x * scale,
                    y: drawingElement.position.y * scale
                )
        }
    }
}

