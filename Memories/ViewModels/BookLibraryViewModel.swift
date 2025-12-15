import Foundation
import SwiftUI
import SwiftData
import Combine

/// ViewModel for managing the book library
@MainActor
final class BookLibraryViewModel: ObservableObject {
    
    @Published var books: [LocalBook] = []
    @Published var isLoading: Bool = false
    @Published var searchText: String = ""
    
    private var modelContext: ModelContext
    
    var filteredBooks: [LocalBook] {
        if searchText.isEmpty {
            return books.sorted { $0.updatedAt > $1.updatedAt }
        }
        return books
            .filter { $0.title.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchBooks()
    }
    
    func fetchBooks() {
        isLoading = true
        
        let descriptor = FetchDescriptor<LocalBook>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        
        do {
            books = try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching books: \(error)")
            books = []
        }
        
        isLoading = false
    }
    
    func createNewBook(title: String = "Untitled Book") -> LocalBook {
        let book = LocalBook(title: title)
        
        // Create initial first page
        let firstPage = LocalPage(orderIndex: 0)
        firstPage.book = book
        book.pages.append(firstPage)
        
        modelContext.insert(book)
        
        do {
            try modelContext.save()
            fetchBooks()
        } catch {
            print("Error creating book: \(error)")
        }
        
        return book
    }
    
    func deleteBook(_ book: LocalBook) {
        modelContext.delete(book)
        
        do {
            try modelContext.save()
            fetchBooks()
        } catch {
            print("Error deleting book: \(error)")
        }
    }
    
    func duplicateBook(_ book: LocalBook) {
        let newBook = LocalBook(title: "\(book.title) (Copy)")
        newBook.coverData = book.coverData
        
        // Duplicate all pages
        for page in book.sortedPages {
            let newPage = LocalPage(orderIndex: page.orderIndex)
            newPage.elementsData = page.elementsData
            newPage.backgroundColorHex = page.backgroundColorHex
            newPage.backgroundImageData = page.backgroundImageData
            newPage.book = newBook
            newBook.pages.append(newPage)
        }
        
        modelContext.insert(newBook)
        
        do {
            try modelContext.save()
            fetchBooks()
        } catch {
            print("Error duplicating book: \(error)")
        }
    }
}

