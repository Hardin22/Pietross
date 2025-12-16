import Combine
import Foundation
import SwiftUI

@MainActor
class BookDetailViewModel: ObservableObject {
    @Published var book: Book
    @Published var pages: [Page] = []
    @Published var isLoading = false

    @Published var alertItem: AlertItem?

    @Published var selectedPageId: UUID?
    @Published var partnerName: String?
    @Published var showAddMemorySheet = false

    // Setup State
    @Published var title: String
    @Published var selectedVibe: String?
    @Published var coverImage: UIImage?

    // Add/Edit Memory State
    @Published var newMemoryImage: UIImage?
    @Published var newMemoryText: String = ""
    @Published var newMemoryDate: Date = Date()

    // Edit Mode State
    @Published var isEditingPage = false
    @Published var editingPageId: UUID?
    private var originalPhotoUrl: String?

    private let socialService = SocialService.shared

    init(book: Book) {
        self.book = book
        self.title = book.title ?? ""
        self.selectedVibe = book.vibe
    }

    func loadPages() async {
        isLoading = true
        do {
            self.pages = try await socialService.getPages(bookId: book.id)
            if selectedPageId == nil {
                selectedPageId = pages.last?.id
            }
        } catch {
            print("Failed to load pages: \(error)")
            // If table doesn't exist yet or other error, pages will be empty which triggers setup flow
        }
        isLoading = false
    }

    func fetchPartnerProfile() async {
        do {
            if let profile = try await socialService.getPartnerProfile(
                friendshipId: book.friendshipId)
            {
                self.partnerName = profile.fullName ?? profile.username
            }
        } catch {
            print("Failed to fetch partner profile: \(error)")
        }
    }

    func saveBookDetails() async -> Bool {
        isLoading = true
        do {
            var coverData: Data?
            if let coverImage = coverImage {
                coverData = coverImage.jpegData(compressionQuality: 0.7)
            }

            try await socialService.updateBook(
                id: book.id,
                title: title,
                coverData: coverData,
                vibe: selectedVibe
            )

            // Refresh book data locally if needed, or assume success
            // Ideally we should fetch the updated book, but for now we update local state
            // Update the local book object so the UI reacts immediately
            var updatedBook = book
            updatedBook.title = title
            updatedBook.vibe = selectedVibe
            // Cover URL would be updated by fetching, but for flow logic title/vibe is enough
            self.book = updatedBook

            isLoading = false
            return true
        } catch {
            alertItem = AlertItem(
                message: "Failed to save book details: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }

    func addMemory() async -> Bool {
        guard let image = newMemoryImage, let imageData = image.jpegData(compressionQuality: 0.8)
        else {
            alertItem = AlertItem(message: "Please select an image.")
            return false
        }

        guard !newMemoryText.isEmpty else {
            alertItem = AlertItem(message: "Please enter a description.")
            return false
        }

        isLoading = true
        do {
            guard let currentUser = try await socialService.getCurrentProfile() else {
                return false
            }

            try await socialService.addPage(
                bookId: book.id,
                authorId: currentUser.id,
                photoData: imageData,
                memoryText: newMemoryText,
                photoDate: newMemoryDate
            )

            await loadPages()  // Refresh pages
            selectedPageId = pages.last?.id  // Select the new page

            // Reset form
            newMemoryImage = nil
            newMemoryText = ""
            newMemoryDate = Date()

            isLoading = false
            return true
        } catch {
            alertItem = AlertItem(message: "Failed to add memory: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }

    func deletePage(_ page: Page) async {
        isLoading = true
        do {
            try await socialService.deletePage(pageId: page.id)

            // Remove the page from local array
            pages.removeAll { $0.id == page.id }

            // Update selected page if needed
            if selectedPageId == page.id {
                selectedPageId = pages.last?.id
            }

            isLoading = false
        } catch {
            alertItem = AlertItem(message: "Failed to delete memory: \(error.localizedDescription)")
            isLoading = false
        }
    }

    // MARK: - Edit Mode

    /// Start editing an existing page
    func startEditingPage(_ page: Page) {
        isEditingPage = true
        editingPageId = page.id
        originalPhotoUrl = page.photoUrl

        // Pre-populate the form fields
        newMemoryText = page.memoryText ?? ""
        newMemoryDate = page.photoDate ?? Date()
        newMemoryImage = nil // Will show existing image from URL
    }

    /// Cancel editing and reset form
    func cancelEditing() {
        isEditingPage = false
        editingPageId = nil
        originalPhotoUrl = nil
        resetMemoryForm()
    }

    /// Reset the memory form to default values
    func resetMemoryForm() {
        newMemoryImage = nil
        newMemoryText = ""
        newMemoryDate = Date()
    }

    /// Update an existing page
    func updateMemory() async -> Bool {
        guard let pageId = editingPageId else {
            alertItem = AlertItem(message: "No page selected for editing.")
            return false
        }

        guard !newMemoryText.isEmpty else {
            alertItem = AlertItem(message: "Please enter a description.")
            return false
        }

        isLoading = true
        do {
            var imageData: Data?
            if let image = newMemoryImage {
                imageData = image.jpegData(compressionQuality: 0.8)
            }

            try await socialService.updatePage(
                pageId: pageId,
                photoData: imageData,
                memoryText: newMemoryText,
                photoDate: newMemoryDate
            )

            await loadPages() // Refresh pages

            // Reset edit state
            isEditingPage = false
            editingPageId = nil
            originalPhotoUrl = nil
            resetMemoryForm()

            isLoading = false
            return true
        } catch {
            alertItem = AlertItem(message: "Failed to update memory: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }

    /// Get the photo URL for the page being edited
    var editingPagePhotoUrl: String? {
        originalPhotoUrl
    }
}
