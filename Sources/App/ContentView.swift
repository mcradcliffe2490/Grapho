import SwiftUI

/// Root view. Owns the navigation path so all destinations route through a
/// single `NavigationStack` with one `navigationDestination(for:)` per route
/// type. Top-level loading / failure states for the Bible JSON are handled
/// here so the rest of the view tree can assume a translation exists.
struct ContentView: View {
    @Environment(BibleStore.self) private var bibleStore
    @State private var path = NavigationPath()

    var body: some View {
        Group {
            switch bibleStore.loadingState {
            case .idle, .loading:
                LoadingScreen()
            case .failed(let message):
                FailureScreen(message: message) {
                    Task { await bibleStore.activateBundled() }
                }
            case .loaded:
                NavigationStack(path: $path) {
                    HomeView()
                        .navigationDestination(for: Book.self) { book in
                            ChapterSelectorView(book: book)
                        }
                        .navigationDestination(for: ChapterRoute.self) { route in
                            ChapterReaderView(route: route) { next in
                                // Replace the top of the stack rather than
                                // appending — sequential reading shouldn't
                                // build up a back-stack of every chapter.
                                if !path.isEmpty { path.removeLast() }
                                path.append(next)
                            }
                        }
                        .navigationDestination(for: LibraryRoute.self) { route in
                            switch route {
                            case .highlights: HighlightsView()
                            case .notes: NotesListView()
                            case .history: HistoryView()
                            case .settings: SettingsView()
                            }
                        }
                }
            }
        }
    }
}

private struct LoadingScreen: View {
    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading Scripture…")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textFaint)
            }
        }
    }
}

private struct FailureScreen: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Couldn't load the Bible text.")
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppColor.textFaint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
                Button("Retry with bundled translation", action: retry)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
        }
    }
}
