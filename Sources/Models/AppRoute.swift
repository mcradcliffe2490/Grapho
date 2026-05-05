import Foundation

/// A specific chapter of a specific book — the destination type for a tap on
/// the chapter grid. Hashable so it can drive `NavigationStack`.
struct ChapterRoute: Hashable {
    let book: Book
    let chapter: Int
}

/// Destinations under the library/secondary nav umbrella. Lifted into an enum
/// so a single `navigationDestination(for:)` covers all of them.
enum LibraryRoute: Hashable {
    case highlights
    case notes
    /// Full-screen browser for typed notes — groups by book, searchable.
    /// Reachable from the reader's left-side library menu bubble.
    case notesBrowser
    case history
    case settings
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
}
