import Foundation
import SwiftData

/// Paper mode's per-chapter page: one freeform `PKDrawing` laid over the
/// printed chapter, remembered exactly as the user left it (design turns
/// 3b/5a). Deliberately mode-independent — Paper has no study modes — so it
/// lives beside `AnnotationLayer` rather than on it.
@Model
final class PaperPage {
    @Attribute(.unique) var id: UUID
    var translation: String
    /// Book abbreviation (USFM 3-letter) — see `Book.rawValue`.
    var book: String
    var chapter: Int
    /// Serialized `PKDrawing`.
    var drawingData: Data
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        translation: String,
        book: String,
        chapter: Int,
        drawingData: Data = Data(),
        updatedAt: Date = .now
    ) {
        self.id = id
        self.translation = translation
        self.book = book
        self.chapter = chapter
        self.drawingData = drawingData
        self.updatedAt = updatedAt
    }
}
