import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext

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

            BooksView(modelContext: modelContext)
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
    let modelContext: ModelContext

    var body: some View {
        BookLibraryView(modelContext: modelContext)
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

