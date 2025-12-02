import Foundation
import AuthenticationServices
import Supabase

class AuthService {
    static let shared = AuthService()
    
    private let client = SupabaseManager.shared.client
    
    var currentUser: User? {
        return client.auth.currentUser
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    func signInWithApple(idToken: String, nonce: String) async throws {
        try await client.auth.signInWithIdToken(credentials: .init(
            provider: .apple,
            idToken: idToken,
            nonce: nonce
        ))
    }
}
