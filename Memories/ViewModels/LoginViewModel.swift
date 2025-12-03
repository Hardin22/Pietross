import Foundation
import Combine
import AuthenticationServices

class LoginViewModel: NSObject, ObservableObject {
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Callback per notificare il Controller che il login è riuscito
    var onLoginSuccess: (() -> Void)?
    
    private var currentNonce: String?
    
    func configureRequest(request: ASAuthorizationAppleIDRequest) {
        let nonce = AppleSignInUtils.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleSignInUtils.sha256(nonce)
    }
    
    func handleAuthorization(_ authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let identityTokenData = appleIDCredential.identityToken,
              let identityTokenString = String(data: identityTokenData, encoding: .utf8)
        else {
            self.errorMessage = "Errore nel recupero delle credenziali Apple."
            return
        }
        
        Task {
            await performSupabaseLogin(idToken: identityTokenString, nonce: nonce, fullName: appleIDCredential.fullName)
        }
    }
    
    @MainActor
    private func performSupabaseLogin(idToken: String, nonce: String, fullName: PersonNameComponents?) async {
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            try await AuthService.shared.signInWithApple(idToken: idToken, nonce: nonce, fullName: fullName)
            self.isLoading = false
            self.onLoginSuccess?()
        } catch {
            self.isLoading = false
            self.errorMessage = "Login fallito: \(error.localizedDescription)"
            print("Supabase Error: \(error)")
        }
    }
    
    func handleError(_ error: Error) {
        self.errorMessage = error.localizedDescription
    }
}
