import SwiftUI
import SwiftData

/// Home — wordmark + active translation top, Continue Reading card, then a
/// flat columnar list of books split by Old / New Testament. No tile cards
/// and no library-quick-link stack: those live in Settings now (and will
/// land on a dedicated Library surface post-MVP). Matches the Figma's
/// quiet, typographic landing.
struct HomeView: View {
    @Environment(BibleStore.self) private var bibleStore
    @AppStorage(PreferenceKey.backgroundPalette) private var paletteRaw: String = BackgroundPalette.default.rawValue

    @State private var showImporter = false
    @State private var importError: String?
    @State private var lastRead: LastReadingPosition? = LastReadingPosition.read()

    private var palette: BackgroundPalette { .current(rawValue: paletteRaw) }

    /// Adaptive column count — we let SwiftUI pick how many columns fit at
    /// ~140pt minimum each. Portrait iPad lands at ~5, landscape at ~7,
    /// matching the Figma.
    private let columns = [GridItem(.adaptive(minimum: 130, maximum: 180), spacing: 16, alignment: .leading)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                    .padding(.top, 24)
                    .padding(.horizontal, 32)

                Divider()
                    .padding(.top, 16)

                if let lastRead {
                    continueReadingCard(lastRead)
                        .padding(.top, 24)
                        .padding(.horizontal, 32)
                }

                bookSection(title: "Old Testament", books: Book.oldTestament)
                    .padding(.top, lastRead == nil ? 32 : 24)

                bookSection(title: "New Testament", books: Book.newTestament)
                    .padding(.top, 24)
                    .padding(.bottom, 64)
            }
        }
        .background(palette.color.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
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
            lastRead = LastReadingPosition.read()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            Text("GRAPHO")
                .font(AppFont.wordmark)
                .tracking(2)
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            // Active translation as a quiet caps label — same treatment as
            // the active-layer indicator in the reader for visual rhyme.
            Text((bibleStore.translation?.identifier ?? "WEB").uppercased())
                .font(AppFont.wordmark)
                .tracking(2)
                .foregroundStyle(AppColor.textSecondary)
                .accessibilityLabel("Active translation")
            // Settings — kept here as a small icon since the Figma omits it
            // but we still need an entry point to preferences.
            NavigationLink(value: LibraryRoute.settings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .padding(.leading, 12)
        }
    }

    // MARK: - Continue Reading

    private func continueReadingCard(_ position: LastReadingPosition) -> some View {
        NavigationLink(value: ChapterRoute(book: position.book, chapter: position.chapter)) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppColor.background)
                        .overlay(Circle().strokeBorder(AppColor.border, lineWidth: 0.75))
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColor.textSecondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("CONTINUE READING")
                        .font(AppFont.microCaps)
                        .tracking(1.5)
                        .foregroundStyle(AppColor.textFaint)
                    Text("\(position.book.displayName) \(position.chapter)")
                        .font(AppFont.bookListName)
                        .foregroundStyle(AppColor.textPrimary)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Book sections

    private func bookSection(title: String, books: [Book]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(title.uppercased())
                    .font(AppFont.listSection)
                    .tracking(AppSpacing.smallCapsTracking)
                    .foregroundStyle(AppColor.textFaint)
                Rectangle()
                    .fill(AppColor.border)
                    .frame(height: 0.5)
                    .frame(maxWidth: .infinity)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(books) { book in
                    NavigationLink(value: book) {
                        Text(book.displayName)
                            .font(AppFont.bookListName)
                            .foregroundStyle(isAvailable(book) ? AppColor.textPrimary : AppColor.textFaint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isAvailable(book))
                }
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Helpers

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
