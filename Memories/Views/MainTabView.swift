import SwiftData
import SwiftUI

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        SocialView()
    }
}

struct BooksView: View {
    let modelContext: ModelContext

    var body: some View {
        BookLibraryView(modelContext: modelContext)
    }
}
