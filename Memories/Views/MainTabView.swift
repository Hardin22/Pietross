import SwiftData
import SwiftUI

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            SocialView()
                .tabItem {
                    Label("Memories", systemImage: "book.closed.fill")
                }

            FriendsView()
                .tabItem {
                    Label("Friends", systemImage: "figure.2.right.holdinghands")
                }
            IncomingView()
                .tabItem {
                    Label("Incoming", systemImage: "bell.fill")
                }
            SendView()
                .tabItem {
                    Label("Send", systemImage: "envelope.front.fill")
                }
            //BooksView(modelContext: modelContext)
            //  .tabItem {
            //    Label("Books", systemImage: "book.closed.fill")
            //}
        }
    }
}

struct BooksView: View {
    let modelContext: ModelContext

    var body: some View {
        BookLibraryView(modelContext: modelContext)
    }
}
