import SwiftUI
import SwiftData

@main
struct GraphoApp: App {
    @State private var bibleStore = BibleStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(bibleStore)
                .task {
                    await bibleStore.loadInitialTranslation()
                }
        }
        .modelContainer(AppModelContainer.shared.container)
    }
}
