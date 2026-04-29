import SwiftUI
import SwiftData

/// The single landing screen. Combines the design doc's "Home" and
/// "BookSelector" — for personal use one fewer tap is a real win, and the
/// book grid is the natural primary surface anyway.
///
/// Layout (top to bottom):
///   1. Translation label + Settings button
///   2. Continue Reading card (if a last-read position exists)
///   3. Library quick-links (Highlights / Notes / History)
///   4. Book grid, segmented Old / New Testament
///   5. Import-translation button at the bottom
struct HomeView: View {
    @Environment(BibleStore.self) private var bibleStore
    @Environment(\.modelContext) private var modelContext

    @State private var showImporter = false
    @State private var importError: String?
    @State private var lastRead: LastReadingPosition? = LastReadingPosition.read()

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                if let lastRead {
                    continueReadingCard(lastRead)
                }

                libraryQuickLinks

                bookSection(title: "Old Testament", books: Book.oldTestament)
                bookSection(title: "New Testament", books: Book.newTestament)

                importButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("Grapho")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: LibraryRoute.settings) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Import failed", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .onAppear {
            // Position can change while we're elsewhere in the stack — refresh
            // each time Home returns.
            lastRead = LastReadingPosition.read()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("GRAPHO")
                    .font(AppFont.stickyTitle)
                    .foregroundStyle(AppColor.textSecondary)
                Text(bibleStore.translation?.displayName ?? "Loading…")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textFaint)
            }
            Spacer()
        }
    }

    private func continueReadingCard(_ position: LastReadingPosition) -> some View {
        NavigationLink(value: ChapterRoute(book: position.book, chapter: position.chapter)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue Reading")
                        .font(.caption)
                        .foregroundStyle(AppColor.textFaint)
                    Text("\(position.book.displayName) \(position.chapter)")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(AppColor.textPrimary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColor.textFaint)
            }
            .padding(16)
            .background(AppColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(AppColor.border, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var libraryQuickLinks: some View {
        HStack(spacing: 12) {
            quickLink(title: "Highlights", icon: "highlighter", route: .highlights)
            quickLink(title: "Notes", icon: "square.and.pencil", route: .notes)
            quickLink(title: "History", icon: "clock", route: .history)
        }
    }

    private func quickLink(title: String, icon: String, route: LibraryRoute) -> some View {
        NavigationLink(value: route) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(AppColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(AppColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(AppColor.border, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func bookSection(title: String, books: [Book]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(AppFont.sectionHeader)
                .foregroundStyle(AppColor.textSecondary)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(books) { book in
                    NavigationLink(value: book) {
                        BookTile(book: book, available: isAvailable(book))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isAvailable(book))
                }
            }
        }
    }

    private var importButton: some View {
        Button {
            showImporter = true
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.down")
                Text("Import Translation (.json)")
            }
            .font(.callout)
            .foregroundStyle(AppColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(AppColor.border, lineWidth: 0.5)
            )
        }
        .padding(.top, 8)
    }

    private func isAvailable(_ book: Book) -> Bool {
        bibleStore.translation?.book(book) != nil
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do {
                    let importer = TranslationImporter()
                    let imported = try importer.importTranslation(from: url)
                    await bibleStore.activate(imported: imported)
                } catch {
                    importError = error.localizedDescription
                }
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}

private struct BookTile: View {
    let book: Book
    let available: Bool

    var body: some View {
        HStack {
            Text(book.displayName)
                .font(.callout)
                .foregroundStyle(available ? AppColor.textPrimary : AppColor.textFaint)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(AppColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(AppColor.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(available ? 1 : 0.55)
    }
}
