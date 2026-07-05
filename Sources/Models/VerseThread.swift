import Foundation
import SwiftData

/// A fully-qualified verse address — book + chapter + verse. Used as the two
/// ends of a `VerseThread` and anywhere the UI needs to talk about "a verse"
/// independent of any loaded chapter.
struct VerseRef: Hashable {
    let book: Book
    let chapter: Int
    let verse: Int

    /// "John 3:14" — the display form used in thread chips and popovers.
    var display: String {
        "\(book.displayName) \(chapter):\(verse)"
    }

    var chapterRoute: ChapterRoute {
        ChapterRoute(book: book, chapter: chapter)
    }

    /// Route that also scrolls the reader to this exact verse.
    var focusedRoute: ChapterRoute {
        ChapterRoute(book: book, chapter: chapter, focusVerse: verse)
    }
}

/// A thread: a directed verse→verse connection the user drew, carrying the
/// study mode it was born in and an optional "why these connect" line.
///
/// Threads deliberately live *outside* `AnnotationLayer` — a layer is scoped
/// to one chapter, but a thread's whole point is to span chapters and books.
/// The mode is stored directly instead. Like layers, threads are scoped to a
/// translation slug so imported translations keep independent webs.
///
/// Direction matters for display ("threaded to" vs "threaded from") but both
/// ends always see the connection — the backlink is free (design turn 8b).
@Model
final class VerseThread {
    @Attribute(.unique) var id: UUID
    var translation: String
    var fromBook: String
    var fromChapter: Int
    var fromVerse: Int
    var toBook: String
    var toChapter: Int
    var toVerse: Int
    /// `LayerKind` raw value — the mode active when the thread was made.
    var modeRaw: String
    /// The user's "why these connect for you". Empty until they add one.
    var why: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        translation: String,
        from: VerseRef,
        to: VerseRef,
        mode: LayerKind,
        why: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.translation = translation
        self.fromBook = from.book.rawValue
        self.fromChapter = from.chapter
        self.fromVerse = from.verse
        self.toBook = to.book.rawValue
        self.toChapter = to.chapter
        self.toVerse = to.verse
        self.modeRaw = mode.rawValue
        self.why = why
        self.createdAt = createdAt
    }

    var mode: LayerKind {
        get { LayerKind(rawValue: modeRaw) ?? .exegetical }
        set { modeRaw = newValue.rawValue }
    }

    /// `nil` only if the stored book abbreviation is unrecognized (corrupt or
    /// future data) — callers skip such threads rather than crash.
    var fromRef: VerseRef? {
        Book(rawValue: fromBook).map { VerseRef(book: $0, chapter: fromChapter, verse: fromVerse) }
    }

    var toRef: VerseRef? {
        Book(rawValue: toBook).map { VerseRef(book: $0, chapter: toChapter, verse: toVerse) }
    }

    /// The end that isn't `ref`, for popovers listing "everything this verse
    /// connects to" regardless of direction.
    func otherEnd(of ref: VerseRef) -> VerseRef? {
        if fromRef == ref { return toRef }
        if toRef == ref { return fromRef }
        return nil
    }
}
