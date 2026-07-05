import Foundation
import SwiftData

/// One annotation layer (Exegetical / Devotional / Thematic) for a specific
/// chapter of a specific translation. Created lazily on first annotation.
/// Holds its own `PKDrawing` data, plus owns its highlights and notes.
@Model
final class AnnotationLayer {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    /// Translation slug — scopes annotations so a different translation has
    /// independent layers, and re-importing the same translation reattaches.
    var translation: String
    /// Book abbreviation (USFM 3-letter) — see `Book.rawValue`.
    var book: String
    var chapter: Int
    /// Serialized `PKDrawing` for the inline reading-column drawing surface.
    /// Reserved for the post-MVP draw-on-text overlay; unused in v1.
    var pkDrawingData: Data
    /// Serialized `PKDrawing` for Scholar mode's right-pane scratchpad. Per
    /// design, the scratchpad is the v1 drawing surface — keeping it on the
    /// same model means switching layers swaps drawings the same way it
    /// swaps highlights and notes.
    var pkScratchpadData: Data = Data()

    @Relationship(deleteRule: .cascade, inverse: \Highlight.layer)
    var highlights: [Highlight]

    @Relationship(deleteRule: .cascade, inverse: \VerseNote.layer)
    var notes: [VerseNote]

    init(
        id: UUID = UUID(),
        kind: LayerKind,
        translation: String,
        book: String,
        chapter: Int,
        pkDrawingData: Data = Data(),
        pkScratchpadData: Data = Data(),
        highlights: [Highlight] = [],
        notes: [VerseNote] = []
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.translation = translation
        self.book = book
        self.chapter = chapter
        self.pkDrawingData = pkDrawingData
        self.pkScratchpadData = pkScratchpadData
        self.highlights = highlights
        self.notes = notes
    }

    var kind: LayerKind {
        get { LayerKind(rawValue: kindRaw) ?? .exegetical }
        set { kindRaw = newValue.rawValue }
    }
}
