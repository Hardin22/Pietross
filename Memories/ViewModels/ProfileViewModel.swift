import Combine
import Foundation
import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var currentProfile: Profile?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let socialService = SocialService.shared
    private let authService = AuthService.shared
    
    func loadProfile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            currentProfile = try await socialService.getCurrentProfile()
        } catch {
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
            print("Error loading profile: \(error)")
        }
        
        isLoading = false
    }
    
    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
            print("Error signing out: \(error)")
        }
    }
}

