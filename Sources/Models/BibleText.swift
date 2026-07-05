import Foundation

/// A parsed Bible translation held in memory after load. Immutable.
/// Books are exposed in canonical order via `orderedBooks`.
struct BibleTranslation: Hashable {
    /// Stable slug used to scope annotations (e.g. "web", "niv").
    let identifier: String
    /// Human-readable name shown in UI (e.g. "World English Bible").
    let displayName: String
    /// Books keyed by `Book` abbreviation. May be sparse — translations that
    /// omit a book (e.g. NT-only) simply have no entry.
    let books: [Book: BibleBook]

    /// Books in canonical Protestant order, filtered to those present.
    var orderedBooks: [BibleBook] {
        Book.allCases.compactMap { books[$0] }
    }

    func book(_ book: Book) -> BibleBook? {
        books[book]
    }

    func chapter(book: Book, number: Int) -> BibleChapter? {
        books[book]?.chapter(number)
    }
}

struct BibleBook: Hashable {
    let book: Book
    /// Chapters keyed by chapter number. Sparse access — most translations are
    /// complete, but we don't assume.
    let chapters: [Int: BibleChapter]

    var orderedChapters: [BibleChapter] {
        chapters.values.sorted { $0.number < $1.number }
    }

    var chapterCount: Int { chapters.count }

    func chapter(_ number: Int) -> BibleChapter? {
        chapters[number]
    }
}

struct BibleChapter: Hashable {
    let book: Book
    let number: Int
    /// Verses in ascending order — the loader normalizes ordering on parse so
    /// downstream code doesn't have to re-sort on every render.
    let verses: [BibleVerse]
    /// Psalm-style superscription detected and split off the original verse 1.
    /// `nil` for non-Psalms and Psalms without a detectable inscription.
    let superscription: String?

    func verse(_ number: Int) -> BibleVerse? {
        verses.first { $0.number == number }
    }
}

struct BibleVerse: Hashable, Identifiable {
    let number: Int
    let text: String

    var id: Int { number }
}
