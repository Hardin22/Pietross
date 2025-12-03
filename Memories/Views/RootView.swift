import SwiftUI
import Supabase

struct RootView: View {
    @State private var isUserLoggedIn: Bool = false
    @State private var needsOnboarding: Bool = false
    @State private var isLoading: Bool = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if isUserLoggedIn {
                if needsOnboarding {
                    OnboardingView(onFinished: {
                        withAnimation {
                            needsOnboarding = false
                        }
                    })
                    .transition(.move(edge: .trailing))
                } else {
                    SocialView()
                        .transition(.opacity)
                }
            } else {
                LoginScreenWrapper(onLoginSuccess: {
                    // Login success, now check if we need onboarding
                    checkSession()
                })
                .transition(.opacity)
            }
        }
        .onAppear {
            checkSession()
        }
    }
    
    private func checkSession() {
        // Initial check
        if let _ = SupabaseManager.shared.client.auth.currentUser {
            self.isUserLoggedIn = true
            checkProfile()
        } else {
            self.isLoading = false
        }
        
        // Listen for auth changes
        Task {
            for await _ in SupabaseManager.shared.client.auth.authStateChanges {
                let user = SupabaseManager.shared.client.auth.currentUser
                await MainActor.run {
                    withAnimation {
                        self.isUserLoggedIn = (user != nil)
                        if user != nil {
                            checkProfile()
                        } else {
                            self.needsOnboarding = false
                        }
                    }
                }
            }
        }
    }
    
    private func checkProfile() {
        Task {
            do {
                if let profile = try await SocialService.shared.getCurrentProfile() {
                    await MainActor.run {
                        // If username is empty or nil, we need onboarding
                        self.needsOnboarding = (profile.username == nil || profile.username?.isEmpty == true)
                        self.isLoading = false
                    }
                } else {
                    // Profile doesn't exist yet (shouldn't happen with trigger, but safe fallback)
                    await MainActor.run {
                        self.needsOnboarding = true
                        self.isLoading = false
                    }
                }
            } catch {
                print("Error checking profile: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// WRAPPERS

struct LoginScreenWrapper: UIViewControllerRepresentable {
    var onLoginSuccess: () -> Void
    
    func makeUIViewController(context: Context) -> LoginViewController {
        let vc = LoginViewController()
        vc.onLoginSuccessExternal = onLoginSuccess
        return vc
    }
    
    func updateUIViewController(_ uiViewController: LoginViewController, context: Context) {}
}

struct MemoryEditorWrapper: UIViewControllerRepresentable {
    let book: Book
    
    func makeUIViewController(context: Context) -> UINavigationController {
        // In future, pass book.id to EditorViewModel to load specific pages
        let vm = EditorViewModel() 
        let vc = MemoryEditorViewController(viewModel: vm)
        vc.title = book.title
        let nav = UINavigationController(rootViewController: vc)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        nav.navigationBar.standardAppearance = appearance
        return nav
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
