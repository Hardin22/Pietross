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
        _ = try? await client.auth.signOut()
    }
    
    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws {
        try await client.auth.signInWithIdToken(credentials: .init(
            provider: .apple,
            idToken: idToken,
            nonce: nonce
        ))
        
        // If we have a name, try to update the profile immediately
        // Note: The trigger creates the profile with nulls. We update it here.
        if let fullName = fullName {
            let formatter = PersonNameComponentsFormatter()
            let nameString = formatter.string(from: fullName)
            
            if let userId = client.auth.currentUser?.id {
                // We use SocialService to update the profile because it has the logic
                // But SocialService is higher level. We can do a direct update here or rely on the user doing it in Onboarding.
                // The user request said "inseriamole nel database alla creazione".
                // So let's try to update the profile if it exists.
                
                let updates: [String: String] = ["full_name": nameString]
                try? await client.from("profiles").update(updates).eq("id", value: userId).execute()
            }
        }
    }
}
