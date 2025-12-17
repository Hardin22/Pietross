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

    // Add Memory State
    @Published var newMemoryImage: UIImage?
    @Published var newMemoryText: String = ""
    @Published var newMemorySticker: UIImage?
    @Published var newMemoryDate: Date = Date()

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
        guard let friendshipId = book.friendshipId else { return }
        do {
            if let profile = try await socialService.getPartnerProfile(
                friendshipId: friendshipId)
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
                // Use ImageCompressor for intelligent background compression
                coverData = ImageCompressor.compress(image: coverImage)
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
        guard let image = newMemoryImage,
            let imageData = ImageCompressor.compress(image: image)
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

            var stickerData: Data?
            if let sticker = newMemorySticker {
                stickerData = sticker.pngData()  // Use PNG for transparency
            }

            try await socialService.addPage(
                bookId: book.id,
                authorId: currentUser.id,
                photoData: imageData,
                memoryText: newMemoryText,
                stickerData: stickerData,
                photoDate: newMemoryDate
            )

            await loadPages()  // Refresh pages
            selectedPageId = pages.last?.id  // Select the new page

            // Reset form
            newMemoryImage = nil
            newMemoryText = ""
            newMemorySticker = nil
            newMemoryDate = Date()

            isLoading = false
            return true
        } catch {
            alertItem = AlertItem(message: "Failed to add memory: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }
}
