import SwiftUI
import Supabase

struct RootView: View {
    @State private var isUserLoggedIn: Bool = false
    @State private var isLoading: Bool = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if isUserLoggedIn {
                MemoryEditorWrapper()
                    .ignoresSafeArea(.all)
                    .transition(.opacity)
            } else {
                LoginScreenWrapper(onLoginSuccess: {
                    withAnimation {
                        isUserLoggedIn = true
                    }
                })
                .transition(.opacity)
            }
        }
        .onAppear {
            checkSession()
        }
    }
    
    private func checkSession() {
        Task {
            let user = SupabaseManager.shared.client.auth.currentUser
            await MainActor.run {
                self.isUserLoggedIn = (user != nil)
                self.isLoading = false
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
    func makeUIViewController(context: Context) -> UINavigationController {
        let vm = EditorViewModel()
        let vc = MemoryEditorViewController(viewModel: vm)
        let nav = UINavigationController(rootViewController: vc)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        nav.navigationBar.standardAppearance = appearance
        return nav
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
