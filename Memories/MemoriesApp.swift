import SwiftUI
import SwiftData

@main
struct MemoriesApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LocalBook.self,
            LocalPage.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
