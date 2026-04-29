import SwiftUI
import SwiftData

@main
struct GraphoApp: App {
    @State private var bibleStore = BibleStore()
    @State private var layerStore = LayerStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(bibleStore)
                .environment(layerStore)
                .task {
                    await bibleStore.loadInitialTranslation()
                }
        }
        .modelContainer(AppModelContainer.shared.container)
    }
}
