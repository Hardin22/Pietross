import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            SocialView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            LettersView()
                .tabItem {
                    Label("Letters", systemImage: "envelope.fill")
                }
            
            BooksView()
                .tabItem {
                    Label("Books", systemImage: "book.closed.fill")
                }
            
            ProfileSettingsView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
    }
}

struct LettersView: View {
    var body: some View {
        NavigationView {
            Text("Letters will be available here.")
                .font(.body)
                .foregroundColor(.secondary)
                .navigationTitle("Letters")
        }
    }
}

struct BooksView: View {
    var body: some View {
        NavigationView {
            Text("Books will be available here.")
                .font(.body)
                .foregroundColor(.secondary)
                .navigationTitle("Books")
        }
    }
}

struct ProfileSettingsView: View {
    var body: some View {
        NavigationView {
            Text("Profile and settings will be available here.")
                .font(.body)
                .foregroundColor(.secondary)
                .navigationTitle("Profile")
        }
    }
}

