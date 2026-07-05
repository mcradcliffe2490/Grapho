import Foundation
import SwiftUI

/// Single source of truth for `UserDefaults` / `@AppStorage` keys. All keys
/// live here so views can grab them via `AppStorage(...)` without inventing
/// stringly-typed identifiers ad hoc.
enum PreferenceKey {
    /// Slug of the active translation (e.g. "web", "niv").
    static let activeTranslation = "activeTranslation"

    /// Last-read book abbreviation (USFM 3-letter). Empty string before first read.
    static let lastBook = "lastBook"

    /// Last-read chapter number. 0 before first read.
    static let lastChapter = "lastChapter"

    /// Selected reading background palette — `BackgroundPalette.rawValue`.
    static let backgroundPalette = "backgroundPalette"

    /// Section-header rendering mode — `HeaderMode.rawValue`.
    static let headerMode = "headerMode"

    /// Last-used annotation layer — `LayerKind.rawValue`.
    static let activeLayerKind = "activeLayerKind"

    /// True if drawing requires Apple Pencil (finger scrolls instead of draws).
    static let pencilOnlyDraw = "pencilOnlyDraw"

    /// Reader's share of the Scholar reflow split (0.35–0.72); 1.0 = study
    /// pane collapsed to its thin edge.
    static let scholarSplitFraction = "scholarSplitFraction"

    /// App-wide reading practice — `ReadingMode.rawValue` (design turn 4).
    static let readingMode = "readingMode"

    /// True once the first-run "choose your practice" screen has been seen.
    static let hasChosenPractice = "hasChosenPractice"
}

/// Strongly-typed wrappers around the active reading position. We keep book
/// and chapter as separate primitives in `UserDefaults` (rather than encoding
/// a struct) so `@AppStorage` works naturally — storing a custom struct
/// requires a `RawRepresentable` indirection that buys us nothing here.
struct LastReadingPosition: Equatable {
    let book: Book
    let chapter: Int

    static func read() -> LastReadingPosition? {
        let defaults = UserDefaults.standard
        guard let bookRaw = defaults.string(forKey: PreferenceKey.lastBook),
              let book = Book(rawValue: bookRaw) else { return nil }
        let chapter = defaults.integer(forKey: PreferenceKey.lastChapter)
        guard chapter > 0 else { return nil }
        return LastReadingPosition(book: book, chapter: chapter)
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(book.rawValue, forKey: PreferenceKey.lastBook)
        defaults.set(chapter, forKey: PreferenceKey.lastChapter)
    }
}
