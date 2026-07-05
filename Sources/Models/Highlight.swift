import Foundation
import SwiftData

/// A colored highlight anchored to a verse. Offsets index into the verse's
/// flattened text, so a single (start, end) pair works identically for prose
/// and poetry. The owning layer determines visibility.
@Model
final class Highlight {
    @Attribute(.unique) var id: UUID
    var verseId: Int
    var startOffset: Int
    var endOffset: Int
    var colorRaw: String
    var layer: AnnotationLayer?

    init(
        id: UUID = UUID(),
        verseId: Int,
        startOffset: Int,
        endOffset: Int,
        color: HighlightColor,
        layer: AnnotationLayer? = nil
    ) {
        self.id = id
        self.verseId = verseId
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.colorRaw = color.rawValue
        self.layer = layer
    }

    var color: HighlightColor {
        get { HighlightColor(rawValue: colorRaw) ?? .yellow }
        set { colorRaw = newValue.rawValue }
    }
}
