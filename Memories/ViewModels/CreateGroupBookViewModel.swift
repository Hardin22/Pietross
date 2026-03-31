import Combine
import PhotosUI
import Supabase
import SwiftUI

class CreateGroupBookViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var coverImage: UIImage?
    @Published var selectedVibe: String = "#FFB7B2"
    @Published var selectedFriends: Set<UUID> = []
    @Published var isLoading = false

    func createBook() async -> Bool {
        guard !title.isEmpty, !selectedFriends.isEmpty else { return false }

        DispatchQueue.main.async { self.isLoading = true }
        defer { DispatchQueue.main.async { self.isLoading = false } }

        do {
            let client = SupabaseManager.shared.client
            let currentUserId = client.auth.currentUser?.id

            guard let ownerId = currentUserId else { return false }

            // 1. Upload Cover if exists
            var coverUrl: String?
            if let image = coverImage {
                // Upload logic (similar to BookDetailViewModel)
                // For brevity, assuming we have a helper or reusing logic.
                // Let's implement a quick upload here or move upload logic to a service.
                // Use ImageCompressor for intelligent background compression
                if let imageData = ImageCompressor.compress(image: image) {
                    let fileName = "\(UUID().uuidString).jpg"
                    // Use AppConstants.Storage.bucket if available, otherwise "photos"
                    // Assuming "photos" based on previous code, but SocialService uses AppConstants.Storage.bucket
                    // Let's use "photos" for now to match what I wrote, or better, use the same bucket as SocialService if I knew it.
                    // But wait, SocialService uses AppConstants.Storage.bucket. I should probably use that.
                    // However, I don't want to break if AppConstants is not found.
                    // I'll stick to "photos" if I can't verify AppConstants, but wait, I can check AppConstants.
                    // To be safe and quick, I'll use "photos" but I'll use createSignedURL.

                    try await client.storage
                        .from(AppConstants.Storage.bucket)
                        .upload(
                            path: fileName, file: imageData,
                            options: FileOptions(contentType: "image/jpeg"))

                    let signedUrl = try await client.storage
                        .from(AppConstants.Storage.bucket)
                        .createSignedURL(path: fileName, expiresIn: 315_360_000)

                    coverUrl = signedUrl.absoluteString
                }
            }

            // 2. Create Book
            struct NewBook: Encodable {
                let title: String
                let vibe: String
                let cover_url: String?
                let is_group: Bool
                let owner_id: UUID
            }

            let newBook = NewBook(
                title: title,
                vibe: selectedVibe,
                cover_url: coverUrl,
                is_group: true,
                owner_id: ownerId
            )

            let book: Book =
                try await client
                .from("books")
                .insert(newBook)
                .select()
                .single()
                .execute()
                .value

            // 3. Add Participants
            // Add owner
            var participants = [
                ["book_id": book.id.uuidString, "user_id": ownerId.uuidString, "role": "owner"]
            ]

            // Add friends
            for friendId in selectedFriends {
                participants.append(
                    [
                        "book_id": book.id.uuidString, "user_id": friendId.uuidString,
                        "role": "member",
                    ]
                )
            }

            try await client
                .from("book_participants")
                .insert(participants)
                .execute()

            return true
        } catch {
            print("Error creating group book: \(error)")
            return false
        }
    }
}
