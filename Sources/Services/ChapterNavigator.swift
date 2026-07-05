import Foundation

/// Pure logic for "what's the next/previous chapter?" given a translation's
/// available books. Lifted out of any view so it's trivially unit-testable.
struct ChapterNavigator {
    let translation: BibleTranslation

    func next(after route: ChapterRoute) -> ChapterRoute? {
        guard let bibleBook = translation.book(route.book) else { return nil }
        let chapters = bibleBook.orderedChapters.map { $0.number }
        if let idx = chapters.firstIndex(of: route.chapter), idx + 1 < chapters.count {
            return ChapterRoute(book: route.book, chapter: chapters[idx + 1])
        }
        // Roll over to the first chapter of the next available book.
        guard let nextBook = nextAvailableBook(after: route.book),
              let firstChapter = translation.book(nextBook)?.orderedChapters.first?.number
        else { return nil }
        return ChapterRoute(book: nextBook, chapter: firstChapter)
    }

    func previous(before route: ChapterRoute) -> ChapterRoute? {
        guard let bibleBook = translation.book(route.book) else { return nil }
        let chapters = bibleBook.orderedChapters.map { $0.number }
        if let idx = chapters.firstIndex(of: route.chapter), idx > 0 {
            return ChapterRoute(book: route.book, chapter: chapters[idx - 1])
        }
        // Roll back to the last chapter of the previous available book.
        guard let prevBook = previousAvailableBook(before: route.book),
              let lastChapter = translation.book(prevBook)?.orderedChapters.last?.number
        else { return nil }
        return ChapterRoute(book: prevBook, chapter: lastChapter)
    }

    private func nextAvailableBook(after book: Book) -> Book? {
        let canonical = Book.allCases
        guard let idx = canonical.firstIndex(of: book) else { return nil }
        return canonical[(idx + 1)...].first { translation.book($0) != nil }
    }

    private func previousAvailableBook(before book: Book) -> Book? {
        let canonical = Book.allCases
        guard let idx = canonical.firstIndex(of: book) else { return nil }
        return canonical[..<idx].reversed().first { translation.book($0) != nil }
    }
}
