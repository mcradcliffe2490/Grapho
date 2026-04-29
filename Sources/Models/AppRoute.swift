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
    case history
    case settings
}
