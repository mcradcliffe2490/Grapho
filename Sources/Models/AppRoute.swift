import Foundation

/// A specific chapter of a specific book — the destination type for a tap on
/// the chapter grid. Hashable so it can drive `NavigationStack`.
struct ChapterRoute: Hashable {
    let book: Book
    let chapter: Int
    /// When set, the reader scrolls to this verse on arrival and pulses it —
    /// how following a thread lands you on the exact verse, not just the
    /// chapter.
    var focusVerse: Int? = nil
}

/// Destinations under the library/secondary nav umbrella. Lifted into an enum
/// so a single `navigationDestination(for:)` covers all of them.
enum LibraryRoute: Hashable {
    case highlights
    case notes
    /// Full-screen browser for typed notes — groups by book, searchable.
    /// Reachable from the reader's left-side library menu bubble.
    case notesBrowser
    /// Full-screen editor for a specific note. Reached by tapping a row in
    /// `notesBrowser` — keeps the editing experience uninterrupted from
    /// the reader (no jumping back to a chapter just to see one note).
    case noteEditor(UUID)
    case history
    case settings
    /// "Your threads in {Book}" — the thread-web constellation (design 8c).
    case threadWeb(Book)
}

/// Bundle of navigation actions a reader needs to drive the global
/// `NavigationStack`. Built once by `ContentView` (which owns the
/// `NavigationPath`) and threaded through the reader views, so any deeper
/// child (the library menu bubble, the chapter footer, etc.) can navigate
/// without each one knowing about the path internals.
struct ReaderNavigation {
    /// Replace the top of the stack with the next chapter (sequential
    /// reading without back-stack accumulation).
    let advance: (ChapterRoute) -> Void
    /// Pop everything — back to Home.
    let goHome: () -> Void
    /// Replace the stack with `[book]` so the user lands on that book's
    /// chapter selector.
    let openBook: (Book) -> Void
    /// Push the full-screen notes browser onto the current stack.
    let openNotesBrowser: () -> Void
    /// Push the full-screen editor for one note (e.g. from a margin dot or
    /// right after "Note" on the verse action menu).
    let openNote: (UUID) -> Void
    /// Push the thread web for a book.
    let openThreadWeb: (Book) -> Void
}
