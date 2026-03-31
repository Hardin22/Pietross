import Combine
import Foundation
import SwiftUI

@MainActor
class EditProfileViewModel: ObservableObject {
    @Published var username: String
    @Published var fullName: String
    @Published var selectedImage: UIImage?
    @Published var isLoading: Bool = false
    @Published var isUploadingImage: Bool = false
    @Published var errorMessage: String?
    @Published var isUsernameValid: Bool = true
    @Published var isCheckingUsername: Bool = false

    private let originalUsername: String
    private let currentProfile: Profile
    private var cancellables = Set<AnyCancellable>()
    private let socialService = SocialService.shared

    init(profile: Profile) {
        self.currentProfile = profile
        self.username = profile.username ?? ""
        self.originalUsername = profile.username ?? ""
        self.fullName = profile.fullName ?? ""

        // Setup username validation with debounce
        $username
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] username in
                guard let self = self else { return }

                // If username hasn't changed, it's valid
                if username == self.originalUsername {
                    self.isUsernameValid = true
                    self.isCheckingUsername = false
                    return
                }

                // Validate length
                guard !username.isEmpty, username.count >= 3 else {
                    self.isUsernameValid = false
                    self.isCheckingUsername = false
                    return
                }

                // Check availability
                Task {
                    await self.checkUsername(username)
                }
            }
            .store(in: &cancellables)
    }

    private func checkUsername(_ username: String) async {
        // Skip check if it's the original username
        if username == originalUsername {
            isUsernameValid = true
            isCheckingUsername = false
            return
        }

        isCheckingUsername = true

        do {
            let isAvailable = try await socialService.isUsernameAvailable(username)
            isUsernameValid = isAvailable
        } catch {
            print("Error checking username: \(error)")
            isUsernameValid = false
        }

        isCheckingUsername = false
    }

    func saveProfile(onSuccess: @escaping () -> Void) async {
        guard isUsernameValid else {
            errorMessage = "Please choose a valid username"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            var avatarUrl: String? = currentProfile.avatarUrl

            // Upload new avatar if selected
            if let image = selectedImage, let imageData = ImageCompressor.compress(image: image) {
                isUploadingImage = true
                avatarUrl = try await socialService.uploadAvatar(
                    userId: currentProfile.id, data: imageData)
                isUploadingImage = false
            }

            // Update profile
            try await socialService.updateProfile(
                id: currentProfile.id,
                username: username,
                fullName: fullName.isEmpty ? nil : fullName,
                avatarUrl: avatarUrl
            )

            isLoading = false
            onSuccess()
        } catch {
            isLoading = false
            isUploadingImage = false
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
            print("Error updating profile: \(error)")
        }
    }
}
