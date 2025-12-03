import Foundation
import SwiftUI
import Combine
import Supabase
import UIKit

class OnboardingViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var fullName: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isUsernameValid: Bool = false
    @Published var isCheckingUsername: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let socialService = SocialService.shared
    
    init() {
        // Debounce username check
        $username
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] username in
                guard let self = self, !username.isEmpty, username.count >= 3 else {
                    self?.isUsernameValid = false
                    return
                }
                Task {
                    await self.checkUsername(username)
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    func checkUsername(_ username: String) async {
        self.isCheckingUsername = true
        do {
            let available = try await socialService.isUsernameAvailable(username)
            self.isUsernameValid = available
            self.isCheckingUsername = false
        } catch {
            self.isCheckingUsername = false
            // Ignore error for availability check, just assume invalid or retry
            print("Error checking username: \(error)")
        }
    }
    
    @Published var selectedImage: UIImage?
    @Published var isUploadingImage: Bool = false
    
    // ... (existing init)
    
    @MainActor
    func saveProfile(onSuccess: @escaping () -> Void) async {
        guard isUsernameValid else {
            self.errorMessage = "Please choose a valid and unique username."
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else {
                throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
            }
            
            var avatarUrl: String?
            
            // Upload Avatar if selected
            if let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.7) {
                self.isUploadingImage = true
                avatarUrl = try await socialService.uploadAvatar(userId: userId, data: imageData)
                self.isUploadingImage = false
            }
            
            print("Saving profile: username=\(username), fullName=\(fullName), avatarUrl=\(avatarUrl ?? "nil")")
            
            try await socialService.updateProfile(
                id: userId,
                username: username,
                fullName: fullName.isEmpty ? nil : fullName,
                avatarUrl: avatarUrl
            )
            
            self.isLoading = false
            onSuccess()
        } catch {
            self.isLoading = false
            self.isUploadingImage = false
            self.errorMessage = "Failed to save profile: \(error.localizedDescription)"
            print("Error saving profile: \(error)")
        }
    }
}
